package com.recessclub.ads;

import android.app.Activity;
import android.util.Log;

import androidx.annotation.NonNull;

import com.android.billingclient.api.AcknowledgePurchaseParams;
import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.ConsumeParams;
import com.android.billingclient.api.PendingPurchasesParams;
import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.QueryProductDetailsParams;
import com.android.billingclient.api.QueryPurchasesParams;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Compras do Recess Club pela Google Play (Passe do Recreio = assinatura mensal).
 * Godot chama: connect_billing, query_product(id), purchase(id), query_purchases(), acknowledge(token).
 * Respostas por sinais (sempre na thread do Godot).
 */
public class RecessBilling extends GodotPlugin implements PurchasesUpdatedListener {
    private static final String TAG = "RecessBilling";
    private BillingClient client;
    private ProductDetails details;
    /** Produtos avulsos (diamantes, moedas): id -> detalhes. */
    private final Map<String, ProductDetails> inapp = new HashMap<>();

    public RecessBilling(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "RecessBilling";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> s = new HashSet<>();
        s.add(new SignalInfo("billing_ready"));
        s.add(new SignalInfo("billing_error", Integer.class, String.class));
        s.add(new SignalInfo("product_info", String.class, String.class));       // id, preço formatado
        s.add(new SignalInfo("purchase_ok", String.class, String.class, Boolean.class)); // id, token, já reconhecida
        s.add(new SignalInfo("purchase_failed", Integer.class, String.class));
        s.add(new SignalInfo("purchases_done"));
        return s;
    }

    private void emit(String name, Object... args) {
        runOnRenderThread(() -> emitSignal(name, args));
    }

    @UsedByGodot
    public void connect_billing() {
        Activity a = getActivity();
        if (a == null) return;
        if (client == null) {
            client = BillingClient.newBuilder(a)
                    .setListener(this)
                    .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
                    .build();
        }
        if (client.isReady()) {
            emit("billing_ready");
            return;
        }
        client.startConnection(new BillingClientStateListener() {
            @Override
            public void onBillingSetupFinished(@NonNull BillingResult r) {
                if (r.getResponseCode() == BillingClient.BillingResponseCode.OK) emit("billing_ready");
                else emit("billing_error", r.getResponseCode(), r.getDebugMessage());
            }

            @Override
            public void onBillingServiceDisconnected() {
                emit("billing_error", -1, "desconectado");
            }
        });
    }

    @UsedByGodot
    public void query_product(String productId) {
        if (client == null || !client.isReady()) return;
        QueryProductDetailsParams p = QueryProductDetailsParams.newBuilder()
                .setProductList(Collections.singletonList(QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(productId).setProductType(BillingClient.ProductType.SUBS).build()))
                .build();
        client.queryProductDetailsAsync(p, (r, list) -> {
            if (r.getResponseCode() != BillingClient.BillingResponseCode.OK || list.isEmpty()) {
                emit("billing_error", r.getResponseCode(), "produto não encontrado");
                return;
            }
            details = list.get(0);
            String price = "";
            List<ProductDetails.SubscriptionOfferDetails> offers = details.getSubscriptionOfferDetails();
            if (offers != null && !offers.isEmpty()) {
                List<ProductDetails.PricingPhase> phases = offers.get(0).getPricingPhases().getPricingPhaseList();
                if (!phases.isEmpty()) price = phases.get(phases.size() - 1).getFormattedPrice();
            }
            emit("product_info", productId, price);
        });
    }

    @UsedByGodot
    public void purchase(String productId) {
        Activity a = getActivity();
        if (client == null || !client.isReady() || a == null || details == null || !details.getProductId().equals(productId)) {
            emit("purchase_failed", -1, "loja indisponível");
            return;
        }
        List<ProductDetails.SubscriptionOfferDetails> offers = details.getSubscriptionOfferDetails();
        if (offers == null || offers.isEmpty()) {
            emit("purchase_failed", -2, "sem oferta");
            return;
        }
        BillingFlowParams.ProductDetailsParams pd = BillingFlowParams.ProductDetailsParams.newBuilder()
                .setProductDetails(details).setOfferToken(offers.get(0).getOfferToken()).build();
        BillingFlowParams fp = BillingFlowParams.newBuilder().setProductDetailsParamsList(Collections.singletonList(pd)).build();
        a.runOnUiThread(() -> client.launchBillingFlow(a, fp));
    }

    /** Produtos avulsos, ids separados por vírgula. Responde product_info para cada um. */
    @UsedByGodot
    public void query_inapp(String idsCsv) {
        if (client == null || !client.isReady()) return;
        List<QueryProductDetailsParams.Product> list = new ArrayList<>();
        for (String id : idsCsv.split(",")) {
            if (id.trim().isEmpty()) continue;
            list.add(QueryProductDetailsParams.Product.newBuilder().setProductId(id.trim())
                    .setProductType(BillingClient.ProductType.INAPP).build());
        }
        if (list.isEmpty()) return;
        client.queryProductDetailsAsync(QueryProductDetailsParams.newBuilder().setProductList(list).build(), (r, found) -> {
            if (r.getResponseCode() != BillingClient.BillingResponseCode.OK) return;
            for (ProductDetails d : found) {
                inapp.put(d.getProductId(), d);
                ProductDetails.OneTimePurchaseOfferDetails o = d.getOneTimePurchaseOfferDetails();
                emit("product_info", d.getProductId(), o != null ? o.getFormattedPrice() : "");
            }
        });
    }

    @UsedByGodot
    public void purchase_inapp(String productId) {
        Activity a = getActivity();
        ProductDetails d = inapp.get(productId);
        if (client == null || !client.isReady() || a == null || d == null) {
            emit("purchase_failed", -1, "loja indisponível");
            return;
        }
        BillingFlowParams.ProductDetailsParams pd = BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(d).build();
        BillingFlowParams fp = BillingFlowParams.newBuilder().setProductDetailsParamsList(Collections.singletonList(pd)).build();
        a.runOnUiThread(() -> client.launchBillingFlow(a, fp));
    }

    /** Diamantes/moedas já entregues: consome a compra (pode comprar de novo). */
    @UsedByGodot
    public void consume(String token) {
        if (client == null || !client.isReady()) return;
        client.consumeAsync(ConsumeParams.newBuilder().setPurchaseToken(token).build(),
                (r, t) -> Log.d(TAG, "consume " + r.getResponseCode()));
    }

    /** Compras avulsas que ficaram sem entregar (o app fechou no meio). */
    @UsedByGodot
    public void query_inapp_purchases() {
        if (client == null || !client.isReady()) return;
        client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build(),
                (r, list) -> {
                    if (r.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                        for (Purchase p : list) report(p);
                    }
                });
    }

    @UsedByGodot
    public void query_purchases() {
        if (client == null || !client.isReady()) return;
        client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build(),
                (r, list) -> {
                    if (r.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                        for (Purchase p : list) report(p);
                    }
                    emit("purchases_done");
                });
    }

    @UsedByGodot
    public void acknowledge(String token) {
        if (client == null || !client.isReady()) return;
        client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(token).build(),
                r -> Log.d(TAG, "ack " + r.getResponseCode()));
    }

    private void report(Purchase p) {
        if (p.getPurchaseState() != Purchase.PurchaseState.PURCHASED) return;
        for (String id : p.getProducts()) emit("purchase_ok", id, p.getPurchaseToken(), p.isAcknowledged());
    }

    @Override
    public void onPurchasesUpdated(@NonNull BillingResult r, List<Purchase> list) {
        if (r.getResponseCode() == BillingClient.BillingResponseCode.OK && list != null) {
            for (Purchase p : list) report(p);
        } else {
            emit("purchase_failed", r.getResponseCode(), r.getDebugMessage());
        }
    }
}
