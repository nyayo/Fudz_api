class Promotion {
  final int id;
  final String name;
  final String description;
  final double discount;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String? banner;

  Promotion({
    required this.id,
    required this.name,
    required this.description,
    required this.discount,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    this.banner,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: _parseInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      discount: _parseDouble(json['discount']) ?? 0.0,
      startDate: DateTime.parse(
        json['start_date']?.toString() ?? DateTime.now().toString(),
      ),
      endDate: DateTime.parse(
        json['end_date']?.toString() ?? DateTime.now().toString(),
      ),
      isActive: json['is_active'] ?? false,
      banner: json['banner']?.toString(),
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
      'banner': banner,
    };
  }

  bool get hasBanner => banner != null && banner!.isNotEmpty;

  bool get isCurrentlyActive {
    final now = DateTime.now();
    final localStart = startDate.toLocal();
    final localEnd = _normalizeEndDate(endDate.toLocal());
    return isActive && !now.isBefore(localStart) && !now.isAfter(localEnd);
  }

  static DateTime _normalizeEndDate(DateTime value) {
    // If the backend sends date-only values, treat the end date as end-of-day.
    if (value.hour == 0 &&
        value.minute == 0 &&
        value.second == 0 &&
        value.millisecond == 0 &&
        value.microsecond == 0) {
      return DateTime(
        value.year,
        value.month,
        value.day,
        23,
        59,
        59,
        999,
        999,
      );
    }

    return value;
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
