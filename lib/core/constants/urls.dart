abstract final class AppUrls {
  static const String baseUrl = "http://localhost:1010";
  static const String login = '$baseUrl/api/login';
  static const String refresh = '$baseUrl/api/auth/refresh';
  static const String productAll = '$baseUrl/api/products/all';
  //Category
  static const String category = '$baseUrl/api/categories';
  static String categoryById(String id) => '$baseUrl/api/categories/$id';
}


// https://imzo-ai.uzjoylar.uz/html-download?pdf_category_item_id=