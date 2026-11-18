package syxme.lkmp.space.http;

import E0.h;
import M1.c;
import android.text.TextUtils;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.Map;
/* loaded from: classes.dex */
public final class PostParams {

    /* renamed from: a  reason: collision with root package name */
    public ArrayList f7285a;

    public PostParams() {
        this.f7285a = new ArrayList();
    }

    public final ArrayList<c> getArray() {
        return this.f7285a;
    }

    public final String getByKey(String str) {
        h.e(str, "key");
        Iterator it = this.f7285a.iterator();
        h.d(it, "iterator(...)");
        while (it.hasNext()) {
            c cVar = (c) it.next();
            if (h.a(cVar.f2012a, str)) {
                return cVar.f2013b;
            }
        }
        return "";
    }

    public final boolean notEmpty() {
        return !this.f7285a.isEmpty();
    }

    public final String pull() {
        ArrayList arrayList = new ArrayList();
        try {
            int size = this.f7285a.size();
            for (int i2 = 0; i2 < size; i2++) {
                arrayList.add(URLEncoder.encode(((c) this.f7285a.get(i2)).f2012a, "UTF-8") + '=' + URLEncoder.encode(((c) this.f7285a.get(i2)).f2013b, "UTF-8"));
            }
        } catch (Exception e2) {
            e2.printStackTrace();
        }
        String join = TextUtils.join("&", arrayList);
        h.d(join, "join(...)");
        return join;
    }

    public final String pullAgent() {
        new ArrayList();
        try {
            String str = "" + ((c) this.f7285a.get(0)).f2013b;
            for (int i2 = 1; i2 < this.f7285a.size(); i2++) {
                str = (str + ';') + ((c) this.f7285a.get(i2)).f2013b;
            }
            return str;
        } catch (Exception e2) {
            e2.printStackTrace();
            return "";
        }
    }

    public final String pullWithoutEncode() {
        ArrayList arrayList = new ArrayList();
        try {
            int size = this.f7285a.size();
            for (int i2 = 0; i2 < size; i2++) {
                arrayList.add(((c) this.f7285a.get(i2)).f2012a + '=' + ((c) this.f7285a.get(i2)).f2013b);
            }
        } catch (Exception e2) {
            e2.printStackTrace();
        }
        String join = TextUtils.join("&", arrayList);
        h.d(join, "join(...)");
        return join;
    }

    public final void remove(String str) {
        h.e(str, "name");
        Iterator it = this.f7285a.iterator();
        h.d(it, "iterator(...)");
        while (it.hasNext()) {
            c cVar = (c) it.next();
            if (h.a(cVar.f2012a, str)) {
                this.f7285a.remove(cVar);
                return;
            }
        }
    }

    public final void set(String str, String str2) {
        h.e(str, "name");
        h.e(str2, "value");
        Iterator it = this.f7285a.iterator();
        h.d(it, "iterator(...)");
        while (it.hasNext()) {
            c cVar = (c) it.next();
            if (h.a(cVar.f2012a, str)) {
                cVar.f2013b = str2;
                return;
            }
        }
        this.f7285a.add(new c(str, str2));
    }

    public final void setArray(ArrayList<c> arrayList) {
        h.e(arrayList, "<set-?>");
        this.f7285a = arrayList;
    }

    public final void setIs(String str, String str2) {
        h.e(str, "name");
        h.e(str2, "value");
        if (str2.length() == 0) {
            return;
        }
        set(str, str2);
    }

    public String toString() {
        StringBuilder sb = new StringBuilder("--------\n");
        Iterator it = this.f7285a.iterator();
        h.d(it, "iterator(...)");
        while (it.hasNext()) {
            c cVar = (c) it.next();
            sb.append(cVar.f2012a + " : " + cVar.f2013b);
            sb.append('\n');
        }
        sb.append("--------");
        String sb2 = sb.toString();
        h.d(sb2, "toString(...)");
        return sb2;
    }

    public PostParams(Map<String, String> map) {
        h.e(map, "map");
        this.f7285a = new ArrayList();
        for (Map.Entry<String, String> entry : map.entrySet()) {
            set(entry.getKey(), entry.getValue());
        }
    }

    public final void set(String str, long j2) {
        h.e(str, "name");
        Iterator it = this.f7285a.iterator();
        h.d(it, "iterator(...)");
        while (it.hasNext()) {
            c cVar = (c) it.next();
            if (h.a(cVar.f2012a, str)) {
                String valueOf = String.valueOf(j2);
                h.e(valueOf, "<set-?>");
                cVar.f2013b = valueOf;
                return;
            }
        }
        this.f7285a.add(new c(str, String.valueOf(j2)));
    }

    public final void set(Map<String, String> map) {
        h.e(map, "map");
        for (Map.Entry<String, String> entry : map.entrySet()) {
            set(entry.getKey(), entry.getValue());
        }
    }

    public final void set(String str, int i2) {
        h.e(str, "name");
        Iterator it = this.f7285a.iterator();
        h.d(it, "iterator(...)");
        while (it.hasNext()) {
            c cVar = (c) it.next();
            if (h.a(cVar.f2012a, str)) {
                String valueOf = String.valueOf(i2);
                h.e(valueOf, "<set-?>");
                cVar.f2013b = valueOf;
                return;
            }
        }
        this.f7285a.add(new c(str, String.valueOf(i2)));
    }

    public final void set(PostParams postParams) {
        h.e(postParams, "p");
        Iterator it = postParams.f7285a.iterator();
        h.d(it, "iterator(...)");
        while (it.hasNext()) {
            c cVar = (c) it.next();
            set(cVar.f2012a, cVar.f2013b);
        }
    }
}
