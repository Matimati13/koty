import shutil

base = "koty/app/src/main/"
j = base + "java/pl/koty/app/"

shutil.copy("Fighter.java", j + "Fighter.java")
shutil.copy("BattleActivity.java", j + "BattleActivity.java")

# manifest
m = base + "AndroidManifest.xml"
t = open(m, encoding="utf-8").read()
cam = '<uses-feature android:name="android.hardware.camera" android:required="false"/>'
assert cam in t, "manifest: brak uses-feature"
t = t.replace(cam, cam + '''
    <uses-feature android:name="android.hardware.bluetooth" android:required="false"/>
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>''', 1)
assert "</application>" in t
t = t.replace("</application>", '''<activity android:name=".BattleActivity" android:exported="false" android:screenOrientation="portrait"/>
    </application>''', 1)
open(m, "w", encoding="utf-8").write(t)

# MainActivity
p = j + "MainActivity.java"
s = open(p, encoding="utf-8").read()


def rep(old, new):
    global s
    assert old in s, "Brak fragmentu: " + old
    s = s.replace(old, new, 1)


rep('''    TextView header, sub, empty, dateView;''',
    '''    TextView header, sub, empty, dateView, cdView;''')

rep('''        TextView rs = btn("🎲 Losuj statystyki");
        panel.addView(rs);
        rs.setOnClickListener(v -> {
            if (cur != null) {
                rollStats(cur.key);
                refreshBars();
            }
        });
''', '''        cdView = new TextView(this);
        cdView.setTextSize(14);
        cdView.setTextColor(MUTE);
        cdView.setPadding(dp(4), dp(16), 0, 0);
        panel.addView(cdView);
        TextView fight = btn("⚔️ Do bitwy!");
        fight.setBackground(round(YELLOW, 12));
        panel.addView(fight);
        fight.setOnClickListener(v -> startBattle());
''')

rep('''            sb.setMax(10);
''', '''            sb.setMax(10);
            sb.setOnTouchListener((v, ev) -> true);
''')

rep('''        for (int i = 0; i < 4; i++) ed.putInt(key + "|s" + i, 1 + rnd.nextInt(10));
''', '''        for (int i = 0; i < 4; i++) ed.putInt(key + "|s" + i, 1 + rnd.nextInt(10));
        ed.putBoolean(key + "|lk", true);
''')

rep('''        big.setImageDrawable(null);
        sv.scrollTo(0, 0);
''', '''        updateCd();
        big.setImageDrawable(null);
        sv.scrollTo(0, 0);
''')

rep('''                for (Cat k : list) {
                    String nm = prefs.getString(k.key + "|n", "");
''', '''                for (Cat k : list) {
                    if (!prefs.getBoolean(k.key + "|lk", false)) rollStats(k.key);
                    String nm = prefs.getString(k.key + "|n", "");
''')

rep('''    TextView btn(String t) {
''', '''    long cdLeft(String key) {
        return prefs.getLong(key + "|cd", 0) - System.currentTimeMillis();
    }

    String fmtMs(long ms) {
        long sec = (ms + 999) / 1000;
        return (sec / 60) + ":" + (sec % 60 < 10 ? "0" : "") + (sec % 60);
    }

    void updateCd() {
        if (cur == null || cdView == null) return;
        long l = cdLeft(cur.key);
        int w = prefs.getInt(cur.key + "|w", 0);
        int lo = prefs.getInt(cur.key + "|l", 0);
        String txt = (l > 0 ? "😴 Odpoczywa po walce: jeszcze " + fmtMs(l) : "Gotowy do walki")
            + "\\nWygrane: " + w + "   Porażki: " + lo;
        cdView.setText(txt);
    }

    @Override protected void onResume() {
        super.onResume();
        updateCd();
    }

    void startBattle() {
        if (cur == null) return;
        saveName();
        String nm = prefs.getString(cur.key + "|n", "");
        if (nm.isEmpty()) {
            Toast.makeText(this, "Najpierw nadaj kotu imię", Toast.LENGTH_SHORT).show();
            return;
        }
        if (cdLeft(cur.key) > 0) {
            Toast.makeText(this, "Kot jeszcze odpoczywa", Toast.LENGTH_SHORT).show();
            return;
        }
        Intent bi = new Intent(this, BattleActivity.class);
        bi.putExtra("key", cur.key);
        bi.putExtra("name", nm);
        bi.putExtra("uri", cur.uri.toString());
        for (int q = 0; q < 4; q++) bi.putExtra("s" + q, prefs.getInt(cur.key + "|s" + q, 5));
        startActivity(bi);
    }

    TextView btn(String t) {
''')

open(p, "w", encoding="utf-8").write(s)