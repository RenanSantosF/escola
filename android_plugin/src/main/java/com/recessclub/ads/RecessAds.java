package com.recessclub.ads;

import android.app.Activity;
import android.util.Log;

import androidx.annotation.NonNull;

import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.RequestConfiguration;
import com.google.android.gms.ads.interstitial.InterstitialAd;
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Set;

/**
 * AdMob para o Recess Club (jogo infantil).
 * Sempre: tratamento para crianças (COPPA), menor de idade (GDPR/LGPD) e
 * conteúdo classificação G. Sem anúncios personalizados.
 * Godot chama: init_ads, load_*, show_*, is_*_ready. Respostas por sinais.
 */
public class RecessAds extends GodotPlugin {
    private static final String TAG = "RecessAds";
    private RewardedAd rewarded;
    private InterstitialAd interstitial;
    private boolean ready = false;
    private boolean rewardEarned = false;

    public RecessAds(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "RecessAds";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> s = new HashSet<>();
        s.add(new SignalInfo("initialized"));
        s.add(new SignalInfo("rewarded_loaded"));
        s.add(new SignalInfo("rewarded_failed_to_load", String.class));
        s.add(new SignalInfo("rewarded_closed", Boolean.class));
        s.add(new SignalInfo("interstitial_loaded"));
        s.add(new SignalInfo("interstitial_failed_to_load", String.class));
        s.add(new SignalInfo("interstitial_closed"));
        s.add(new SignalInfo("show_failed", String.class, String.class));
        return s;
    }

    /** Sinais sempre na thread do Godot (os callbacks do AdMob vêm da thread da interface). */
    private void emit(String name, Object... args) {
        runOnRenderThread(() -> emitSignal(name, args));
    }

    private void ui(Runnable r) {
        Activity a = getActivity();
        if (a != null) a.runOnUiThread(r);
    }

    @UsedByGodot
    public void init_ads(boolean childDirected, String maxRating) {
        ui(() -> {
            RequestConfiguration.Builder b = MobileAds.getRequestConfiguration().toBuilder();
            if (childDirected) {
                b.setTagForChildDirectedTreatment(RequestConfiguration.TAG_FOR_CHILD_DIRECTED_TREATMENT_TRUE);
                b.setTagForUnderAgeOfConsent(RequestConfiguration.TAG_FOR_UNDER_AGE_OF_CONSENT_TRUE);
            }
            String r = RequestConfiguration.MAX_AD_CONTENT_RATING_G;
            if ("PG".equals(maxRating)) r = RequestConfiguration.MAX_AD_CONTENT_RATING_PG;
            b.setMaxAdContentRating(r);
            MobileAds.setRequestConfiguration(b.build());
            MobileAds.initialize(getActivity(), status -> {
                ready = true;
                emit("initialized");
            });
        });
    }

    @UsedByGodot
    public boolean is_initialized() {
        return ready;
    }

    // ------------------------------------------------------------ premiado
    @UsedByGodot
    public void load_rewarded(String unit) {
        ui(() -> RewardedAd.load(getActivity(), unit, new AdRequest.Builder().build(), new RewardedAdLoadCallback() {
            @Override
            public void onAdLoaded(@NonNull RewardedAd ad) {
                rewarded = ad;
                emit("rewarded_loaded");
            }

            @Override
            public void onAdFailedToLoad(@NonNull LoadAdError e) {
                rewarded = null;
                Log.w(TAG, "rewarded: " + e.getMessage());
                emit("rewarded_failed_to_load", e.getCode() + ": " + e.getMessage());
            }
        }));
    }

    @UsedByGodot
    public boolean is_rewarded_ready() {
        return rewarded != null;
    }

    @UsedByGodot
    public void show_rewarded() {
        ui(() -> {
            RewardedAd ad = rewarded;
            if (ad == null) {
                emit("show_failed", "rewarded", "não carregado");
                return;
            }
            rewarded = null;
            rewardEarned = false;
            ad.setFullScreenContentCallback(new FullScreenContentCallback() {
                @Override
                public void onAdDismissedFullScreenContent() {
                    emit("rewarded_closed", rewardEarned);
                }

                @Override
                public void onAdFailedToShowFullScreenContent(@NonNull AdError e) {
                    emit("show_failed", "rewarded", e.getMessage());
                }
            });
            ad.show(getActivity(), item -> rewardEarned = true);
        });
    }

    // ---------------------------------------------------------- intersticial
    @UsedByGodot
    public void load_interstitial(String unit) {
        ui(() -> InterstitialAd.load(getActivity(), unit, new AdRequest.Builder().build(), new InterstitialAdLoadCallback() {
            @Override
            public void onAdLoaded(@NonNull InterstitialAd ad) {
                interstitial = ad;
                emit("interstitial_loaded");
            }

            @Override
            public void onAdFailedToLoad(@NonNull LoadAdError e) {
                interstitial = null;
                Log.w(TAG, "interstitial: " + e.getMessage());
                emit("interstitial_failed_to_load", e.getCode() + ": " + e.getMessage());
            }
        }));
    }

    @UsedByGodot
    public boolean is_interstitial_ready() {
        return interstitial != null;
    }

    @UsedByGodot
    public void show_interstitial() {
        ui(() -> {
            InterstitialAd ad = interstitial;
            if (ad == null) {
                emit("show_failed", "interstitial", "não carregado");
                return;
            }
            interstitial = null;
            ad.setFullScreenContentCallback(new FullScreenContentCallback() {
                @Override
                public void onAdDismissedFullScreenContent() {
                    emit("interstitial_closed");
                }

                @Override
                public void onAdFailedToShowFullScreenContent(@NonNull AdError e) {
                    emit("show_failed", "interstitial", e.getMessage());
                }
            });
            ad.show(getActivity());
        });
    }
}
