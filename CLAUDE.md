# Flutter ilova (`uz_ai_dev`) — Claude yo'riqnomasi

Bu **Flutter Claude** ning ish maydoni. Sen FAQAT shu papkani (`uz_ai_dev/`) o'zgartirasan.
Backend (`mone_backend_user_admin/`) ga TEGMA — u boshqa Claude'ning ishi.

> To'liq loyiha konteksti va ikkita Claude bilan parallel ishlash qoidasi yuqoridagi
> `../CLAUDE.md` (mone_app/CLAUDE.md) faylida.

## Stack va arxitektura
- **State:** Provider (`ChangeNotifier`) — `lib/*/provider/`. Global providerlar `lib/main.dart` da.
- **DI:** GetIt (`sl<...>`) — `lib/core/di/di.dart`.
- **HTTP:** Dio — `lib/core/network/dio_settings.dart`. Token interceptor orqali `Bearer` qo'shiladi.
- **Local saqlash:** SharedPreferences (`lib/core/data/local/`) — `token`, `role`, `is_admin`, `user`.
- **Endpoint manzillari:** HAMMASI `lib/core/constants/urls.dart` → `AppUrls`. Yangi endpoint shu yerga qo'shiladi.

## Rollar (faqat 2 ta)
- `seller` (oddiy user) → `lib/user/`
- `admin` / `superadmin` → `lib/admin/`
- `customer` va `bringer` **o'chirilgan**. Bu rollarni qайta tiklama. `login_page.dart` va
  `splash_screen.dart` da bu rollar kelsa token tozalanib, xato dialogi chiqadi.

## Konvensiyalar
- Yangi feature uchun naqsh: `models/` → `services/` (Dio chaqiruv) → `provider/` (holat) → `ui/` (ekran).
- Backend JSON `snake_case` ishlatadi; model `fromJson`/`toJson` da shuni hisobga ol.
- API JSON shaklini `../CLAUDE.md` dagi kontrakt bo'yicha aniq moslab yoz.
- Tugatgach: `flutter analyze` da yangi **error** bo'lmasligi kerak (mavjud `info` lintlar muammo emas).

## Tekshirish
```bash
flutter analyze --no-pub
```

## Git (vazifa tugagach)
```bash
git -C . add -A
git -C . commit -m "<o'zbekcha: nima qilindi>"
git -C . push origin main
```
Commit oxiriga: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
