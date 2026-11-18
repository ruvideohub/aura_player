package A;

/* ВЫДЕРЖКА из A/b.java (полный класс в lkmp_decompiled_sources/A/b.java).
   Код 1:1 из APK; убраны только импорты и чужие методы. */


    // ===== E — MD5 (БЕЗ паддинга нулями — нюанс!) =====
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

    // ===== L — Reader -> String =====
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

    // ===== Q — 3 байта big-endian (заголовки скина/скин-контейнера) =====
    public static final int Q(byte[] bArr, int i2) {
        return (bArr[i2 + 2] & 255) | ((bArr[i2] & 255) << 16) | ((bArr[i2 + 1] & 255) << 8);
    }

    // ===== x — User-Agent =====
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

    // ===== y — device_id = android_id + ':' + MD5(Model+ID+Manufacturer+Brand+Type+os.arch) =====
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
