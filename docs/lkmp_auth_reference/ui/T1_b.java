package T1;

import B1.C0044a;
import B1.T;
import S1.B;
import android.support.v4.media.session.q;
import android.view.View;
import android.view.ViewGroup;
import android.widget.EditText;
import m1.h;
/* loaded from: classes.dex */
public final class b {

    /* renamed from: a  reason: collision with root package name */
    public a f3762a;

    /* renamed from: b  reason: collision with root package name */
    public final View f3763b;

    /* renamed from: c  reason: collision with root package name */
    public final EditText f3764c;

    /* renamed from: d  reason: collision with root package name */
    public h f3765d;

    /* renamed from: e  reason: collision with root package name */
    public final C0044a f3766e;

    public b(String str, q qVar, a aVar) {
        E0.h.e(qVar, "inflater");
        this.f3762a = aVar;
        C0044a c0044a = new C0044a();
        this.f3766e = c0044a;
        this.f3763b = qVar.N("auth_steep_" + str + ".xml", null, c0044a, false);
        View b2 = c0044a.b("value");
        E0.h.c(b2, "null cannot be cast to non-null type android.widget.EditText");
        EditText editText = (EditText) b2;
        this.f3764c = editText;
        c0044a.f("button", new T(15, this), null);
        if (str.equals("password")) {
            editText.setInputType(524417);
        } else if (str.equals("enter_login")) {
            editText.setInputType(524289);
        }
        editText.setOnEditorActionListener(new B(4, this));
    }

    public final void a(ViewGroup viewGroup) {
        int childCount = viewGroup.getChildCount();
        View view = this.f3763b;
        if (childCount != 0) {
            View childAt = viewGroup.getChildAt(0);
            if (childAt != null) {
                if (childAt.equals(view)) {
                    return;
                }
            } else {
                throw new IndexOutOfBoundsException("Index: 0, Size: " + viewGroup.getChildCount());
            }
        }
        viewGroup.removeAllViews();
        viewGroup.addView(view);
    }

    public final h b() {
        h hVar = this.f3765d;
        C0044a c0044a = this.f3766e;
        if (hVar != null) {
            View b2 = c0044a.b("captcha_value");
            E0.h.c(b2, "null cannot be cast to non-null type android.widget.EditText");
            String obj = ((EditText) b2).getText().toString();
            E0.h.e(obj, "<set-?>");
            hVar.f6422e = obj;
        }
        c0044a.k("captcha_block", Boolean.FALSE);
        h hVar2 = this.f3765d;
        this.f3765d = null;
        return hVar2;
    }

    public final void c(String str) {
        boolean z2;
        E0.h.e(str, "text");
        if (str.length() > 0) {
            z2 = true;
        } else {
            z2 = false;
        }
        C0044a c0044a = this.f3766e;
        if (z2) {
            c0044a.n("info", str);
        }
        c0044a.k("info", Boolean.valueOf(z2));
    }
}
