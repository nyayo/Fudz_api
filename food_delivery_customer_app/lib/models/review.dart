class Review {
  final int id;
  final int restaurant;
  final int? customer;
  final String customerName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.restaurant,
    this.customer,
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as int,
      restaurant: json['restaurant'] is int
          ? json['restaurant']
          : int.tryParse(json['restaurant'].toString()) ?? 0,
      customer: json['customer'] is int ? json['customer'] : null,
      customerName: json['customer_name']?.toString() ?? 'Anonymous',
      rating: json['rating'] is int
          ? json['rating']
          : int.tryParse(json['rating'].toString()) ?? 0,
      comment: json['comment']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'restaurant': restaurant,
      'rating': rating,
      'comment': comment,
    };
  }
}
