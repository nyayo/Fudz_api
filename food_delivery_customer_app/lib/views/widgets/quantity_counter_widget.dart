import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/models/menu_item.dart';

class QuantityCounter extends StatelessWidget {
  final CartController cartController;
  final MenuItem menuItem;
  final String? accessToken;
  final double height;
  final bool compact;

  const QuantityCounter({
    super.key,
    required this.cartController,
    required this.menuItem,
    this.accessToken,
    this.height = 40,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final quantity = cartController.getItemQuantity(menuItem.id);
      final cartItemId = cartController.getCartItemId(menuItem.id);
      final isUpdating = cartItemId != null 
          ? cartController.isItemProcessing('${cartItemId}_update')
          : false;
      final isInCart = cartController.isItemInCart(menuItem.id);

      if (!isInCart) {
        return _buildAddButton();
      }

      return _buildCounter(quantity, cartItemId!, isUpdating);
    });
  }

  Widget _buildAddButton() {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: TColor.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 20,
            vertical: 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 8 : 12),
          ),
          elevation: 0,
        ),
        onPressed: accessToken == null || accessToken!.isEmpty
            ? null
            : () async {
                await cartController.addToCart(
                  menuItem: menuItem,
                  quantity: 1,
                  accessToken: accessToken,
                );
              },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart,
              size: compact ? 16 : 18,
            ),
            const SizedBox(width: 4),
            Text(
              'Add',
              style: TextStyle(
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounter(int quantity, String cartItemId, bool isUpdating) {
    final buttonSize = compact ? 28.0 : 32.0;
    final iconSize = compact ? 14.0 : 18.0;
    final fontSize = compact ? 12.0 : 14.0;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: TColor.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(compact ? 20 : 25),
        border: Border.all(
          color: TColor.primary.withOpacity(0.3),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                quantity <= 1 ? Icons.delete_outline : Icons.remove,
                color: quantity <= 1 ? Colors.red : TColor.primary,
                size: iconSize,
              ),
              onPressed: isUpdating
                  ? null
                  : () {
                      cartController.updateQuantity(
                        itemId: cartItemId,
                        quantity: quantity - 1,
                        accessToken: accessToken,
                      );
                    },
            ),
          ),
          Container(
            constraints: BoxConstraints(minWidth: compact ? 24 : 32),
            child: isUpdating
                ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TColor.primary,
                    ),
                  )
                : Text(
                    '$quantity',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: TColor.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.add,
                color: TColor.primary,
                size: iconSize,
              ),
              onPressed: isUpdating
                  ? null
                  : () {
                      cartController.updateQuantity(
                        itemId: cartItemId,
                        quantity: quantity + 1,
                        accessToken: accessToken,
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }
}
