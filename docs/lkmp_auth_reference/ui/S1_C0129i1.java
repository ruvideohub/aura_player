package S1;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.WebView;
import android.widget.FrameLayout;
import syxme.lkmp.Main;
import w1.C0588d;
/* renamed from: S1.i1  reason: case insensitive filesystem */
/* loaded from: classes.dex */
public final class C0129i1 extends P1.l {

    /* renamed from: A  reason: collision with root package name */
    public final C0588d f3520A;

    /* renamed from: z  reason: collision with root package name */
    public final String f3521z;

    /* JADX WARN: 'super' call moved to the top of the method (can break code semantics) */
    public C0129i1(String str, ViewGroup viewGroup, C0588d c0588d) {
        super(22, viewGroup, false);
        E0.h.e(viewGroup, "container");
        this.f3521z = str;
        this.f3520A = c0588d;
        Context context = this.f2738o;
        E0.h.c(context, "null cannot be cast to non-null type syxme.lkmp.skinner.ISkin");
        B1.X x2 = ((Main) ((B1.E) context)).p().f724m;
        E0.h.b(x2);
        this.f2744u = B1.P.c("main_background", x2);
    }

    @Override // P1.l
    public final void q(View view) {
        E0.h.e(view, "view");
    }

    @Override // P1.l
    public final View r(LayoutInflater layoutInflater, ViewGroup viewGroup) {
        E0.h.e(viewGroup, "root");
        Context context = this.f2738o;
        FrameLayout frameLayout = new FrameLayout(context);
        frameLayout.setLayoutParams(new FrameLayout.LayoutParams(-1, -1));
        WebView webView = new WebView(context);
        webView.setLayoutParams(new FrameLayout.LayoutParams(-1, -1));
        webView.addJavascriptInterface(new C0126h1(new G(this, webView, 5)), "AndroidBridge");
        webView.getSettings().setJavaScriptEnabled(true);
        webView.getSettings().setDomStorageEnabled(true);
        webView.getSettings().setLoadsImagesAutomatically(true);
        webView.getSettings().setDatabaseEnabled(true);
        frameLayout.addView(webView);
        webView.loadUrl(this.f3521z);
        return frameLayout;
    }

    @Override // P1.l
    public final void s() {
    }
}
