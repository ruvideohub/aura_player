package android.support.v4.media.session;

/* ВЫДЕРЖКА из android/support/v4/media/session/q.java (артефакт обфускации:
   реальный класс приложения-хранилища сессии попал в пакет медиасессии).
   this.f4222f = SharedPreferences сессии. Код 1:1 из APK. */


    // ===== R — восстановление сессии из prefs: b=access_token, c=user_id, ex=exchange_token =====
    public boolean R(M1.d dVar) {
        boolean z2;
        E0.h.e(dVar, "o");
        SharedPreferences sharedPreferences = (SharedPreferences) this.f4222f;
        String valueOf = String.valueOf(sharedPreferences.getString("ex", ""));
        String valueOf2 = String.valueOf(sharedPreferences.getString("a", ""));
        String valueOf3 = String.valueOf(sharedPreferences.getString("b", ""));
        String valueOf4 = String.valueOf(sharedPreferences.getString("c", ""));
        dVar.f2014a = valueOf3;
        dVar.f2016c = valueOf;
        dVar.f2015b = valueOf4;
        dVar.f2017d = valueOf2;
        boolean z3 = false;
        if (dVar.f2014a.length() > 0) {
            z2 = true;
        } else {
            z2 = false;
        }
        if (dVar.f2015b.length() > 0) {
            z3 = true;
        }
        return z2 & z3;
    }

    // ===== S — выход: очистка ключей =====
    public void S() {
        SharedPreferences.Editor edit = ((SharedPreferences) this.f4222f).edit();
        E0.h.d(edit, "edit(...)");
        edit.remove("a");
        edit.remove("b");
        edit.remove("c");
        edit.remove("ua");
        edit.remove("ub");
        edit.remove("uc");
        edit.remove("ud");
        edit.remove("ue");
        edit.remove("uf");
        edit.remove("ur");
        edit.remove("ux");
        edit.remove("uy");
        edit.remove("session_uid");
        edit.apply();
        W("user_send_data", false);
    }

    // ===== V — сохранение сессии =====
    public void V(M1.d dVar) {
        E0.h.e(dVar, "o");
        SharedPreferences.Editor edit = ((SharedPreferences) this.f4222f).edit();
        E0.h.d(edit, "edit(...)");
        edit.putString("ex", dVar.f2016c);
        edit.putString("b", dVar.f2014a);
        edit.putString("c", dVar.f2015b);
        edit.apply();
    }
