package N1;

import B.C0007d0;
import B1.C0044a;
import D.C;
import D0.l;
import I1.f;
import N0.o;
import N0.q;
import N0.s;
import N0.u;
import N0.w;
import N0.y;
import S1.C0117e1;
import S1.D0;
import S1.E0;
import S1.G;
import S1.H;
import S1.L0;
import S1.O1;
import S1.Q1;
import V0.m;
import android.content.Context;
import android.graphics.drawable.ColorDrawable;
import android.widget.TextView;
import android.widget.Toast;
import androidx.recyclerview.widget.RecyclerView;
import f1.C0299a;
import f1.C0302d;
import f1.C0303e;
import f1.C0307i;
import j1.k;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.regex.Pattern;
import java.util.zip.GZIPInputStream;
import l.ViewTreeObserver$OnPreDrawListenerC0404k;
import org.json.JSONArray;
import org.json.JSONObject;
import q0.C0520d;
import r0.AbstractC0544j;
import r1.C0549a;
import r1.C0550b;
import r1.C0551c;
import syxme.lkmp.Main;
import syxme.lkmp.audio.modules.ModuleNative;
import syxme.lkmp.space.http.PostParams;
import t1.h;
import t1.i;
import v1.z;
import z1.AbstractServiceC0650u;
/* loaded from: classes.dex */
public final /* synthetic */ class b implements l {

    /* renamed from: f  reason: collision with root package name */
    public final /* synthetic */ int f2279f;

    /* renamed from: g  reason: collision with root package name */
    public final /* synthetic */ Object f2280g;

    /* renamed from: h  reason: collision with root package name */
    public final /* synthetic */ Object f2281h;

    /* renamed from: i  reason: collision with root package name */
    public final /* synthetic */ Object f2282i;

    public /* synthetic */ b(int i2, Object obj, Object obj2, String str) {
        this.f2279f = i2;
        this.f2280g = obj;
        this.f2282i = obj2;
        this.f2281h = str;
    }

    /* JADX WARN: Multi-variable type inference failed */
    /* JADX WARN: Type inference failed for: r11v4, types: [java.lang.Object, java.lang.Iterable] */
    /* JADX WARN: Type inference failed for: r4v0 */
    /* JADX WARN: Type inference failed for: r4v1, types: [boolean, int] */
    /* JADX WARN: Type inference failed for: r4v5 */
    @Override // D0.l
    public final Object a(Object obj) {
        M1.e eVar;
        String m2;
        l1.d dVar;
        k kVar;
        Object obj2 = null;
        h hVar = null;
        r3 = null;
        C0549a c0549a = null;
        ?? r4 = 1;
        boolean z2 = false;
        z2 = false;
        Object obj3 = this.f2281h;
        Object obj4 = this.f2280g;
        Object obj5 = this.f2282i;
        switch (this.f2279f) {
            case 0:
                String str = (String) obj3;
                PostParams postParams = (PostParams) obj5;
                f fVar = (f) obj;
                E0.h.e(fVar, "it");
                e eVar2 = (e) obj4;
                M1.d dVar2 = eVar2.f2301g;
                Context context = eVar2.f2295a;
                try {
                    postParams.set("access_token", dVar2.f2014a);
                    postParams.set("lang", "ru");
                    postParams.set("v", "5.276");
                    postParams.set("https", "1");
                    C0007d0 c0007d0 = e.f2293m;
                    postParams.set("device_id", A.b.y(context));
                    String pull = postParams.pull();
                    Pattern pattern = q.f2184c;
                    C.k r2 = V0.d.r(pull, m.q("application/x-www-form-urlencoded; charset=utf-8"));
                    u uVar = new u();
                    uVar.d("https://api.vk.ru/method/" + str);
                    uVar.c("POST", r2);
                    uVar.b("Cache-Control", "no-cache");
                    uVar.b("Accept", "image/webp");
                    uVar.b("Accept-Encoding", "gzip");
                    uVar.b("User-Agent", A.b.x(context));
                    uVar.b("X-VK-Android-Client", "new");
                    C.e a2 = uVar.a();
                    s sVar = eVar2.f2300f;
                    sVar.getClass();
                    w c2 = new R0.h(sVar, a2).c();
                    C.e eVar3 = c2.f2261f;
                    boolean a3 = E0.h.a(w.j(c2, "Content-Encoding"), "gzip");
                    y yVar = c2.f2267l;
                    if (a3) {
                        E0.h.b(yVar);
                        m2 = A.b.L(new BufferedReader(new InputStreamReader(new GZIPInputStream(yVar.l().i()), M0.a.f1992a), 8192));
                    } else {
                        E0.h.b(yVar);
                        m2 = yVar.m();
                    }
                    String str2 = m2;
                    new JSONObject(str2);
                    E0.h.e(e.f2293m, "cookie");
                    eVar = new M1.e(str2, ((o) eVar3.f843b).f2182h, M1.b.f2010b, c2.f2264i, M1.a.f2008b, false);
                } catch (Exception e2) {
                    e2.printStackTrace();
                    eVar = new M1.e("ERROR", "", new M1.b(), 0, new M1.a(), true);
                }
                String str3 = eVar.f2018a;
                if (eVar.f2023f) {
                    return new d(true, new JSONObject(), 10, 8);
                }
                try {
                    JSONObject jSONObject = new JSONObject(str3);
                    if (jSONObject.has("execute_errors")) {
                        JSONArray jSONArray = jSONObject.getJSONArray("execute_errors");
                        int length = jSONArray.length();
                        for (int i2 = 0; i2 < length; i2++) {
                            JSONObject jSONObject2 = jSONArray.getJSONObject(i2);
                            StringBuilder sb = new StringBuilder();
                            sb.append("API:ERROR = ");
                            E0.h.b(jSONObject2);
                            sb.append(R1.a.c(jSONObject2, "error_msg", ""));
                            System.out.println((Object) sb.toString());
                        }
                        z2 = true;
                    } else if (jSONObject.has("error")) {
                        int i3 = jSONObject.getJSONObject("error").getInt("error_code");
                        if (i3 == 1117 && eVar2.h()) {
                            int i4 = fVar.f1547b;
                            if (i4 < 3) {
                                fVar.f1547b = i4 + 1;
                                obj2 = fVar.f1546a.a(fVar);
                            }
                            return (d) obj2;
                        } else if (i3 > 0) {
                            return new d(true, new JSONObject(str3), i3, 8);
                        }
                    }
                    return new d(z2, jSONObject, 6, 8);
                } catch (Exception e3) {
                    e3.printStackTrace();
                    return new d(true, new JSONObject(), 5, 8);
                }
            case 1:
                float floatValue = ((Float) obj).floatValue();
                if (floatValue < 1.0f) {
                    r4 = 0;
                }
                E0.k kVar2 = (E0.k) obj4;
                if (kVar2.f1219f != r4) {
                    kVar2.f1219f = r4;
                    ((C0044a) ((C.e) obj3).f847f).j(r4, "sheetSurface");
                }
                ((ColorDrawable) obj5).setAlpha(m.H(V0.d.n((floatValue - 0.8f) / 0.2f, 0.0f, 1.0f) * 255));
                return q0.h.f6590c;
            case ModuleNative.API /* 2 */:
                String str4 = (String) obj;
                E0.h.e(str4, "title");
                C0303e c0303e = (C0303e) obj4;
                String e4 = c0303e.f5302b.e(str4, null);
                if (e4 != null) {
                    return e4;
                }
                c0303e.a(new G(str4, (C0299a) obj5, 0));
                Toast.makeText(((H) obj3).f3155a, "Пресет добавлен в библиотеку", 0).show();
                return null;
            case 3:
                C0551c c0551c = (C0551c) obj;
                L0 l02 = (L0) obj4;
                if (!l02.f2743t) {
                    Main main = l02.f3192C;
                    if (!main.isDestroyed()) {
                        E0 e02 = (E0) obj3;
                        e02.f3135e = false;
                        TextView textView = e02.f3133c;
                        if (c0551c == null) {
                            e02.f3136f = true;
                            textView.setText("Не удалось загрузить · Повторить");
                            textView.setEnabled(true);
                        } else {
                            HashSet hashSet = e02.f3137g;
                            hashSet.add((C0549a) obj5);
                            C0549a c0549a2 = c0551c.f6761e;
                            if (c0549a2 != null && !hashSet.contains(c0549a2)) {
                                c0549a = c0549a2;
                            }
                            e02.f3134d = c0549a;
                            textView.setVisibility(8);
                            l1.h hVar2 = e02.f3131a;
                            ArrayList arrayList = hVar2.f6315x.f6013f;
                            HashSet hashSet2 = new HashSet();
                            int size = arrayList.size();
                            int i5 = 0;
                            while (i5 < size) {
                                Object obj6 = arrayList.get(i5);
                                i5++;
                                hashSet2.add(((l1.d) obj6).f6254h);
                            }
                            ArrayList arrayList2 = new ArrayList();
                            ArrayList arrayList3 = c0551c.f6760d;
                            int size2 = arrayList3.size();
                            int i6 = 0;
                            while (i6 < size2) {
                                Object obj7 = arrayList3.get(i6);
                                i6++;
                                r0.q.v(((C0550b) obj7).f6753d, arrayList2);
                            }
                            ArrayList arrayList4 = new ArrayList();
                            int size3 = arrayList2.size();
                            int i7 = 0;
                            while (i7 < size3) {
                                Object obj8 = arrayList2.get(i7);
                                i7++;
                                if (hashSet2.add(((l1.d) obj8).f6254h)) {
                                    arrayList4.add(obj8);
                                }
                            }
                            hVar2.a(arrayList4);
                            AbstractServiceC0650u abstractServiceC0650u = main.f6877r;
                            if (abstractServiceC0650u != null) {
                                abstractServiceC0650u.h().l(hVar2);
                            }
                            RecyclerView recyclerView = e02.f3132b;
                            ViewTreeObserver$OnPreDrawListenerC0404k.a(recyclerView, new D0(recyclerView, e02, 0));
                        }
                    }
                }
                return q0.h.f6590c;
            case 4:
                C0302d c0302d = (C0302d) obj;
                E0.h.e(c0302d, "$this$change");
                String str5 = c0302d.a((String) obj3, (C0307i) obj4).f5289a;
                ((C0117e1) obj5).f3472D = str5;
                c0302d.f(str5);
                return q0.h.f6590c;
            case 5:
                i iVar = (i) obj;
                Q1 q12 = (Q1) obj4;
                if (!q12.f2743t) {
                    if (iVar != null) {
                        C c3 = iVar.f7352e;
                        hVar = (h) ((HashMap) c3.f915g).get((String) c3.f914f);
                        if (hVar == null) {
                            hVar = (h) AbstractC0544j.D((ArrayList) c3.f916h);
                        }
                    }
                    String str6 = (String) obj3;
                    String str7 = (String) obj5;
                    if (hVar == null) {
                        q12.E(new O1(q12, str6, str7, 0));
                    } else {
                        q12.f3289D.add(new C0520d(str6, str7));
                        Q1.D(0, q12, iVar, hVar);
                    }
                }
                return q0.h.f6590c;
            case 6:
                JSONObject jSONObject3 = (JSONObject) obj;
                E0.h.e(jSONObject3, "it");
                ArrayList arrayList5 = r1.k.f6794a;
                return C0007d0.Z(jSONObject3, (m1.f) obj4, (String) obj3, (String) obj5);
            case 7:
                z zVar = (z) obj;
                if (zVar != null) {
                    AbstractServiceC0650u abstractServiceC0650u2 = (AbstractServiceC0650u) obj4;
                    if (!abstractServiceC0650u2.f8269E && abstractServiceC0650u2.h().f8088j == (dVar = (l1.d) obj5) && E0.h.a(dVar.f6249c, (String) obj3)) {
                        dVar.f6250d = zVar;
                        abstractServiceC0650u2.u(dVar);
                        l1.b bVar = abstractServiceC0650u2.f8304l;
                        if (bVar != null && (kVar = bVar.f6229d) != null) {
                            kVar.f(dVar);
                        }
                        abstractServiceC0650u2.q();
                    }
                }
                return q0.h.f6590c;
            default:
                z1.y.I((z1.y) obj4, (E0.o) obj5, (String) obj3, (Throwable) obj);
                return q0.h.f6590c;
        }
    }

    public /* synthetic */ b(Object obj, Object obj2, Object obj3, int i2) {
        this.f2279f = i2;
        this.f2280g = obj;
        this.f2281h = obj2;
        this.f2282i = obj3;
    }

    public /* synthetic */ b(String str, C0307i c0307i, C0117e1 c0117e1) {
        this.f2279f = 4;
        this.f2281h = str;
        this.f2280g = c0307i;
        this.f2282i = c0117e1;
    }
}
