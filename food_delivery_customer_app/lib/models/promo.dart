class Promotion {
  final int id;
  final String name;
  final String description;
  final double discount;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  Promotion({
    required this.id,
    required this.name,
    required this.description,
    required this.discount,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: _parseInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      discount: _parseDouble(json['discount']) ?? 0.0,
      startDate: DateTime.parse(json['start_date']?.toString() ?? DateTime.now().toString()),
      endDate: DateTime.parse(json['end_date']?.toString() ?? DateTime.now().toString()),
      isActive: json['is_active'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'discount': discount,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_active': isActive,
    };
  }

  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && now.isAfter(startDate) && now.isBefore(endDate);
  }

  String get formattedDiscount {
    if (discount % 1 == 0) {
      return '${discount.toInt()}%';
    }
    return '${discount.toStringAsFixed(1)}%';
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}