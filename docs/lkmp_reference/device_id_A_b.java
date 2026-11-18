package A;

import B1.P;
import B1.X;
import E0.h;
import E0.n;
import G.s;
import N0.t;
import V0.m;
import a1.C0192e;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.Point;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.os.Build;
import android.os.Parcel;
import android.os.Parcelable;
import android.provider.Settings;
import android.support.v4.media.session.q;
import android.view.MotionEvent;
import android.view.View;
import androidx.core.graphics.drawable.IconCompat;
import e.AbstractFutureC0258g;
import e.C0254c;
import e.C0257f;
import h1.C0346d;
import h1.EnumC0343a;
import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.RandomAccessFile;
import java.io.Reader;
import java.io.StringWriter;
import java.lang.reflect.Method;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLConnection;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Iterator;
import java.util.Locale;
import java.util.concurrent.TimeUnit;
import java.util.logging.Logger;
import k0.AbstractC0384a;
import k0.p;
import l.C0389D;
import l1.g;
import o.C0510a;
import org.json.JSONArray;
import org.json.JSONObject;
import r0.AbstractC0542h;
import r0.AbstractC0546l;
import syxme.lkmp.R;
import syxme.mp3decoder.Mp3Encoder;
import syxme.mp3decoder.OfflineDecoder;
import x0.AbstractC0627a;
/* loaded from: classes.dex */
public abstract class b {

    /* renamed from: a  reason: collision with root package name */
    public static boolean f1a;

    public static final Class A(K0.a aVar) {
        h.e(aVar, "<this>");
        Class a2 = ((E0.c) aVar).a();
        if (a2.isPrimitive()) {
            String name = a2.getName();
            switch (name.hashCode()) {
                case -1325958191:
                    if (name.equals("double")) {
                        return Double.class;
                    }
                    break;
                case 104431:
                    if (name.equals("int")) {
                        return Integer.class;
                    }
                    break;
                case 3039496:
                    if (name.equals("byte")) {
                        return Byte.class;
                    }
                    break;
                case 3052374:
                    if (name.equals("char")) {
                        return Character.class;
                    }
                    break;
                case 3327612:
                    if (name.equals("long")) {
                        return Long.class;
                    }
                    break;
                case 3625364:
                    if (name.equals("void")) {
                        return Void.class;
                    }
                    break;
                case 64711720:
                    if (name.equals("boolean")) {
                        return Boolean.class;
                    }
                    break;
                case 97526364:
                    if (name.equals("float")) {
                        return Float.class;
                    }
                    break;
                case 109413500:
                    if (name.equals("short")) {
                        return Short.class;
                    }
                    break;
            }
        }
        return a2;
    }

    public static boolean B(MotionEvent motionEvent, int i2) {
        if ((motionEvent.getSource() & i2) == i2) {
            return true;
        }
        return false;
    }

    public static float C(float f2) {
        if (f2 <= 0.04045f) {
            return f2 / 12.92f;
        }
        return (float) Math.pow((f2 + 0.055f) / 1.055f, 2.4f);
    }

    public static float D(I1.a aVar) {
        float C2 = C(aVar.f1531a);
        float C3 = C(aVar.f1532b) * 0.7152f;
        return (C(aVar.f1533c) * 0.0722f) + C3 + (C2 * 0.2126f);
    }

    public static String E(String str) {
        h.e(str, "s");
        try {
            MessageDigest messageDigest = MessageDigest.getInstance("MD5");
            byte[] bytes = str.getBytes(M0.a.f1992a);
            h.d(bytes, "getBytes(...)");
            messageDigest.update(bytes);
            byte[] digest = messageDigest.digest();
            StringBuffer stringBuffer = new StringBuffer();
            for (byte b2 : digest) {
                stringBuffer.append(Integer.toHexString(b2 & 255));
            }
            String stringBuffer2 = stringBuffer.toString();
            h.d(stringBuffer2, "toString(...)");
            return stringBuffer2;
        } catch (NoSuchAlgorithmException unused) {
            return "";
        }
    }

    public static HttpURLConnection F(String str) {
        h.e(str, "address");
        URL url = new URL(str);
        int i2 = 0;
        while (i2 < 6) {
            if (!Thread.currentThread().isInterrupted()) {
                if (!h.a(url.getProtocol(), "http") && !h.a(url.getProtocol(), "https")) {
                    throw new IOException("Invalid image URL");
                }
                URLConnection openConnection = url.openConnection();
                h.c(openConnection, "null cannot be cast to non-null type java.net.HttpURLConnection");
                HttpURLConnection httpURLConnection = (HttpURLConnection) openConnection;
                httpURLConnection.setConnectTimeout(10000);
                httpURLConnection.setReadTimeout(10000);
                httpURLConnection.setInstanceFollowRedirects(false);
                try {
                    int responseCode = httpURLConnection.getResponseCode();
                    if (responseCode != 301 && responseCode != 302 && responseCode != 303 && responseCode != 307 && responseCode != 308) {
                        if (200 <= responseCode && responseCode < 300) {
                            return httpURLConnection;
                        }
                        throw new IOException("Image HTTP " + responseCode);
                    }
                    if (i2 != 5) {
                        String headerField = httpURLConnection.getHeaderField("Location");
                        if (headerField != null) {
                            URL url2 = new URL(url, headerField);
                            httpURLConnection.disconnect();
                            i2++;
                            url = url2;
                        } else {
                            throw new IOException("Missing image redirect URL");
                        }
                    } else {
                        throw new IOException("Too many image redirects");
                    }
                } catch (Exception e2) {
                    httpURLConnection.disconnect();
                    throw e2;
                }
            } else {
                throw new InterruptedException();
            }
        }
        throw new IOException("Too many image redirects");
    }

    public static final boolean G(String str) {
        h.e(str, "method");
        if (!str.equals("GET") && !str.equals("HEAD")) {
            return true;
        }
        return false;
    }

    public static final byte[] J(InputStream inputStream) {
        ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
        byte[] bArr = new byte[8192];
        while (true) {
            int read = inputStream.read(bArr);
            if (read >= 0) {
                if (byteArrayOutputStream.size() + read <= 1048576) {
                    byteArrayOutputStream.write(bArr, 0, read);
                } else {
                    throw new IllegalArgumentException("Failed requirement.");
                }
            } else {
                byte[] byteArray = byteArrayOutputStream.toByteArray();
                h.d(byteArray, "toByteArray(...)");
                return byteArray;
            }
        }
    }

    public static q K(p pVar) {
        pVar.C(1);
        int t2 = pVar.t();
        long j2 = pVar.f6094b + t2;
        int i2 = t2 / 18;
        long[] jArr = new long[i2];
        long[] jArr2 = new long[i2];
        int i3 = 0;
        while (true) {
            if (i3 >= i2) {
                break;
            }
            long l2 = pVar.l();
            if (l2 == -1) {
                jArr = Arrays.copyOf(jArr, i3);
                jArr2 = Arrays.copyOf(jArr2, i3);
                break;
            }
            jArr[i3] = l2;
            jArr2[i3] = pVar.l();
            pVar.C(2);
            i3++;
        }
        pVar.C((int) (j2 - pVar.f6094b));
        return new q(jArr, jArr2);
    }

    public static final String L(Reader reader) {
        StringWriter stringWriter = new StringWriter();
        char[] cArr = new char[8192];
        int read = reader.read(cArr);
        while (read >= 0) {
            stringWriter.write(cArr, 0, read);
            read = reader.read(cArr);
        }
        String stringWriter2 = stringWriter.toString();
        h.d(stringWriter2, "toString(...)");
        return stringWriter2;
    }

    public static float M(I1.a aVar) {
        float f2;
        float f3 = aVar.f1531a;
        float f4 = aVar.f1532b;
        float f5 = ((f3 + f4) + aVar.f1533c) / 3.0f;
        double d2 = 2;
        return (float) Math.sqrt(((((float) Math.pow(f3 - f5, d2)) + ((float) Math.pow(f4 - f5, d2))) + ((float) Math.pow(f2 - f5, d2))) / 3.0f);
    }

    public static EnumC0343a N(File file, File file2, byte[] bArr, C0346d c0346d) {
        Object obj;
        ByteBuffer byteBuffer;
        long j2;
        h.e(bArr, "tag");
        EnumC0343a r2 = r(file);
        EnumC0343a enumC0343a = EnumC0343a.f5597h;
        if (r2 != enumC0343a && Mp3Encoder.f7310g) {
            MediaExtractor mediaExtractor = new MediaExtractor();
            try {
                mediaExtractor.setDataSource(file.getAbsolutePath());
                Iterator it = V0.d.c0(0, mediaExtractor.getTrackCount()).iterator();
                while (true) {
                    J0.b bVar = (J0.b) it;
                    if (bVar.f1625h) {
                        obj = bVar.next();
                        if (h.a(mediaExtractor.getTrackFormat(((Number) obj).intValue()).getString("mime"), "audio/mp4a-latm")) {
                            break;
                        }
                    } else {
                        obj = null;
                        break;
                    }
                }
                Integer num = (Integer) obj;
                if (num != null) {
                    int intValue = num.intValue();
                    MediaFormat trackFormat = mediaExtractor.getTrackFormat(intValue);
                    h.d(trackFormat, "getTrackFormat(...)");
                    int integer = trackFormat.getInteger("sample-rate");
                    int integer2 = trackFormat.getInteger("channel-count");
                    ByteBuffer byteBuffer2 = trackFormat.getByteBuffer("csd-0");
                    if (byteBuffer2 != null) {
                        byteBuffer = byteBuffer2.duplicate();
                    } else {
                        byteBuffer = null;
                    }
                    if (byteBuffer != null) {
                        byte[] bArr2 = new byte[byteBuffer.remaining()];
                        byteBuffer.get(bArr2);
                        if (O(bArr2, integer, integer2)) {
                            if (trackFormat.containsKey("durationUs")) {
                                j2 = trackFormat.getLong("durationUs");
                            } else {
                                j2 = 0;
                            }
                            mediaExtractor.selectTrack(intValue);
                            ByteBuffer allocateDirect = ByteBuffer.allocateDirect(65536);
                            ByteBuffer order = ByteBuffer.allocateDirect(16384).order(ByteOrder.LITTLE_ENDIAN);
                            byte[] bArr3 = new byte[32768];
                            OfflineDecoder offlineDecoder = new OfflineDecoder(true, integer, integer2);
                            Mp3Encoder mp3Encoder = new Mp3Encoder(integer, integer2);
                            try {
                                RandomAccessFile randomAccessFile = new RandomAccessFile(file2, "rw");
                                randomAccessFile.setLength(0L);
                                randomAccessFile.write(bArr);
                                long j3 = 0;
                                while (!Thread.currentThread().isInterrupted()) {
                                    allocateDirect.clear();
                                    EnumC0343a enumC0343a2 = enumC0343a;
                                    int readSampleData = mediaExtractor.readSampleData(allocateDirect, 0);
                                    if (readSampleData >= 0) {
                                        if (readSampleData <= allocateDirect.capacity()) {
                                            int decode = offlineDecoder.decode(allocateDirect, readSampleData, order);
                                            if (decode > 0) {
                                                int l2 = mp3Encoder.l(decode, order, bArr3);
                                                if (l2 >= 0) {
                                                    randomAccessFile.write(bArr3, 0, l2);
                                                    ByteBuffer byteBuffer3 = allocateDirect;
                                                    j3 += decode / (integer2 * 2);
                                                    if (j2 > 0) {
                                                        c0346d.a(Integer.valueOf(V0.d.o((int) ((100 * mediaExtractor.getSampleTime()) / j2), 0, 99)));
                                                    }
                                                    if (mediaExtractor.advance()) {
                                                        allocateDirect = byteBuffer3;
                                                        enumC0343a = enumC0343a2;
                                                    }
                                                } else {
                                                    throw new IOException("Ошибка MP3-кодировщика: " + l2);
                                                }
                                            } else {
                                                throw new IOException("Не удалось декодировать AAC нашей библиотекой");
                                            }
                                        } else {
                                            throw new IOException("Слишком большой AAC-пакет");
                                        }
                                    }
                                    if (j3 > 0) {
                                        if (!Thread.currentThread().isInterrupted()) {
                                            int j4 = mp3Encoder.j(bArr3);
                                            if (j4 >= 0) {
                                                randomAccessFile.write(bArr3, 0, j4);
                                                int k2 = mp3Encoder.k(bArr3);
                                                if (k2 >= 0) {
                                                    if (k2 > 0) {
                                                        randomAccessFile.seek(bArr.length);
                                                        randomAccessFile.write(bArr3, 0, k2);
                                                    }
                                                    c0346d.a(100);
                                                    randomAccessFile.close();
                                                    m.i(mp3Encoder, null);
                                                    m.i(offlineDecoder, null);
                                                    mediaExtractor.release();
                                                    return enumC0343a2;
                                                }
                                                throw new IllegalStateException("Check failed.");
                                            }
                                            throw new IllegalStateException("Check failed.");
                                        }
                                        throw new InterruptedException();
                                    }
                                    throw new IllegalStateException("Пустая AAC-дорожка");
                                }
                                throw new InterruptedException();
                            } finally {
                            }
                        } else {
                            throw new IOException("Конвертация этого профиля AAC пока не поддерживается");
                        }
                    } else {
                        throw new IOException("Конвертация этого профиля AAC пока не поддерживается");
                    }
                } else {
                    throw new IOException("В файле нет AAC-дорожки");
                }
            } finally {
                mediaExtractor.release();
            }
        } else {
            long j5 = 0;
            BufferedInputStream bufferedInputStream = new BufferedInputStream(new FileInputStream(file), 8192);
            try {
                BufferedOutputStream bufferedOutputStream = new BufferedOutputStream(new FileOutputStream(file2), 8192);
                byte[] bArr4 = new byte[65536];
                while (!Thread.currentThread().isInterrupted()) {
                    int read = bufferedInputStream.read(bArr4);
                    if (read >= 0) {
                        bufferedOutputStream.write(bArr4, 0, read);
                        j5 += read;
                        long j6 = 100 * j5;
                        long length = file.length();
                        if (length < 1) {
                            length = 1;
                        }
                        c0346d.a(Integer.valueOf((int) (j6 / length)));
                    } else {
                        bufferedOutputStream.close();
                        bufferedInputStream.close();
                        return r2;
                    }
                }
                throw new InterruptedException();
            } finally {
            }
        }
    }

    public static boolean O(byte[] bArr, int i2, int i3) {
        Integer s2;
        int[] iArr = {96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000, 7350};
        if (P(bArr, 0, 5) == 2 && (s2 = AbstractC0542h.s(P(bArr, 5, 4), iArr)) != null && s2.intValue() == i2 && P(bArr, 9, 4) == i3 && P(bArr, 13, 3) == 0 && 1 <= i3 && i3 < 3) {
            J0.c c02 = V0.d.c0(16, bArr.length * 8);
            if (!(c02 instanceof Collection) || !((Collection) c02).isEmpty()) {
                Iterator it = c02.iterator();
                while (true) {
                    if (!((J0.b) it).f1625h) {
                        break;
                    } else if (P(bArr, ((J0.b) it).a(), 1) != 0) {
                        if (P(bArr, 16, 11) == 695 && P(bArr, 27, 5) == 5 && P(bArr, 32, 1) == 0) {
                            J0.c c03 = V0.d.c0(33, bArr.length * 8);
                            if (!(c03 instanceof Collection) || !((Collection) c03).isEmpty()) {
                                Iterator it2 = c03.iterator();
                                while (((J0.b) it2).f1625h) {
                                    if (P(bArr, ((J0.b) it2).a(), 1) != 0) {
                                    }
                                }
                            }
                        }
                    }
                }
            }
            return true;
        }
        return false;
    }

    public static final int P(byte[] bArr, int i2, int i3) {
        int i4 = i3 + i2;
        if (i4 > bArr.length * 8) {
            return -1;
        }
        int i5 = 0;
        while (i2 < i4) {
            i5 = (i5 << 1) | ((bArr[i2 / 8] >>> (7 - (i2 % 8))) & 1);
            i2++;
        }
        return i5;
    }

    public static final int Q(byte[] bArr, int i2) {
        return (bArr[i2 + 2] & 255) | ((bArr[i2] & 255) << 16) | ((bArr[i2 + 1] & 255) << 8);
    }

    public static String R(String str) {
        int length = str.length();
        int i2 = 0;
        while (i2 < length) {
            char charAt = str.charAt(i2);
            if (charAt >= 'A' && charAt <= 'Z') {
                char[] charArray = str.toCharArray();
                while (i2 < length) {
                    char c2 = charArray[i2];
                    if (c2 >= 'A' && c2 <= 'Z') {
                        charArray[i2] = (char) (c2 ^ ' ');
                    }
                    i2++;
                }
                return String.valueOf(charArray);
            }
            i2++;
        }
        return str;
    }

    public static String S(String str) {
        int length = str.length();
        int i2 = 0;
        while (i2 < length) {
            char charAt = str.charAt(i2);
            if (charAt >= 'a' && charAt <= 'z') {
                char[] charArray = str.toCharArray();
                while (i2 < length) {
                    char c2 = charArray[i2];
                    if (c2 >= 'a' && c2 <= 'z') {
                        charArray[i2] = (char) (c2 ^ ' ');
                    }
                    i2++;
                }
                return String.valueOf(charArray);
            }
            i2++;
        }
        return str;
    }

    public static Object a(Parcel parcel, Parcelable.Creator creator) {
        if (parcel.readInt() != 0) {
            return creator.createFromParcel(parcel);
        }
        return null;
    }

    public static final void b(Q0.a aVar, Q0.c cVar, String str) {
        Q0.d.f2957h.getClass();
        Logger logger = Q0.d.f2959j;
        logger.fine(cVar.f2952b + ' ' + String.format("%-22s", Arrays.copyOf(new Object[]{str}, 1)) + ": " + aVar.f2945a);
    }

    public static void c(Throwable th, Throwable th2) {
        h.e(th, "<this>");
        h.e(th2, "exception");
        if (th != th2) {
            Integer num = y0.a.f8026a;
            if (num != null && num.intValue() < 19) {
                Method method = AbstractC0627a.f7999a;
                if (method != null) {
                    method.invoke(th, th2);
                    return;
                }
                return;
            }
            th.addSuppressed(th2);
        }
    }

    public static C0192e d() {
        C0192e c0192e = C0192e.f4103l;
        h.b(c0192e);
        C0192e c0192e2 = c0192e.f4105f;
        if (c0192e2 == null) {
            long nanoTime = System.nanoTime();
            C0192e.f4100i.await(C0192e.f4101j, TimeUnit.MILLISECONDS);
            C0192e c0192e3 = C0192e.f4103l;
            h.b(c0192e3);
            if (c0192e3.f4105f != null || System.nanoTime() - nanoTime < C0192e.f4102k) {
                return null;
            }
            return C0192e.f4103l;
        }
        long nanoTime2 = c0192e2.f4106g - System.nanoTime();
        if (nanoTime2 > 0) {
            C0192e.f4100i.await(nanoTime2, TimeUnit.NANOSECONDS);
            return null;
        }
        C0192e c0192e4 = C0192e.f4103l;
        h.b(c0192e4);
        c0192e4.f4105f = c0192e2.f4105f;
        c0192e2.f4105f = null;
        return c0192e2;
    }

    public static String e(String str, int i2, int i3) {
        if (i2 < 0) {
            return V0.d.G("%s (%s) must not be negative", str, Integer.valueOf(i2));
        }
        if (i3 >= 0) {
            return V0.d.G("%s (%s) must not be greater than size (%s)", str, Integer.valueOf(i2), Integer.valueOf(i3));
        }
        StringBuilder sb = new StringBuilder(26);
        sb.append("negative size: ");
        sb.append(i3);
        throw new IllegalArgumentException(sb.toString());
    }

    /* JADX WARN: Type inference failed for: r0v1, types: [L0.k, java.lang.Object, u0.a] */
    public static final void f(View view) {
        h.e(view, "<this>");
        ?? obj = new Object();
        C0389D c0389d = new C0389D(view, obj);
        c0389d.f6133h = obj;
        obj.f1826i = c0389d;
        while (obj.hasNext()) {
            View view2 = (View) obj.next();
            C0510a c0510a = (C0510a) view2.getTag(R.id.pooling_container_listener_holder_tag);
            if (c0510a == null) {
                c0510a = new C0510a();
                view2.setTag(R.id.pooling_container_listener_holder_tag, c0510a);
            }
            ArrayList arrayList = c0510a.f6545a;
            int q2 = AbstractC0546l.q(arrayList);
            if (-1 < q2) {
                arrayList.get(q2).getClass();
                throw new ClassCastException();
            }
        }
    }

    public static void j(int i2, int i3) {
        String G2;
        if (i2 >= 0 && i2 < i3) {
            return;
        }
        if (i2 >= 0) {
            if (i3 >= 0) {
                G2 = V0.d.G("%s (%s) must be less than size (%s)", "index", Integer.valueOf(i2), Integer.valueOf(i3));
            } else {
                StringBuilder sb = new StringBuilder(26);
                sb.append("negative size: ");
                sb.append(i3);
                throw new IllegalArgumentException(sb.toString());
            }
        } else {
            G2 = V0.d.G("%s (%s) must not be negative", "index", Integer.valueOf(i2));
        }
        throw new IndexOutOfBoundsException(G2);
    }

    public static void k(int i2, int i3) {
        if (i2 >= 0 && i2 <= i3) {
            return;
        }
        throw new IndexOutOfBoundsException(e("index", i2, i3));
    }

    public static void l(int i2, int i3, int i4) {
        String e2;
        if (i2 >= 0 && i3 >= i2 && i3 <= i4) {
            return;
        }
        if (i2 >= 0 && i2 <= i4) {
            if (i3 >= 0 && i3 <= i4) {
                e2 = V0.d.G("end index (%s) must not be less than start index (%s)", Integer.valueOf(i3), Integer.valueOf(i2));
            } else {
                e2 = e("end index", i3, i4);
            }
        } else {
            e2 = e("start index", i2, i4);
        }
        throw new IndexOutOfBoundsException(e2);
    }

    public static void m(long j2, p pVar, s[] sVarArr) {
        int i2;
        int i3;
        boolean z2;
        while (true) {
            boolean z3 = true;
            if (pVar.a() > 1) {
                int i4 = 0;
                while (true) {
                    if (pVar.a() == 0) {
                        i2 = -1;
                        break;
                    }
                    int r2 = pVar.r();
                    i4 += r2;
                    if (r2 != 255) {
                        i2 = i4;
                        break;
                    }
                }
                int i5 = 0;
                while (true) {
                    if (pVar.a() == 0) {
                        i5 = -1;
                        break;
                    }
                    int r3 = pVar.r();
                    i5 += r3;
                    if (r3 != 255) {
                        break;
                    }
                }
                int i6 = pVar.f6094b + i5;
                if (i5 != -1 && i5 <= pVar.a()) {
                    if (i2 == 4 && i5 >= 8) {
                        int r4 = pVar.r();
                        int w2 = pVar.w();
                        if (w2 == 49) {
                            i3 = pVar.e();
                        } else {
                            i3 = 0;
                        }
                        int r5 = pVar.r();
                        if (w2 == 47) {
                            pVar.C(1);
                        }
                        if (r4 == 181 && ((w2 == 49 || w2 == 47) && r5 == 3)) {
                            z2 = true;
                        } else {
                            z2 = false;
                        }
                        if (w2 == 49) {
                            if (i3 != 1195456820) {
                                z3 = false;
                            }
                            z2 &= z3;
                        }
                        if (z2) {
                            n(j2, pVar, sVarArr);
                        }
                    }
                } else {
                    AbstractC0384a.z("CeaUtil", "Skipping remainder of malformed SEI NAL unit.");
                    i6 = pVar.f6095c;
                }
                pVar.B(i6);
            } else {
                return;
            }
        }
    }

    public static void n(long j2, p pVar, s[] sVarArr) {
        long j3;
        int r2 = pVar.r();
        if ((r2 & 64) != 0) {
            pVar.C(1);
            int i2 = (r2 & 31) * 3;
            int i3 = pVar.f6094b;
            int length = sVarArr.length;
            int i4 = 0;
            while (i4 < length) {
                s sVar = sVarArr[i4];
                pVar.B(i3);
                sVar.a(i2, pVar);
                if (j2 != -9223372036854775807L) {
                    j3 = j2;
                    sVar.d(j3, 1, i2, 0, null);
                } else {
                    j3 = j2;
                }
                i4++;
                j2 = j3;
            }
        }
    }

    public static long o(InputStream inputStream, OutputStream outputStream) {
        byte[] bArr = new byte[8192];
        int read = inputStream.read(bArr);
        long j2 = 0;
        while (read >= 0) {
            outputStream.write(bArr, 0, read);
            j2 += read;
            read = inputStream.read(bArr);
        }
        return j2;
    }

    /* JADX WARN: Code restructure failed: missing block: B:101:0x023e, code lost:
        throw new java.lang.IllegalArgumentException("Повреждён заголовок AAC");
     */
    /* JADX WARN: Code restructure failed: missing block: B:85:0x020d, code lost:
        throw new java.lang.IllegalArgumentException("Failed requirement.");
     */
    /* JADX WARN: Code restructure failed: missing block: B:90:0x021a, code lost:
        throw new java.lang.IllegalArgumentException("Формат AAC изменился внутри трека");
     */
    /* JADX WARN: Code restructure failed: missing block: B:99:0x0235, code lost:
        throw new java.lang.IllegalArgumentException("Поток должен содержать AAC-LC");
     */
    /* JADX WARN: Multi-variable type inference failed */
    /* JADX WARN: Removed duplicated region for block: B:118:0x0279  */
    /* JADX WARN: Type inference failed for: r14v0, types: [java.lang.Object] */
    /* JADX WARN: Type inference failed for: r14v1, types: [E0.m] */
    /* JADX WARN: Type inference failed for: r14v3 */
    /* JADX WARN: Type inference failed for: r14v7 */
    /* JADX WARN: Type inference failed for: r1v0, types: [java.lang.Object, E0.n] */
    /* JADX WARN: Type inference failed for: r2v47 */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct add '--show-bad-code' argument
    */
    public static void p(g1.C0311B r30, java.io.OutputStream r31) {
        /*
            Method dump skipped, instructions count: 670
            To view this dump add '--comments-level debug' option
        */
        throw new UnsupportedOperationException("Method not decompiled: A.b.p(g1.B, java.io.OutputStream):void");
    }

    public static final void q(E0.m mVar, ByteBuffer byteBuffer, n nVar, OutputStream outputStream, ByteBuffer byteBuffer2) {
        float f2;
        byteBuffer2.order(ByteOrder.LITTLE_ENDIAN);
        while (byteBuffer2.remaining() >= mVar.f1221f * 2) {
            byteBuffer.clear();
            while (byteBuffer2.remaining() >= mVar.f1221f * 2 && byteBuffer.remaining() >= 8) {
                float f3 = byteBuffer2.getShort() / 32768.0f;
                if (mVar.f1221f == 1) {
                    f2 = f3;
                } else {
                    f2 = byteBuffer2.getShort() / 32768.0f;
                }
                byteBuffer.putFloat(f3);
                byteBuffer.putFloat(f2);
                nVar.f1222f++;
            }
            outputStream.write(byteBuffer.array(), 0, byteBuffer.position());
        }
    }

    /* JADX WARN: Code restructure failed: missing block: B:37:0x0081, code lost:
        if (r15.read() < 0) goto L43;
     */
    /* JADX WARN: Code restructure failed: missing block: B:40:0x008d, code lost:
        throw new java.io.IOException("Неполный ID3");
     */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct add '--show-bad-code' argument
    */
    public static h1.EnumC0343a r(java.io.File r15) {
        /*
            Method dump skipped, instructions count: 238
            To view this dump add '--comments-level debug' option
        */
        throw new UnsupportedOperationException("Method not decompiled: A.b.r(java.io.File):h1.a");
    }

    public static final String s(long j2) {
        String str;
        if (j2 <= -999500000) {
            str = ((j2 - 500000000) / 1000000000) + " s ";
        } else if (j2 <= -999500) {
            str = ((j2 - 500000) / 1000000) + " ms";
        } else if (j2 <= 0) {
            str = ((j2 - 500) / 1000) + " µs";
        } else if (j2 < 999500) {
            str = ((j2 + 500) / 1000) + " µs";
        } else if (j2 < 999500000) {
            str = ((j2 + 500000) / 1000000) + " ms";
        } else {
            str = ((j2 + 500000000) / 1000000000) + " s ";
        }
        return String.format("%6s", Arrays.copyOf(new Object[]{str}, 1));
    }

    public static int t(float f2, float f3, float f4) {
        return Color.rgb((int) ((V0.d.n(f2, 0.0f, 1.0f) * 255.0f) + 0.5f), (int) ((V0.d.n(f3, 0.0f, 1.0f) * 255.0f) + 0.5f), (int) ((V0.d.n(f4, 0.0f, 1.0f) * 255.0f) + 0.5f));
    }

    public static ArrayList u(JSONObject jSONObject, String str) {
        String c2;
        String str2;
        h.e(jSONObject, "data");
        ArrayList arrayList = new ArrayList();
        JSONArray optJSONArray = jSONObject.optJSONArray(str);
        if (optJSONArray != null) {
            int length = optJSONArray.length();
            for (int i2 = 0; i2 < length; i2++) {
                JSONObject optJSONObject = optJSONArray.optJSONObject(i2);
                if (optJSONObject != null) {
                    int b2 = R1.a.b(optJSONObject, "id", 0);
                    if (str.equals("profiles")) {
                        c2 = R1.a.c(optJSONObject, "first_name", "") + ' ' + R1.a.c(optJSONObject, "last_name", "");
                    } else {
                        c2 = R1.a.c(optJSONObject, "name", "");
                    }
                    String str3 = c2;
                    if (str.equals("groups")) {
                        str2 = "page";
                    } else {
                        str2 = "profile";
                    }
                    String str4 = str2;
                    String c3 = R1.a.c(optJSONObject, "photo_200", "");
                    if (c3.length() == 0) {
                        c3 = R1.a.c(optJSONObject, "photo_base", "");
                    }
                    String str5 = c3;
                    String c4 = R1.a.c(optJSONObject, "photo_50", "");
                    if (c4.length() == 0) {
                        c4 = R1.a.c(optJSONObject, "photo_base", "");
                    }
                    arrayList.add(new g(b2, str3, str4, str5, c4));
                }
            }
        }
        return arrayList;
    }

    /* JADX WARN: Removed duplicated region for block: B:21:0x004b  */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct add '--show-bad-code' argument
    */
    public static N0.k v(javax.net.ssl.SSLSession r5) {
        /*
            r0.s r0 = r0.s.f6736f
            java.lang.String r1 = r5.getCipherSuite()
            if (r1 == 0) goto L79
            java.lang.String r2 = "TLS_NULL_WITH_NULL_NULL"
            boolean r2 = r1.equals(r2)
            if (r2 == 0) goto L12
            r2 = 1
            goto L18
        L12:
            java.lang.String r2 = "SSL_NULL_WITH_NULL_NULL"
            boolean r2 = r1.equals(r2)
        L18:
            if (r2 != 0) goto L6d
            N0.b r2 = N0.f.f2117b
            N0.f r1 = r2.e(r1)
            java.lang.String r2 = r5.getProtocol()
            if (r2 == 0) goto L65
            java.lang.String r3 = "NONE"
            boolean r3 = r3.equals(r2)
            if (r3 != 0) goto L5d
            N0.A r2 = V0.m.p(r2)
            java.security.cert.Certificate[] r3 = r5.getPeerCertificates()     // Catch: javax.net.ssl.SSLPeerUnverifiedException -> L42
            if (r3 == 0) goto L42
            int r4 = r3.length     // Catch: javax.net.ssl.SSLPeerUnverifiedException -> L42
            java.lang.Object[] r3 = java.util.Arrays.copyOf(r3, r4)     // Catch: javax.net.ssl.SSLPeerUnverifiedException -> L42
            java.util.List r3 = O0.b.k(r3)     // Catch: javax.net.ssl.SSLPeerUnverifiedException -> L42
            goto L43
        L42:
            r3 = r0
        L43:
            N0.k r4 = new N0.k
            java.security.cert.Certificate[] r5 = r5.getLocalCertificates()
            if (r5 == 0) goto L54
            int r0 = r5.length
            java.lang.Object[] r5 = java.util.Arrays.copyOf(r5, r0)
            java.util.List r0 = O0.b.k(r5)
        L54:
            N0.j r5 = new N0.j
            r5.<init>(r3)
            r4.<init>(r2, r1, r0, r5)
            return r4
        L5d:
            java.io.IOException r5 = new java.io.IOException
            java.lang.String r0 = "tlsVersion == NONE"
            r5.<init>(r0)
            throw r5
        L65:
            java.lang.IllegalStateException r5 = new java.lang.IllegalStateException
            java.lang.String r0 = "tlsVersion == null"
            r5.<init>(r0)
            throw r5
        L6d:
            java.io.IOException r5 = new java.io.IOException
            java.lang.String r0 = "cipherSuite == "
            java.lang.String r0 = r0.concat(r1)
            r5.<init>(r0)
            throw r5
        L79:
            java.lang.IllegalStateException r5 = new java.lang.IllegalStateException
            java.lang.String r0 = "cipherSuite == null"
            r5.<init>(r0)
            throw r5
        */
        throw new UnsupportedOperationException("Method not decompiled: A.b.v(javax.net.ssl.SSLSession):N0.k");
    }

    public static t w(String str) {
        if (str.equals("http/1.0")) {
            return t.f2235g;
        }
        if (str.equals("http/1.1")) {
            return t.f2236h;
        }
        if (str.equals("h2_prior_knowledge")) {
            return t.f2239k;
        }
        if (str.equals("h2")) {
            return t.f2238j;
        }
        if (str.equals("spdy/3.1")) {
            return t.f2237i;
        }
        if (str.equals("quic")) {
            return t.f2240l;
        }
        throw new IOException("Unexpected protocol: ".concat(str));
    }

    public static String x(Context context) {
        try {
            String property = System.getProperty("os.arch");
            String language = Locale.getDefault().getLanguage();
            Point i2 = R1.a.i(context);
            return "VKAndroidApp/8.175-51775 (Android " + Build.VERSION.RELEASE + "; SDK " + Build.VERSION.SDK_INT + "; " + property + "; " + Build.MODEL + "; " + language + "; " + i2.x + 'x' + i2.y + ')';
        } catch (Exception e2) {
            e2.printStackTrace();
            return "VKAndroidApp/8.87-21014 (Android 12; SDK 31; arm64-v8a;Google Nexus 5X; ru; 1920x1080)";
        }
    }

    public static String y(Context context) {
        String str;
        h.e(context, "ctx");
        if (N1.e.f2294n.length() > 0) {
            return N1.e.f2294n;
        }
        try {
            str = Settings.Secure.getString(context.getContentResolver(), "android_id");
            h.d(str, "getString(...)");
        } catch (Exception unused) {
            str = "";
        }
        try {
            String property = System.getProperty("os.arch");
            StringBuilder sb = new StringBuilder();
            sb.append(str);
            sb.append(':');
            sb.append(E(Build.MODEL + Build.ID + Build.MANUFACTURER + Build.BRAND + Build.TYPE + property));
            String sb2 = sb.toString();
            N1.e.f2294n = sb2;
            return sb2;
        } catch (Exception e2) {
            e2.printStackTrace();
            String concat = str.concat(":45c4c99f645eacee39036f5c4f8cddbf");
            N1.e.f2294n = concat;
            return concat;
        }
    }

    public static IconCompat z(P p2, String str, int i2) {
        X x2 = p2.f724m;
        h.b(x2);
        Bitmap e2 = p2.e(str, x2, i2, i2);
        h.b(e2);
        IconCompat iconCompat = new IconCompat(1);
        iconCompat.f4238b = e2;
        return iconCompat;
    }

    public abstract void H(C0257f c0257f, C0257f c0257f2);

    public abstract void I(C0257f c0257f, Thread thread);

    public abstract boolean g(AbstractFutureC0258g abstractFutureC0258g, C0254c c0254c);

    public abstract boolean h(AbstractFutureC0258g abstractFutureC0258g, Object obj, Object obj2);

    public abstract boolean i(AbstractFutureC0258g abstractFutureC0258g, C0257f c0257f, C0257f c0257f2);
}
