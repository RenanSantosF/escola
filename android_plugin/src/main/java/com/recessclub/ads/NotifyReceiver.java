package com.recessclub.ads;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

/** Mostra a notificação agendada (e abre o jogo ao tocar). */
public class NotifyReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context c, Intent i) {
        post(c, i.getIntExtra("id", 1), i.getStringExtra("title"), i.getStringExtra("text"));
    }

    static void post(Context c, int id, String title, String text) {
        if (title == null || title.isEmpty()) return;
        RecessNotify.ensureChannel(c);
        NotificationManager nm = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null) return;
        Intent open = c.getPackageManager().getLaunchIntentForPackage(c.getPackageName());
        PendingIntent pi = open == null ? null : PendingIntent.getActivity(c, 0, open, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
        Notification.Builder b = Build.VERSION.SDK_INT >= 26 ? new Notification.Builder(c, RecessNotify.CHANNEL) : new Notification.Builder(c);
        b.setContentTitle(title).setContentText(text).setAutoCancel(true)
                .setSmallIcon(c.getApplicationInfo().icon);
        if (pi != null) b.setContentIntent(pi);
        try {
            nm.notify(id, b.build());
        } catch (SecurityException e) {
            // sem permissão de notificação (Android 13+): fica quieto
        }
    }
}
