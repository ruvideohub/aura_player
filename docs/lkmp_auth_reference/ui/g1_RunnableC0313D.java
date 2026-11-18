package g1;

import B.J0;
import android.os.Handler;
import android.util.Log;
import java.io.File;
import java.util.ArrayList;
import m1.C0448c;
import org.json.JSONObject;
import syxme.lkmp.space.http.PostParams;
import w1.C0587c;
/* renamed from: g1.D  reason: case insensitive filesystem */
/* loaded from: classes.dex */
public final /* synthetic */ class RunnableC0313D implements Runnable {

    /* renamed from: a  reason: collision with root package name */
    public final /* synthetic */ int f5360a;

    /* renamed from: b  reason: collision with root package name */
    public final /* synthetic */ Object f5361b;

    /* renamed from: c  reason: collision with root package name */
    public final /* synthetic */ Object f5362c;

    /* renamed from: d  reason: collision with root package name */
    public final /* synthetic */ Object f5363d;

    /* renamed from: e  reason: collision with root package name */
    public final /* synthetic */ Object f5364e;

    /* renamed from: f  reason: collision with root package name */
    public final /* synthetic */ Object f5365f;

    /* renamed from: g  reason: collision with root package name */
    public final /* synthetic */ Object f5366g;

    public /* synthetic */ RunnableC0313D(Object obj, Object obj2, Object obj3, Object obj4, Object obj5, Object obj6, int i2) {
        this.f5360a = i2;
        this.f5361b = obj;
        this.f5362c = obj2;
        this.f5363d = obj3;
        this.f5364e = obj4;
        this.f5365f = obj5;
        this.f5366g = obj6;
    }

    /* JADX WARN: Type inference failed for: r2v3, types: [java.lang.Object, E0.m] */
    @Override // java.lang.Runnable
    public final void run() {
        JSONObject optJSONObject;
        switch (this.f5360a) {
            case 0:
                L l2 = (L) this.f5361b;
                l1.d dVar = (l1.d) this.f5362c;
                File file = (File) this.f5363d;
                H h2 = (H) this.f5364e;
                C0331q c0331q = (C0331q) this.f5365f;
                C0324j c0324j = (C0324j) this.f5366g;
                try {
                    File[] listFiles = l2.f5408a.listFiles();
                    if (listFiles != null) {
                        ArrayList arrayList = new ArrayList();
                        int i2 = 0;
                        for (File file2 : listFiles) {
                            if (!E0.h.a(file2, file) && file2.isDirectory()) {
                                String name = file2.getName();
                                E0.h.d(name, "getName(...)");
                                if (M0.m.X(name, "work-", false)) {
                                    arrayList.add(file2);
                                }
                            }
                        }
                        int size = arrayList.size();
                        while (i2 < size) {
                            Object obj = arrayList.get(i2);
                            i2++;
                            File file3 = (File) obj;
                            E0.h.b(file3);
                            A0.j.P(file3);
                        }
                    }
                    int i3 = dVar.f6261o;
                    if (i3 < 30) {
                        i3 = 30;
                    }
                    if (file.getUsableSpace() > (i3 * 44100 * 24) + 67108864) {
                        try {
                            File A2 = V0.m.A(h2.f5385a, dVar, file, new G(2, h2, H.class, "update", "update(Ljava/lang/String;I)V", 1));
                            File file4 = new File(file, "original.f32");
                            ?? obj2 = new Object();
                            obj2.f1221f = -1;
                            C0336w.b(A2, file4, new S1.G(obj2, h2, 14));
                            if (file4.length() <= 536870912) {
                                if (E0.h.a(A2.getParentFile(), file)) {
                                    A2.delete();
                                }
                                h2.f5387c.post(new RunnableC0314E(h2, c0331q, c0324j, file4, file, dVar, l2, 0));
                                return;
                            }
                            throw new IllegalArgumentException("Трек слишком длинный для обработки");
                        } catch (Exception e2) {
                            e = e2;
                            h2 = h2;
                            H.b(file, h2, e);
                            return;
                        }
                    }
                    throw new IllegalArgumentException("Недостаточно места для обработки трека");
                } catch (Exception e3) {
                    e = e3;
                }
                break;
            case 1:
                m1.f fVar = (m1.f) this.f5361b;
                PostParams postParams = (PostParams) this.f5362c;
                String str = (String) this.f5363d;
                String str2 = (String) this.f5364e;
                Handler handler = (Handler) this.f5365f;
                final C0587c c0587c = (C0587c) this.f5366g;
                try {
                    String c2 = fVar.c();
                    C0448c c0448c = (C0448c) fVar.f6409d;
                    postParams.set("sid", c0448c.f6396a);
                    postParams.set("verification_method", str);
                    postParams.set("code", str2);
                    postParams.set("access_token", c2);
                    N1.d a2 = ((N1.e) fVar.f6411f).a(postParams);
                    if (a2.f2289b.has("error")) {
                        try {
                            JSONObject jSONObject = a2.f2289b.getJSONObject("error");
                            if (jSONObject.has("error_code") && jSONObject.getInt("error_code") == 14) {
                                throw new L1.a(new m1.h(R1.a.c(a2.f2289b, "captcha_img", ""), R1.a.c(a2.f2289b, "captcha_ratio", ""), R1.a.c(a2.f2289b, "captcha_sid", ""), R1.a.c(a2.f2289b, "captcha_ts", ""), R1.a.c(a2.f2289b, "redirect_uri", "")));
                            }
                        } catch (Exception unused) {
                        }
                        JSONObject jSONObject2 = a2.f2289b.getJSONObject("error");
                        E0.h.d(jSONObject2, "getJSONObject(...)");
                        throw new Exception(R1.a.c(jSONObject2, "error_text", ""));
                    }
                    if (a2.f2289b.has("response")) {
                        JSONObject jSONObject3 = a2.f2289b.getJSONObject("response");
                        if (jSONObject3.has("can_skip_password")) {
                            c0448c.f6401f = R1.a.a(jSONObject3, "can_skip_password");
                            c0448c.f6396a = R1.a.c(jSONObject3, "sid", "");
                        }
                    } else if (a2.f2289b.has("access_token")) {
                        final m1.g b2 = fVar.b(a2.f2289b);
                        handler.post(new Runnable() { // from class: m1.b
                            @Override // java.lang.Runnable
                            public final void run() {
                                switch (r3) {
                                    case 0:
                                        c0587c.a(b2);
                                        return;
                                    default:
                                        c0587c.a(b2);
                                        return;
                                }
                            }
                        });
                    }
                    if (!c0448c.f6401f) {
                        handler.post(new J0(26, c0587c));
                        return;
                    }
                    final m1.g a3 = fVar.a("", new PostParams());
                    handler.post(new Runnable() { // from class: m1.b
                        @Override // java.lang.Runnable
                        public final void run() {
                            switch (r3) {
                                case 0:
                                    c0587c.a(a3);
                                    return;
                                default:
                                    c0587c.a(a3);
                                    return;
                            }
                        }
                    });
                    return;
                } catch (L1.a e4) {
                    handler.post(new T(c0587c, e4, 10));
                    return;
                } catch (Exception e5) {
                    handler.post(new T(c0587c, e5, 11));
                    return;
                }
            default:
                m1.f fVar2 = (m1.f) this.f5361b;
                String str3 = (String) this.f5362c;
                PostParams postParams2 = (PostParams) this.f5363d;
                D0.l lVar = (D0.l) this.f5364e;
                Object obj3 = null;
                try {
                    N1.d e6 = ((N1.e) fVar2.f6411f).e(str3, postParams2);
                    if (!e6.f2288a && (optJSONObject = e6.f2289b.optJSONObject("response")) != null) {
                        obj3 = lVar.a(optJSONObject);
                    }
                } catch (Exception e7) {
                    Log.w("AudioCatalog", "Cannot read " + str3 + " response", e7);
                }
                ((Handler) this.f5365f).post(new T((D0.l) this.f5366g, obj3, 16));
                return;
        }
    }
}
