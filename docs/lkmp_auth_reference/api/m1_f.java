package m1;

import B.C0007d0;
import I1.r;
import P1.o;
import S1.F;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.AssetManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.support.v4.media.session.q;
import j1.j;
import j1.k;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.Serializable;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executor;
import org.json.JSONObject;
import q0.C0520d;
import r0.w;
import syxme.lkmp.VKMPLite;
import syxme.lkmp.space.http.PostParams;
import v.AbstractC0572c;
/* loaded from: classes.dex */
public final class f {

    /* renamed from: a  reason: collision with root package name */
    public String f6406a;

    /* renamed from: b  reason: collision with root package name */
    public boolean f6407b;

    /* renamed from: c  reason: collision with root package name */
    public final Object f6408c;

    /* renamed from: d  reason: collision with root package name */
    public final Object f6409d;

    /* renamed from: e  reason: collision with root package name */
    public final Object f6410e;

    /* renamed from: f  reason: collision with root package name */
    public final Object f6411f;

    /* renamed from: g  reason: collision with root package name */
    public Serializable f6412g;

    /* renamed from: h  reason: collision with root package name */
    public Object f6413h;

    /* JADX WARN: Type inference failed for: r0v0, types: [java.lang.Object, m1.c] */
    public f(Context context) {
        this.f6408c = context;
        ?? obj = new Object();
        obj.f6396a = "";
        obj.f6397b = "";
        obj.f6398c = "";
        obj.f6399d = true;
        obj.f6400e = "sms";
        obj.f6401f = false;
        this.f6409d = obj;
        Context applicationContext = context.getApplicationContext();
        E0.h.c(applicationContext, "null cannot be cast to non-null type syxme.lkmp.VKMPLite");
        q a2 = ((VKMPLite) applicationContext).a();
        this.f6410e = a2;
        this.f6411f = new N1.e(context, a2);
        this.f6412g = new ConcurrentHashMap();
        new HashMap();
        new ArrayList();
        this.f6413h = new g(true, "Что-то сломалось", EnumC0446a.f6382g, null);
        this.f6406a = "";
    }

    public g a(String str, PostParams postParams) {
        E0.h.e(str, "password");
        C0448c c0448c = (C0448c) this.f6409d;
        postParams.set("sid", c0448c.f6396a);
        postParams.set("password", str);
        postParams.set("username", c0448c.f6397b);
        postParams.set("anonymous_token", c());
        N1.e eVar = (N1.e) this.f6411f;
        eVar.getClass();
        C0520d c0520d = new C0520d("libverify_support", "1");
        C0520d c0520d2 = new C0520d("scope", "all");
        C0520d c0520d3 = new C0520d("device_trusted_hash_supported", "1");
        C0520d c0520d4 = new C0520d("grant_type", "phone_confirmation_sid");
        C0520d c0520d5 = new C0520d("2fa_supported", "1");
        C0520d c0520d6 = new C0520d("supported_ways", "push,email");
        C0520d c0520d7 = new C0520d("lang", "ru");
        C0007d0 c0007d0 = N1.e.f2293m;
        postParams.set(w.j(c0520d, c0520d2, c0520d3, c0520d4, c0520d5, c0520d6, c0520d7, new C0520d("device_id", A.b.y(eVar.f2295a)), new C0520d("sak_version", "1.144.0"), new C0520d("flow_type", "tg_flow"), new C0520d("gaid", eVar.f2299e), new C0520d("anonymous_token", eVar.b()), new C0520d("v", "5.276"), new C0520d("https", "1"), new C0520d("api_id", "2274003")));
        String str2 = "https://api.vk.ru/oauth/token";
        if (eVar.f2298d.length() > 0) {
            str2 = "https://api.vk.ru/oauth/token" + eVar.f2298d;
        }
        N1.d d2 = eVar.d(str2, postParams, "auth_password", false);
        if (d2.f2289b.has("error")) {
            String string = d2.f2289b.getString("error");
            if (!E0.h.a(string, "need_captcha")) {
                if (E0.h.a(string, "need_validation")) {
                    String c2 = R1.a.c(d2.f2289b, "validation_type", "");
                    c0448c.f6396a = R1.a.c(d2.f2289b, "validation_sid", "");
                    switch (c2.hashCode()) {
                        case 143225679:
                            c2.equals("2fa_app");
                            break;
                        case 143242887:
                            if (c2.equals("2fa_sms")) {
                                return f(25);
                            }
                            break;
                        case 145480620:
                            if (c2.equals("2fa_push")) {
                                return f(27);
                            }
                            break;
                        case 204517706:
                            if (c2.equals("2fa_email")) {
                                return f(26);
                            }
                            break;
                    }
                    throw new Exception(R1.a.c(d2.f2289b, "error_description", ""));
                } else if (E0.h.a(string, "invalid_client") && d2.f2289b.has("error_description")) {
                    throw new Exception(R1.a.c(d2.f2289b, "error_description", ""));
                } else {
                    throw new Exception(d2.f2289b.toString());
                }
            }
            throw new L1.a(new h(R1.a.c(d2.f2289b, "captcha_img", ""), R1.a.c(d2.f2289b, "captcha_ratio", ""), R1.a.c(d2.f2289b, "captcha_sid", ""), R1.a.c(d2.f2289b, "captcha_ts", ""), R1.a.c(d2.f2289b, "redirect_uri", "")));
        } else if (d2.f2289b.has("access_token")) {
            return b(d2.f2289b);
        } else {
            throw new Exception(d2.f2289b.toString());
        }
    }

    public g b(JSONObject jSONObject) {
        E0.h.e(jSONObject, "json");
        N1.e eVar = (N1.e) this.f6411f;
        M1.d dVar = eVar.f2301g;
        String c2 = R1.a.c(jSONObject, "access_token", "");
        dVar.getClass();
        dVar.f2014a = c2;
        String c3 = R1.a.c(jSONObject, "user_id", "");
        M1.d dVar2 = eVar.f2301g;
        dVar2.getClass();
        dVar2.f2015b = c3;
        PostParams postParams = new PostParams();
        postParams.set("func_v", 33);
        postParams.set("needExchangeToken", 1);
        JSONObject jSONObject2 = eVar.e("execute.getUserInfo", postParams).f2289b.getJSONObject("response");
        if (jSONObject2.has("exchange_token")) {
            String string = jSONObject2.getString("exchange_token");
            E0.h.d(string, "getString(...)");
            dVar2.getClass();
            dVar2.f2016c = string;
        }
        PostParams postParams2 = new PostParams();
        postParams2.set("lang", "ru");
        N1.d e2 = eVar.e("auth.refreshToken", postParams2);
        if (e2.f2289b.has("response")) {
            e2.f2289b.getJSONObject("response");
            q qVar = (q) this.f6410e;
            qVar.V(dVar2);
            try {
                JSONObject jSONObject3 = eVar.e("account.getProfileInfo", postParams2).f2289b.getJSONObject("response");
                I1.q qVar2 = (I1.q) eVar.f2302h.f6021a;
                E0.h.b(jSONObject3);
                String c4 = R1.a.c(jSONObject3, "bdate", "");
                qVar2.getClass();
                qVar2.f1583d = c4;
                qVar2.f1580a = R1.a.c(jSONObject3, "first_name", "");
                qVar2.f1581b = R1.a.c(jSONObject3, "last_name", "");
                qVar2.f1582c = R1.a.b(jSONObject3, "id", 0);
                qVar2.f1587h = R1.a.b(jSONObject3, "sex", 0);
                qVar2.f1586g = R1.a.c(jSONObject3, "photo_200", "");
                qVar2.f1588i = R1.a.c(jSONObject3, "screen_name", "");
                if (jSONObject3.has("city")) {
                    JSONObject jSONObject4 = jSONObject3.getJSONObject("city");
                    StringBuilder sb = new StringBuilder();
                    E0.h.b(jSONObject4);
                    sb.append(R1.a.c(jSONObject4, "id", ""));
                    sb.append('_');
                    sb.append(R1.a.c(jSONObject4, "title", ""));
                    String sb2 = sb.toString();
                    E0.h.e(sb2, "<set-?>");
                    qVar2.f1584e = sb2;
                }
                if (jSONObject3.has("country")) {
                    JSONObject jSONObject5 = jSONObject3.getJSONObject("country");
                    StringBuilder sb3 = new StringBuilder();
                    E0.h.b(jSONObject5);
                    sb3.append(R1.a.c(jSONObject5, "id", ""));
                    sb3.append('_');
                    sb3.append(R1.a.c(jSONObject5, "title", ""));
                    String sb4 = sb3.toString();
                    E0.h.e(sb4, "<set-?>");
                    qVar2.f1585f = sb4;
                }
                k kVar = eVar.f2302h;
                kVar.getClass();
                k.f6020e.post(new j(kVar, 1));
            } catch (Exception e3) {
                e3.printStackTrace();
            }
            I1.q qVar3 = (I1.q) eVar.f2302h.f6021a;
            E0.h.e(qVar3, "o");
            SharedPreferences.Editor edit = ((SharedPreferences) qVar.f4222f).edit();
            E0.h.d(edit, "edit(...)");
            edit.putString("ua", qVar3.f1583d);
            edit.putString("ub", qVar3.f1584e);
            edit.putString("uc", qVar3.f1580a);
            edit.putString("ud", qVar3.f1581b);
            edit.putString("ue", qVar3.f1588i);
            edit.putString("uf", qVar3.f1586g);
            edit.putInt("ur", qVar3.f1582c);
            edit.putInt("ux", qVar3.f1587h);
            edit.putString("uy", qVar3.f1585f);
            edit.apply();
            return new g(true, "", EnumC0446a.f6381f, null);
        }
        return (g) this.f6413h;
    }

    public String c() {
        if (this.f6406a.length() == 0) {
            this.f6406a = ((N1.e) this.f6411f).b();
        }
        return this.f6406a;
    }

    public boolean d() {
        N1.e eVar = (N1.e) this.f6411f;
        M1.d dVar = eVar.f2301g;
        q qVar = (q) this.f6410e;
        boolean R2 = qVar.R(dVar);
        this.f6407b = R2;
        if (R2) {
            I1.q qVar2 = (I1.q) eVar.f2302h.f6021a;
            E0.h.e(qVar2, "o");
            SharedPreferences sharedPreferences = (SharedPreferences) qVar.f4222f;
            qVar2.f1583d = String.valueOf(sharedPreferences.getString("ua", ""));
            qVar2.f1584e = String.valueOf(sharedPreferences.getString("ub", ""));
            qVar2.f1580a = String.valueOf(sharedPreferences.getString("uc", ""));
            qVar2.f1581b = String.valueOf(sharedPreferences.getString("ud", ""));
            qVar2.f1588i = String.valueOf(sharedPreferences.getString("ue", ""));
            qVar2.f1586g = String.valueOf(sharedPreferences.getString("uf", ""));
            qVar2.f1585f = String.valueOf(sharedPreferences.getString("uy", ""));
            qVar2.f1582c = sharedPreferences.getInt("ur", 0);
            qVar2.f1587h = sharedPreferences.getInt("ux", 0);
            k kVar = eVar.f2302h;
            kVar.getClass();
            k.f6020e.post(new j(kVar, 1));
            r rVar = eVar.f2303i;
            E0.h.e(rVar, "o");
            rVar.f1590b = sharedPreferences.getInt("usa", 0);
            rVar.f1589a = sharedPreferences.getInt("usb", 0);
        }
        return this.f6407b;
    }

    public FileInputStream e(AssetManager assetManager, String str) {
        try {
            return assetManager.openFd(str).createInputStream();
        } catch (FileNotFoundException e2) {
            String message = e2.getMessage();
            if (message != null && message.contains("compressed")) {
                ((v.f) this.f6409d).y();
                return null;
            }
            return null;
        }
    }

    public g f(int i2) {
        String str;
        String c2 = c();
        PostParams postParams = new PostParams();
        C0448c c0448c = (C0448c) this.f6409d;
        postParams.set("sid", c0448c.f6396a);
        postParams.set("access_token", c2);
        N1.e eVar = (N1.e) this.f6411f;
        eVar.getClass();
        C0520d c0520d = new C0520d("lang", "ru");
        C0007d0 c0007d0 = N1.e.f2293m;
        postParams.set(w.j(c0520d, new C0520d("device_id", A.b.y(eVar.f2295a)), new C0520d("sak_version", "1.144.0"), new C0520d("flow_type", "tg_flow"), new C0520d("gaid", eVar.f2299e), new C0520d("access_token", eVar.b()), new C0520d("v", "5.276"), new C0520d("https", "1"), new C0520d("api_id", "2274003")));
        if (i2 != 26) {
            if (i2 != 27) {
                str = "sendOtpSms";
            } else {
                str = "sendOtpPush";
            }
        } else {
            str = "sendOtpEmail";
        }
        N1.d d2 = eVar.d("https://api.vk.ru/method/ecosystem.".concat(str), postParams, "auth", false);
        if (d2.f2289b.has("response")) {
            JSONObject jSONObject = d2.f2289b.getJSONObject("response");
            E0.h.b(jSONObject);
            c0448c.f6396a = R1.a.c(jSONObject, "sid", c0448c.f6396a);
            EnumC0446a enumC0446a = EnumC0446a.f6391p;
            String c3 = R1.a.c(jSONObject, "info", "");
            String str2 = c0448c.f6400e;
            int hashCode = str2.hashCode();
            if (hashCode != 114009) {
                if (hashCode != 3452698) {
                    if (hashCode == 96619420 && str2.equals("email")) {
                        enumC0446a = EnumC0446a.f6383h;
                    }
                    c3 = AbstractC0572c.a(new StringBuilder("Метод "), c0448c.f6400e, " не поддерживается, но попробуйте");
                } else {
                    if (str2.equals("push")) {
                        enumC0446a = EnumC0446a.f6385j;
                    }
                    c3 = AbstractC0572c.a(new StringBuilder("Метод "), c0448c.f6400e, " не поддерживается, но попробуйте");
                }
            } else {
                if (str2.equals("sms")) {
                    enumC0446a = EnumC0446a.f6387l;
                }
                c3 = AbstractC0572c.a(new StringBuilder("Метод "), c0448c.f6400e, " не поддерживается, но попробуйте");
            }
            return new g(false, c3, enumC0446a, jSONObject);
        }
        return new g(true, "Что-то сломалось:" + d2.f2289b, EnumC0446a.f6382g, null);
    }

    public void g(int i2, InterfaceC0449d interfaceC0449d) {
        new Thread(new o(this, i2, new Handler(Looper.getMainLooper()), interfaceC0449d, 4)).start();
    }

    public void h(int i2, Serializable serializable) {
        ((Executor) this.f6408c).execute(new F(this, i2, serializable, 4));
    }

    public g i(String str, PostParams postParams) {
        C0448c c0448c = (C0448c) this.f6409d;
        E0.h.e(str, "<set-?>");
        c0448c.f6397b = str;
        postParams.set("access_token", c());
        postParams.set("login", str);
        N1.e eVar = (N1.e) this.f6411f;
        eVar.getClass();
        C0520d c0520d = new C0520d("lang", "ru");
        C0007d0 c0007d0 = N1.e.f2293m;
        postParams.set(w.j(c0520d, new C0520d("device_id", A.b.y(eVar.f2295a)), new C0520d("supported_ways", "push,email,sms,callreset,password,reserve_code,codegen,official_messenger,max_code,passkey,libverify,max_messenger"), new C0520d("force_password", "0"), new C0520d("sak_version", "1.144.0"), new C0520d("flow_type", "auth_without_password"), new C0520d("gaid", eVar.f2299e), new C0520d("access_token", eVar.b()), new C0520d("v", "5.276"), new C0520d("https", "1"), new C0520d("api_id", "2274003")));
        String str2 = "https://api.vk.ru/method/auth.validateAccount";
        if (eVar.f2298d.length() > 0) {
            str2 = "https://api.vk.ru/method/auth.validateAccount" + eVar.f2298d;
        }
        JSONObject jSONObject = eVar.d(str2, postParams, "auth_start_with_phone", false).f2289b;
        if (jSONObject.has("error")) {
            JSONObject jSONObject2 = jSONObject.getJSONObject("error");
            if (jSONObject2.has("error_code") && jSONObject2.getInt("error_code") == 14) {
                throw new L1.a(new h(R1.a.c(jSONObject2, "captcha_img", ""), R1.a.c(jSONObject2, "captcha_ratio", ""), R1.a.c(jSONObject2, "captcha_sid", ""), R1.a.c(jSONObject2, "captcha_ts", ""), R1.a.c(jSONObject2, "redirect_uri", "")));
            }
            throw new Exception(jSONObject.getJSONObject("error").getString("error_text"));
        }
        JSONObject jSONObject3 = jSONObject.getJSONObject("response");
        E0.h.d(jSONObject3, "getJSONObject(...)");
        boolean has = jSONObject3.has("next_step");
        EnumC0446a enumC0446a = EnumC0446a.f6382g;
        if (!has && !jSONObject3.has("flow_name")) {
            return new g(true, "Что-то сломалось", enumC0446a, null);
        }
        String c2 = R1.a.c(jSONObject3, "flow_name", "");
        c0448c.f6396a = R1.a.c(jSONObject3, "sid", "");
        c0448c.f6398c = R1.a.c(jSONObject3, "remember_hash", "");
        boolean has2 = jSONObject3.has("next_step");
        EnumC0446a enumC0446a2 = EnumC0446a.f6384i;
        if (has2) {
            JSONObject jSONObject4 = jSONObject3.getJSONObject("next_step");
            E0.h.b(jSONObject4);
            c0448c.f6399d = R1.a.a(jSONObject4, "has_another_verification_methods");
            String c3 = R1.a.c(jSONObject4, "verification_method", "");
            c0448c.f6400e = c3;
            switch (c3.hashCode()) {
                case -1115951216:
                    if (c3.equals("reserve_code")) {
                        return new g(false, "", EnumC0446a.f6386k, null);
                    }
                    break;
                case 114009:
                    if (c3.equals("sms")) {
                        return f(25);
                    }
                    break;
                case 3452698:
                    if (c3.equals("push")) {
                        return f(27);
                    }
                    break;
                case 96619420:
                    if (c3.equals("email")) {
                        return f(26);
                    }
                    break;
                case 941850179:
                    if (c3.equals("codegen")) {
                        return new g(false, "", EnumC0446a.f6388m, null);
                    }
                    break;
                case 1216985755:
                    if (c3.equals("password")) {
                        return new g(false, "", enumC0446a2, null);
                    }
                    break;
            }
            return new g(true, "ХЗ МЕТОД:".concat(c0448c.f6400e), EnumC0446a.f6390o, null);
        } else if (!c2.equals("need_registration")) {
            if (c2.equals("need_password_and_validation")) {
                return new g(false, "", enumC0446a2, null);
            }
            return new g(true, "ХЗ МЕТОД_2:" + jSONObject3, enumC0446a, null);
        } else {
            throw new Exception("Пользователь не зарегистрирован");
        }
    }

    public f(AssetManager assetManager, Executor executor, v.f fVar, String str, File file) {
        this.f6407b = false;
        this.f6408c = executor;
        this.f6409d = fVar;
        this.f6406a = str;
        this.f6411f = file;
        int i2 = Build.VERSION.SDK_INT;
        byte[] bArr = null;
        if (i2 >= 24 && i2 <= 34) {
            switch (i2) {
                case 24:
                case 25:
                    bArr = v.g.f7384h;
                    break;
                case 26:
                    bArr = v.g.f7383g;
                    break;
                case 27:
                    bArr = v.g.f7382f;
                    break;
                case 28:
                case 29:
                case 30:
                    bArr = v.g.f7381e;
                    break;
                case 31:
                case 32:
                case 33:
                case 34:
                    bArr = v.g.f7380d;
                    break;
            }
        }
        this.f6410e = bArr;
    }
}
