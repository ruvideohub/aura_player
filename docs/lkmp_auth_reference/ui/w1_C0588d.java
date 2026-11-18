package w1;

import S1.C0106b;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.view.ViewGroup;
import java.util.ArrayList;
import java.util.Iterator;
import m1.C0450e;
import m1.EnumC0446a;
import m1.InterfaceC0449d;
import org.json.JSONObject;
import syxme.lkmp.Main;
import syxme.lkmp.space.http.PostParams;
/* renamed from: w1.d  reason: case insensitive filesystem */
/* loaded from: classes.dex */
public final /* synthetic */ class C0588d implements InterfaceC0449d, T1.a, y1.d {

    /* renamed from: f  reason: collision with root package name */
    public final /* synthetic */ int f7576f;

    /* renamed from: g  reason: collision with root package name */
    public final /* synthetic */ C0589e f7577g;

    public /* synthetic */ C0588d(C0589e c0589e, int i2) {
        this.f7576f = i2;
        this.f7577g = c0589e;
    }

    @Override // m1.InterfaceC0449d
    public void a(m1.g gVar) {
        String str;
        E0.h.e(gVar, "out");
        C0589e c0589e = this.f7577g;
        J1.b bVar = c0589e.f7585p;
        if (bVar != null) {
            bVar.b();
        }
        if (gVar.f6416c == EnumC0446a.f6381f) {
            ArrayList arrayList = new ArrayList();
            Object obj = gVar.f6417d;
            E0.h.c(obj, "null cannot be cast to non-null type java.util.ArrayList<syxme.lkmp.modules.auth.Auth.VerificationMethods>");
            Iterator it = ((ArrayList) obj).iterator();
            E0.h.d(it, "iterator(...)");
            while (it.hasNext()) {
                Object next = it.next();
                E0.h.d(next, "next(...)");
                C0450e c0450e = (C0450e) next;
                String str2 = c0450e.f6405d;
                E0.h.e(str2, "method");
                String str3 = c0450e.f6402a;
                E0.h.e(str3, "info");
                switch (str2.hashCode()) {
                    case -1115951216:
                        if (str2.equals("reserve_code")) {
                            str = "Ввести резервный код";
                            continue;
                            P1.u uVar = new P1.u(str);
                            arrayList.add(uVar);
                            uVar.f2795d = new C0586b(c0450e, c0589e);
                        }
                        break;
                    case 114009:
                        if (str2.equals("sms")) {
                            str = "Номер телефона ".concat(str3);
                            continue;
                            P1.u uVar2 = new P1.u(str);
                            arrayList.add(uVar2);
                            uVar2.f2795d = new C0586b(c0450e, c0589e);
                        }
                        break;
                    case 3452698:
                        if (str2.equals("push")) {
                            str = "Уведомление на устройство ".concat(str3);
                            continue;
                            P1.u uVar22 = new P1.u(str);
                            arrayList.add(uVar22);
                            uVar22.f2795d = new C0586b(c0450e, c0589e);
                        }
                        break;
                    case 96619420:
                        if (str2.equals("email")) {
                            str = "Электронная почта ".concat(str3);
                            continue;
                            P1.u uVar222 = new P1.u(str);
                            arrayList.add(uVar222);
                            uVar222.f2795d = new C0586b(c0450e, c0589e);
                        }
                        break;
                    case 941850179:
                        if (str2.equals("codegen")) {
                            str = "Приложение для генерации кодов";
                            continue;
                            P1.u uVar2222 = new P1.u(str);
                            arrayList.add(uVar2222);
                            uVar2222.f2795d = new C0586b(c0450e, c0589e);
                        }
                        break;
                    case 1216985755:
                        if (str2.equals("password")) {
                            str = "Ввести пароль";
                            continue;
                            P1.u uVar22222 = new P1.u(str);
                            arrayList.add(uVar22222);
                            uVar22222.f2795d = new C0586b(c0450e, c0589e);
                        }
                        break;
                }
                str = "Непонятный метод-" + str2 + " - " + str3;
                P1.u uVar222222 = new P1.u(str);
                arrayList.add(uVar222222);
                uVar222222.f2795d = new C0586b(c0450e, c0589e);
            }
            if (arrayList.size() > 0) {
                P1.t tVar = c0589e.f7584o;
                if (tVar != null) {
                    tVar.c(arrayList);
                }
                if (tVar != null) {
                    tVar.e(false);
                }
            }
        }
    }

    @Override // T1.a
    public void g(String str, T1.b bVar) {
        switch (this.f7576f) {
            case 1:
                E0.h.e(str, "login");
                E0.h.e(bVar, "sView");
                if (str.length() == 0 || str.length() < 4) {
                    bVar.c("Слишком короткий логин");
                    return;
                }
                bVar.c("");
                bVar.f3766e.k("button", Boolean.FALSE);
                C0589e c0589e = this.f7577g;
                J1.b bVar2 = c0589e.f7585p;
                if (bVar2 != null) {
                    bVar2.c();
                }
                PostParams postParams = new PostParams();
                m1.h b2 = bVar.b();
                if (b2 != null) {
                    postParams.set("captcha_sid", b2.f6420c);
                    postParams.set("captcha_key", b2.f6422e);
                    postParams.set("captcha_attempt", "1");
                    postParams.set("captcha_ts", b2.f6421d);
                    postParams.set("is_sound_captcha", "0");
                }
                Context context = c0589e.f7578i;
                E0.h.c(context, "null cannot be cast to non-null type syxme.lkmp.Main");
                new Thread(new O1.a(((Main) context).n(), str, postParams, new Handler(Looper.getMainLooper()), (InterfaceC0449d) new C0587c(bVar, c0589e), 3)).start();
                return;
            default:
                E0.h.e(str, "password");
                E0.h.e(bVar, "sView");
                if (str.length() <= 3) {
                    bVar.c("Слишком короткий пароль");
                    return;
                }
                bVar.c("");
                C0589e c0589e2 = this.f7577g;
                J1.b bVar3 = c0589e2.f7585p;
                if (bVar3 != null) {
                    bVar3.c();
                }
                PostParams postParams2 = new PostParams();
                m1.h b3 = bVar.b();
                if (b3 != null) {
                    postParams2.set("captcha_sid", b3.f6420c);
                    postParams2.set("captcha_key", b3.f6422e);
                    postParams2.set("captcha_attempt", "1");
                    postParams2.set("captcha_ts", b3.f6421d);
                    postParams2.set("is_sound_captcha", "0");
                }
                C0587c c0587c = new C0587c(c0589e2, bVar, 0);
                m1.f fVar = c0589e2.f7589t;
                fVar.getClass();
                new Thread(new O1.a(fVar, str, postParams2, new Handler(Looper.getMainLooper()), (InterfaceC0449d) c0587c, 4)).start();
                return;
        }
    }

    @Override // y1.d
    public void i(boolean z2, JSONObject jSONObject) {
        E0.h.e(jSONObject, "o");
        if (z2 && jSONObject.has("update")) {
            JSONObject jSONObject2 = jSONObject.getJSONObject("update");
            E0.h.b(jSONObject2);
            l1.p pVar = new l1.p(R1.a.n(R1.a.c(jSONObject2, "title", "")), R1.a.n(R1.a.c(jSONObject2, "text", "")), R1.a.c(jSONObject2, "vcode", ""), R1.a.c(jSONObject2, "vname", ""), R1.a.a(jSONObject2, "market"), R1.a.c(jSONObject2, "url", ""));
            ViewGroup viewGroup = this.f7577g.f7586q;
            E0.h.b(viewGroup);
            new C0106b(viewGroup, pVar).d();
        }
    }
}
