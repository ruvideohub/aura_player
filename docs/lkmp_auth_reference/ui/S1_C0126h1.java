package S1;

import android.webkit.JavascriptInterface;
/* renamed from: S1.h1  reason: case insensitive filesystem */
/* loaded from: classes.dex */
public final class C0126h1 {

    /* renamed from: a  reason: collision with root package name */
    public final G f3514a;

    public C0126h1(G g2) {
        this.f3514a = g2;
    }

    @JavascriptInterface
    public final void VKCaptchaGetResult(String str) {
        E0.h.e(str, "result");
        this.f3514a.a(str);
    }
}
