package m1;
/* JADX WARN: Failed to restore enum class, 'enum' modifier and super class removed */
/* JADX WARN: Unknown enum class pattern. Please report as an issue! */
/* renamed from: m1.a  reason: case insensitive filesystem */
/* loaded from: classes.dex */
public final class EnumC0446a {

    /* renamed from: f  reason: collision with root package name */
    public static final EnumC0446a f6381f;

    /* renamed from: g  reason: collision with root package name */
    public static final EnumC0446a f6382g;

    /* renamed from: h  reason: collision with root package name */
    public static final EnumC0446a f6383h;

    /* renamed from: i  reason: collision with root package name */
    public static final EnumC0446a f6384i;

    /* renamed from: j  reason: collision with root package name */
    public static final EnumC0446a f6385j;

    /* renamed from: k  reason: collision with root package name */
    public static final EnumC0446a f6386k;

    /* renamed from: l  reason: collision with root package name */
    public static final EnumC0446a f6387l;

    /* renamed from: m  reason: collision with root package name */
    public static final EnumC0446a f6388m;

    /* renamed from: n  reason: collision with root package name */
    public static final EnumC0446a f6389n;

    /* renamed from: o  reason: collision with root package name */
    public static final EnumC0446a f6390o;

    /* renamed from: p  reason: collision with root package name */
    public static final EnumC0446a f6391p;

    /* renamed from: q  reason: collision with root package name */
    public static final /* synthetic */ EnumC0446a[] f6392q;

    /* JADX WARN: Multi-variable type inference failed */
    /* JADX WARN: Type inference failed for: r10v2, types: [java.lang.Enum, m1.a] */
    /* JADX WARN: Type inference failed for: r11v2, types: [java.lang.Enum, m1.a] */
    /* JADX WARN: Type inference failed for: r12v2, types: [java.lang.Enum, m1.a] */
    /* JADX WARN: Type inference failed for: r13v2, types: [java.lang.Enum, m1.a] */
    /* JADX WARN: Type inference failed for: r14v2, types: [java.lang.Enum, m1.a] */
    /* JADX WARN: Type inference failed for: r15v2, types: [java.lang.Enum, m1.a] */
    /* JADX WARN: Type inference failed for: r1v0, types: [java.lang.Enum, m1.a] */
    /* JADX WARN: Type inference failed for: r2v1, types: [java.lang.Enum, m1.a] */
    /* JADX WARN: Type inference failed for: r7v2, types: [java.lang.Enum, m1.a] */
    /* JADX WARN: Type inference failed for: r8v2, types: [java.lang.Enum, m1.a] */
    /* JADX WARN: Type inference failed for: r9v2, types: [java.lang.Enum, m1.a] */
    static {
        ?? r12 = new Enum("SUCCESS", 0);
        f6381f = r12;
        ?? r2 = new Enum("ERROR", 1);
        f6382g = r2;
        Enum r02 = new Enum("ENTER_LOGIN", 2);
        ?? r15 = new Enum("EMAIL_CODE", 3);
        f6383h = r15;
        ?? r14 = new Enum("PASSWORD", 4);
        f6384i = r14;
        ?? r13 = new Enum("PUSH", 5);
        f6385j = r13;
        ?? r122 = new Enum("RESERVE_CODE", 6);
        f6386k = r122;
        ?? r11 = new Enum("SMS_CODE", 7);
        f6387l = r11;
        ?? r10 = new Enum("CODE_GEN", 8);
        f6388m = r10;
        ?? r9 = new Enum("CAPTCHA", 9);
        f6389n = r9;
        ?? r8 = new Enum("SELECT_ANOTHER", 10);
        f6390o = r8;
        ?? r7 = new Enum("HZ", 11);
        f6391p = r7;
        f6392q = new EnumC0446a[]{r12, r2, r02, r15, r14, r13, r122, r11, r10, r9, r8, r7, new Enum("FA_SMS", 12), new Enum("FA_APP", 13), new Enum("FA_PHONE_MASK", 14), new Enum("FA_REDIRECT", 15), new Enum("FA_CAPTCHA", 16)};
    }

    public static EnumC0446a valueOf(String str) {
        return (EnumC0446a) Enum.valueOf(EnumC0446a.class, str);
    }

    public static EnumC0446a[] values() {
        return (EnumC0446a[]) f6392q.clone();
    }
}
