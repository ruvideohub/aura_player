package O1;

import A0.j;
import B.C0039v;
import B.RunnableC0023l0;
import B.RunnableC0042y;
import D.C;
import D.F;
import E0.h;
import M0.m;
import N0.u;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Handler;
import android.widget.ImageView;
import g1.C0316b;
import g1.C0320f;
import g1.C0323i;
import g1.C0324j;
import g1.C0331q;
import g1.C0336w;
import g1.T;
import g1.r;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.net.URL;
import java.net.URLConnection;
import java.util.ArrayList;
import java.util.UUID;
import javax.net.ssl.HttpsURLConnection;
import m1.InterfaceC0449d;
import m1.f;
import syxme.lkmp.audio.modules.ModuleNative;
import syxme.lkmp.space.http.PostParams;
import w1.C0587c;
import z1.C0646p;
/* loaded from: classes.dex */
public final /* synthetic */ class a implements Runnable {

    /* renamed from: a  reason: collision with root package name */
    public final /* synthetic */ int f2601a;

    /* renamed from: b  reason: collision with root package name */
    public final /* synthetic */ Object f2602b;

    /* renamed from: c  reason: collision with root package name */
    public final /* synthetic */ Object f2603c;

    /* renamed from: d  reason: collision with root package name */
    public final /* synthetic */ Object f2604d;

    /* renamed from: e  reason: collision with root package name */
    public final /* synthetic */ Object f2605e;

    /* renamed from: f  reason: collision with root package name */
    public final /* synthetic */ Object f2606f;

    public /* synthetic */ a(u uVar, File file, String str, String str2, C0039v c0039v) {
        this.f2601a = 1;
        this.f2604d = uVar;
        this.f2602b = file;
        this.f2603c = str;
        this.f2605e = str2;
        this.f2606f = c0039v;
    }

    @Override // java.lang.Runnable
    public final void run() {
        Bitmap bitmap;
        String l02;
        switch (this.f2601a) {
            case 0:
                d dVar = (d) this.f2604d;
                dVar.f2614b.getClass();
                Bitmap E2 = A1.b.E((File) this.f2602b, ((e) this.f2605e).f2621b);
                if (E2 != null) {
                    F f2 = dVar.f2613a;
                    String str = (String) this.f2603c;
                    f2.g(E2, str);
                    dVar.f2619g.post(new N1.c((Object) dVar, (Object) ((ImageView) this.f2606f), str, (Object) E2, 1));
                    return;
                }
                return;
            case 1:
                File file = (File) this.f2602b;
                String str2 = (String) this.f2603c;
                u uVar = (u) this.f2604d;
                try {
                    URLConnection openConnection = new URL(str2).openConnection();
                    h.c(openConnection, "null cannot be cast to non-null type javax.net.ssl.HttpsURLConnection");
                    HttpsURLConnection httpsURLConnection = (HttpsURLConnection) openConnection;
                    httpsURLConnection.setConnectTimeout(10000);
                    httpsURLConnection.setReadTimeout(10000);
                    httpsURLConnection.setInstanceFollowRedirects(true);
                    bitmap = BitmapFactory.decodeStream(httpsURLConnection.getInputStream());
                    httpsURLConnection.disconnect();
                    h.b(bitmap);
                    try {
                        FileOutputStream fileOutputStream = new FileOutputStream(file);
                        try {
                            bitmap.compress(Bitmap.CompressFormat.JPEG, 90, fileOutputStream);
                            fileOutputStream.close();
                        } catch (Throwable th) {
                            try {
                                throw th;
                            } catch (Throwable th2) {
                                V0.d.l(fileOutputStream, th);
                                throw th2;
                            }
                        }
                    } catch (IOException e2) {
                        e2.printStackTrace();
                    }
                } catch (Exception e3) {
                    e3.printStackTrace();
                    bitmap = null;
                }
                Bitmap bitmap2 = bitmap;
                Handler handler = (Handler) uVar.f2245c;
                String str3 = (String) this.f2605e;
                C0039v c0039v = (C0039v) this.f2606f;
                if (bitmap2 != null) {
                    handler.post(new N1.c(uVar, str3, c0039v, bitmap2, 2));
                    return;
                } else {
                    handler.post(new RunnableC0042y(c0039v, str3, 7));
                    return;
                }
            case ModuleNative.API /* 2 */:
                C0316b c0316b = (C0316b) this.f2604d;
                C0331q c0331q = (C0331q) this.f2602b;
                C0324j c0324j = (C0324j) this.f2605e;
                l1.d dVar2 = (l1.d) this.f2603c;
                C0646p c0646p = (C0646p) this.f2606f;
                File file2 = new File(c0316b.f5479a.getCacheDir(), "live-stem-" + UUID.randomUUID());
                file2.mkdirs();
                try {
                    File[] listFiles = c0316b.f5479a.getCacheDir().listFiles();
                    if (listFiles != null) {
                        ArrayList arrayList = new ArrayList();
                        for (File file3 : listFiles) {
                            if (!h.a(file3, file2) && file3.isDirectory()) {
                                String name = file3.getName();
                                h.d(name, "getName(...)");
                                if (m.X(name, "live-stem-", false)) {
                                    arrayList.add(file3);
                                }
                            }
                        }
                        int size = arrayList.size();
                        int i2 = 0;
                        while (i2 < size) {
                            Object obj = arrayList.get(i2);
                            i2++;
                            File file4 = (File) obj;
                            h.b(file4);
                            j.P(file4);
                        }
                    }
                    C c2 = c0331q.f5547b;
                    r q2 = c2.q();
                    if (q2 != null) {
                        c2.M(q2);
                        c0316b.f5484f = "Проверка доступа…";
                        new C0323i(c0316b.f5479a).a(c0324j, C0336w.n(dVar2));
                        File file5 = new File(c0316b.f5479a.getFilesDir(), "audios");
                        if (!file5.exists()) {
                            file5.mkdirs();
                        }
                        File file6 = new File(file5, "_vk_" + dVar2.a());
                        if (file6.isFile()) {
                            l02 = file6.getAbsolutePath();
                        } else {
                            l02 = M0.e.l0(dVar2.f6269w, "?siren=1");
                        }
                        String str4 = l02;
                        h.b(str4);
                        if (!M0.e.g0(str4)) {
                            Context context = c0316b.f5479a;
                            String str5 = c0316b.f5483e;
                            int i3 = dVar2.f6261o;
                            if (i3 < 1) {
                                i3 = 1;
                            }
                            c0316b.f5480b.post(new RunnableC0023l0(c0316b, c0646p, new C0320f(context, file2, str4, q2, str5, i3 * 44100), 10));
                            return;
                        }
                        throw new IllegalArgumentException("Ссылка на трек недоступна");
                    }
                    throw new IllegalStateException("Сначала загрузите модуль");
                } catch (Exception e4) {
                    j.P(file2);
                    synchronized (c0331q) {
                        c0331q.f5551f = false;
                        c0331q.d("Обработка во время воспроизведения выключена");
                        c0316b.f5480b.post(new RunnableC0023l0(c0316b, e4, c0646p, 11));
                        return;
                    }
                }
            case 3:
                f fVar = (f) this.f2604d;
                String str6 = (String) this.f2603c;
                PostParams postParams = (PostParams) this.f2602b;
                Handler handler2 = (Handler) this.f2605e;
                C0587c c0587c = (C0587c) this.f2606f;
                try {
                    handler2.post(new T(c0587c, fVar.i(str6, postParams), 7));
                    return;
                } catch (L1.a e5) {
                    handler2.post(new T(c0587c, e5, 8));
                    return;
                } catch (Exception e6) {
                    handler2.post(new T(c0587c, e6, 9));
                    return;
                }
            default:
                f fVar2 = (f) this.f2604d;
                String str7 = (String) this.f2603c;
                PostParams postParams2 = (PostParams) this.f2602b;
                Handler handler3 = (Handler) this.f2605e;
                C0587c c0587c2 = (C0587c) this.f2606f;
                try {
                    handler3.post(new T(c0587c2, fVar2.a(str7, postParams2), 12));
                    return;
                } catch (L1.a e7) {
                    handler3.post(new T(c0587c2, e7, 13));
                    return;
                } catch (Exception e8) {
                    handler3.post(new T(c0587c2, e8, 3));
                    return;
                }
        }
    }

    public /* synthetic */ a(Object obj, Object obj2, Object obj3, Object obj4, Object obj5, int i2) {
        this.f2601a = i2;
        this.f2604d = obj;
        this.f2602b = obj2;
        this.f2605e = obj3;
        this.f2603c = obj4;
        this.f2606f = obj5;
    }

    public /* synthetic */ a(f fVar, String str, PostParams postParams, Handler handler, InterfaceC0449d interfaceC0449d, int i2) {
        this.f2601a = i2;
        this.f2604d = fVar;
        this.f2603c = str;
        this.f2602b = postParams;
        this.f2605e = handler;
        this.f2606f = interfaceC0449d;
    }
}
