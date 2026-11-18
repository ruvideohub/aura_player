package M1;

import B.AbstractC0008e;
import E0.h;
/* loaded from: classes.dex */
public final class c {

    /* renamed from: a  reason: collision with root package name */
    public final String f2012a;

    /* renamed from: b  reason: collision with root package name */
    public String f2013b;

    public c(String str, String str2) {
        h.e(str, "name");
        h.e(str2, "value");
        this.f2012a = str;
        this.f2013b = str2;
    }

    public final boolean equals(Object obj) {
        if (this == obj) {
            return true;
        }
        if (!(obj instanceof c)) {
            return false;
        }
        c cVar = (c) obj;
        if (h.a(this.f2012a, cVar.f2012a) && h.a(this.f2013b, cVar.f2013b)) {
            return true;
        }
        return false;
    }

    public final int hashCode() {
        return this.f2013b.hashCode() + (this.f2012a.hashCode() * 31);
    }

    public final String toString() {
        StringBuilder sb = new StringBuilder("ObjectJS(name=");
        sb.append(this.f2012a);
        sb.append(", value=");
        return AbstractC0008e.i(sb, this.f2013b, ')');
    }
}
