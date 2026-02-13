/// Currency formatting utility for Ugandan Shillings
class CurrencyFormatter {
  /// Format a price in Ugandan Shillings (no decimals)
  static String format(double amount) {
    // Round to nearest whole number and format with thousand separators
    final roundedAmount = amount.round();
    return 'UGX ${_formatWithCommas(roundedAmount)}';
  }

  /// Format a price with a minus sign (for discounts)
  static String formatDiscount(double amount) {
    final roundedAmount = amount.round();
    return '-UGX ${_formatWithCommas(roundedAmount)}';
  }

  /// Format just the number without currency symbol
  static String formatNumber(double amount) {
    return _formatWithCommas(amount.round());
  }

  /// Add thousand separators to a number
  static String _formatWithCommas(int number) {
    final str = number.toString();
    final result = StringBuffer();
    int count = 0;

    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result.write(',');
      }
      result.write(str[i]);
      count++;
    }

    return result.toString().split('').reversed.join('');
  }
}
