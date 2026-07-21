# CODEMAP — `uz_ai_dev` (Mone Flutter ilovasi)

Bu fayl butun ilova bo'ylab **tez navigatsiya** uchun. Sessiya boshida shuni o'qi:
qaysi papka nima uchun, feature qanday qatlamlarga bo'linadi, muhim ekran/provider
qayerda va «falon vazifa uchun qayerga qarash» kerak.

- Har bir `.dart` faylning eng tepasida qisqa **maqsad izohi** bor (asosiy
  class/screen/provider nomi bilan) — grep uchun ideal boshlanish nuqtasi.
- Stack: **Provider** (ChangeNotifier) holat, **GetIt** (`sl<...>`) DI, **Dio** HTTP,
  **SharedPreferences** lokal saqlash. Feature naqsh: `models/ → services/ → provider/ → ui/`.
- Rollar: `seller` (=user), `admin`/`superadmin`, hamda ichki logistika rollari
  `ombor`, `yuk_keltiruvchi`, `bugalter`, `shef` (roles: `lib/core/constants/roles.dart`).
- ⚠️ **Float serverga yubormaymiz.** кг/л miqdorlar API'da BUTUN гр/мл; pul — BUTUN so'm int.
  Konvert: `lib/core/utils/qty_units.dart`.

---

## 1. Papka xaritasi

| Papka | Roli / feature | Asosiy ekranlar / providerlar |
|---|---|---|
| `lib/admin/` | admin / superadmin: mahsulot, kategoriya, тех карта, foyda, POS, filial, user | `AdminHomeUi`, `AddProductPage`, `EditProductPage`, `TechCardEditorPage`, `ProfitControlUi`, `ProfitAnalyticsUi`, POS ekranlari (`pos_*_ui`), `FilialLimitsUi`, `UserManagementScreen`. Providerlar: `ProductProviderAdmin` (YAGONA manba), `CategoryProviderAdmin`, `FilialProviderAdmin`, `CategoryProviderAdminUpload` |
| `lib/user/` | `seller` (oddiy foydalanuvchi): katalog ko'rish + buyurtma berish | `UserHomeUi`, `ProductsScreen`, `UserProductDetailUi`, `CartPage` (`order_ui`), `OrdersPage`. Provider: `ProductProvider` (`user/provider/provider.dart`) |
| `lib/ombor/` | `ombor` (bozor/sklad): bozor mahsulotidan buyurtma, ishlab chiqarish, qoldiq | `OmborHomeUi`, `OmborCategoryProductsUi`, `OmborOrdersUi`, `OmborProductionUi`, `OmborStockUi`, `OmborLowStockUi`. Provider: `OmborProvider`, `OmborProductionProvider` |
| `lib/yuk/` | `yuk_keltiruvchi`: sklad buyurtmalari, kunlik hisob daftari, magazin qarzlari, targovli pul | `YukHomeUi` (katta), `YukProfileUi`, `YukMagazinUi`/`YukMagazinDetailUi`, `YukHistoryUi`, `YukTransferHistoryUi`. Provider: `YukProvider` (markaziy), `MagazinProvider` |
| `lib/production/` | ishlab chiqarish + sklad qoldig'i + tannarx + narx tarixi + inventarizatsiya (акт). `ombor`/`admin`/`bugalter`/`shef` uchun umumiy | `StockInventoryPage`, `InventoryHistoryPage`, vidjetlar (`stock_widgets`, `production_order_widgets`, `cost_sheet`, `price_history_sheet`). Provider: `StockProvider`, `Base/Ombor/Admin/BugalterProductionProvider` |
| `lib/shef/` | `shef`: ishlab chiqarish buyurtmasi yaratish, bosqichlarni qabul/rad, полуфабрикат limiti | `ShefHomeUi`, `ShefCreateOrderUi`, `ShefOrderDetailUi`. Provider: `ShefProvider` |
| `lib/bugalter/` | `bugalter` (hisobchi): narxlangan buyurtmalar, yuk keltiruvchiga pul berish | `BugalterHomeUi`, `BugalterProductionUi`. Provider: `BugalterProvider` |
| `lib/core/` | umumiy yadro: DI, tarmoq, lokal saqlash, endpointlar, birlik konverti, media | `di.dart`, `urls.dart` (`AppUrls`), `dio_settings.dart`, `order_socket.dart`, `qty_units.dart`, `context_extension.dart`, `media/*` (kamera/video) |
| (root) `lib/` | kirish + marshrutlash | `main.dart`, `splash_screen.dart` (rolga yo'naltirish), `login_page.dart`, `check_version.dart` |

---

## 2. Feature naqshi (`models → services → provider → ui`)

Har bir feature 4 qatlamga bo'linadi:

1. **`models/`** — `fromJson`/`toJson` bilan ma'lumot modeli (backend `snake_case`).
2. **`services/`** — Dio bilan bitta API chaqiruvi; `AppUrls` dan endpoint oladi.
3. **`provider/`** — `ChangeNotifier`, holatni ushlaydi, service'ni chaqiradi, `notifyListeners()`.
4. **`ui/`** — ekran; `context.watch/read<Provider>()` orqali holatga ulanadi.

### Konkret misol — тех карта / полуфабрикат oqimi

Bitta mahsulotning тех карта (kompozitsiya) va tannarxi qanday qatlamlardan o'tadi:

| Qatlam | Fayl | Nima qiladi |
|---|---|---|
| model | `lib/admin/model/tech_card.dart` | `TechCard`, `bases[]`, `consumables[]`; og'irliklar BUTUN gr/ml, avto-hisob |
| model | `lib/admin/model/product_model.dart` | `ProductModelAdmin` — `techCard`, `isSemiFinished`, `wasteBase/wasteAmount` |
| **tannarx** | `lib/admin/model/tech_card_cost.dart` | **YAGONA manba** — sof funksiyalar (`techIngredientPieceCost`, `techFullPieceCost`); narx `GET /api/prices/latest` |
| service | `lib/production/services/production_service.dart` | `GET /api/production/products`, narxlar; `admin/services/api_product_service.dart` — mahsulot CRUD |
| provider | `lib/admin/provider/admin_product_provider.dart` | `ProductProviderAdmin` — mahsulotni xotirada saqlaydi/yangilaydi |
| ui | `lib/admin/ui/tech_card_editor_page.dart` | `TechCardEditorPage` — Excel «тех карта» varag'iga o'xshash muharrir |
| ui (widget) | `lib/admin/ui/widgets/tech_card_section.dart`, `tech_item_editor.dart` | muharrir sub-vidjetlari |
| ui (foyda) | `lib/admin/ui/profit_control_ui.dart` | `ProfitControlUi` — o'sha `tech_card_cost.dart` bilan marja hisoblaydi |

**Muhim:** tannarx matematikasi FAQAT `tech_card_cost.dart` da. Yangi joyda tannarx
hisoblama — o'sha helperlarni chaqir.

---

## 3. Yadro (core) qatlami

| Nima | Fayl | Izoh |
|---|---|---|
| **DI (GetIt)** | `lib/core/di/di.dart` | `setupInit()` — `SharedPreferences`, `BaseStorage`/`TokenStorage`, `Dio` singletonlari. `main()` dan birinchi chaqiriladi. `sl<T>()` bilan olinadi |
| **Global providerlar** | `lib/main.dart` | `MultiProvider` ro'yxati (7-bo'limga qara). Yangi global provider shu yerga qo'shiladi |
| **Marshrutlash** | `lib/splash_screen.dart` | token+role bo'yicha mos Home'ga (`context.pushReplacement`). `lib/core/context_extension.dart` — `push`/`pushReplacement`/`pushAndRemove` qisqartmalari (nomli route YO'Q) |
| **Endpointlar** | `lib/core/constants/urls.dart` | `AppUrls` — BARCHA API manzillari. Yangi endpoint SHU YERGA. `baseUrl` lokalda `localhost:1010` bo'lishi mumkin (test uchun — o'zgartirma) |
| **Dio + token** | `lib/core/network/dio_settings.dart` | `AppDioClient.createDio()` — `Bearer` token interceptor, `X-Qty-Unit: milli` header (гр/мл kontrakti), faqat-debug logger |
| **WebSocket** | `lib/core/network/order_socket.dart` | `OrderSocket` (singleton) — buyurtma/targovli-pul/ishlab-chiqarish real-time hodisalari; auto-reconnect |
| **Xato matni** | `lib/core/network/error_handler.dart` | `parseDioError()` — DioException → o'qiladigan matn |
| **Lokal saqlash** | `lib/core/data/local/` | `BaseStorage` interfeys, `SharedPreferencesImpl`, `TokenStorage` (`token`). Kalitlar: `token`, `role`, `is_admin`, `user`, `name` |
| **Birlik konverti** | `lib/core/utils/qty_units.dart` | `qtyFromUi`/`qtyFromUiSafe` (kg/l → BUTUN gr/ml), `qtyToUi`/`formatQty`/`formatQtyUnit` (gr/ml → kg/l). ⚠️ gram-yozish himoyasi bor |
| **Rollar** | `lib/core/constants/roles.dart` | `AppRoles` — role string konstantalari |
| **Media** | `lib/core/media/` | Ilova ICHIDA kamera/video: `InAppPhotoCamera`, `TelegramStyleVideoRecorder`, `VideoPreviewScreen` (`video_pervi`), `VideoProcessor`, `CircularNetworkVideoPlayer` |

---

## 4. Muhim (og'ir) ekranlar

| Ekran | Fayl | Nima uchun og'ir |
|---|---|---|
| Тех карта muharriri | `lib/admin/ui/tech_card_editor_page.dart` (~2200 qator) | Excel varag'iga 1:1 baza bloklari + расходник, jonli tannarx kataklari |
| Mahsulot qo'shish | `lib/admin/ui/admin_add_product_ui.dart` | тип, mone/bozor, tozalash yo'qotishi, полуфабрикат, tex karta |
| Mahsulot tahrirlash | `lib/admin/ui/admin_edit_product_ui.dart` | yuqoridagidek + rasm yuklash |
| Foyda nazorati | `lib/admin/ui/profit_control_ui.dart` | tannarx vs sotuv narxi, marja (`tech_card_cost.dart` bilan) |
| Foyda analitikasi | `lib/admin/ui/profit_analytics_ui.dart` (~1200 qator) | tortlar bo'yicha tushum/tannarx/foyda grafiklari (`GET /api/analytics/profit`) |
| Shef buyurtma | `lib/shef/ui/shef_create_order_ui.dart`, `shef_order_detail_ui.dart` | полуфабрикат limiti (`pf-availability`), bosqich qabul/rad |
| Ombor ishlab chiqarish | `lib/ombor/ui/ombor_production_ui.dart`, `ombor_orders_ui.dart` (~1400 qator) | ishlab chiqarish oqimi, buyurtma ro'yxati |
| Inventarizatsiya | `lib/production/ui/inventory_page.dart`, `inventory_history_page.dart` | акт инвентаризации, real sanash to'ri |
| Yuk bosh ekran | `lib/yuk/ui/yuk_home_ui.dart` (~2600 qator) | sklad buyurtmalari + targovli pul + kunlik hisob |
| POS (Konak) | `lib/admin/ui/pos_*_ui.dart` (`pos_hub`, `pos_menu`, `pos_orders`, `pos_sales`, `pos_recons`) | Konak POS integratsiyasi (menyu, avto-buyurtma, sotuv, recon) |

---

## 5. «Vazifa → qayerga qarash»

| Vazifa | Qayerga qarash |
|---|---|
| **Yangi endpoint ishlatish** | `lib/core/constants/urls.dart` (`AppUrls` ga URL qo'sh) + tegishli `*/services/*.dart` (Dio chaqiruvi) |
| **Yangi ekran qo'shish** | `*/ui/` (ekran) + `*/provider/` (holat) + agar global bo'lsa `lib/main.dart` provider ro'yxati; navigatsiya `context.push(...)` (`core/context_extension.dart`) |
| **gram/pul konvert** | `lib/core/utils/qty_units.dart` — hech qaerda qo'lda `*1000` yozma; `qtyFromUi`/`qtyToUi`/`formatQty` ishlat |
| **Tannarx / marja matematikasi** | `lib/admin/model/tech_card_cost.dart` — **YAGONA manba** (`techIngredientPieceCost`, `techFullPieceCost`); yangi hisob shu yerga |
| **Тех карта modeli** | `lib/admin/model/tech_card.dart` (struktura) + `admin/model/product_model.dart` (`techCard` maydoni) |
| **Real-time yangilanish** | `lib/core/network/order_socket.dart` (`OrderSocket.instance.events` / `transferEvents` / `productionEvents`) |
| **Token / auth / role saqlash** | `lib/core/data/local/token_storage.dart` + `SharedPreferences` (`token`/`role`/`is_admin`); interceptor `core/network/dio_settings.dart` |
| **Rolga yo'naltirish** | `lib/splash_screen.dart` va `lib/login_page.dart` (`_navigateByRole`) |
| **Admin mahsulot ro'yxati o'zgarishi** | `lib/admin/provider/admin_product_provider.dart` (`ProductProviderAdmin`) — xotirada create/update/delete, re-fetch YO'Q |
| **Rasm/video yuklash** | `lib/admin/provider/upload_image_provider.dart`, `admin/services/tech_image_upload_service.dart`, `core/media/*` |
| **Filial limitlari** | `lib/admin/ui/filial_limits_ui.dart` + `admin/services/filial_limit_service.dart` (`GET/POST /api/filial-limits`) |
| **POS (Konak) integratsiya** | `lib/admin/ui/pos_*_ui.dart` + `admin/services/pos_*_service.dart` + `admin/model/pos_*_model.dart` |
| **Sklad qoldig'i / korreksiya / inventar** | `lib/production/` — `StockProvider`, `stock_service.dart`, `stock_widgets.dart`, `inventory_page.dart` |
| **Versiya tekshiruvi** | `lib/check_version.dart` (`VersionChecker`) |

---

## 6. Providerlar (global — `lib/main.dart` da ro'yxatlangan)

`MultiProvider` da ro'yxatlangan 13 ta global `ChangeNotifier`. Har biri nima ushlaydi:

| Provider | Fayl | Nima ushlaydi |
|---|---|---|
| `ProductProvider` | `user/provider/provider.dart` | seller katalogi + savat (cart) |
| `OmborProvider` | `ombor/provider/ombor_provider.dart` | bozor mahsulotlari, savat, ombor buyurtmalari, socket |
| `YukProvider` | `yuk/provider/yuk_provider.dart` | yuk keltiruvchi: buyurtmalar, ledger, transferlar, narx qoralamalari, offline kesh |
| `BugalterProvider` | `bugalter/provider/bugalter_provider.dart` | hisobchi: narxlangan buyurtmalar, yuk userlar, to'lovlar |
| `ShefProvider` | `shef/provider/shef_provider.dart` | shef: ishlab chiqarish buyurtmalari, mahsulotlar, bosqich holati |
| `OmborProductionProvider` | `production/provider/production_orders_provider.dart` | ombor ishlab chiqarish buyurtmalari |
| `AdminProductionProvider` | `production/provider/production_orders_provider.dart` | admin ishlab chiqarish buyurtmalari |
| `BugalterProductionProvider` | `production/provider/production_orders_provider.dart` | bugalter ishlab chiqarish buyurtmalari |
| `StockProvider` | `production/provider/stock_provider.dart` | sklad qoldig'i keshi, korreksiya, harakatlar tarixi, inventar |
| **`ProductProviderAdmin`** | `admin/provider/admin_product_provider.dart` | **admin mahsulotlarining YAGONA manbai** — bir marta yuklab, create/update/delete/reorder'ni xotirada bajaradi (re-fetch YO'Q) |
| `CategoryProviderAdmin` | `admin/provider/admin_categoriy_provider.dart` | admin kategoriyalari |
| `FilialProviderAdmin` | `admin/provider/admin_filial_provider.dart` | filiallar ro'yxati |
| `CategoryProviderAdminUpload` | `admin/provider/upload_image_provider.dart` | rasm/media yuklash holati |

> Lokal (ekran ichida yaratiladigan) provider: `MagazinProvider`
> (`yuk/provider/magazin_provider.dart`) — magazin qarz daftari ekranlarida.
