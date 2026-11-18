package m1;

import B.AbstractC0008e;
/* loaded from: classes.dex */
public final class g {

    /* renamed from: a  reason: collision with root package name */
    public final boolean f6414a;

    /* renamed from: b  reason: collision with root package name */
    public final String f6415b;

    /* renamed from: c  reason: collision with root package name */
    public final EnumC0446a f6416c;

    /* renamed from: d  reason: collision with root package name */
    public final Object f6417d;

    public g(boolean z2, String str, EnumC0446a enumC0446a, Object obj) {
        E0.h.e(str, "text");
        this.f6414a = z2;
        this.f6415b = str;
        this.f6416c = enumC0446a;
        this.f6417d = obj;
    }

    public final boolean equals(Object obj) {
        if (this != obj) {
            if (obj instanceof g) {
                g gVar = (g) obj;
                if (this.f6414a != gVar.f6414a || !E0.h.a(this.f6415b, gVar.f6415b) || this.f6416c != gVar.f6416c || !E0.h.a(this.f6417d, gVar.f6417d)) {
                    return false;
                }
                return true;
            }
            return false;
        }
        return true;
    }

    public final int hashCode() {
        int i2;
        int hashCode;
        if (this.f6414a) {
            i2 = 1231;
        } else {
            i2 = 1237;
        }
        int hashCode2 = (this.f6416c.hashCode() + AbstractC0008e.c(this.f6415b, i2 * 31, 31)) * 31;
        Object obj = this.f6417d;
        if (obj == null) {
            hashCode = 0;
        } else {
            hashCode = obj.hashCode();
        }
        return hashCode2 + hashCode;
    }

    public final String toString() {
        return "AuthRes(error=" + this.f6414a + ", text=" + this.f6415b + ", code=" + this.f6416c + ", out=" + this.f6417d + ')';
    }
}
