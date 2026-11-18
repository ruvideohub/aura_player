package m1;

import B.AbstractC0008e;
/* renamed from: m1.e  reason: case insensitive filesystem */
/* loaded from: classes.dex */
public final class C0450e {

    /* renamed from: a  reason: collision with root package name */
    public String f6402a;

    /* renamed from: b  reason: collision with root package name */
    public int f6403b;

    /* renamed from: c  reason: collision with root package name */
    public int f6404c;

    /* renamed from: d  reason: collision with root package name */
    public String f6405d;

    public final boolean equals(Object obj) {
        if (this == obj) {
            return true;
        }
        if (!(obj instanceof C0450e)) {
            return false;
        }
        C0450e c0450e = (C0450e) obj;
        if (E0.h.a(this.f6402a, c0450e.f6402a) && this.f6403b == c0450e.f6403b && this.f6404c == c0450e.f6404c && E0.h.a(this.f6405d, c0450e.f6405d)) {
            return true;
        }
        return false;
    }

    public final int hashCode() {
        return this.f6405d.hashCode() + (((((this.f6402a.hashCode() * 31) + this.f6403b) * 31) + this.f6404c) * 31);
    }

    public final String toString() {
        StringBuilder sb = new StringBuilder("VerificationMethods(info=");
        sb.append(this.f6402a);
        sb.append(", priority=");
        sb.append(this.f6403b);
        sb.append(", timeout=");
        sb.append(this.f6404c);
        sb.append(", name=");
        return AbstractC0008e.i(sb, this.f6405d, ')');
    }
}
