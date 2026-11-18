package N1;

import B.C0007d0;
import E0.h;
import H0.f;
import I1.r;
import N0.o;
import N0.s;
import N0.u;
import N0.y;
import V0.m;
import android.content.Context;
import android.graphics.Point;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.support.v4.media.session.q;
import j1.k;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.CookieManager;
import java.net.CookiePolicy;
import java.net.URLConnection;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Pattern;
import java.util.zip.GZIPInputStream;
import javax.net.ssl.HttpsURLConnection;
import org.json.JSONObject;
import q0.C0520d;
import r0.AbstractC0544j;
import r0.AbstractC0547m;
import r0.w;
import syxme.lkmp.VKMPLite;
import syxme.lkmp.space.http.PostParams;
/* loaded from: classes.dex */
public final class e {

    /* renamed from: m  reason: collision with root package name */
    public static final C0007d0 f2293m = new C0007d0();

    /* renamed from: n  reason: collision with root package name */
    public static String f2294n = "";

    /* renamed from: a  reason: collision with root package name */
    public final Context f2295a;

    /* renamed from: b  reason: collision with root package name */
    public final q f2296b;

    /* renamed from: c  reason: collision with root package name */
    public final f f2297c;

    /* renamed from: d  reason: collision with root package name */
    public String f2298d;

    /* renamed from: e  reason: collision with root package name */
    public final String f2299e;

    /* renamed from: f  reason: collision with root package name */
    public final s f2300f;

    /* renamed from: g  reason: collision with root package name */
    public final M1.d f2301g;

    /* renamed from: h  reason: collision with root package name */
    public final k f2302h;

    /* renamed from: i  reason: collision with root package name */
    public final r f2303i;

    /* renamed from: j  reason: collision with root package name */
    public final String f2304j;

    /* renamed from: k  reason: collision with root package name */
    public final Handler f2305k;

    /* renamed from: l  reason: collision with root package name */
    public final String f2306l;

    /* JADX WARN: Type inference failed for: r1v8, types: [java.lang.Object, I1.q] */
    /* JADX WARN: Type inference failed for: r7v3, types: [java.lang.Object, I1.r] */
    public e(Context context, q qVar) {
        this.f2295a = context;
        this.f2296b = qVar;
        long currentTimeMillis = System.currentTimeMillis();
        this.f2297c = new f((int) currentTimeMillis, (int) (currentTimeMillis >> 32));
        this.f2298d = "";
        this.f2299e = g(8) + '-' + g(4) + '-' + g(4) + '-' + g(4) + '-' + g(12);
        N0.r rVar = new N0.r();
        CookieManager cookieManager = new CookieManager();
        cookieManager.setCookiePolicy(CookiePolicy.ACCEPT_ALL);
        rVar.f2197j = new A1.b(16, cookieManager);
        this.f2300f = new s(rVar);
        this.f2301g = new M1.d();
        ?? obj = new Object();
        obj.f1580a = "";
        obj.f1581b = "";
        obj.f1582c = 0;
        obj.f1583d = "";
        obj.f1584e = "";
        obj.f1585f = "";
        obj.f1586g = "";
        obj.f1587h = 0;
        obj.f1588i = "";
        this.f2302h = new k(obj);
        ?? obj2 = new Object();
        obj2.f1589a = 0;
        obj2.f1590b = 0;
        this.f2303i = obj2;
        this.f2304j = " (Android 12; SDK 31; arm64-v8a;Google Nexus 5X; ru; 1920x1080)";
        this.f2305k = new Handler(Looper.getMainLooper());
        this.f2306l = "-";
        try {
            String property = System.getProperty("os.arch");
            String language = Locale.getDefault().getLanguage();
            Point i2 = R1.a.i(context);
            this.f2304j = " (Android " + Build.VERSION.RELEASE + "; SDK " + Build.VERSION.SDK_INT + "; " + property + "; " + Build.MODEL + "; " + language + "; " + i2.x + 'x' + i2.y + ')';
            StringBuilder sb = new StringBuilder("AGENT:");
            sb.append(this.f2304j);
            System.out.println((Object) sb.toString());
        } catch (Exception e2) {
            e2.printStackTrace();
        }
        try {
            String string = Settings.Secure.getString(this.f2295a.getContentResolver(), "android_id");
            h.d(string, "getString(...)");
            this.f2306l = string;
        } catch (Exception unused) {
        }
    }

    public final d a(PostParams postParams) {
        postParams.set(w.j(new C0520d("lang", "ru"), new C0520d("device_id", A.b.y(this.f2295a)), new C0520d("sak_version", "1.144.0"), new C0520d("flow_type", "tg_flow"), new C0520d("gaid", this.f2299e), new C0520d("access_token", b()), new C0520d("v", "5.276"), new C0520d("https", "1"), new C0520d("api_id", "2274003")));
        return d("https://api.vk.ru/method/ecosystem.checkOtp", postParams, "auth", false);
    }

    public final String b() {
        d d2 = d("https://api.vk.ru/method/auth.getAnonymToken", new PostParams(w.j(new C0520d("client_id", "2274003"), new C0520d("client_secret", "hHbZxrka2uZ6jB1inYsH"), new C0520d("device_id", A.b.y(this.f2295a)), new C0520d("lang", "ru"), new C0520d("v", "5.276"), new C0520d("https", "1"), new C0520d("api_id", "2274003"))), "auth_start_with_phone", false);
        if (!d2.f2288a && d2.f2289b.has("response")) {
            JSONObject jSONObject = d2.f2289b.getJSONObject("response");
            if (jSONObject.has("token")) {
                String string = jSONObject.getString("token");
                h.d(string, "getString(...)");
                return string;
            }
        }
        throw new Exception("Ошибка получения мохентокена");
    }

    public final d c(PostParams postParams) {
        postParams.set(w.j(new C0520d("lang", "ru"), new C0520d("device_id", A.b.y(this.f2295a)), new C0520d("sak_version", "1.144.0"), new C0520d("flow_type", "tg_flow"), new C0520d("gaid", this.f2299e), new C0520d("access_token", b()), new C0520d("v", "5.276"), new C0520d("https", "1"), new C0520d("api_id", "2274003")));
        String str = "https://api.vk.ru/method/ecosystem.getVerificationMethods";
        if (this.f2298d.length() > 0) {
            str = "https://api.vk.ru/method/ecosystem.getVerificationMethods" + this.f2298d;
        }
        return d(str, postParams, "auth", false);
    }

    public final d d(String str, PostParams postParams, String str2, boolean z2) {
        String m2;
        try {
            d dVar = new d(false, new JSONObject(), 0, 12);
            String pull = postParams.pull();
            Pattern pattern = N0.q.f2184c;
            C.k r2 = V0.d.r(pull, m.q("application/x-www-form-urlencoded; charset=utf-8"));
            u uVar = new u();
            uVar.d(str);
            uVar.c("POST", r2);
            uVar.b("X-Screen", str2);
            uVar.b("Cache-Control", "no-cache");
            uVar.b("Accept", "image/webp");
            uVar.b("Accept-Encoding", "gzip");
            uVar.b("User-Agent", A.b.x(this.f2295a));
            uVar.b("X-VK-Android-Client", "new");
            C.e a2 = uVar.a();
            s sVar = this.f2300f;
            sVar.getClass();
            N0.w c2 = new R0.h(sVar, a2).c();
            boolean a3 = h.a(N0.w.j(c2, "Content-Encoding"), "gzip");
            y yVar = c2.f2267l;
            if (a3) {
                h.b(yVar);
                m2 = A.b.L(new BufferedReader(new InputStreamReader(new GZIPInputStream(yVar.l().i()), M0.a.f1992a), 8192));
            } else {
                h.b(yVar);
                m2 = yVar.m();
            }
            if (!z2) {
                dVar.f2289b = new JSONObject(m2);
            }
            dVar.f2292e = ((o) c2.f2261f.f843b).f2182h;
            return dVar;
        } catch (Exception e2) {
            e2.printStackTrace();
            return new d(true, new JSONObject(), 0, 12);
        }
    }

    public final d e(String str, PostParams postParams) {
        Object obj;
        h.e(str, "m");
        h.e(postParams, "params");
        b bVar = new b(this, str, postParams, 0);
        I1.f fVar = new I1.f(bVar);
        int i2 = fVar.f1547b;
        if (i2 < 3) {
            fVar.f1547b = i2 + 1;
            obj = bVar.a(fVar);
        } else {
            obj = null;
        }
        d dVar = (d) obj;
        if (dVar == null) {
            return new d(true, new JSONObject(), 5, 8);
        }
        return dVar;
    }

    public final void f(String str, PostParams postParams, a aVar) {
        new Thread(new c(this, str, postParams, aVar, 0)).start();
    }

    public final String g(int i2) {
        J0.a aVar = new J0.a(1, i2, 1);
        ArrayList arrayList = new ArrayList(AbstractC0547m.u(aVar, 10));
        Iterator it = aVar.iterator();
        while (((J0.b) it).f1625h) {
            ((J0.b) it).a();
            arrayList.add(Character.valueOf("0123456789abcdef".charAt(this.f2297c.e(16))));
        }
        return AbstractC0544j.G(arrayList, "", null, 62);
    }

    public final boolean h() {
        M1.e eVar;
        String str;
        PostParams postParams = new PostParams();
        C0520d c0520d = new C0520d("lang", "ru");
        C0520d c0520d2 = new C0520d("https", "1");
        C0520d c0520d3 = new C0520d("api_id", "2274003");
        C0520d c0520d4 = new C0520d("client_id", "2274003");
        C0520d c0520d5 = new C0520d("initiator", "expired_token");
        C0520d c0520d6 = new C0520d("gaid", this.f2299e);
        M1.d dVar = this.f2301g;
        postParams.set(w.j(c0520d, c0520d2, c0520d3, c0520d4, c0520d5, c0520d6, new C0520d("exchange_token", dVar.f2016c), new C0520d("scope", "all"), new C0520d("device_id", A.b.y(this.f2295a)), new C0520d("v", "5.276")));
        String str2 = d("https://api.vk.ru/oauth/auth_by_exchange_token", postParams, "auth_password", true).f2292e;
        int length = str2.length();
        q qVar = this.f2296b;
        if (length == 0) {
            PostParams postParams2 = new PostParams();
            postParams2.set("needExchangeToken", 1);
            postParams2.set("func_v", "30");
            try {
                String str3 = "&device_id=" + this.f2306l;
                String byKey = postParams2.getByKey("v");
                if (byKey.length() <= 0) {
                    str = "5.131";
                } else {
                    postParams2.remove("v");
                    str = byKey;
                }
                VKMPLite vKMPLite = VKMPLite.f6886b;
                URLConnection vMethod = m.r().vMethod("execute.getUserInfo", dVar.f2014a, dVar.f2017d, postParams2, this.f2304j, str3, str);
                h.c(vMethod, "null cannot be cast to non-null type javax.net.ssl.HttpsURLConnection");
                HttpsURLConnection httpsURLConnection = (HttpsURLConnection) vMethod;
                Map<String, List<String>> headerFields = httpsURLConnection.getHeaderFields();
                StringBuilder sb = new StringBuilder();
                int responseCode = httpsURLConnection.getResponseCode();
                String url = httpsURLConnection.getURL().toString();
                h.d(url, "toString(...)");
                String str4 = "";
                h.b(headerFields);
                for (Map.Entry<String, List<String>> entry : headerFields.entrySet()) {
                    String key = entry.getKey();
                    if (key != null) {
                        Locale locale = Locale.getDefault();
                        h.d(locale, "getDefault(...)");
                        String lowerCase = key.toLowerCase(locale);
                        h.d(lowerCase, "toLowerCase(...)");
                        if (lowerCase.equals("content-encoding")) {
                            List<String> list = headerFields.get(key);
                            h.b(list);
                            String str5 = list.get(0);
                            h.d(str5, "get(...)");
                            str4 = str5;
                        }
                    }
                }
                if (str4.length() > 0 && str4.equals("gzip")) {
                    BufferedReader bufferedReader = new BufferedReader(new InputStreamReader(new GZIPInputStream(httpsURLConnection.getInputStream()), "UTF-8"));
                    while (true) {
                        String readLine = bufferedReader.readLine();
                        if (readLine == null) {
                            break;
                        }
                        sb.append(readLine);
                    }
                    httpsURLConnection.disconnect();
                    String sb2 = sb.toString();
                    h.d(sb2, "toString(...)");
                    eVar = new M1.e(sb2, url, new M1.b(), responseCode, new M1.a(), false);
                } else {
                    BufferedReader bufferedReader2 = new BufferedReader(new InputStreamReader(httpsURLConnection.getInputStream(), "UTF-8"));
                    while (true) {
                        String readLine2 = bufferedReader2.readLine();
                        if (readLine2 == null) {
                            break;
                        }
                        sb.append(readLine2);
                    }
                    String sb3 = sb.toString();
                    h.d(sb3, "toString(...)");
                    eVar = new M1.e(sb3, url, M1.b.f2010b, responseCode, M1.a.f2008b, false);
                }
            } catch (Exception e2) {
                System.out.println((Object) "ERROR");
                e2.printStackTrace();
                eVar = new M1.e("ERROR", "", new M1.b(), 0, new M1.a(), true);
            }
            try {
                String string = new JSONObject(eVar.f2018a).getJSONObject("response").getString("exchange_token");
                h.b(string);
                if (string.length() > 0) {
                    dVar.f2016c = string;
                    qVar.V(dVar);
                    return true;
                }
                return false;
            } catch (Exception e3) {
                e3.printStackTrace();
                return false;
            }
        }
        String substring = str2.substring(M0.e.e0(str2, "#", 0, false, 6) + 1);
        h.d(substring, "substring(...)");
        String[] strArr = (String[]) M0.e.o0(substring, new String[]{"&"}).toArray(new String[0]);
        HashMap hashMap = new HashMap();
        for (String str6 : strArr) {
            hashMap.put(((String[]) M0.e.o0(str6, new String[]{"="}).toArray(new String[0]))[0], ((String[]) M0.e.o0(str6, new String[]{"="}).toArray(new String[0]))[1]);
        }
        Object obj = hashMap.get("access_token");
        h.b(obj);
        dVar.f2014a = (String) obj;
        qVar.V(dVar);
        return true;
    }
}
