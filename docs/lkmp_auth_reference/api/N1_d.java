package N1;

import B.C0007d0;
import E0.h;
import org.json.JSONObject;
/* loaded from: classes.dex */
public final class d {

    /* renamed from: a  reason: collision with root package name */
    public final boolean f2288a;

    /* renamed from: b  reason: collision with root package name */
    public JSONObject f2289b;

    /* renamed from: c  reason: collision with root package name */
    public final int f2290c;

    /* renamed from: d  reason: collision with root package name */
    public final C0007d0 f2291d;

    /* renamed from: e  reason: collision with root package name */
    public String f2292e;

    public d(boolean z2, JSONObject jSONObject, int i2, int i3) {
        i2 = (i3 & 4) != 0 ? 0 : i2;
        C0007d0 c0007d0 = e.f2293m;
        h.e(c0007d0, "cookie");
        this.f2288a = z2;
        this.f2289b = jSONObject;
        this.f2290c = i2;
        this.f2291d = c0007d0;
        this.f2292e = "";
    }

    public final boolean equals(Object obj) {
        if (this == obj) {
            return true;
        }
        if (!(obj instanceof d)) {
            return false;
        }
        d dVar = (d) obj;
        if (this.f2288a == dVar.f2288a && h.a(this.f2289b, dVar.f2289b) && this.f2290c == dVar.f2290c && h.a(this.f2291d, dVar.f2291d)) {
            return true;
        }
        return false;
    }

    public final int hashCode() {
        int i2;
        if (this.f2288a) {
            i2 = 1231;
        } else {
            i2 = 1237;
        }
        int hashCode = this.f2289b.hashCode();
        return this.f2291d.hashCode() + ((((hashCode + (i2 * 31)) * 31) + this.f2290c) * 31);
    }

    public final String toString() {
        return "ApiRes(error=" + this.f2288a + ", json=" + this.f2289b + ", code=" + this.f2290c + ", cookie=" + this.f2291d + ')';
    }
}
