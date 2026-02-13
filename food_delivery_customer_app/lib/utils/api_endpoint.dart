// utils/api_endpoint.dart
class ApiEndpoint {
  // Base API URL is taken from environment at compile time so we don't
  // commit production hostnames in source. Use --dart-define to set
  // API_BASE_URL during builds (example below). A secure HTTPS default
  // is provided for local development if no define is supplied.
  //
  // Example: flutter run --dart-define=API_BASE_URL=https://api.myhost.com/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.example.com/api/v1',
  );

  // Auth endpoints
  static const String requestOtpEmail = '$baseUrl/users/auth/request-otp/';
  static const String verifyOtpEmail = '$baseUrl/users/auth/verify-otp/';
  static const String googleAuth = '$baseUrl/users/auth/google/';
  static String get register => "$baseUrl/users/auth/register/";
  static String get userProfile => "$baseUrl/users/auth/profile/";
  static String get refreshToken => "$baseUrl/users/auth/token/refresh/";
  
  // Restaurant endpoints
  static const String getRestaurants = '$baseUrl/restaurants/restaurants/';
  static const String getCategories = '$baseUrl/restaurants/categories/';
  static String getCategoryDetail(int id) => '$baseUrl/restaurants/categories/$id/';
  static String getRestaurantDetail(int id) => '$baseUrl/restaurants/restaurants/$id/';
  static String getRestaurantCategories(int restaurantId) => '$baseUrl/restaurants/restaurants/$restaurantId/categories/';
  static String getCategoryItems(int restaurantId, int categoryId) => '$baseUrl/restaurants/restaurants/$restaurantId/categories/$categoryId/items/';
  static String getMenuItemDetail(int restaurantId, int categoryId, int itemId) => '$baseUrl/restaurants/restaurants/$restaurantId/categories/$categoryId/items/$itemId/';
  
  // Menu Items endpoints
  static const String getAllMenuItems = '$baseUrl/restaurants/menu-items/'; // All menu items
  static String getMenuItemDetailById(int itemId) => '$baseUrl/restaurants/menu-items/$itemId/';
  
  // Cart endpoints
  static const String createCart = '$baseUrl/orders/carts/';
  static String getCart(String cartId) => '$baseUrl/orders/carts/$cartId/';
  static String getCartItems(String cartId) => '$baseUrl/orders/carts/$cartId/items/';
  static String getCartItem(String cartId, int itemId) => '$baseUrl/orders/carts/$cartId/items/$itemId/';
  
  // Order endpoints
  static const String createOrder = '$baseUrl/orders/orders/';
  static const String getUserOrders = '$baseUrl/orders/orders/';
  static String getOrderDetail(int orderId) => '$baseUrl/orders/orders/$orderId/';
  static String acceptOrder(int orderId) => '$baseUrl/orders/orders/$orderId/accept/';

  // Wishlist endpoints
  static const String getWishlist = '$baseUrl/wishlists/';
  static const String addToWishlist = '$baseUrl/wishlists/add/';
  static String removeFromWishlist(int menuItemId) => '$baseUrl/wishlists/remove/$menuItemId/';
}