import 'package:food_delivery_customer_app/models/menu_item.dart';

class PendingCartOperation {
  final String id;
  final MenuItem menuItem;
  final int quantity;
  final CartOperationType type;
  final DateTime timestamp;

  PendingCartOperation({
    required this.id,
    required this.menuItem,
    required this.quantity,
    required this.type,
    required this.timestamp,
  });
}

enum CartOperationType { add, update, remove }
