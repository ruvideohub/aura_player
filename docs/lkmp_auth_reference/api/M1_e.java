package M1;

import B.AbstractC0008e;
import E0.h;
/* loaded from: classes.dex */
public final class e {

    /* renamed from: a  reason: collision with root package name */
    public final String f2018a;

    /* renamed from: b  reason: collision with root package name */
    public final String f2019b;

    /* renamed from: c  reason: collision with root package name */
    public final b f2020c;

    /* renamed from: d  reason: collision with root package name */
    public final int f2021d;

    /* renamed from: e  reason: collision with root package name */
    public final a f2022e;

    /* renamed from: f  reason: collision with root package name */
    public final boolean f2023f;

    public e(String str, String str2, b bVar, int i2, a aVar, boolean z2) {
        h.e(str, "body");
        h.e(bVar, "headers");
        h.e(aVar, "cookie");
        this.f2018a = str;
        this.f2019b = str2;
        this.f2020c = bVar;
        this.f2021d = i2;
        this.f2022e = aVar;
        this.f2023f = z2;
    }

    public final boolean equals(Object obj) {
        if (this != obj) {
            if (obj instanceof e) {
                e eVar = (e) obj;
                if (!h.a(this.f2018a, eVar.f2018a) || !this.f2019b.equals(eVar.f2019b) || !h.a(this.f2020c, eVar.f2020c) || this.f2021d != eVar.f2021d || !h.a(this.f2022e, eVar.f2022e) || this.f2023f != eVar.f2023f) {
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
        int c2 = AbstractC0008e.c(this.f2019b, this.f2018a.hashCode() * 31, 31);
        int hashCode = (this.f2022e.hashCode() + ((((this.f2020c.hashCode() + c2) * 31) + this.f2021d) * 31)) * 31;
        if (this.f2023f) {
            i2 = 1231;
        } else {
            i2 = 1237;
        }
        return hashCode + i2;
    }

    public final String toString() {
        return "httpResponse(body=" + this.f2018a + ", url=" + this.f2019b + ", headers=" + this.f2020c + ", code=" + this.f2021d + ", cookie=" + this.f2022e + ", error=" + this.f2023f + ')';
    }
}
