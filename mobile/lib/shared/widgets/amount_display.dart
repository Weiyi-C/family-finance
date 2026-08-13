import 'package:flutter/material.dart';

/// 金额显示组件
class AmountDisplay extends StatelessWidget {
  final int cents;
  final String? type;
  final bool showSign;
  final TextStyle? style;

  const AmountDisplay({
    super.key,
    required this.cents,
    this.type,
    this.showSign = true,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final yuan = cents / 100;
    final isExpense = type == 'expense';
    final isIncome = type == 'income';
    final isTransfer = type == 'transfer';

    Color? color;
    String prefix = '';

    if (isExpense) {
      color = Colors.red;
      prefix = showSign ? '-' : '';
    } else if (isIncome) {
      color = Colors.green;
      prefix = showSign ? '+' : '';
    } else if (isTransfer) {
      color = Colors.blue;
    }

    return Text(
      '$prefix¥${yuan.toStringAsFixed(2)}',
      style: style?.copyWith(color: color) ?? TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
