abstract final class AppUrls {
  static const String baseUrl = "https://moneapp.monebakeryuz.uz";
  // static const String baseUrl = "http://localhost:1010";

  static const String login = '$baseUrl/api/login';
  static const String register = '$baseUrl/api/register';
  static const String refresh = '$baseUrl/api/auth/refresh';
  static const String productAll = '$baseUrl/api/products/all';
  static const String product1 = '$baseUrl/api/products1';
  static const String product = '$baseUrl/api/products';

  // Mahsulot tarkibi uchun birliklar ro'yxati
  static const String units = '$baseUrl/api/units';

  // Ombor (bozor mahsulotlari)
  static String omborProducts = '$baseUrl/api/ombor/products';

  // Yuk keltiruvchi (sklad buyurtmalari)
  static String yukOrders = '$baseUrl/api/yuk/orders';

  static const String users = '$baseUrl/api/users';
  static String orders = '$baseUrl/api/orders';

  // Real-time buyurtmalar uchun WebSocket. https->wss, http->ws avtomatik.
  static String wsOrders = '${baseUrl.replaceFirst('http', 'ws')}/api/ws';
  static const String orderslist = '$baseUrl/api/orderslist';
  //filials
  static const String filials = '$baseUrl/api/filials';
  //Category
  static const String category = '$baseUrl/api/categories';
  static String categoryById(String id) => '$baseUrl/api/categories/$id';
  static const String categoryReorder = '$baseUrl/api/categories/reorder';
  static const String productReorder = '$baseUrl/api/products/reorder';
  //Category Items
  static const String categoryItems = '$baseUrl/api/category-items';
  static String categoryItemsByCategory(int id) =>
      '$baseUrl/api/categories/$id/items';

  // Upload
  static const String upload = '$baseUrl/api/upload';
  static const String uploadVideo = '$baseUrl/api/upload-video';
}
