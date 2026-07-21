# Flutter ilova (`uz_ai_dev`) — Claude yo'riqnomasi

Bu **Flutter Claude** ning ish maydoni. Sen FAQAT shu papkani (`uz_ai_dev/`) o'zgartirasan.
Backend (`mone_backend_user_admin/`) ga TEGMA — u boshqa Claude'ning ishi.

> To'liq loyiha konteksti va ikkita Claude bilan parallel ishlash qoidasi yuqoridagi
> `../CLAUDE.md` (mone_app/CLAUDE.md) faylida.

## Navigatsiya

To'liq navigatsiya xaritasi: **`CODEMAP.md`** (papka xaritasi, `models→services→provider→ui`
naqshi, muhim/og'ir ekranlar, «vazifa → qayerga qarash» jadvali, global providerlar
ro'yxati). Sessiya boshida shuni o'qi. Har bir `.dart` fayl tepasida maqsad izohi bor.

Eng ko'p kerak bo'ladiganlar:
- **Endpointlar** → `lib/core/constants/urls.dart` (`AppUrls`)
- **DI (GetIt `sl`)** → `lib/core/di/di.dart`; **global providerlar ro'yxati** → `lib/main.dart`
- **Tannarx / marja matematikasi (YAGONA manba)** → `lib/admin/model/tech_card_cost.dart`
- **gram / pul konvert** → `lib/core/utils/qty_units.dart` (qo'lda `*1000` yozma)
- **Admin mahsulot manbai** → `lib/admin/provider/admin_product_provider.dart` (`ProductProviderAdmin`)

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
- **⚠️ FLOAT SERVERGA YUBORILMAYDI.** Backend saqlaydigan hamma son — eng kichik birlikdagi
  BUTUN son: miqdor (кг/л → гр/мл, `lib/core/utils/qty_units.dart` → `qtyFromUi` bilan
  ×1000 butun; ko'rsatishda `qtyToUi`/`formatQty` bilan kg'ga qaytariladi), **pul — butun
  SO'M** (tiyin yo'q). Foydalanuvchi kg yoki kasr yozsa — UI yaxlitlaydi, keyin yuboradi.
  Kasr pul yuborilsa server so'rovni rad etishi mumkin (`int` maydon). Sabab: `../CLAUDE.md`
  → «NEVER STORE A FLOAT». Hisoblangan nisbat (1 гр narxi, marja %) ekranda float bo'lishi
  mumkin — u saqlanmaydi.
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
