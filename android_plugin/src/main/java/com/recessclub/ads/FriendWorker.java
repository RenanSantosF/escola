package com.recessclub.ads;

import android.content.Context;
import android.content.SharedPreferences;

import androidx.annotation.NonNull;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;

/** A cada ~15 min: "fulano está jogando agora!" (só amigos aceitos, só se o jogo estiver fechado). */
public class FriendWorker extends Worker {
    public FriendWorker(@NonNull Context c, @NonNull WorkerParameters p) {
        super(c, p);
    }

    @NonNull
    @Override
    public Result doWork() {
        Context c = getApplicationContext();
        SharedPreferences p = c.getSharedPreferences(RecessNotify.PREFS, Context.MODE_PRIVATE);
        String base = p.getString("base", "");
        String token = p.getString("token", "");
        if (base.isEmpty() || token.isEmpty() || !p.getBoolean("friends", true) || p.getBoolean("foreground", false)) return Result.success();
        try {
            HttpURLConnection h = (HttpURLConnection) new URL(base + "/api/friends/online").openConnection();
            h.setRequestProperty("Authorization", "Bearer " + token);
            h.setConnectTimeout(8000);
            h.setReadTimeout(8000);
            if (h.getResponseCode() != 200) return Result.success();
            StringBuilder sb = new StringBuilder();
            BufferedReader r = new BufferedReader(new InputStreamReader(h.getInputStream(), "UTF-8"));
            String line;
            while ((line = r.readLine()) != null) sb.append(line);
            JSONArray list = new JSONObject(sb.toString()).optJSONArray("online");
            if (list == null || list.length() == 0) {
                p.edit().putString("last", "").apply();
                return Result.success();
            }
            // só avisa quem acabou de entrar (não repete o mesmo aviso)
            String last = p.getString("last", "");
            StringBuilder now = new StringBuilder();
            String first = null;
            for (int i = 0; i < list.length(); i++) {
                String n = list.getJSONObject(i).optString("name", "");
                now.append(n).append(",");
                if (first == null && !last.contains(n + ",")) first = n;
            }
            p.edit().putString("last", now.toString()).apply();
            if (first != null) {
                String more = list.length() > 1 ? " (e mais " + (list.length() - 1) + ")" : "";
                NotifyReceiver.post(c, 77, first + " está jogando agora!" + more, "Entre no Recess Club e brinque junto no recreio.");
            }
        } catch (Exception e) {
            return Result.success();
        }
        return Result.success();
    }
}
