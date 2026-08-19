class MoneyFormatter {
  const MoneyFormatter._();

  static String formatCents(int amountCents, String currency) {
    final bool negative = amountCents < 0;
    final int absoluteCents = amountCents.abs();
    final int whole = absoluteCents ~/ 100;
    final String cents = (absoluteCents % 100).toString().padLeft(2, '0');
    return '$currency ${negative ? '-' : ''}$whole.$cents';
  }
}
