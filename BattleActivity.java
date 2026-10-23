package pl.koty.app;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.AlertDialog;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothServerSocket;
import android.bluetooth.BluetoothSocket;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.res.ColorStateList;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.util.Size;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.widget.*;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

@SuppressLint("MissingPermission")
public class BattleActivity extends Activity {
    static final UUID ID = UUID.fromString("8f6c5a3e-2b7d-4c1e-9a55-3d2e7b1f0c42");
    static final long REST_MS = 10 * 60 * 1000L;
    static final int YELLOW = 0xFFF2B705;
    static final int INK = 0xFF1C1F26;
    static final int MUTE = 0xFF6B6F78;
    static final int CARD = 0xFFE4E1D9;

    SharedPreferences prefs;
    BluetoothAdapter bt;
    volatile BluetoothServerSocket server;
    volatile BluetoothSocket sock;
    DataOutputStream out;
    ExecutorService io = Executors.newSingleThreadExecutor();
    Fighter me, foe;
    Uri myUri;
    Bitmap myBmp;
    String myKey;
    int pendingAction;
    boolean myTurn, over, gone, inBattle, busy;

    FrameLayout root;
    LinearLayout setupBox, battleBox;
    TextView status, turnView, logView;
    ScrollView logScroll;
    ImageView myImg, foeImg;
    TextView myName, foeName, myHpTv, foeHpTv;
    ProgressBar myBar, foeBar;
    TextView[] skillBtns = new TextView[4];

    int dp(float v) { return (int) (v * getResources().getDisplayMetrics().density); }

    TextView tv(String t, int sp, int color, boolean bold) {
        TextView v = new TextView(this);
        v.setText(t);
        v.setTextSize(sp);
        v.setTextColor(color);
        if (bold) v.setTypeface(Typeface.DEFAULT_BOLD);
        return v;
    }

    TextView button(String t, boolean primary) {
        TextView b = tv(t, 17, INK, true);
        b.setGravity(Gravity.CENTER);
        GradientDrawable g = new GradientDrawable();
        g.setColor(primary ? YELLOW : CARD);
        g.setCornerRadius(dp(14));
        b.setBackground(g);
        b.setPadding(dp(16), dp(16), dp(16), dp(16));
        LinearLayout.LayoutParams l = new LinearLayout.LayoutParams(-1, -2);
        l.topMargin = dp(12);
        b.setLayoutParams(l);
        return b;
    }

    ProgressBar bar() {
        ProgressBar p = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        p.setProgressTintList(ColorStateList.valueOf(0xFF3BA55D));
        return p;
    }

    LinearLayout row(ImageView iv, TextView nm, ProgressBar pb, TextView hp) {
        LinearLayout r = new LinearLayout(this);
        r.setOrientation(LinearLayout.HORIZONTAL);
        r.setGravity(Gravity.CENTER_VERTICAL);
        r.setPadding(0, dp(8), 0, dp(8));
        iv.setScaleType(ImageView.ScaleType.CENTER_CROP);
        iv.setBackgroundColor(CARD);
        r.addView(iv, new LinearLayout.LayoutParams(dp(72), dp(72)));
        LinearLayout c = new LinearLayout(this);
        c.setOrientation(LinearLayout.VERTICAL);
        c.setPadding(dp(12), 0, 0, 0);
        nm.setTextSize(18);
        nm.setTypeface(Typeface.DEFAULT_BOLD);
        nm.setTextColor(INK);
        c.addView(nm);
        c.addView(pb, new LinearLayout.LayoutParams(-1, dp(14)));
        hp.setTextSize(13);
        hp.setTextColor(MUTE);
        c.addView(hp);
        r.addView(c, new LinearLayout.LayoutParams(0, -2, 1f));
        return r;
    }

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        prefs = getSharedPreferences("cats", MODE_PRIVATE);
        Intent it = getIntent();
        myKey = it.getStringExtra("key");
        myUri = Uri.parse(it.getStringExtra("uri"));
        int[] st = new int[4];
        for (int i = 0; i < 4; i++) st[i] = it.getIntExtra("s" + i, 5);
        me = new Fighter(it.getStringExtra("name"), st);
        bt = BluetoothAdapter.getDefaultAdapter();
        build();
        if (bt == null) status.setText("Ten telefon nie ma Bluetooth.");
    }

    void build() {
        root = new FrameLayout(this);
        root.setBackgroundColor(0xFFF3F1EC);

        setupBox = new LinearLayout(this);
        setupBox.setOrientation(LinearLayout.VERTICAL);
        setupBox.setPadding(dp(24), dp(40), dp(24), dp(24));
        setupBox.addView(tv("⚔️ Bitwa kotów", 26, INK, true));
        TextView who = tv(me.name + "  •  HP " + me.maxHp, 18, INK, false);
        who.setPadding(0, dp(8), 0, dp(8));
        setupBox.addView(who);
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 4; i++) {
            sb.append(Fighter.SKILLS[i]).append(": ").append(Fighter.describe(i, me.st));
            sb.append(Fighter.CD[i] > 0 ? " (odnowienie " + Fighter.CD[i] + ")" : "").append("\n");
        }
        setupBox.addView(tv(sb.toString(), 14, MUTE, false));
        TextView btnHost = button("Utwórz pokój", true);
        btnHost.setOnClickListener(v -> go(1));
        setupBox.addView(btnHost);
        TextView btnJoin = button("Dołącz do rywala", true);
        btnJoin.setOnClickListener(v -> go(2));
        setupBox.addView(btnJoin);
        TextView btnPair = button("Sparuj telefony (ustawienia Bluetooth)", false);
        btnPair.setOnClickListener(v -> startActivity(new Intent(Settings.ACTION_BLUETOOTH_SETTINGS)));
        setupBox.addView(btnPair);
        status = tv("Najpierw sparuj oba telefony. Potem jeden gracz tworzy pokój, a drugi do niego dołącza.", 15, MUTE, false);
        status.setPadding(0, dp(18), 0, 0);
        setupBox.addView(status);

        battleBox = new LinearLayout(this);
        battleBox.setOrientation(LinearLayout.VERTICAL);
        battleBox.setPadding(dp(16), dp(24), dp(16), dp(16));
        battleBox.setVisibility(View.GONE);
        foeImg = new ImageView(this);
        foeName = new TextView(this);
        foeBar = bar();
        foeHpTv = new TextView(this);
        myImg = new ImageView(this);
        myName = new TextView(this);
        myBar = bar();
        myHpTv = new TextView(this);
        battleBox.addView(row(foeImg, foeName, foeBar, foeHpTv));
        turnView = tv("", 16, INK, true);
        turnView.setGravity(Gravity.CENTER);
        turnView.setPadding(0, dp(10), 0, dp(6));
        battleBox.addView(turnView);
        logView = tv("", 14, MUTE, false);
        logScroll = new ScrollView(this);
        logScroll.addView(logView);
        battleBox.addView(logScroll, new LinearLayout.LayoutParams(-1, 0, 1f));
        battleBox.addView(row(myImg, myName, myBar, myHpTv));
        LinearLayout g1 = new LinearLayout(this);
        LinearLayout g2 = new LinearLayout(this);
        for (int i = 0; i < 4; i++) {
            final int k = i;
            TextView b = tv("", 14, INK, true);
            b.setGravity(Gravity.CENTER);
            GradientDrawable g = new GradientDrawable();
            g.setColor(YELLOW);
            g.setCornerRadius(dp(14));
            b.setBackground(g);
            b.setPadding(dp(10), dp(12), dp(10), dp(12));
            b.setOnClickListener(v -> use(k));
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, -2, 1f);
            lp.setMargins(dp(4), dp(4), dp(4), dp(4));
            skillBtns[i] = b;
            (i < 2 ? g1 : g2).addView(b, lp);
        }
        battleBox.addView(g1);
        battleBox.addView(g2);

        root.addView(setupBox, new FrameLayout.LayoutParams(-1, -1));
        root.addView(battleBox, new FrameLayout.LayoutParams(-1, -1));
        setContentView(root);
    }

    void go(int a) {
        pendingAction = a;
        if (bt == null) return;
        if (Build.VERSION.SDK_INT >= 31 && checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.BLUETOOTH_CONNECT}, 7);
            return;
        }
        if (!bt.isEnabled()) {
            startActivityForResult(new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE), 8);
            return;
        }
        if (a == 1) startHost(); else pickRival();
    }

    @Override public void onRequestPermissionsResult(int rc, String[] p, int[] r) {
        super.onRequestPermissionsResult(rc, p, r);
        if (rc == 7) {
            if (r.length > 0 && r[0] == PackageManager.PERMISSION_GRANTED) go(pendingAction);
            else status.setText("Bitwy wymagają zgody na Bluetooth.");
        }
    }

    @Override protected void onActivityResult(int rc, int res, Intent d) {
        super.onActivityResult(rc, res, d);
        if (rc == 8) {
            if (bt != null && bt.isEnabled()) go(pendingAction);
            else status.setText("Włącz Bluetooth, żeby walczyć.");
        }
    }

    void startHost() {
        if (busy) return;
        busy = true;
        status.setText("Czekam na rywala… Drugi gracz wybiera „Dołącz do rywala”.");
        new Thread(() -> {
            try {
                server = bt.listenUsingRfcommWithServiceRecord("KotyBitwa", ID);
                sock = server.accept();
                try { server.close(); } catch (Exception e) { }
                play(true);
            } catch (Exception e) {
                fail();
            }
        }).start();
    }

    void pickRival() {
        if (busy) return;
        Set<BluetoothDevice> set = bt.getBondedDevices();
        if (set == null || set.isEmpty()) {
            status.setText("Brak sparowanych urządzeń. Najpierw sparuj telefony.");
            return;
        }
        final List<BluetoothDevice> list = new ArrayList<>(set);
        String[] names = new String[list.size()];
        for (int i = 0; i < names.length; i++) {
            String n = list.get(i).getName();
            names[i] = n != null ? n : list.get(i).getAddress();
        }
        new AlertDialog.Builder(this)
            .setTitle("Wybierz telefon rywala")
            .setItems(names, (d, w) -> connect(list.get(w)))
            .show();
    }

    void connect(final BluetoothDevice dev) {
        busy = true;
        status.setText("Łączę z rywalem…");
        new Thread(() -> {
            try {
                bt.cancelDiscovery();
                sock = dev.createRfcommSocketToServiceRecord(ID);
                sock.connect();
                play(false);
            } catch (Exception e) {
                fail();
            }
        }).start();
    }

    byte[] thumbBytes() {
        try {
            myBmp = getContentResolver().loadThumbnail(myUri, new Size(200, 200), null);
            ByteArrayOutputStream bo = new ByteArrayOutputStream();
            myBmp.compress(Bitmap.CompressFormat.JPEG, 70, bo);
            return bo.toByteArray();
        } catch (Exception e) {
            return new byte[0];
        }
    }

    void play(boolean isHost) {
        try {
            DataInputStream din = new DataInputStream(sock.getInputStream());
            out = new DataOutputStream(sock.getOutputStream());
            byte[] ph = thumbBytes();
            out.writeUTF(me.name);
            for (int i = 0; i < 4; i++) out.writeInt(me.st[i]);
            out.writeInt(ph.length);
            out.write(ph);
            out.flush();
            String n = din.readUTF();
            int[] s = new int[4];
            for (int i = 0; i < 4; i++) s[i] = Math.max(1, Math.min(10, din.readInt()));
            int len = din.readInt();
            if (len < 0 || len > 300000) throw new java.io.IOException("bad");
            byte[] pb = new byte[len];
            din.readFully(pb);
            if (n.length() > 24) n = n.substring(0, 24);
            Fighter f = new Fighter(n, s);
            f.photo = pb;
            final boolean first = me.st[1] != f.st[1] ? me.st[1] > f.st[1] : isHost;
            foe = f;
            prefs.edit().putLong(myKey + "|cd", System.currentTimeMillis() + REST_MS).apply();
            runOnUiThread(() -> startBattle(first));
            while (true) {
                final int sk = din.readInt();
                runOnUiThread(() -> {
                    if (!over && !myTurn && sk >= 0 && sk < 4 && foe.cd[sk] == 0) turn(foe, me, sk);
                });
            }
        } catch (Exception e) {
            fail();
        }
    }

    void startBattle(boolean first) {
        inBattle = true;
        setupBox.setVisibility(View.GONE);
        battleBox.setVisibility(View.VISIBLE);
        myName.setText(me.name);
        foeName.setText(foe.name);
        if (myBmp != null) myImg.setImageBitmap(myBmp);
        if (foe.photo.length > 0) foeImg.setImageBitmap(BitmapFactory.decodeByteArray(foe.photo, 0, foe.photo.length));
        myTurn = first;
        (first ? me : foe).startTurn();
        log("Walka: " + me.name + " kontra " + foe.name + "!");
        log((first ? me.name : foe.name) + " zaczyna (większa odwaga).");
        refresh();
    }

    void use(final int k) {
        if (!inBattle || over || !myTurn || me.cd[k] > 0) return;
        io.execute(() -> {
            try {
                out.writeInt(k);
                out.flush();
            } catch (Exception e) {
                fail();
            }
        });
        turn(me, foe, k);
    }

    void turn(Fighter a, Fighter d, int sk) {
        log(a.use(sk, d));
        if (d.hp <= 0) {
            finishBattle(a == me);
            return;
        }
        myTurn = (a == foe);
        (myTurn ? me : foe).startTurn();
        refresh();
    }

    void finishBattle(boolean won) {
        over = true;
        myTurn = false;
        String k = myKey + (won ? "|w" : "|l");
        prefs.edit().putInt(k, prefs.getInt(k, 0) + 1).apply();
        log(won ? "🏆 " + me.name + " wygrywa!" : "💥 " + me.name + " przegrywa…");
        refresh();
        new AlertDialog.Builder(this)
            .setTitle(won ? "Wygrana!" : "Porażka")
            .setMessage(me.name + " odpoczywa 10 minut.")
            .setPositiveButton("OK", null)
            .show();
    }

    void refresh() {
        myBar.setMax(me.maxHp);
        myBar.setProgress(me.hp);
        myHpTv.setText(me.hp + " / " + me.maxHp + (me.shield > 0 ? "   🛡 −" + me.shield + "%" : ""));
        foeBar.setMax(foe.maxHp);
        foeBar.setProgress(foe.hp);
        foeHpTv.setText(foe.hp + " / " + foe.maxHp + (foe.shield > 0 ? "   🛡 −" + foe.shield + "%" : ""));
        turnView.setText(over ? "Koniec walki" : (myTurn ? "Twoja tura" : "Tura rywala…"));
        for (int i = 0; i < 4; i++) {
            skillBtns[i].setText(Fighter.SKILLS[i] + "\n" + Fighter.describe(i, me.st) + (me.cd[i] > 0 ? "\n⏳ " + me.cd[i] : ""));
            boolean ok = myTurn && !over && me.cd[i] == 0;
            skillBtns[i].setAlpha(ok ? 1f : 0.4f);
        }
    }

    void log(String s) {
        logView.append(s + "\n");
        logScroll.post(() -> logScroll.fullScroll(View.FOCUS_DOWN));
    }

    void fail() {
        runOnUiThread(() -> {
            if (gone || over) return;
            busy = false;
            if (inBattle) {
                over = true;
                myTurn = false;
                log("Połączenie przerwane.");
                refresh();
            } else {
                closeAll();
                status.setText("Nie udało się połączyć. Upewnij się, że telefony są sparowane i rywal czeka w pokoju.");
            }
        });
    }

    void closeAll() {
        try { if (sock != null) sock.close(); } catch (Exception e) { }
        try { if (server != null) server.close(); } catch (Exception e) { }
    }

    @Override public void onBackPressed() {
        if (inBattle && !over) {
            new AlertDialog.Builder(this)
                .setMessage("Poddać walkę?")
                .setPositiveButton("Poddaj się", (d, w) -> {
                    prefs.edit().putInt(myKey + "|l", prefs.getInt(myKey + "|l", 0) + 1).apply();
                    over = true;
                    finish();
                })
                .setNegativeButton("Walcz dalej", null)
                .show();
        } else {
            super.onBackPressed();
        }
    }

    @Override protected void onDestroy() {
        gone = true;
        closeAll();
        io.shutdownNow();
        super.onDestroy();
    }
}