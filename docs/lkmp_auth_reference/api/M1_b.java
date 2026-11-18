package M1;

import E0.h;
import java.util.ArrayList;
/* loaded from: classes.dex */
public final class b {

    /* renamed from: b  reason: collision with root package name */
    public static final b f2010b = new b();

    /* renamed from: a  reason: collision with root package name */
    public final ArrayList f2011a = new ArrayList();

    public final void a(String str, String str2) {
        h.e(str2, "value");
        ArrayList arrayList = this.f2011a;
        int size = arrayList.size();
        int i2 = 0;
        while (i2 < size) {
            Object obj = arrayList.get(i2);
            i2++;
            c cVar = (c) obj;
            if (h.a(cVar.f2012a, str)) {
                cVar.f2013b = str2;
                return;
            }
        }
        arrayList.add(new c(str, str2));
    }
}
