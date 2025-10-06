abstract final class AppUrls {
  static const String baseUrl = "https://api.uz-dev-ai.uz";
  static const String login = '$baseUrl/api/login';
  static const String register = '$baseUrl/api/register';
  static const String refresh = '$baseUrl/api/auth/refresh';
  static const String productAll = '$baseUrl/api/products/all';
  static const String product1 = '$baseUrl/api/products1';
  static const String product = '$baseUrl/api/products';
  static const String users = '$baseUrl/api/users';
  static String orders = '$baseUrl/api/orders';
  //filials
  static const String filials = '$baseUrl/api/filials';
  //Category
  static const String category = '$baseUrl/api/categories';
  static String categoryById(String id) => '$baseUrl/api/categories/$id';
}


// https://imzo-ai.uzjoylar.uz/html-download?pdf_category_item_id=
// https://api.uz-dev-ai.uz