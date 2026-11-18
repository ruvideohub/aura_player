package w1;

import P1.InterfaceC0094b;
import m1.C0450e;
import m1.EnumC0446a;
import m1.InterfaceC0449d;
/* renamed from: w1.b  reason: case insensitive filesystem */
/* loaded from: classes.dex */
public final /* synthetic */ class C0586b implements InterfaceC0449d, InterfaceC0094b {

    /* renamed from: f  reason: collision with root package name */
    public final /* synthetic */ int f7570f;

    /* renamed from: g  reason: collision with root package name */
    public final /* synthetic */ C0589e f7571g;

    /* renamed from: h  reason: collision with root package name */
    public final /* synthetic */ C0450e f7572h;

    public /* synthetic */ C0586b(C0450e c0450e, C0589e c0589e) {
        this.f7570f = 3;
        this.f7572h = c0450e;
        this.f7571g = c0589e;
    }

    @Override // m1.InterfaceC0449d
    public void a(m1.g gVar) {
        switch (this.f7570f) {
            case 0:
                E0.h.e(gVar, "it");
                this.f7571g.o(EnumC0446a.f6387l, this.f7572h.f6402a);
                return;
            case 1:
                E0.h.e(gVar, "it");
                this.f7571g.o(EnumC0446a.f6385j, this.f7572h.f6402a);
                return;
            default:
                E0.h.e(gVar, "it");
                this.f7571g.o(EnumC0446a.f6383h, this.f7572h.f6402a);
                return;
        }
    }

    @Override // P1.InterfaceC0094b
    public void c() {
        C0450e c0450e = this.f7572h;
        String str = c0450e.f6405d;
        int hashCode = str.hashCode();
        String str2 = c0450e.f6402a;
        C0589e c0589e = this.f7571g;
        switch (hashCode) {
            case -1115951216:
                if (!str.equals("reserve_code")) {
                    return;
                }
                c0589e.o(EnumC0446a.f6386k, str2);
                return;
            case 114009:
                if (str.equals("sms")) {
                    c0589e.f7589t.g(25, new C0586b(c0589e, c0450e, 0));
                    return;
                }
                return;
            case 3452698:
                if (str.equals("push")) {
                    c0589e.f7589t.g(27, new C0586b(c0589e, c0450e, 1));
                    return;
                }
                return;
            case 96619420:
                if (str.equals("email")) {
                    c0589e.f7589t.g(26, new C0586b(c0589e, c0450e, 2));
                    return;
                }
                return;
            case 941850179:
                if (str.equals("codegen")) {
                    c0589e.o(EnumC0446a.f6388m, str2);
                    return;
                }
                return;
            case 1216985755:
                if (str.equals("password")) {
                    c0589e.q();
                    return;
                }
                return;
            default:
                return;
        }
    }

    public /* synthetic */ C0586b(C0589e c0589e, C0450e c0450e, int i2) {
        this.f7570f = i2;
        this.f7571g = c0589e;
        this.f7572h = c0450e;
    }
}
