package com.recessclub.ads;

import android.Manifest;
import android.app.Activity;
import android.app.AlarmManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.work.Constraints;
import androidx.work.ExistingPeriodicWorkPolicy;
import androidx.work.NetworkType;
import androidx.work.PeriodicWorkRequest;
import androidx.work.WorkManager;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.concurrent.TimeUnit;

/**
 * Notificações do Recess Club:
 *  - lembretes agendados ("o recreio está te esperando") quando o jogo vai para segundo plano;
 *  - "fulano está jogando agora": um trabalho do Android (WorkManager, a cada ~15 min)
 *    pergunta ao servidor quais amigos estão online e avisa.
 */
public class RecessNotify extends GodotPlugin {
    static final String CHANNEL = "recess_club";
    static final String PREFS = "recess_notify";

    public RecessNotify(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "RecessNotify";
    }

    static void ensureChannel(Context c) {
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationManager nm = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm != null && nm.getNotificationChannel(CHANNEL) == null) {
                NotificationChannel ch = new NotificationChannel(CHANNEL, "Recess Club", NotificationManager.IMPORTANCE_DEFAULT);
                ch.setDescription("Amigos online e lembretes do recreio");
                nm.createNotificationChannel(ch);
            }
        }
    }

    @UsedByGodot
    public void request_permission() {
        Activity a = getActivity();
        if (a == null) return;
        ensureChannel(a);
        if (Build.VERSION.SDK_INT >= 33 && a.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            a.requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 4417);
        }
    }

    @UsedByGodot
    public void schedule(int id, String title, String text, int delaySeconds) {
        Activity a = getActivity();
        if (a == null) return;
        ensureChannel(a);
        AlarmManager am = (AlarmManager) a.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;
        am.set(AlarmManager.RTC, System.currentTimeMillis() + delaySeconds * 1000L, pending(a, id, title, text));
    }

    @UsedByGodot
    public void cancel(int id) {
        Activity a = getActivity();
        if (a == null) return;
        AlarmManager am = (AlarmManager) a.getSystemService(Context.ALARM_SERVICE);
        if (am != null) am.cancel(pending(a, id, "", ""));
    }

    @UsedByGodot
    public void show_now(int id, String title, String text) {
        Activity a = getActivity();
        if (a != null) NotifyReceiver.post(a, id, title, text);
    }

    /** Servidor e conta (token) para o trabalho que vê os amigos online. */
    @UsedByGodot
    public void set_account(String baseUrl, String token, boolean friendAlerts) {
        Activity a = getActivity();
        if (a == null) return;
        SharedPreferences p = a.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        p.edit().putString("base", baseUrl).putString("token", token).putBoolean("friends", friendAlerts).apply();
        WorkManager wm = WorkManager.getInstance(a);
        if (friendAlerts && !token.isEmpty()) {
            PeriodicWorkRequest w = new PeriodicWorkRequest.Builder(FriendWorker.class, 15, TimeUnit.MINUTES)
                    .setConstraints(new Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                    .build();
            wm.enqueueUniquePeriodicWork("recess_friends", ExistingPeriodicWorkPolicy.UPDATE, w);
        } else {
            wm.cancelUniqueWork("recess_friends");
        }
    }

    /** O jogo está aberto: não precisa avisar de amigos (ele mesmo mostra). */
    @UsedByGodot
    public void set_foreground(boolean on) {
        Activity a = getActivity();
        if (a == null) return;
        a.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean("foreground", on).apply();
    }

    private PendingIntent pending(Context c, int id, String title, String text) {
        Intent i = new Intent(c, NotifyReceiver.class);
        i.putExtra("id", id);
        i.putExtra("title", title);
        i.putExtra("text", text);
        return PendingIntent.getBroadcast(c, id, i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }
}
