package m1;

import B.AbstractC0008e;
/* loaded from: classes.dex */
public final class h {

    /* renamed from: a  reason: collision with root package name */
    public final String f6418a;

    /* renamed from: b  reason: collision with root package name */
    public final String f6419b;

    /* renamed from: c  reason: collision with root package name */
    public final String f6420c;

    /* renamed from: d  reason: collision with root package name */
    public final String f6421d;

    /* renamed from: e  reason: collision with root package name */
    public String f6422e = "";

    /* renamed from: f  reason: collision with root package name */
    public final String f6423f;

    public h(String str, String str2, String str3, String str4, String str5) {
        this.f6418a = str;
        this.f6419b = str2;
        this.f6420c = str3;
        this.f6421d = str4;
        this.f6423f = str5;
    }

    public final boolean equals(Object obj) {
        if (this == obj) {
            return true;
        }
        if (!(obj instanceof h)) {
            return false;
        }
        h hVar = (h) obj;
        if (E0.h.a(this.f6418a, hVar.f6418a) && E0.h.a(this.f6419b, hVar.f6419b) && E0.h.a(this.f6420c, hVar.f6420c) && E0.h.a(this.f6421d, hVar.f6421d) && E0.h.a(this.f6422e, hVar.f6422e) && E0.h.a(this.f6423f, hVar.f6423f)) {
            return true;
        }
        return false;
    }

    public final int hashCode() {
        return this.f6423f.hashCode() + AbstractC0008e.c(this.f6422e, AbstractC0008e.c(this.f6421d, AbstractC0008e.c(this.f6420c, AbstractC0008e.c(this.f6419b, this.f6418a.hashCode() * 31, 31), 31), 31), 31);
    }

    public final String toString() {
        StringBuilder sb = new StringBuilder("Captcha(captcha_img=");
        sb.append(this.f6418a);
        sb.append(", captcha_ratio=");
        sb.append(this.f6419b);
        sb.append(", captcha_sid=");
        sb.append(this.f6420c);
        sb.append(", captcha_ts=");
        sb.append(this.f6421d);
        sb.append(", captcha_key=");
        sb.append(this.f6422e);
        sb.append(", redirect_uri=");
        return AbstractC0008e.i(sb, this.f6423f, ')');
    }
}
