package N1;

import B.C0007d0;
import B.C0039v;
import B.RunnableC0042y;
import D0.l;
import E0.h;
import I1.q;
import N0.u;
import S1.C0135k1;
import S1.L;
import android.content.Context;
import android.graphics.Bitmap;
import android.widget.ImageView;
import b0.C0222t;
import b0.C0227y;
import j1.i;
import java.util.ArrayList;
import java.util.Iterator;
import l1.f;
import l1.g;
import l1.n;
import org.json.JSONObject;
import r1.C0551c;
import r1.k;
import syxme.lkmp.Main;
import syxme.lkmp.audio.modules.ModuleNative;
import syxme.lkmp.space.http.PostParams;
/* loaded from: classes.dex */
public final /* synthetic */ class c implements Runnable {

    /* renamed from: a  reason: collision with root package name */
    public final /* synthetic */ int f2283a;

    /* renamed from: b  reason: collision with root package name */
    public final /* synthetic */ Object f2284b;

    /* renamed from: c  reason: collision with root package name */
    public final /* synthetic */ Object f2285c;

    /* renamed from: d  reason: collision with root package name */
    public final /* synthetic */ Object f2286d;

    /* renamed from: e  reason: collision with root package name */
    public final /* synthetic */ Object f2287e;

    public /* synthetic */ c(Object obj, Object obj2, Object obj3, Object obj4, int i2) {
        this.f2283a = i2;
        this.f2285c = obj;
        this.f2284b = obj2;
        this.f2286d = obj3;
        this.f2287e = obj4;
    }

    /* JADX WARN: Type inference failed for: r2v0, types: [java.lang.Object, b0.C] */
    @Override // java.lang.Runnable
    public final void run() {
        Object obj;
        Object obj2 = this.f2287e;
        ?? r2 = this.f2284b;
        Object obj3 = this.f2286d;
        Object obj4 = this.f2285c;
        switch (this.f2283a) {
            case 0:
                e eVar = (e) obj4;
                eVar.f2305k.post(new RunnableC0042y((a) obj2, eVar.e((String) r2, (PostParams) obj3), 5));
                return;
            case 1:
                ImageView imageView = (ImageView) obj3;
                if (h.a(((O1.d) obj4).f2617e.get(imageView), (String) r2)) {
                    imageView.setImageBitmap((Bitmap) obj2);
                    return;
                }
                return;
            case ModuleNative.API /* 2 */:
                String str = (String) r2;
                if (h.a(((u) obj4).f2243a, str)) {
                    ((C0039v) obj3).k((Bitmap) obj2, str);
                    return;
                }
                return;
            case 3:
                C0135k1 c0135k1 = (C0135k1) obj4;
                c0135k1.u(false, false);
                d dVar = (d) obj3;
                boolean z2 = c0135k1.f3537B;
                L l2 = c0135k1.f3538C;
                if (z2) {
                    if (dVar.f2289b.has("response")) {
                        ArrayList arrayList = new ArrayList();
                        ArrayList arrayList2 = k.f6794a;
                        JSONObject jSONObject = dVar.f2289b.getJSONObject("response");
                        h.d(jSONObject, "getJSONObject(...)");
                        l1.h c02 = C0007d0.c0(jSONObject, arrayList);
                        Context context = c0135k1.f2738o;
                        h.c(context, "null cannot be cast to non-null type syxme.lkmp.Main");
                        Main main = (Main) context;
                        q qVar = (q) ((e) main.n().f6411f).f2302h.f6021a;
                        f fVar = c02.f6310s;
                        int i2 = qVar.f1582c;
                        g gVar = new g(i2, qVar.f1580a + ' ' + qVar.f1581b, "profile", qVar.f1586g, "");
                        fVar.getClass();
                        fVar.f6278d = gVar;
                        i.h(((n) main.f6860g.f701g).f6337a, 0, c02);
                        l2.b(true);
                        c0135k1.n();
                        return;
                    }
                    return;
                }
                l1.h hVar = c0135k1.f3536A;
                hVar.getClass();
                String str2 = (String) r2;
                h.e(str2, "<set-?>");
                hVar.f6294c = str2;
                String str3 = (String) obj2;
                h.e(str3, "<set-?>");
                hVar.f6300i = str3;
                c0135k1.y();
                c0135k1.n();
                if (dVar.f2289b.has("response")) {
                    l2.b(true);
                    return;
                }
                return;
            case 4:
                r2.d(((F.f) obj4).f1238a, (C0227y) obj3, (C0222t) obj2);
                return;
            case 5:
                if (((Boolean) ((D0.a) obj4).b()).booleanValue()) {
                    i iVar = ((n) ((Main) r2).f6860g.f702h).f6337a;
                    Iterator it = iVar.f6013f.iterator();
                    while (true) {
                        if (it.hasNext()) {
                            obj = it.next();
                            if (h.a(((l1.h) obj).f6286C, "PHONE")) {
                            }
                        } else {
                            obj = null;
                        }
                    }
                    l1.h hVar2 = (l1.h) obj;
                    if (hVar2 == null) {
                        hVar2 = new l1.h("PHONE", "Музыка с телефона");
                        iVar.g(hVar2);
                    }
                    hVar2.f6294c = "Музыка с телефона";
                    hVar2.f6291H = 2;
                    hVar2.f6312u = "offline";
                    hVar2.f6287D = true;
                    i.s(hVar2.f6315x, (ArrayList) obj3);
                    ((l) obj2).a(Boolean.TRUE);
                    return;
                }
                return;
            case 6:
                if (h.a(((e) ((m1.f) obj4).f6411f).f2301g.f2015b, (String) r2)) {
                    ((l) obj3).a((C0551c) obj2);
                    return;
                }
                return;
            default:
                if (((Boolean) ((D0.a) obj4).b()).booleanValue() && ((e) ((m1.f) obj3).f6411f).f2301g.f2015b.equals((String) r2)) {
                    ((D0.a) obj2).b();
                    return;
                }
                return;
        }
    }

    public /* synthetic */ c(Object obj, Object obj2, String str, Object obj3, int i2) {
        this.f2283a = i2;
        this.f2285c = obj;
        this.f2286d = obj2;
        this.f2284b = str;
        this.f2287e = obj3;
    }
}
