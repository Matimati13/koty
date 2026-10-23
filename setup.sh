set -e
mkdir -p koty/app/src/main/java/pl/koty/app
cd koty

cat > settings.gradle <<'EOF'
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositories { google(); mavenCentral() } }
rootProject.name = 'Koty'
include ':app'
EOF

cat > build.gradle <<'EOF'
plugins { id 'com.android.application' version '8.5.2' apply false }
EOF

cat > gradle.properties <<'EOF'
org.gradle.jvmargs=-Xmx2g
EOF

cat > app/build.gradle <<'EOF'
plugins { id 'com.android.application' }
android {
    namespace 'pl.koty.app'
    compileSdk 34
    defaultConfig {
        applicationId 'pl.koty.app'
        minSdk 29
        targetSdk 34
        versionCode 2
        versionName '1.1'
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}
EOF

cat > app/src/main/AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-feature android:name="android.hardware.camera" android:required="false"/>
    <application
        android:label="Koty"
        android:icon="@android:drawable/ic_menu_camera"
        android:allowBackup="false"
        android:theme="@android:style/Theme.DeviceDefault.Light.NoActionBar">
        <activity android:name=".MainActivity" android:exported="true"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

cat > app/src/main/java/pl/koty/app/MainActivity.java <<'EOF'
package pl.koty.app;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ContentUris;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.res.ColorStateList;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.ImageDecoder;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.provider.MediaStore;
import android.text.InputType;
import android.text.TextUtils;
import android.util.LruCache;
import android.util.Size;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.widget.*;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends Activity {
    static final int REQ = 1;
    static final Uri BASE = MediaStore.Images.Media.EXTERNAL_CONTENT_URI;
    static final String[] STATS = {"Puszystość", "Odwaga", "Przyjazność", "Leniwość"};
    static final int YELLOW = 0xFFF2B705;
    static final int INK = 0xFF1C1F26;
    static final int MUTE = 0xFF6B6F78;

    static class Cat {
        Uri uri;
        long id;
        String key;
        long added;
    }

    static class Cell extends FrameLayout {
        ImageView img;
        TextView label;
        long id;
        Cell(Context c) {
            super(c);
            float d = c.getResources().getDisplayMetrics().density;
            img = new ImageView(c);
            img.setScaleType(ImageView.ScaleType.CENTER_CROP);
            img.setBackgroundColor(0xFFE4E1D9);
            addView(img, new FrameLayout.LayoutParams(-1, -1));
            label = new TextView(c);
            label.setTextColor(0xFFFFFFFF);
            label.setTextSize(12);
            label.setSingleLine(true);
            label.setEllipsize(TextUtils.TruncateAt.END);
            label.setBackgroundColor(0x99000000);
            label.setPadding((int) (6 * d), (int) (3 * d), (int) (6 * d), (int) (3 * d));
            addView(label, new FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM));
        }
        @Override protected void onMeasure(int w, int h) { super.onMeasure(w, w); }
    }

    SharedPreferences prefs;
    Uri pending;
    String pendingName, openKey;
    GridView grid;
    TextView header, sub, empty, dateView;
    FrameLayout overlay;
    ScrollView sv;
    ImageView big;
    EditText nameEdit;
    SeekBar[] bars = new SeekBar[4];
    TextView[] barLabels = new TextView[4];
    Cat cur;
    List<Cat> items = new ArrayList<>();
    LruCache<Long, Bitmap> cache = new LruCache<>(80);
    ExecutorService pool = Executors.newFixedThreadPool(3);
    BaseAdapter adapter;

    int dp(float v) { return (int) (v * getResources().getDisplayMetrics().density); }

    GradientDrawable round(int color, float radiusDp) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(color);
        g.setCornerRadius(dp(radiusDp));
        return g;
    }

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        prefs = getSharedPreferences("cats", MODE_PRIVATE);
        if (b != null) {
            pending = b.getParcelable("p");
            pendingName = b.getString("pn");
        }
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(0xFFF3F1EC);

        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        header = new TextView(this);
        header.setTextSize(26);
        header.setTypeface(Typeface.DEFAULT_BOLD);
        header.setTextColor(INK);
        header.setPadding(dp(20), dp(20), dp(20), dp(2));
        sub = new TextView(this);
        sub.setTextSize(14);
        sub.setTextColor(MUTE);
        sub.setPadding(dp(20), 0, dp(20), dp(10));
        grid = new GridView(this);
        grid.setNumColumns(3);
        grid.setHorizontalSpacing(dp(4));
        grid.setVerticalSpacing(dp(4));
        grid.setPadding(dp(4), dp(4), dp(4), dp(150));
        grid.setClipToPadding(false);
        col.addView(header);
        col.addView(sub);
        col.addView(grid, new LinearLayout.LayoutParams(-1, 0, 1f));
        root.addView(col, new FrameLayout.LayoutParams(-1, -1));

        empty = new TextView(this);
        empty.setText("Brak kotów w kolekcji.\nZobaczysz kota? Dotknij żółtego przycisku i zrób mu zdjęcie.");
        empty.setTextSize(17);
        empty.setTextColor(MUTE);
        empty.setGravity(Gravity.CENTER);
        empty.setPadding(dp(32), dp(32), dp(32), dp(32));
        root.addView(empty, new FrameLayout.LayoutParams(-1, -1));

        TextView fab = new TextView(this);
        fab.setText("📷");
        fab.setTextSize(36);
        fab.setGravity(Gravity.CENTER);
        GradientDrawable g = new GradientDrawable();
        g.setShape(GradientDrawable.OVAL);
        g.setColor(YELLOW);
        fab.setBackground(g);
        fab.setElevation(dp(6));
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(dp(96), dp(96), Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        lp.bottomMargin = dp(28);
        root.addView(fab, lp);
        fab.setOnClickListener(v -> shoot());

        buildOverlay();
        root.addView(overlay, new FrameLayout.LayoutParams(-1, -1));
        setContentView(root);

        adapter = new BaseAdapter() {
            public int getCount() { return items.size(); }
            public Object getItem(int i) { return items.get(i); }
            public long getItemId(int i) { return i; }
            public View getView(int pos, View cv, ViewGroup parent) {
                final Cell cell = cv == null ? new Cell(MainActivity.this) : (Cell) cv;
                final Cat c = items.get(pos);
                cell.id = c.id;
                String nm = prefs.getString(c.key + "|n", "");
                if (nm.isEmpty()) {
                    cell.label.setVisibility(View.GONE);
                } else {
                    cell.label.setText(nm);
                    cell.label.setVisibility(View.VISIBLE);
                }
                Bitmap bm = cache.get(c.id);
                if (bm != null) {
                    cell.img.setImageBitmap(bm);
                } else {
                    cell.img.setImageDrawable(null);
                    pool.execute(() -> {
                        try {
                            final Bitmap t = getContentResolver().loadThumbnail(c.uri, new Size(320, 320), null);
                            cache.put(c.id, t);
                            runOnUiThread(() -> {
                                if (cell.id == c.id) cell.img.setImageBitmap(t);
                            });
                        } catch (Exception e) { }
                    });
                }
                return cell;
            }
        };
        grid.setAdapter(adapter);
        grid.setOnItemClickListener((p, v, pos, id) -> show(items.get(pos)));
        grid.setOnItemLongClickListener((p, v, pos, id) -> {
            confirmDelete(items.get(pos), false);
            return true;
        });
        load();
    }

    void buildOverlay() {
        overlay = new FrameLayout(this);
        overlay.setBackgroundColor(0xFFF3F1EC);
        overlay.setClickable(true);
        overlay.setVisibility(View.GONE);

        sv = new ScrollView(this);
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);

        big = new ImageView(this);
        big.setBackgroundColor(0xFF000000);
        big.setScaleType(ImageView.ScaleType.FIT_CENTER);
        int h = (int) (getResources().getDisplayMetrics().heightPixels * 0.5f);
        box.addView(big, new LinearLayout.LayoutParams(-1, h));

        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setPadding(dp(20), dp(18), dp(20), dp(32));

        nameEdit = new EditText(this);
        nameEdit.setHint("Imię kota");
        nameEdit.setTextSize(24);
        nameEdit.setTypeface(Typeface.DEFAULT_BOLD);
        nameEdit.setTextColor(INK);
        nameEdit.setHintTextColor(0xFFA5A8B0);
        nameEdit.setSingleLine(true);
        nameEdit.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        nameEdit.setImeOptions(EditorInfo.IME_ACTION_DONE);
        nameEdit.setOnEditorActionListener((tv, a, e) -> {
            saveName();
            hideKb();
            return true;
        });
        panel.addView(nameEdit, new LinearLayout.LayoutParams(-1, -2));

        dateView = new TextView(this);
        dateView.setTextSize(14);
        dateView.setTextColor(MUTE);
        dateView.setPadding(dp(4), dp(2), 0, dp(18));
        panel.addView(dateView);

        for (int i = 0; i < 4; i++) {
            final int idx = i;
            TextView lab = new TextView(this);
            lab.setTextSize(16);
            lab.setTextColor(INK);
            lab.setPadding(dp(4), dp(8), 0, 0);
            barLabels[i] = lab;
            panel.addView(lab);
            SeekBar sb = new SeekBar(this);
            sb.setMax(10);
            sb.setProgressTintList(ColorStateList.valueOf(YELLOW));
            sb.setThumbTintList(ColorStateList.valueOf(YELLOW));
            sb.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
                public void onProgressChanged(SeekBar s, int p, boolean fromUser) {
                    if (!fromUser || cur == null) return;
                    barLabels[idx].setText(STATS[idx] + ": " + p);
                    prefs.edit().putInt(cur.key + "|s" + idx, p).apply();
                }
                public void onStartTrackingTouch(SeekBar s) { }
                public void onStopTrackingTouch(SeekBar s) { }
            });
            bars[i] = sb;
            panel.addView(sb, new LinearLayout.LayoutParams(-1, -2));
        }

        TextView del = new TextView(this);
        del.setText("Usuń zdjęcie");
        del.setTextSize(16);
        del.setTextColor(0xFFC0392B);
        del.setGravity(Gravity.CENTER);
        del.setBackground(round(0xFFE4E1D9, 12));
        del.setPadding(dp(16), dp(14), dp(16), dp(14));
        LinearLayout.LayoutParams dlp = new LinearLayout.LayoutParams(-1, -2);
        dlp.topMargin = dp(28);
        panel.addView(del, dlp);
        del.setOnClickListener(v -> { if (cur != null) confirmDelete(cur, true); });

        box.addView(panel, new LinearLayout.LayoutParams(-1, -2));
        sv.addView(box, new ViewGroup.LayoutParams(-1, -2));
        overlay.addView(sv, new FrameLayout.LayoutParams(-1, -1));

        TextView x = new TextView(this);
        x.setText("✕");
        x.setTextSize(20);
        x.setTextColor(0xFFFFFFFF);
        x.setGravity(Gravity.CENTER);
        GradientDrawable xb = new GradientDrawable();
        xb.setShape(GradientDrawable.OVAL);
        xb.setColor(0x99000000);
        x.setBackground(xb);
        FrameLayout.LayoutParams xl = new FrameLayout.LayoutParams(dp(44), dp(44), Gravity.TOP | Gravity.RIGHT);
        xl.topMargin = dp(36);
        xl.rightMargin = dp(14);
        overlay.addView(x, xl);
        x.setOnClickListener(v -> close());
    }

    void show(Cat c) {
        cur = c;
        nameEdit.setText(prefs.getString(c.key + "|n", ""));
        for (int i = 0; i < 4; i++) {
            int v = prefs.getInt(c.key + "|s" + i, 5);
            bars[i].setProgress(v);
            barLabels[i].setText(STATS[i] + ": " + v);
        }
        dateView.setText("Znaleziony: " + new SimpleDateFormat("d MMMM yyyy, HH:mm", new Locale("pl", "PL")).format(new Date(c.added)));
        big.setImageDrawable(null);
        sv.scrollTo(0, 0);
        overlay.setVisibility(View.VISIBLE);
        final Cat target = c;
        pool.execute(() -> {
            try {
                final Bitmap bm = ImageDecoder.decodeBitmap(ImageDecoder.createSource(getContentResolver(), target.uri), (dec, info, src) -> {
                    int m = Math.max(info.getSize().getWidth(), info.getSize().getHeight());
                    dec.setTargetSampleSize(Math.max(1, m / 1600));
                    dec.setAllocator(ImageDecoder.ALLOCATOR_SOFTWARE);
                });
                runOnUiThread(() -> { if (cur == target) big.setImageBitmap(bm); });
            } catch (Exception e) { }
        });
    }

    void saveName() {
        if (cur != null) {
            prefs.edit().putString(cur.key + "|n", nameEdit.getText().toString().trim()).apply();
        }
    }

    void hideKb() {
        InputMethodManager imm = (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
        if (imm != null) imm.hideSoftInputFromWindow(nameEdit.getWindowToken(), 0);
        nameEdit.clearFocus();
    }

    void close() {
        saveName();
        hideKb();
        overlay.setVisibility(View.GONE);
        big.setImageDrawable(null);
        cur = null;
        load();
    }

    void confirmDelete(final Cat c, final boolean fromView) {
        new AlertDialog.Builder(this)
            .setMessage("Usunąć to zdjęcie?")
            .setPositiveButton("Usuń", (d, w) -> {
                try { getContentResolver().delete(c.uri, null, null); } catch (Exception e) { }
                SharedPreferences.Editor ed = prefs.edit();
                ed.remove(c.key + "|n");
                for (int i = 0; i < 4; i++) ed.remove(c.key + "|s" + i);
                ed.apply();
                if (fromView) {
                    hideKb();
                    overlay.setVisibility(View.GONE);
                    big.setImageDrawable(null);
                    cur = null;
                }
                load();
            })
            .setNegativeButton("Anuluj", null)
            .show();
    }

    @Override public void onBackPressed() {
        if (overlay.getVisibility() == View.VISIBLE) close();
        else super.onBackPressed();
    }

    @Override protected void onPause() {
        super.onPause();
        saveName();
    }

    void shoot() {
        String name = "kot_" + System.currentTimeMillis() + ".jpg";
        ContentValues v = new ContentValues();
        v.put(MediaStore.Images.Media.DISPLAY_NAME, name);
        v.put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg");
        v.put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Koty");
        pending = getContentResolver().insert(BASE, v);
        pendingName = name;
        if (pending == null) { Toast.makeText(this, "Nie można zapisać zdjęcia", Toast.LENGTH_SHORT).show(); return; }
        Intent i = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
        i.putExtra(MediaStore.EXTRA_OUTPUT, pending);
        i.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION | Intent.FLAG_GRANT_READ_URI_PERMISSION);
        try {
            startActivityForResult(i, REQ);
        } catch (Exception e) {
            try { getContentResolver().delete(pending, null, null); } catch (Exception x) { }
            pending = null;
            Toast.makeText(this, "Brak aplikacji aparatu", Toast.LENGTH_SHORT).show();
        }
    }

    @Override protected void onActivityResult(int req, int res, Intent data) {
        super.onActivityResult(req, res, data);
        if (req == REQ && pending != null) {
            if (res == RESULT_OK) {
                openKey = pendingName;
            } else {
                try { getContentResolver().delete(pending, null, null); } catch (Exception e) { }
            }
            pending = null;
            load();
        }
    }

    @Override protected void onSaveInstanceState(Bundle o) {
        super.onSaveInstanceState(o);
        if (pending != null) o.putParcelable("p", pending);
        if (pendingName != null) o.putString("pn", pendingName);
    }

    void load() {
        pool.execute(() -> {
            final List<Cat> list = new ArrayList<>();
            try (Cursor c = getContentResolver().query(BASE,
                    new String[]{MediaStore.Images.Media._ID, MediaStore.Images.Media.DISPLAY_NAME, MediaStore.Images.Media.DATE_ADDED},
                    MediaStore.Images.Media.RELATIVE_PATH + " LIKE ? AND " + MediaStore.Images.Media.SIZE + " > 0",
                    new String[]{"Pictures/Koty%"},
                    MediaStore.Images.Media.DATE_ADDED + " DESC")) {
                while (c != null && c.moveToNext()) {
                    Cat k = new Cat();
                    k.id = c.getLong(0);
                    k.key = c.getString(1);
                    k.added = c.getLong(2) * 1000L;
                    k.uri = ContentUris.withAppendedId(BASE, k.id);
                    list.add(k);
                }
            } catch (Exception e) { }
            runOnUiThread(() -> {
                items.clear();
                items.addAll(list);
                adapter.notifyDataSetChanged();
                header.setText(list.isEmpty() ? "Moje koty" : "Moje koty (" + list.size() + ")");
                empty.setVisibility(list.isEmpty() ? View.VISIBLE : View.GONE);
                int named = 0, best = -1;
                String bestName = "";
                for (Cat k : list) {
                    String nm = prefs.getString(k.key + "|n", "");
                    if (!nm.isEmpty()) named++;
                    if (prefs.contains(k.key + "|s1")) {
                        int v = prefs.getInt(k.key + "|s1", 5);
                        if (v > best) { best = v; bestName = nm.isEmpty() ? "bez imienia" : nm; }
                    }
                }
                if (list.isEmpty()) {
                    sub.setText("");
                    sub.setVisibility(View.GONE);
                } else {
                    String s = "Z imieniem: " + named + " z " + list.size();
                    if (best >= 0) s += "  •  Najodważniejszy: " + bestName + " (" + best + ")";
                    sub.setText(s);
                                       sub.setVisibility(View.VISIBLE);
                }
                if (openKey != null) {
                    for (Cat k : list) {
                        if (k.key.equals(openKey)) { show(k); break; }
                    }
                    openKey = null;
                }
            });
        });
    }
}
EOF
