class MoneyFormatter {
  const MoneyFormatter._();

  static String formatCents(int amountCents, String currency) {
    final amount = amountCents / 100;
    return '$currency ${amount.toStringAsFixed(2)}';
  }
}
