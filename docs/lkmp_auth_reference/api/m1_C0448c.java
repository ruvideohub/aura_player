package m1;

import B.AbstractC0008e;
/* renamed from: m1.c  reason: case insensitive filesystem */
/* loaded from: classes.dex */
public final class C0448c {

    /* renamed from: a  reason: collision with root package name */
    public String f6396a;

    /* renamed from: b  reason: collision with root package name */
    public String f6397b;

    /* renamed from: c  reason: collision with root package name */
    public String f6398c;

    /* renamed from: d  reason: collision with root package name */
    public boolean f6399d;

    /* renamed from: e  reason: collision with root package name */
    public String f6400e;

    /* renamed from: f  reason: collision with root package name */
    public boolean f6401f;

    public final boolean equals(Object obj) {
        if (this == obj) {
            return true;
        }
        if (!(obj instanceof C0448c)) {
            return false;
        }
        C0448c c0448c = (C0448c) obj;
        if (E0.h.a(this.f6396a, c0448c.f6396a) && E0.h.a(this.f6397b, c0448c.f6397b) && E0.h.a(this.f6398c, c0448c.f6398c) && this.f6399d == c0448c.f6399d && E0.h.a(this.f6400e, c0448c.f6400e) && this.f6401f == c0448c.f6401f) {
            return true;
        }
        return false;
    }

    public final int hashCode() {
        int i2;
        int c2 = AbstractC0008e.c(this.f6398c, AbstractC0008e.c(this.f6397b, this.f6396a.hashCode() * 31, 31), 31);
        int i3 = 1237;
        if (this.f6399d) {
            i2 = 1231;
        } else {
            i2 = 1237;
        }
        int c3 = AbstractC0008e.c(this.f6400e, (c2 + i2) * 31, 31);
        if (this.f6401f) {
            i3 = 1231;
        }
        return c3 + i3;
    }

    public final String toString() {
        return "AuthInfo(sid=" + this.f6396a + ", login=" + this.f6397b + ", remember_hash=" + this.f6398c + ", has_another_verification_methods=" + this.f6399d + ", verification_method=" + this.f6400e + ", can_skip_password=" + this.f6401f + ')';
    }
}
