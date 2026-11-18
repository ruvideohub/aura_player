package w1;

import B.C0039v;
import B.RunnableC0023l0;
import B1.C0044a;
import B1.P;
import S1.C0129i1;
import android.content.Context;
import android.graphics.BitmapFactory;
import android.os.Handler;
import android.os.Looper;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ScrollView;
import java.io.File;
import java.util.HashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import m1.EnumC0446a;
import r0.AbstractC0545k;
import syxme.lkmp.Main;
import syxme.lkmp.space.http.PostParams;
import syxme.lkmp.space.window.MultiSlideWindowView;
/* renamed from: w1.e  reason: case insensitive filesystem */
/* loaded from: classes.dex */
public final class C0589e extends j1.g {

    /* renamed from: i  reason: collision with root package name */
    public final Context f7578i;

    /* renamed from: j  reason: collision with root package name */
    public final c1.h f7579j;

    /* renamed from: k  reason: collision with root package name */
    public final C0044a f7580k;

    /* renamed from: l  reason: collision with root package name */
    public final Main f7581l;

    /* renamed from: m  reason: collision with root package name */
    public ViewGroup f7582m;

    /* renamed from: n  reason: collision with root package name */
    public final android.support.v4.media.session.q f7583n;

    /* renamed from: o  reason: collision with root package name */
    public final P1.t f7584o;

    /* renamed from: p  reason: collision with root package name */
    public J1.b f7585p;

    /* renamed from: q  reason: collision with root package name */
    public ViewGroup f7586q;

    /* renamed from: r  reason: collision with root package name */
    public final HashMap f7587r;

    /* renamed from: s  reason: collision with root package name */
    public T1.b f7588s;

    /* renamed from: t  reason: collision with root package name */
    public final m1.f f7589t;

    /* JADX WARN: 'super' call moved to the top of the method (can break code semantics) */
    public C0589e(Context context, c1.h hVar) {
        super(context);
        E0.h.e(context, "ctx");
        this.f7578i = context;
        this.f7579j = hVar;
        this.f7580k = new C0044a();
        Main main = (Main) context;
        this.f7581l = main;
        android.support.v4.media.session.q qVar = ((Main) ((B1.E) context)).p().f723l;
        E0.h.e(qVar, "<set-?>");
        this.f7583n = qVar;
        this.f7584o = main.f6882w;
        this.f7587r = new HashMap();
        this.f7589t = main.n();
    }

    @Override // j1.g
    public final View i(LayoutInflater layoutInflater) {
        Context context = this.f5998a;
        E0.h.c(context, "null cannot be cast to non-null type syxme.lkmp.skinner.ISkin");
        P p2 = ((Main) ((B1.E) context)).p();
        View O2 = android.support.v4.media.session.q.O(p2.f723l, "route_auth.xml", null, this.f7580k, false, 24);
        FrameLayout frameLayout = new FrameLayout(context);
        frameLayout.setTag("MultiSlideWindow");
        frameLayout.setLayoutParams(new FrameLayout.LayoutParams(-1, -1));
        MultiSlideWindowView multiSlideWindowView = new MultiSlideWindowView(context, null, 2, null);
        multiSlideWindowView.setLayoutParams(new FrameLayout.LayoutParams(-1, -1));
        multiSlideWindowView.a();
        multiSlideWindowView.addView(O2);
        frameLayout.addView(multiSlideWindowView);
        return frameLayout;
    }

    @Override // j1.g
    public final void j() {
        C0044a c0044a = this.f7580k;
        View b2 = c0044a.b("authScroll");
        E0.h.c(b2, "null cannot be cast to non-null type android.widget.ScrollView");
        ((ScrollView) b2).setFillViewport(true);
        View b3 = c0044a.b("updateLayer");
        E0.h.c(b3, "null cannot be cast to non-null type android.view.ViewGroup");
        this.f7586q = (ViewGroup) b3;
        View b4 = c0044a.b("content_block");
        E0.h.c(b4, "null cannot be cast to non-null type android.view.ViewGroup");
        this.f7582m = (ViewGroup) b4;
        View b5 = c0044a.b("logo");
        E0.h.d(b5, "getView(...)");
        this.f7585p = new J1.b(b5);
        c0044a.f("another_confirm", new View.OnClickListener(this) { // from class: w1.a

            /* renamed from: b  reason: collision with root package name */
            public final /* synthetic */ C0589e f7569b;

            {
                this.f7569b = this;
            }

            @Override // android.view.View.OnClickListener
            public final void onClick(View view) {
                switch (r2) {
                    case 0:
                        this.f7569b.s();
                        return;
                    default:
                        C0589e c0589e = this.f7569b;
                        R1.a.l(c0589e.n());
                        Main main = c0589e.f7581l;
                        main.g();
                        main.f6878s = true;
                        main.getSharedPreferences("radio", 0).edit().putBoolean("guest", true).apply();
                        main.f6867j0 = false;
                        P1.J u2 = main.u();
                        u2.f2683a.k("bottomPanel", Boolean.TRUE);
                        main.P();
                        main.F(c1.i.f4733l);
                        return;
                }
            }
        }, null);
        c0044a.f("notLogin_btn", new View.OnClickListener(this) { // from class: w1.a

            /* renamed from: b  reason: collision with root package name */
            public final /* synthetic */ C0589e f7569b;

            {
                this.f7569b = this;
            }

            @Override // android.view.View.OnClickListener
            public final void onClick(View view) {
                switch (r2) {
                    case 0:
                        this.f7569b.s();
                        return;
                    default:
                        C0589e c0589e = this.f7569b;
                        R1.a.l(c0589e.n());
                        Main main = c0589e.f7581l;
                        main.g();
                        main.f6878s = true;
                        main.getSharedPreferences("radio", 0).edit().putBoolean("guest", true).apply();
                        main.f6867j0 = false;
                        P1.J u2 = main.u();
                        u2.f2683a.k("bottomPanel", Boolean.TRUE);
                        main.P();
                        main.F(c1.i.f4733l);
                        return;
                }
            }
        }, null);
        PostParams postParams = new PostParams();
        postParams.set("v", "1.0");
        postParams.set("v_code", 34);
        Handler handler = y1.j.f8052m;
        AbstractC0545k.c("app.getUpdate", postParams, new C0588d(this, 2));
        R1.a.l(n());
        r("enter_login", new C0588d(this, 1));
    }

    public final void m(String str, String str2, String str3) {
        boolean z2;
        E0.h.e(str3, "description");
        this.f7580k.k("another_confirm", Boolean.TRUE);
        R1.a.l(n());
        C0044a c0044a = r("code", new A1.f(this, str, 16)).f3766e;
        c0044a.n("title", str2);
        if (str3.length() > 0) {
            z2 = true;
        } else {
            z2 = false;
        }
        if (z2) {
            c0044a.n("description", str3);
        }
        c0044a.k("description", Boolean.valueOf(z2));
    }

    public final ViewGroup n() {
        ViewGroup viewGroup = this.f7582m;
        if (viewGroup != null) {
            return viewGroup;
        }
        E0.h.i("contentBlock");
        throw null;
    }

    public final void o(EnumC0446a enumC0446a, String str) {
        E0.h.e(enumC0446a, "type");
        E0.h.e(str, "info");
        int ordinal = enumC0446a.ordinal();
        if (ordinal != 3) {
            if (ordinal != 5) {
                if (ordinal != 6) {
                    if (ordinal != 7) {
                        if (ordinal != 8) {
                            return;
                        }
                        m("codegen", "Введите код", "Код создаётся в приложении для генерации кодов");
                        return;
                    }
                    m("sms", "Введите код из смс", "На ваш номер " + str + " поступит SMS-сообщение с кодом или звонок-сброс");
                    return;
                }
                m("reserve_code", "Введите резервный код", "Один из одноразовых резервных кодов от вашего аккаунта VK ID");
                return;
            }
            m("push", "Введите код из уведомления", "Push-уведомление отправлено на ваше устройство ".concat(str));
            return;
        }
        m("email", "Введите код из письма", "Письмо отправлено на почту ".concat(str));
    }

    /* JADX WARN: Type inference failed for: r4v0, types: [java.lang.Object, N0.u] */
    public final void p(m1.h hVar) {
        E0.h.e(hVar, "captcha");
        if (hVar.f6423f.length() > 0) {
            String str = hVar.f6423f;
            View view = this.f6001d;
            E0.h.b(view);
            new C0129i1(str, (ViewGroup) view, new C0588d(this, 4)).v();
            return;
        }
        T1.b bVar = this.f7588s;
        if (bVar != null) {
            bVar.f3765d = hVar;
            bVar.f3766e.k("captcha_block", Boolean.TRUE);
            Context context = bVar.f3763b.getContext();
            E0.h.d(context, "getContext(...)");
            ?? obj = new Object();
            obj.f2244b = Executors.newFixedThreadPool(2);
            obj.f2245c = new Handler(Looper.getMainLooper());
            obj.f2246d = new File(context.getCacheDir(), "max_images").getAbsoluteFile();
            obj.f2247e = new Object();
            obj.f2243a = "";
            m1.h hVar2 = bVar.f3765d;
            E0.h.b(hVar2);
            String str2 = hVar2.f6418a;
            m1.h hVar3 = bVar.f3765d;
            E0.h.b(hVar3);
            String str3 = hVar3.f6418a;
            C0039v c0039v = new C0039v(25, bVar);
            if (str2.length() != 0) {
                if (obj.f2243a.length() == 0) {
                    obj.f2243a = str3;
                }
                synchronized (obj.f2247e) {
                    obj.f2243a = str3;
                }
                File file = new File((File) obj.f2246d, str3);
                if (file.exists()) {
                    c0039v.k(BitmapFactory.decodeFile(file.getAbsolutePath()), str3);
                } else {
                    ((ExecutorService) obj.f2244b).submit(new O1.a(obj, file, str2, str3, c0039v));
                }
            }
        }
    }

    public final void q() {
        this.f7580k.k("another_confirm", Boolean.TRUE);
        R1.a.l(n());
        r("password", new C0588d(this, 3));
    }

    public final T1.b r(String str, T1.a aVar) {
        HashMap hashMap = this.f7587r;
        if (hashMap.containsKey(str)) {
            Object obj = hashMap.get(str);
            E0.h.b(obj);
            T1.b bVar = (T1.b) obj;
            bVar.f3762a = aVar;
            bVar.a(n());
            bVar.f3766e.k("button", Boolean.TRUE);
            return bVar;
        }
        android.support.v4.media.session.q qVar = this.f7583n;
        if (qVar != null) {
            T1.b bVar2 = new T1.b(str, qVar, aVar);
            bVar2.a(n());
            hashMap.put(str, bVar2);
            Object obj2 = hashMap.get(str);
            E0.h.b(obj2);
            T1.b bVar3 = (T1.b) obj2;
            this.f7588s = bVar3;
            return bVar3;
        }
        E0.h.i("inflater");
        throw null;
    }

    public final void s() {
        J1.b bVar = this.f7585p;
        if (bVar != null) {
            bVar.c();
        }
        C0588d c0588d = new C0588d(this, 0);
        m1.f fVar = this.f7589t;
        fVar.getClass();
        new Thread(new RunnableC0023l0(fVar, new Handler(Looper.getMainLooper()), c0588d, 17)).start();
    }
}
