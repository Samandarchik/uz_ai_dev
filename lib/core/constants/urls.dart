abstract final class AppUrls {
  // static const String baseUrl = "https://moneapp.monebakeryuz.uz";
  static const baseUrl = "http://localhost:1010";

  static const String login = '$baseUrl/api/login';
  static const String register = '$baseUrl/api/register';
  static const String refresh = '$baseUrl/api/auth/refresh';
  static const String productAll = '$baseUrl/api/products/all';
  static const String product1 = '$baseUrl/api/products1';
  static const String product = '$baseUrl/api/products';

  static const String users = '$baseUrl/api/users';
  static String orders = '$baseUrl/api/orders';
  static const String orderslist = '$baseUrl/api/orderslist';
  //filials
  static const String filials = '$baseUrl/api/filials';
  //Category
  static const String category = '$baseUrl/api/categories';
  static String categoryById(String id) => '$baseUrl/api/categories/$id';
  //Category Items
  static const String categoryItems = '$baseUrl/api/category-items';
  static String categoryItemsByCategory(int id) =>
      '$baseUrl/api/categories/$id/items';

  // Bringer Profiles
  static const String bringerProfiles = '$baseUrl/api/bringer-profiles';

  // Customer Orders
  static const String customerOrders = '$baseUrl/api/customer/orders';

  // Bringer Orders
  static const String bringerOrders = '$baseUrl/api/bringer/orders';
  static const String bringerOrdersActive =
      '$baseUrl/api/bringer/orders/active';
  static const String bringerOrderItems = '$baseUrl/api/bringer/orders/items';
  static const String bringerOrderPush = '$baseUrl/api/bringer/orders/push';

  // Bringer Tasks
  static const String bringerTasks = '$baseUrl/api/bringer/tasks';

  // Bringer Balance
  static const String bringerBalance = '$baseUrl/api/bringer/balance';
  static const String bringerBalanceAdd = '$baseUrl/api/bringer/balance/add';
  static const String bringerTransactions =
      '$baseUrl/api/bringer/balance/transactions';

  // Upload
  static const String upload = '$baseUrl/api/upload';
  static const String uploadVideo = '$baseUrl/api/upload-video';
}
