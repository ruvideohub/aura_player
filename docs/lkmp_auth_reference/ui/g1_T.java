package g1;

import S1.C0106b;
import S1.C0118f;
import S1.C0160t0;
import android.media.session.MediaSession;
import android.os.Build;
import android.os.Handler;
import android.util.Log;
import android.view.ViewGroup;
import e1.C0281e;
import h1.C0350h;
import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.List;
import k1.C0385a;
import m1.EnumC0446a;
import m1.InterfaceC0449d;
import syxme.lkmp.audio.modules.ModuleNative;
import syxme.mp3decoder.LKMPlayer;
import w1.C0587c;
import w1.C0588d;
import z1.C0634d;
import z1.C0635e;
import z1.C0637g;
/* loaded from: classes.dex */
public final /* synthetic */ class T implements Runnable {

    /* renamed from: a  reason: collision with root package name */
    public final /* synthetic */ int f5429a;

    /* renamed from: b  reason: collision with root package name */
    public final /* synthetic */ Object f5430b;

    /* renamed from: c  reason: collision with root package name */
    public final /* synthetic */ Object f5431c;

    public /* synthetic */ T(Object obj, Object obj2, int i2) {
        this.f5429a = i2;
        this.f5430b = obj;
        this.f5431c = obj2;
    }

    @Override // java.lang.Runnable
    public final void run() {
        switch (this.f5429a) {
            case 0:
                U u2 = (U) this.f5430b;
                Exception exc = (Exception) this.f5431c;
                if (!u2.f5442k) {
                    u2.f5435d.a(exc);
                    return;
                }
                return;
            case 1:
                C0350h.g(((C0350h) this.f5430b).f5640e);
                ((I1.p) this.f5431c).d(false, false);
                return;
            case ModuleNative.API /* 2 */:
                ((j0.r) this.f5431c).a(((k0.o) this.f5430b).c());
                return;
            case 3:
                ((C0587c) this.f5430b).a(new m1.g(true, "Ой:" + ((Exception) this.f5431c).getMessage(), EnumC0446a.f6382g, null));
                return;
            case 4:
                ((InterfaceC0449d) this.f5430b).a((m1.g) this.f5431c);
                return;
            case 5:
                ((InterfaceC0449d) this.f5430b).a(new m1.g(true, String.valueOf(((Exception) this.f5431c).getMessage()), EnumC0446a.f6382g, null));
                return;
            case 6:
                ((C0588d) this.f5430b).a((m1.g) this.f5431c);
                return;
            case 7:
                ((C0587c) this.f5430b).a((m1.g) this.f5431c);
                return;
            case 8:
                ((C0587c) this.f5430b).a(new m1.g(true, "", EnumC0446a.f6389n, ((L1.a) this.f5431c).f1835f));
                return;
            case 9:
                ((C0587c) this.f5430b).a(new m1.g(true, String.valueOf(((Exception) this.f5431c).getMessage()), EnumC0446a.f6382g, null));
                return;
            case 10:
                ((C0587c) this.f5430b).a(new m1.g(true, "", EnumC0446a.f6389n, ((L1.a) this.f5431c).f1835f));
                return;
            case 11:
                ((C0587c) this.f5430b).a(new m1.g(true, String.valueOf(((Exception) this.f5431c).getMessage()), EnumC0446a.f6382g, null));
                return;
            case 12:
                ((C0587c) this.f5430b).a((m1.g) this.f5431c);
                return;
            case 13:
                ((C0587c) this.f5430b).a(new m1.g(true, "", EnumC0446a.f6389n, ((L1.a) this.f5431c).f1835f));
                return;
            case 14:
                if (((Boolean) ((D0.a) this.f5430b).b()).booleanValue()) {
                    ((D0.l) this.f5431c).a(Boolean.FALSE);
                    return;
                }
                return;
            case 15:
                ((C0160t0) this.f5430b).a((List) this.f5431c);
                return;
            case 16:
                ((D0.l) this.f5430b).a(this.f5431c);
                return;
            case 17:
                I1.p pVar = (I1.p) this.f5430b;
                ((D.C) pVar.f1579e).F((l1.d) this.f5431c, ((C0281e) pVar.f1576b).f5030i);
                return;
            case 18:
                ViewGroup viewGroup = ((y1.j) this.f5430b).f8061h;
                E0.h.b(viewGroup);
                new C0118f(viewGroup, (ArrayList) this.f5431c).d();
                return;
            case 19:
                ViewGroup viewGroup2 = ((y1.j) this.f5430b).f8061h;
                E0.h.b(viewGroup2);
                new C0106b(viewGroup2, (l1.p) this.f5431c).d();
                return;
            case 20:
                C0635e c0635e = (C0635e) this.f5430b;
                if (c0635e.b((C0634d) this.f5431c)) {
                    c0635e.f8213f.b();
                    return;
                }
                return;
            case 21:
                C0635e c0635e2 = (C0635e) this.f5430b;
                Exception exc2 = (Exception) this.f5431c;
                if (!c0635e2.f8218k) {
                    c0635e2.f8214g.a(exc2);
                    return;
                }
                return;
            case 22:
                C0637g c0637g = (C0637g) this.f5430b;
                c0637g.f8231n = null;
                if (c0637g.f8229l) {
                    B.K k2 = c0637g.f8227j;
                    B.K k3 = (B.K) this.f5431c;
                    if (k2 == k3) {
                        if (k3 != null) {
                            k3.d(k3.k(), -9223372036854775807L);
                        }
                        if (k3 != null) {
                            k3.v();
                            return;
                        }
                        return;
                    }
                    return;
                }
                return;
            case 23:
                q0.g gVar = (q0.g) this.f5430b;
                LKMPlayer.initMP3Player(((Number) gVar.f6586f).intValue(), ((Number) gVar.f6587g).intValue(), ((Number) gVar.f6588h).floatValue());
                LKMPlayer.setPlayerCallback(new C0385a(4, (z1.y) this.f5431c));
                return;
            default:
                android.support.v4.media.session.q qVar = (android.support.v4.media.session.q) this.f5430b;
                if (qVar != null) {
                    android.support.v4.media.session.l lVar = (android.support.v4.media.session.l) qVar.f4222f;
                    lVar.f4215e.kill();
                    int i2 = Build.VERSION.SDK_INT;
                    MediaSession mediaSession = lVar.f4211a;
                    if (i2 == 27) {
                        try {
                            Field declaredField = mediaSession.getClass().getDeclaredField("mCallback");
                            declaredField.setAccessible(true);
                            Handler handler = (Handler) declaredField.get(mediaSession);
                            if (handler != null) {
                                handler.removeCallbacksAndMessages(null);
                            }
                        } catch (Exception e2) {
                            Log.w("MediaSessionCompat", "Exception happened while accessing MediaSession.mCallback.", e2);
                        }
                    }
                    mediaSession.setCallback(null);
                    lVar.f4212b.f4210b.set(null);
                    mediaSession.release();
                }
                ((z1.H) this.f5431c).f8118j = null;
                return;
        }
    }
}
