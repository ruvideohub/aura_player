package M1;

import B.AbstractC0008e;
import E0.h;
/* loaded from: classes.dex */
public final class d {

    /* renamed from: a  reason: collision with root package name */
    public String f2014a = "";

    /* renamed from: b  reason: collision with root package name */
    public String f2015b = "";

    /* renamed from: c  reason: collision with root package name */
    public String f2016c = "";

    /* renamed from: d  reason: collision with root package name */
    public String f2017d = "";

    public final boolean equals(Object obj) {
        if (this == obj) {
            return true;
        }
        if (!(obj instanceof d)) {
            return false;
        }
        d dVar = (d) obj;
        if (h.a(this.f2014a, dVar.f2014a) && h.a(this.f2015b, dVar.f2015b) && h.a(this.f2016c, dVar.f2016c) && h.a(this.f2017d, dVar.f2017d)) {
            return true;
        }
        return false;
    }

    public final int hashCode() {
        return this.f2017d.hashCode() + AbstractC0008e.c(this.f2016c, AbstractC0008e.c(this.f2015b, this.f2014a.hashCode() * 31, 31), 31);
    }

    public final String toString() {
        StringBuilder sb = new StringBuilder("audat(token=");
        sb.append(this.f2014a);
        sb.append(", user_id=");
        sb.append(this.f2015b);
        sb.append(", exchange_token=");
        sb.append(this.f2016c);
        sb.append(", secret=");
        return AbstractC0008e.i(sb, this.f2017d, ')');
    }
}
