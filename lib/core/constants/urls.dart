// core/constants/urls.dart — BARCHA backend endpoint manzillari (AppUrls):
// baseUrl + har bir API yo'li (login, products, ombor, yuk, production, stock,
// prices, analytics, POS, filials...). Yangi endpoint SHU YERGA qo'shiladi.
abstract final class AppUrls {
  static const String baseUrl = "https://moneapp.monebakeryuz.uz";
  // static const String baseUrl = "http://localhost:1010";

  static const String login = '$baseUrl/api/login';
  // v1 login — FAQAT parol bilan kirish (eski /api/login telefon+parol
  // bilan ishlashda davom etadi, eski ilova versiyalari uchun).
  static const String loginV1 = '$baseUrl/api/v1/login';
  static const String register = '$baseUrl/api/register';
  static const String productAll = '$baseUrl/api/products/all';
  static const String product1 = '$baseUrl/api/products1';
  static const String product = '$baseUrl/api/products';
  // Masalliqning QO'LDA kiritilgan xarid narxi (hech qachon sotib olinmagan
  // mahsulot uchun): PUT {"manual_price": 8000} — BUTUN so'm, mahsulotning
  // TO'LIQ birligi uchun (кг → 1 kg narxi, шт → 1 dona narxi). 0 —
  // o'chirish. Faqat admin.
  static String productManualPrice(int id) =>
      '$baseUrl/api/products/$id/manual-price';

  // Retsept (tex karta) tarixi: GET — versiyalar ro'yxati (meta, kartasiz),
  // POST rollback {"version_id": N} — kartani tanlangan nusxaga qaytaradi.
  // Faqat admin.
  static String techCardVersions(int id) =>
      '$baseUrl/api/products/$id/tech-card/versions';
  static String techCardRollback(int id) =>
      '$baseUrl/api/products/$id/tech-card/rollback';

  // Ombor (bozor mahsulotlari)
  static String omborProducts = '$baseUrl/api/ombor/products';

  // Yuk keltiruvchi (sklad buyurtmalari)
  static String yukOrders = '$baseUrl/api/yuk/orders';
  // Yuk keltiruvchi buyurtmaga biriktiriladigan rasm/video yuklash
  static String yukUpload = '$baseUrl/api/yuk/upload';
  // Qo'shimcha yozuv "Nomi" maydoni uchun takliflar
  // (?item_type=proche — katalog + ilgarigi nomlar, ?item_type=rasxod —
  // faqat ilgari yozilgan xarajat nomlari).
  static String procheNames = '$baseUrl/api/yuk/proche-names';
  // Yuk keltiruvchining kunlik hisob daftari (ostatok/rasxod/prixod)
  static String yukLedger = '$baseUrl/api/yuk/ledger';
  // Bitta kunning xarajat tafsiloti (?date=YYYY-MM-DD[&user_id=N])
  static String yukLedgerDay = '$baseUrl/api/yuk/ledger/day';
  // Yuk keltiruvchi foydalanuvchilar ro'yxati (bugalter pul berishi uchun)
  static String yukUsers = '$baseUrl/api/yuk-users';
  // Bugalter yuk keltiruvchiga pul berishi (prixod yozuvi)
  static String payments = '$baseUrl/api/payments';
  // Targovli (qilinadigan_ishlar) tizimidan yuborilgan pullar —
  // yuk keltiruvchi qabul qiladi/rad etadi (accept/reject POST'lari ham
  // shu bazaviy yo'l ostida: /{id}/accept, /{id}/reject).
  static String yukTransfers = '$baseUrl/api/yuk/transfers';
  // Yuk keltiruvchining qarz daftari (magazinchilardan qarzlar). Ost-yo'llar:
  //   /{id}                  — magazinni tahrirlash (PUT) / o'chirish (DELETE)
  //   /{id}/debts            — qarz yozuvlari (GET ro'yxat, POST qo'shish)
  //   /{id}/debts/{debtId}   — qarz yozuvini o'chirish (DELETE)
  static String magazins = '$baseUrl/api/magazins';

  // Bugalter (hisobchi): barcha skladlarning narxlangan/qabul qilingan
  // buyurtmalari.
  static String bugalterOrders = '$baseUrl/api/bugalter/orders';
  // Bugalter buyurtma ichidagi mahsulot miqdori yoki SUMMASINI tuzatishi
  // (eski APK'lardan qolgan gram xatolari va xato narxlar uchun).
  // PUT {taken?, received?, count?, subtotal?} — kamida bittasi; miqdorlar
  // API birlikda (кг/л -> butun gr/ml), subtotal — BUTUN so'm.
  static String bugalterOrderItemQty(int orderId, int productId) =>
      '$baseUrl/api/bugalter/orders/$orderId/items/$productId/qty';
  // DELETE — bugalter mahsulotni o'chiradi (soft-delete: deleted=true,
  // miqdor/summa nolga qaytadi). Rollar: bugalter yoki admin.
  static String bugalterOrderItem(int orderId, int productId) =>
      '$baseUrl/api/bugalter/orders/$orderId/items/$productId';
  // Shu tahrirlarning TARIXI: GET ?order_id=&product_id=&limit= — kim,
  // qachon, qaysi maydonni, eski → yangi. Eng yangisi birinchi.
  // Rollar: bugalter yoki admin. Javob — audit yozuvlari (AuditLogEntry).
  static String bugalterEdits = '$baseUrl/api/bugalter/edits';
  // Bugalter Excel hisobot: GET ?from=YYYY-MM-DD&to=YYYY-MM-DD (ikkalasi
  // majburiy, `to` kuni ham kiradi) -> .xlsx binar fayl (attachment).
  // Rollar: bugalter yoki admin. Xato JSON {success:false, message}.
  static String bugalterExport = '$baseUrl/api/bugalter/export';

  // Ishlab chiqarish (производство) — shef roli.
  // Tex kartasi bor mahsulotlar ro'yxati (buyurtma yaratish uchun).
  static String productionProducts = '$baseUrl/api/production/products';

  // Admin boshqaruv paneli: bugungi buyurtmalar, ishlab chiqarish holati,
  // kam qolgan xomashyo jamlanmasi.
  static String dashboard = '$baseUrl/api/dashboard';

  // Kunlik ishlab chiqarish rejasi (MRP): ?date=YYYY-MM-DD&sklad_id=N —
  // filial buyurtmalaridan tort → П/Ф → xomashyo ehtiyoji va defitsit.
  static String productionRequirements = '$baseUrl/api/production/requirements';
  // Ishlab chiqarish buyurtmalari. Ost-yo'llar:
  //   /{id}                                   — bitta buyurtma
  //   /{id}/items/{pi}/stages/{si}/accept     — shef masalliqni qabul qildi
  //   /{id}/items/{pi}/stages/{si}/reject     — rad etdi (body: {comment})
  //   /{id}/items/{pi}/stages/{si}/progress   — done_qty kiritish (PUT)
  // pi/si — 0-based item/stage indekslari.
  static String productionOrders = '$baseUrl/api/production/orders';
  // Полуфабрикат qoldig'i bo'yicha buyurtma limiti:
  // GET ?product_id=N&qty=Q (shef/ombor — o'z skladi; admin/bugalter
  // qo'shimcha &sklad_id=M berishi mumkin). data: { sklad_id, max_qty
  // (null = cheksiz), limits: [{product_id, name, image_url, batch_qty,
  // per_batch_need, need, stock, reserved, available}] }.
  static String pfAvailability = '$baseUrl/api/production/pf-availability';
  // Takrorlanadigan bir xil bazalarni полуфабрикат mahsulotlarga aylantirish
  // (faqat admin). POST {"dry_run": true|false} -> data: {created, skipped}.
  static String techcardsConvertPf = '$baseUrl/api/techcards/convert-pf';

  // Sklad qoldig'i (to'liq inventar). GET ?sklad_id=N — qoldiqlar ro'yxati.
  static String stock = '$baseUrl/api/stock';
  // POST {sklad_id, product_id, qty(+/-), comment} — qo'lda korreksiya.
  static String stockAdjust = '$baseUrl/api/stock/adjust';
  // GET ?sklad_id=N[&product_id=M][&limit=K] — harakatlar tarixi (desc).
  static String stockMoves = '$baseUrl/api/stock/moves';
  // POST {sklad_id, product_id, qty(+), reason} — SPISANIYA (brak/yo'qotish):
  // skladdan chiqim + audit ("spisaniya" — POS spisaniyasi bilan bitta hisobot).
  static String stockWriteOff = '$baseUrl/api/stock/write-off';
  // POST {sklad_id, product_id, min_qty} — minimal qoldiq chegarasi.
  static String stockMin = '$baseUrl/api/stock/min';
  // POST {sklad_id, items:[{product_id, actual_qty}]} — inventarizatsiya
  // (real sanab chiqilgan qoldiqlar; farqlar korreksiya bo'lib yoziladi).
  static String stockInventory = '$baseUrl/api/stock/inventory';
  // Inventarizatsiya dalolatnomalari (акт): qachon sanalgan, nima kam chiqqan
  // va bu qancha pul. Ombor — o'z skladi, admin — istalgani. Ost-yo'llar:
  //   GET ?sklad_id=N[&limit=K] — ro'yxat (eng yangisi birinchi, items'siz)
  //   GET /{id}                 — bitta dalolatnoma, items (farqli qatorlar)
  //                               bilan; narxlar sanash paytidagi holatda.
  static String stockInventories = '$baseUrl/api/stock/inventories';

  // Tannarx: GET ?product_id=N — mahsulot tex kartasi bo'yicha 1 partiya /
  // 1 dona tannarxi (admin/bugalter).
  static String productionCost = '$baseUrl/api/production/cost';
  // Statistika: GET ?from=YYYY-MM-DD&to=YYYY-MM-DD (admin/bugalter).
  static String productionStats = '$baseUrl/api/production/stats';
  // Oxirgi xarid narxlari: GET — barcha mahsulotlarning eng so'nggi narxi.
  // unit_price ENG KICHIK birlik uchun (кг/л -> 1 gr/ml, шт -> 1 dona,
  // м -> 1 metr). Hech narxlanmaganlar ro'yxatda yo'q. Admin/bugalter.
  static String latestPrices = '$baseUrl/api/prices/latest';
  // Xarid narxlari tarixi: GET ?product_id=N&limit=20 — bitta mahsulotning
  // narxlangan xaridlari (eng yangisi birinchi). Admin/bugalter.
  static String pricesHistory = '$baseUrl/api/prices/history';
  // Foyda analitikasi: GET ?days=N (7/30/90) — tortlar bo'yicha tushum/
  // tannarx/foyda, kunlik marja dinamikasi va masalliq narx sakrashlari.
  // Admin/bugalter.
  static String profitAnalytics = '$baseUrl/api/analytics/profit';

  // Audit jurnali: GET ?limit=&entity=&action= — admin harakatlari tarixi
  // (narx o'zgarishi, sklad korreksiyasi, o'chirishlar...). Faqat admin.
  static const String auditLog = '$baseUrl/api/audit-log';

  static const String users = '$baseUrl/api/users';
  // Login+parolni Telegram orqali yuborish:
  //   POST $users/{id}/send-credentials — bitta foydalanuvchiga (service ichida quriladi)
  //   POST quyidagi manzil — barcha foydalanuvchilarga birdan
  static const String usersSendAllCredentials = '$users/send-all-credentials';
  // GET — Telegram bot username'i ({"data":{"username":"..."}}).
  static const String telegramBot = '$baseUrl/api/telegram-bot';
  static String orders = '$baseUrl/api/orders';

  // Real-time buyurtmalar uchun WebSocket. https->wss, http->ws avtomatik.
  static String wsOrders = '${baseUrl.replaceFirst('http', 'ws')}/api/ws';
  //filials
  static const String filials = '$baseUrl/api/filials';

  // Skladlar (omborxonalar): GET — hamma rol o'qiydi (nom/tab/dropdown shu
  // ro'yxatdan); POST {name}, PUT /{id} {name}, DELETE /{id} — faqat superadmin.
  static const String sklads = '$baseUrl/api/sklads';

  // Print agentlar (admin): ulangan Windows agentlar va ulardagi real printer
  // nomlari — kategoriya oynasidagi printer dropdown shu ro'yxatdan quriladi.
  static const String printAgents = '$baseUrl/api/print-agents';
  // Filial limitlari: GET ?filial_id=N — filialning mahsulot limitlari;
  // POST {filial_id, product_id, limit_qty} — upsert (limit_qty: 0 —
  // o'chirish). limit_qty birlik kontrakti: кг/л -> BUTUN gr/ml. Faqat admin.
  static const String filialLimits = '$baseUrl/api/filial-limits';
  // POS (Konak) buyurtmalari: GET ?limit=50 — «POS avto» useri yaratgan
  // avto-buyurtmalar (eng yangisi birinchi). Faqat admin.
  static const String posOrders = '$baseUrl/api/pos-orders';
  // POST — buyurtmani bazadan POS'ga yuborish (PosDelivery yaratadi).
  static String posOrderDispatch(int id) =>
      '$baseUrl/api/pos-orders/$id/dispatch';
  // POS smena sotuvlari hisoboti: GET ?days=30[&filial_id=] —
  // {sales:[...], total}. days default 30, clamp [1,92]. Faqat admin.
  static const String posSales = '$baseUrl/api/pos-sales';
  // POS smena solishtirish (recon): GET ?days=30[&filial_id=] —
  // {recons:[...]}. days default 30, clamp [1,92]. Faqat admin.
  static const String posRecons = '$baseUrl/api/pos-recons';
  // POS menyu — Konak POS ko'radigan katalog: GET ?filial_id=N (ixtiyoriy,
  // default birinchi filial) — {filial_id, filial_name, categories, products}.
  // Faqat admin.
  static const String posMenu = '$baseUrl/api/pos-menu';
  // RK7 integratsiyasi (faqat admin). Import qilingan smenalar: GET ?days=30 —
  // {shifts:[...]}, eng yangisi birinchi, days clamp [1,92].
  static const String rk7Shifts = '$baseUrl/api/rk7/shifts';
  // Bitta smena to'liq: items/voids/deductions/unmapped.
  static String rk7Shift(int id) => '$baseUrl/api/rk7/shifts/$id';
  // Sotuvda uchragan bog'lanmagan RK7 taomlari (smenalardan jamlab):
  // {dish_guid, dish_name, last_date, total_qty_milli}.
  static const String rk7Unmapped = '$baseUrl/api/rk7/unmapped';
  // Taom → Mone mahsuloti bog'lanishi: GET ?q= (nom/kod qidiruvi, limit 200);
  // POST {dish_guid, product_id, deduct_mode, per_portion, active} — upsert.
  // per_portion — BUTUN (1 porsiyaga necha saqlash birligi), float yo'q.
  static const String rk7Mappings = '$baseUrl/api/rk7/mappings';
  // RK7 sotuv nuqtalari: GET — hammasi (mapping holati bilan);
  // POST {uot_guid, filial_id, sklad_id, active} — upsert.
  static const String rk7SalePlaces = '$baseUrl/api/rk7/sale-places';

  //Category
  static const String category = '$baseUrl/api/categories';
  static const String categoryReorder = '$baseUrl/api/categories/reorder';
  static const String productReorder = '$baseUrl/api/products/reorder';

  // Upload
  static const String upload = '$baseUrl/api/upload';

  // Kategoriya mahsulotlari PDF katalogi (POST — stream yuklab olinadi).
  static String categoryPdf(int categoryId) =>
      '$baseUrl/api/products/category/$categoryId/pdf';
}
