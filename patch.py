p = "koty/app/src/main/java/pl/koty/app/MainActivity.java"
s = open(p, encoding="utf-8").read()


def rep(old, new):
    global s
    assert old in s, "Brak fragmentu: " + old
    s = s.replace(old, new, 1)


rep('''    static final int MUTE = 0xFF6B6F78;
''', '''    static final int MUTE = 0xFF6B6F78;
    static final String[] NAMES = {"Puszek", "Mruczek", "Filemon", "Behemot", "Garfield", "Bonifacy", "Zefirek", "Luna", "Fistaszek", "Pyza", "Mirabelka", "Kluska", "Szarek", "Tygrys", "Pantera", "Ciapek", "Wąsacz", "Figaro", "Bazyli", "Kajtek", "Rudzielec", "Oliwka", "Śnieżka", "Kiwi", "Parys", "Gacek", "Sfinks", "Pimpek", "Ciastek", "Ananas", "Wafelek", "Pączek", "Kefir", "Rysiek", "Zygzak", "Cezary", "Ziemniak", "Kapsel", "Mgiełka", "Burza"};
    java.util.Random rnd = new java.util.Random();
''')

rep('''        panel.addView(nameEdit, new LinearLayout.LayoutParams(-1, -2));
''', '''        panel.addView(nameEdit, new LinearLayout.LayoutParams(-1, -2));

        TextView rn = btn("🎲 Losuj imię");
        panel.addView(rn);
        rn.setOnClickListener(v -> {
            nameEdit.setText(NAMES[rnd.nextInt(NAMES.length)]);
            nameEdit.setSelection(nameEdit.getText().length());
            saveName();
        });
''')

rep('''        TextView del = new TextView(this);
''', '''        TextView rs = btn("🎲 Losuj statystyki");
        panel.addView(rs);
        rs.setOnClickListener(v -> {
            if (cur != null) {
                rollStats(cur.key);
                refreshBars();
            }
        });

        TextView del = new TextView(this);
''')

rep('''    void show(Cat c) {
''', '''    TextView btn(String t) {
        TextView b = new TextView(this);
        b.setText(t);
        b.setTextSize(15);
        b.setTextColor(INK);
        b.setGravity(Gravity.CENTER);
        b.setBackground(round(0xFFE4E1D9, 12));
        b.setPadding(dp(16), dp(10), dp(16), dp(10));
        LinearLayout.LayoutParams l = new LinearLayout.LayoutParams(-2, -2);
        l.topMargin = dp(8);
        b.setLayoutParams(l);
        return b;
    }

    void rollStats(String key) {
        SharedPreferences.Editor ed = prefs.edit();
        for (int i = 0; i < 4; i++) ed.putInt(key + "|s" + i, 1 + rnd.nextInt(10));
        ed.apply();
    }

    void refreshBars() {
        if (cur == null) return;
        for (int i = 0; i < 4; i++) {
            int v = prefs.getInt(cur.key + "|s" + i, 5);
            bars[i].setProgress(v);
            barLabels[i].setText(STATS[i] + ": " + v);
        }
    }

    void show(Cat c) {
''')

rep('''                openKey = pendingName;
''', '''                openKey = pendingName;
                rollStats(pendingName);
''')

open(p, "w", encoding="utf-8").write(s)