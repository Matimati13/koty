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
        versionCode 1
        versionName '1.0'
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
        <activity android:name=".MainActivity" android:exported="true">
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
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.provider.MediaStore;
import android.util.LruCache;
import android.util.Size;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.*;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends Activity {
    static final int REQ = 1;
    static final Uri BASE = MediaStore.Images.Media.EXTERNAL_CONTENT_URI;
    Uri pending;
    GridView grid;
    TextView header, empty;
    List<Uri> items = new ArrayList<>();
    LruCache<Long, Bitmap> cache = new LruCache<>(80);
    ExecutorService pool = Executors.newFixedThreadPool(3);
    BaseAdapter adapter;

    static class Sq extends ImageView {
        Sq(Context c) { super(c); }
        @Override protected void onMeasure(int w, int h) { super.onMeasure(w, w); }
    }

    int dp(float v) { return (int) (v * getResources().getDisplayMetrics().density); }

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        if (b != null) pending = b.getParcelable("p");
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(0xFFF3F1EC);
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        header = new TextView(this);
        header.setTextSize(26);
        header.setTypeface(Typeface.DEFAULT_BOLD);
        header.setTextColor(0xFF1C1F26);
        header.setPadding(dp(20), dp(20), dp(20), dp(12));
        grid = new GridView(this);
        grid.setNumColumns(3);
        grid.setHorizontalSpacing(dp(4));
        grid.setVerticalSpacing(dp(4));
        grid.setPadding(dp(4), dp(4), dp(4), dp(150));
        grid.setClipToPadding(false);
        col.addView(header);
        col.addView(grid, new LinearLayout.LayoutParams(-1, 0, 1f));
        root.addView(col, new FrameLayout.LayoutParams(-1, -1));

        empty = new TextView(this);
        empty.setText("Brak kotów w kolekcji.\nZobaczysz kota? Dotknij żółtego przycisku i zrób mu zdjęcie.");
        empty.setTextSize(17);
        empty.setTextColor(0xFF6B6F78);
        empty.setGravity(Gravity.CENTER);
        empty.setPadding(dp(32), dp(32), dp(32), dp(32));
        root.addView(empty, new FrameLayout.LayoutParams(-1, -1));

        TextView fab = new TextView(this);
        fab.setText("📷");
        fab.setTextSize(36);
        fab.setGravity(Gravity.CENTER);
        GradientDrawable g = new GradientDrawable();
        g.setShape(GradientDrawable.OVAL);
        g.setColor(0xFFF2B705);
        fab.setBackground(g);
        fab.setElevation(dp(6));
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(dp(96), dp(96), Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        lp.bottomMargin = dp(28);
        root.addView(fab, lp);
        fab.setOnClickListener(v -> shoot());
        setContentView(root);

        adapter = new BaseAdapter() {
            public int getCount() { return items.size(); }
            public Object getItem(int i) { return items.get(i); }
            public long getItemId(int i) { return i; }
            public View getView(int pos, View cv, ViewGroup parent) {
                final Sq iv = cv == null ? new Sq(MainActivity.this) : (Sq) cv;
                iv.setScaleType(ImageView.ScaleType.CENTER_CROP);
                iv.setBackgroundColor(0xFFE4E1D9);
                final Uri u = items.get(pos);
                final long id = ContentUris.parseId(u);
                iv.setTag(id);
                Bitmap bm = cache.get(id);
                if (bm != null) {
                    iv.setImageBitmap(bm);
                } else {
                    iv.setImageDrawable(null);
                    pool.execute(() -> {
                        try {
                            final Bitmap t = getContentResolver().loadThumbnail(u, new Size(320, 320), null);
                            cache.put(id, t);
                            runOnUiThread(() -> {
                                Object tag = iv.getTag();
                                if (tag != null && ((Long) tag).longValue() == id) iv.setImageBitmap(t);
                            });
                        } catch (Exception e) { }
                    });
                }
                return iv;
            }
        };
        grid.setAdapter(adapter);
        grid.setOnItemClickListener((p, v, pos, id) -> {
            Intent i = new Intent(Intent.ACTION_VIEW);
            i.setDataAndType(items.get(pos), "image/jpeg");
            i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            try { startActivity(i); } catch (Exception e) { }
        });
        grid.setOnItemLongClickListener((p, v, pos, id) -> {
            final Uri u = items.get(pos);
            new AlertDialog.Builder(this)
                .setMessage("Usunąć to zdjęcie?")
                .setPositiveButton("Usuń", (d, w) -> {
                    try { getContentResolver().delete(u, null, null); } catch (Exception e) { }
                    load();
                })
                .setNegativeButton("Anuluj", null)
                .show();
            return true;
        });
        load();
    }

    void shoot() {
        ContentValues v = new ContentValues();
        v.put(MediaStore.Images.Media.DISPLAY_NAME, "kot_" + System.currentTimeMillis() + ".jpg");
        v.put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg");
        v.put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Koty");
        pending = getContentResolver().insert(BASE, v);
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
                Toast.makeText(this, "Kot dodany do kolekcji", Toast.LENGTH_SHORT).show();
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
    }

    void load() {
        pool.execute(() -> {
            final List<Uri> list = new ArrayList<>();
            try (Cursor c = getContentResolver().query(BASE,
                    new String[]{MediaStore.Images.Media._ID},
                    MediaStore.Images.Media.RELATIVE_PATH + " LIKE ? AND " + MediaStore.Images.Media.SIZE + " > 0",
                    new String[]{"Pictures/Koty%"},
                    MediaStore.Images.Media.DATE_ADDED + " DESC")) {
                while (c != null && c.moveToNext()) list.add(ContentUris.withAppendedId(BASE, c.getLong(0)));
            } catch (Exception e) { }
            runOnUiThread(() -> {
                items.clear();
                items.addAll(list);
                adapter.notifyDataSetChanged();
                header.setText(list.isEmpty() ? "Moje koty" : "Moje koty (" + list.size() + ")");
                empty.setVisibility(list.isEmpty() ? View.VISIBLE : View.GONE);
            });
        });
    }
}
EOF
