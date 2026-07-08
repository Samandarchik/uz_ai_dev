abstract final class AppUrls {
  static const String baseUrl = "https://moneapp.monebakeryuz.uz";
  // static const String baseUrl = "http://localhost:1010";

  static const String login = '$baseUrl/api/login';
  static const String register = '$baseUrl/api/register';
  static const String productAll = '$baseUrl/api/products/all';
  static const String product1 = '$baseUrl/api/products1';
  static const String product = '$baseUrl/api/products';

  // Ombor (bozor mahsulotlari)
  static String omborProducts = '$baseUrl/api/ombor/products';

  // Yuk keltiruvchi (sklad buyurtmalari)
  static String yukOrders = '$baseUrl/api/yuk/orders';
  // Yuk keltiruvchi buyurtmaga biriktiriladigan rasm/video yuklash
  static String yukUpload = '$baseUrl/api/yuk/upload';
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

  // Bugalter (hisobchi): barcha skladlarning narxlangan/qabul qilingan
  // buyurtmalari.
  static String bugalterOrders = '$baseUrl/api/bugalter/orders';

  // Ishlab chiqarish (производство) — shef roli.
  // Tex kartasi bor mahsulotlar ro'yxati (buyurtma yaratish uchun).
  static String productionProducts = '$baseUrl/api/production/products';
  // Ishlab chiqarish buyurtmalari. Ost-yo'llar:
  //   /{id}                                   — bitta buyurtma
  //   /{id}/items/{pi}/stages/{si}/accept     — shef masalliqni qabul qildi
  //   /{id}/items/{pi}/stages/{si}/reject     — rad etdi (body: {comment})
  //   /{id}/items/{pi}/stages/{si}/progress   — done_qty kiritish (PUT)
  // pi/si — 0-based item/stage indekslari.
  static String productionOrders = '$baseUrl/api/production/orders';

  // Sklad qoldig'i (to'liq inventar). GET ?sklad_id=N — qoldiqlar ro'yxati.
  static String stock = '$baseUrl/api/stock';
  // POST {sklad_id, product_id, qty(+/-), comment} — qo'lda korreksiya.
  static String stockAdjust = '$baseUrl/api/stock/adjust';
  // GET ?sklad_id=N[&product_id=M][&limit=K] — harakatlar tarixi (desc).
  static String stockMoves = '$baseUrl/api/stock/moves';

  static const String users = '$baseUrl/api/users';
  static String orders = '$baseUrl/api/orders';

  // Real-time buyurtmalar uchun WebSocket. https->wss, http->ws avtomatik.
  static String wsOrders = '${baseUrl.replaceFirst('http', 'ws')}/api/ws';
  //filials
  static const String filials = '$baseUrl/api/filials';
  //Category
  static const String category = '$baseUrl/api/categories';
  static const String categoryReorder = '$baseUrl/api/categories/reorder';
  static const String productReorder = '$baseUrl/api/products/reorder';

  // Upload
  static const String upload = '$baseUrl/api/upload';
}
