import 'package:food_delivery_customer_app/models/review.dart';
import 'package:food_delivery_customer_app/services/api_service.dart';
import 'package:get/get.dart';

class ReviewController extends GetxController {
  final ApiService _apiService = Get.find();

  final RxList<Review> reviews = <Review>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSubmitting = false.obs;
  final Rx<Review?> userReview = Rx<Review?>(null);
  final RxString error = ''.obs;

  Future<void> fetchReviews(int restaurantId) async {
    try {
      isLoading.value = true;
      error.value = '';

      final response = await _apiService.get(
        'reviews/',
        params: {'restaurant': restaurantId.toString()},
      );

      final List<dynamic> data = response is List
          ? response
          : (response['results'] ?? []);
      reviews.value = data.map((json) => Review.fromJson(json)).toList();

      // Find current user's review if exists
      _findUserReview();
    } catch (e) {
      error.value = e.toString();
      print('❌ Error fetching reviews: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _findUserReview() {
    // The user's own review will be identified by checking against
    // the customer profile id if available
    // For now, we track it after submission
  }

  Future<bool> submitReview({
    required int restaurantId,
    required int rating,
    required String comment,
  }) async {
    try {
      isSubmitting.value = true;
      error.value = '';

      final data = {
        'restaurant': restaurantId,
        'rating': rating,
        'comment': comment,
      };

      if (userReview.value != null) {
        // Update existing review
        await _apiService.patch('reviews/${userReview.value!.id}/', data);
      } else {
        // Create new review
        await _apiService.post('reviews/', data);
      }

      // Refresh reviews
      await fetchReviews(restaurantId);
      return true;
    } catch (e) {
      error.value = e.toString();
      print('❌ Error submitting review: $e');
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  double get averageRating {
    if (reviews.isEmpty) return 0;
    final total = reviews.fold<int>(0, (sum, r) => sum + r.rating);
    return total / reviews.length;
  }

  int get reviewCount => reviews.length;
}
