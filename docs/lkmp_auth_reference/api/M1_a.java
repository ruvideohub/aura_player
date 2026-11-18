package M1;

import E0.h;
import java.util.ArrayList;
/* loaded from: classes.dex */
public final class a {

    /* renamed from: b  reason: collision with root package name */
    public static final a f2008b = new a();

    /* renamed from: a  reason: collision with root package name */
    public final ArrayList f2009a = new ArrayList();

    public final void a(ArrayList arrayList) {
        h.e(arrayList, "list");
        int size = arrayList.size();
        for (int i2 = 0; i2 < size; i2++) {
            if (h.a(((c) arrayList.get(i2)).f2012a, "Set-Cookie")) {
                String str = ((c) arrayList.get(i2)).f2013b;
                String str2 = ((String[]) M0.e.o0(((String[]) M0.e.o0(str, new String[]{";"}).toArray(new String[0]))[0], new String[]{"="}).toArray(new String[0]))[0];
                String str3 = ((String[]) M0.e.o0(((String[]) M0.e.o0(str, new String[]{";"}).toArray(new String[0]))[0], new String[]{"="}).toArray(new String[0]))[1];
                ArrayList arrayList2 = this.f2009a;
                int size2 = arrayList2.size();
                int i3 = 0;
                while (true) {
                    if (i3 < size2) {
                        if (h.a(((c) arrayList2.get(i3)).f2012a, str2)) {
                            if (h.a(str3, "DELETED")) {
                                arrayList2.remove(i3);
                            } else {
                                c cVar = (c) arrayList2.get(i3);
                                cVar.getClass();
                                h.e(str3, "<set-?>");
                                cVar.f2013b = str3;
                            }
                        } else {
                            i3++;
                        }
                    } else if (!h.a(str3, "DELETED")) {
                        arrayList2.add(new c(str2, str3));
                    }
                }
            }
        }
    }

    public final String b() {
        ArrayList arrayList;
        int size = this.f2009a.size();
        String str = "";
        for (int i2 = 0; i2 < size; i2++) {
            str = str + ((c) arrayList.get(i2)).f2012a + '=' + ((c) arrayList.get(i2)).f2013b;
            if (i2 < arrayList.size() - 1) {
                str = str + ';';
            }
        }
        return str;
    }

    public final String toString() {
        ArrayList arrayList;
        int size = this.f2009a.size();
        String str = "";
        for (int i2 = 0; i2 < size; i2++) {
            str = str + ((c) arrayList.get(i2)).f2012a + '=' + ((c) arrayList.get(i2)).f2013b;
            if (i2 < arrayList.size() - 1) {
                str = str + ';';
            }
        }
        return str;
    }
}
