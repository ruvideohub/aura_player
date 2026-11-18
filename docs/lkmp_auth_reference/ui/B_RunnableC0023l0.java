package B;

import B.RunnableC0034r0;
import B1.L;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.Debug;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.os.Messenger;
import android.provider.MediaStore;
import android.util.Log;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.recyclerview.widget.RecyclerView;
import e1.n;
import g1.RunnableC0338y;
import java.io.File;
import java.util.ArrayList;
import m1.C0448c;
import m1.EnumC0446a;
import org.json.JSONArray;
import org.json.JSONObject;
import syxme.lkmp.Main;
import syxme.lkmp.audio.modules.ModuleWorkerService;
import syxme.lkmp.space.http.PostParams;
import u1.C0569a;
import w1.C0588d;
/* renamed from: B.l0  reason: case insensitive filesystem */
/* loaded from: classes.dex */
public final /* synthetic */ class RunnableC0023l0 implements Runnable {

    /* renamed from: a  reason: collision with root package name */
    public final /* synthetic */ int f537a;

    /* renamed from: b  reason: collision with root package name */
    public final /* synthetic */ Object f538b;

    /* renamed from: c  reason: collision with root package name */
    public final /* synthetic */ Object f539c;

    /* renamed from: d  reason: collision with root package name */
    public final /* synthetic */ Object f540d;

    public /* synthetic */ RunnableC0023l0(C0002b c0002b, ViewGroup viewGroup, j1.g gVar) {
        this.f537a = 16;
        this.f538b = c0002b;
        this.f539c = viewGroup;
        this.f540d = gVar;
    }

    private final void a() {
        RunnableC0338y runnableC0338y;
        ModuleWorkerService moduleWorkerService = (ModuleWorkerService) this.f538b;
        Handler handler = moduleWorkerService.f6914b;
        Bundle bundle = (Bundle) this.f539c;
        Messenger messenger = (Messenger) this.f540d;
        int i2 = ModuleWorkerService.f6912d;
        Bundle bundle2 = new Bundle();
        try {
            moduleWorkerService.a(bundle, new C0039v(29, messenger));
            bundle2.putBoolean("ok", true);
            Debug.MemoryInfo memoryInfo = new Debug.MemoryInfo();
            Debug.getMemoryInfo(memoryInfo);
            bundle2.putInt("pssKb", memoryInfo.getTotalPss());
            try {
                Message obtain = Message.obtain((Handler) null, 2);
                obtain.setData(bundle2);
                messenger.send(obtain);
            } catch (Exception unused) {
            }
            runnableC0338y = new RunnableC0338y(moduleWorkerService, 1);
        } catch (Throwable th) {
            try {
                Log.w("AudioModule", "Processing failed", th);
                String message = th.getMessage();
                if (message == null) {
                    message = "Ошибка модуля";
                }
                bundle2.putString("error", message);
                Debug.MemoryInfo memoryInfo2 = new Debug.MemoryInfo();
                Debug.getMemoryInfo(memoryInfo2);
                bundle2.putInt("pssKb", memoryInfo2.getTotalPss());
                try {
                    Message obtain2 = Message.obtain((Handler) null, 2);
                    obtain2.setData(bundle2);
                    messenger.send(obtain2);
                } catch (Exception unused2) {
                }
                runnableC0338y = new RunnableC0338y(moduleWorkerService, 1);
            } catch (Throwable th2) {
                Debug.MemoryInfo memoryInfo3 = new Debug.MemoryInfo();
                Debug.getMemoryInfo(memoryInfo3);
                bundle2.putInt("pssKb", memoryInfo3.getTotalPss());
                try {
                    Message obtain3 = Message.obtain((Handler) null, 2);
                    obtain3.setData(bundle2);
                    messenger.send(obtain3);
                } catch (Exception unused3) {
                }
                handler.postDelayed(new RunnableC0338y(moduleWorkerService, 1), 150L);
                throw th2;
            }
        }
        handler.postDelayed(runnableC0338y, 150L);
    }

    /* JADX WARN: Type inference failed for: r7v0, types: [m1.e, java.lang.Object] */
    private final void b() {
        m1.g gVar;
        N1.d c2;
        m1.f fVar = (m1.f) this.f538b;
        fVar.getClass();
        try {
            PostParams postParams = new PostParams();
            String c3 = fVar.c();
            postParams.set("sid", ((C0448c) fVar.f6409d).f6396a);
            postParams.set("access_token", c3);
            c2 = ((N1.e) fVar.f6411f).c(postParams);
        } catch (Exception e2) {
            gVar = new m1.g(true, String.valueOf(e2.getMessage()), EnumC0446a.f6382g, null);
        }
        if (c2.f2289b.has("response")) {
            JSONObject jSONObject = c2.f2289b.getJSONObject("response");
            if (jSONObject.has("methods")) {
                JSONArray jSONArray = jSONObject.getJSONArray("methods");
                ArrayList arrayList = new ArrayList();
                int length = jSONArray.length();
                for (int i2 = 0; i2 < length; i2++) {
                    JSONObject jSONObject2 = jSONArray.getJSONObject(i2);
                    E0.h.b(jSONObject2);
                    String c4 = R1.a.c(jSONObject2, "info", "");
                    int b2 = R1.a.b(jSONObject2, "priority", 0);
                    int b3 = R1.a.b(jSONObject2, "timeout", 0);
                    String c5 = R1.a.c(jSONObject2, "name", "");
                    ?? obj = new Object();
                    obj.f6402a = c4;
                    obj.f6403b = b2;
                    obj.f6404c = b3;
                    obj.f6405d = c5;
                    arrayList.add(obj);
                }
                if (!arrayList.isEmpty()) {
                    gVar = new m1.g(false, "", EnumC0446a.f6381f, arrayList);
                    ((Handler) this.f539c).post(new g1.T((C0588d) this.f540d, gVar, 6));
                    return;
                }
                throw new Exception("Methods is empty");
            }
            throw new Exception("Methods not fond");
        }
        throw new Exception("Response not fond");
    }

    private final void c() {
        Main main = (Main) this.f538b;
        D0.a aVar = (D0.a) this.f539c;
        D0.l lVar = (D0.l) this.f540d;
        Thread currentThread = Thread.currentThread();
        try {
            Uri uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI;
            ArrayList arrayList = new ArrayList(100);
            Cursor query = main.getContentResolver().query(uri, null, "is_music != 0", null, "title ASC");
            if (query != null) {
                while (query.moveToNext() && ((Boolean) aVar.b()).booleanValue() && !currentThread.isInterrupted()) {
                    try {
                        String e2 = R1.a.e(query, "_data");
                        String e3 = R1.a.e(query, "title");
                        String e4 = R1.a.e(query, "artist");
                        int d2 = R1.a.d(query, "duration") / 1000;
                        if (!M0.e.g0(e2)) {
                            if (e4.length() < 2 || e4.equals("<unknown>")) {
                                e4 = null;
                            }
                            if (e4 == null) {
                                e4 = "Неизвестный исполнитель";
                            }
                            String str = e4;
                            if (M0.e.g0(e3)) {
                                e3 = null;
                            }
                            if (e3 == null) {
                                e3 = A0.j.Q(new File(e2));
                            }
                            String str2 = e3;
                            String str3 = "phone_" + R1.a.e(query, "_id");
                            l1.d dVar = new l1.d(str, str2, str3, e2, true);
                            dVar.f6262p = new l1.c("", str3.hashCode(), str3.hashCode(), e2, e2, e2, str2);
                            dVar.f6261o = d2;
                            dVar.f();
                            dVar.f6254h = str3;
                            arrayList.add(dVar);
                        }
                    } catch (Exception unused) {
                    }
                }
                query.close();
                if (((Boolean) aVar.b()).booleanValue() && !currentThread.isInterrupted()) {
                    new Handler(Looper.getMainLooper()).post(new N1.c(aVar, main, arrayList, lVar, 5));
                    return;
                }
                return;
            }
            throw new IllegalStateException("MediaStore query failed");
        } catch (Exception unused2) {
            if (((Boolean) aVar.b()).booleanValue() && !currentThread.isInterrupted()) {
                new Handler(Looper.getMainLooper()).post(new g1.T(aVar, lVar, 14));
            }
        }
    }

    private final void d() {
        m1.f fVar = (m1.f) this.f538b;
        Handler handler = (Handler) this.f539c;
        final B1.L l2 = (B1.L) this.f540d;
        PostParams postParams = new PostParams();
        postParams.set("fields", "photo_100,photo_200_orig,photo_200,photo_50,photo_max_orig");
        postParams.set("order", "hints");
        final ArrayList arrayList = new ArrayList();
        try {
            JSONArray jSONArray = ((N1.e) fVar.f6411f).e("friends.get", postParams).f2289b.getJSONObject("response").getJSONArray("items");
            int length = jSONArray.length();
            for (int i2 = 0; i2 < length; i2++) {
                JSONObject jSONObject = jSONArray.getJSONObject(i2);
                E0.h.b(jSONObject);
                String c2 = R1.a.c(jSONObject, "photo_200_orig", "");
                if (c2.length() == 0) {
                    c2 = R1.a.c(jSONObject, "photo_200", "");
                }
                if (c2.length() == 0) {
                    c2 = R1.a.c(jSONObject, "photo_max_orig", "");
                }
                String c3 = R1.a.c(jSONObject, "photo_100", "");
                if (c3.length() == 0) {
                    c3 = c2;
                }
                if (c3.length() == 0) {
                    c3 = R1.a.c(jSONObject, "photo_50", "");
                }
                String str = c3;
                String str2 = R1.a.c(jSONObject, "first_name", "") + ' ' + R1.a.c(jSONObject, "last_name", "");
                long j2 = jSONObject.getLong("id");
                if (c2.length() == 0) {
                    c2 = str;
                }
                arrayList.add(new l1.i(str2, j2, str, c2, l1.o.f6339g));
            }
            handler.post(new Runnable() { // from class: r1.d
                @Override // java.lang.Runnable
                public final void run() {
                    switch (r3) {
                        case 0:
                            L l3 = l2;
                            ArrayList arrayList2 = arrayList;
                            n nVar = (n) l3.f701g;
                            RecyclerView recyclerView = (RecyclerView) l3.f703i;
                            C0569a c0569a = (C0569a) l3.f700f;
                            c0569a.f2736m.Q("animationEnd", new RunnableC0034r0(c0569a, false, arrayList2, nVar, recyclerView, (TextView) l3.f702h));
                            return;
                        default:
                            L l4 = l2;
                            ArrayList arrayList3 = arrayList;
                            n nVar2 = (n) l4.f701g;
                            RecyclerView recyclerView2 = (RecyclerView) l4.f703i;
                            C0569a c0569a2 = (C0569a) l4.f700f;
                            c0569a2.f2736m.Q("animationEnd", new RunnableC0034r0(c0569a2, true, arrayList3, nVar2, recyclerView2, (TextView) l4.f702h));
                            return;
                    }
                }
            });
        } catch (Exception e2) {
            e2.printStackTrace();
            handler.post(new Runnable() { // from class: r1.d
                @Override // java.lang.Runnable
                public final void run() {
                    switch (r3) {
                        case 0:
                            L l3 = l2;
                            ArrayList arrayList2 = arrayList;
                            n nVar = (n) l3.f701g;
                            RecyclerView recyclerView = (RecyclerView) l3.f703i;
                            C0569a c0569a = (C0569a) l3.f700f;
                            c0569a.f2736m.Q("animationEnd", new RunnableC0034r0(c0569a, false, arrayList2, nVar, recyclerView, (TextView) l3.f702h));
                            return;
                        default:
                            L l4 = l2;
                            ArrayList arrayList3 = arrayList;
                            n nVar2 = (n) l4.f701g;
                            RecyclerView recyclerView2 = (RecyclerView) l4.f703i;
                            C0569a c0569a2 = (C0569a) l4.f700f;
                            c0569a2.f2736m.Q("animationEnd", new RunnableC0034r0(c0569a2, true, arrayList3, nVar2, recyclerView2, (TextView) l4.f702h));
                            return;
                    }
                }
            });
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    /* JADX WARN: Removed duplicated region for block: B:212:0x052f  */
    /* JADX WARN: Removed duplicated region for block: B:225:0x055f  */
    /* JADX WARN: Removed duplicated region for block: B:228:0x0565  */
    /* JADX WARN: Removed duplicated region for block: B:246:0x05aa  */
    /* JADX WARN: Removed duplicated region for block: B:304:0x0725  */
    /* JADX WARN: Removed duplicated region for block: B:350:0x07f6  */
    /* JADX WARN: Removed duplicated region for block: B:421:0x09f9  */
    /* JADX WARN: Removed duplicated region for block: B:518:0x0a3b A[SYNTHETIC] */
    /* JADX WARN: Type inference failed for: r12v18, types: [java.util.Collection, java.lang.Object] */
    /* JADX WARN: Type inference failed for: r12v35, types: [android.view.View$OnLayoutChangeListener, java.lang.Object] */
    /* JADX WARN: Type inference failed for: r12v46, types: [java.util.Collection, java.lang.Object] */
    /* JADX WARN: Type inference failed for: r13v3, types: [java.util.List, java.util.Collection, java.lang.Object] */
    /* JADX WARN: Type inference failed for: r1v6, types: [java.util.List, java.util.Collection, java.lang.Object] */
    /* JADX WARN: Type inference failed for: r1v7, types: [java.util.Collection, java.lang.Object] */
    /* JADX WARN: Type inference failed for: r3v23, types: [java.lang.Object, b0.C] */
    /* JADX WARN: Type inference failed for: r4v18, types: [java.lang.Object, java.lang.Iterable] */
    /* JADX WARN: Type inference failed for: r4v28, types: [java.util.Collection, java.lang.Object] */
    /* JADX WARN: Type inference failed for: r6v47, types: [java.lang.Object, java.lang.Iterable] */
    /* JADX WARN: Type inference failed for: r9v43, types: [java.lang.Throwable, android.view.View] */
    /* JADX WARN: Type inference failed for: r9v50, types: [java.util.Collection, java.lang.Object] */
    @Override // java.lang.Runnable
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct add '--show-bad-code' argument
    */
    public final void run() {
        /*
            Method dump skipped, instructions count: 3028
            To view this dump add '--comments-level debug' option
        */
        throw new UnsupportedOperationException("Method not decompiled: B.RunnableC0023l0.run():void");
    }

    public /* synthetic */ RunnableC0023l0(Object obj, Object obj2, Object obj3, int i2) {
        this.f537a = i2;
        this.f538b = obj;
        this.f539c = obj2;
        this.f540d = obj3;
    }
}
