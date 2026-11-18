package w1;

import m1.EnumC0446a;
import m1.InterfaceC0449d;
import org.json.JSONObject;
import syxme.lkmp.audio.modules.ModuleNative;
/* renamed from: w1.c  reason: case insensitive filesystem */
/* loaded from: classes.dex */
public final /* synthetic */ class C0587c implements InterfaceC0449d {

    /* renamed from: f  reason: collision with root package name */
    public final /* synthetic */ int f7573f;

    /* renamed from: g  reason: collision with root package name */
    public final /* synthetic */ C0589e f7574g;

    /* renamed from: h  reason: collision with root package name */
    public final /* synthetic */ T1.b f7575h;

    public /* synthetic */ C0587c(T1.b bVar, C0589e c0589e) {
        this.f7573f = 2;
        this.f7575h = bVar;
        this.f7574g = c0589e;
    }

    @Override // m1.InterfaceC0449d
    public final void a(m1.g gVar) {
        switch (this.f7573f) {
            case 0:
                E0.h.e(gVar, "it");
                C0589e c0589e = this.f7574g;
                J1.b bVar = c0589e.f7585p;
                if (bVar != null) {
                    bVar.b();
                }
                EnumC0446a enumC0446a = EnumC0446a.f6389n;
                EnumC0446a enumC0446a2 = gVar.f6416c;
                if (enumC0446a2 == enumC0446a) {
                    Object obj = gVar.f6417d;
                    E0.h.c(obj, "null cannot be cast to non-null type syxme.lkmp.modules.auth.Captcha");
                    c0589e.p((m1.h) obj);
                    return;
                } else if (enumC0446a2 == EnumC0446a.f6382g) {
                    this.f7575h.c(gVar.f6415b);
                    return;
                } else if (enumC0446a2 == EnumC0446a.f6381f) {
                    c0589e.f7579j.b(true);
                    return;
                } else {
                    return;
                }
            case 1:
                E0.h.e(gVar, "it");
                C0589e c0589e2 = this.f7574g;
                J1.b bVar2 = c0589e2.f7585p;
                if (bVar2 != null) {
                    bVar2.b();
                }
                Boolean bool = Boolean.TRUE;
                T1.b bVar3 = this.f7575h;
                bVar3.f3766e.k("button", bool);
                EnumC0446a enumC0446a3 = EnumC0446a.f6382g;
                EnumC0446a enumC0446a4 = gVar.f6416c;
                if (enumC0446a4 == enumC0446a3) {
                    bVar3.c(gVar.f6415b);
                    return;
                } else if (enumC0446a4 == EnumC0446a.f6384i) {
                    c0589e2.q();
                    return;
                } else if (enumC0446a4 == EnumC0446a.f6381f) {
                    c0589e2.f7579j.b(true);
                    return;
                } else {
                    return;
                }
            default:
                E0.h.e(gVar, "it");
                Boolean bool2 = Boolean.TRUE;
                T1.b bVar4 = this.f7575h;
                bVar4.f3766e.k("button", bool2);
                C0589e c0589e3 = this.f7574g;
                J1.b bVar5 = c0589e3.f7585p;
                if (bVar5 != null) {
                    bVar5.b();
                }
                EnumC0446a enumC0446a5 = gVar.f6416c;
                int ordinal = enumC0446a5.ordinal();
                Object obj2 = gVar.f6417d;
                String str = gVar.f6415b;
                switch (ordinal) {
                    case 1:
                        bVar4.c(str);
                        return;
                    case ModuleNative.API /* 2 */:
                    default:
                        R1.a.l(c0589e3.n());
                        bVar4.c(str);
                        return;
                    case 3:
                    case 5:
                    case 6:
                    case 7:
                    case 8:
                        c0589e3.o(enumC0446a5, str);
                        return;
                    case 4:
                        c0589e3.q();
                        return;
                    case 9:
                        E0.h.c(obj2, "null cannot be cast to non-null type syxme.lkmp.modules.auth.Captcha");
                        c0589e3.p((m1.h) obj2);
                        return;
                    case 10:
                        bVar4.c(str);
                        c0589e3.s();
                        return;
                    case 11:
                        try {
                            E0.h.c(obj2, "null cannot be cast to non-null type org.json.JSONObject");
                            String string = ((JSONObject) obj2).getJSONObject("next_steep").getString("verification_method");
                            E0.h.b(string);
                            c0589e3.m(string, "Введите какой-нибудь код", str);
                            return;
                        } catch (Exception e2) {
                            bVar4.c(String.valueOf(e2.getMessage()));
                            return;
                        }
                }
        }
    }

    public /* synthetic */ C0587c(C0589e c0589e, T1.b bVar, int i2) {
        this.f7573f = i2;
        this.f7574g = c0589e;
        this.f7575h = bVar;
    }
}
