import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreditBillScreen extends ConsumerWidget {
  const CreditBillScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('信用账单'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 待还总额
            _buildSummaryCard(context),
            const SizedBox(height: 16),
            // 账单列表
            Text(
              '账单列表',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildBillItem(context, '工商银行信用卡', '¥3,500', '2026-08-25', '待还款'),
            _buildBillItem(context, '花呗', '¥1,200', '2026-09-01', '待还款'),
            _buildBillItem(context, '招商银行信用卡', '¥0', '2026-08-20', '已还清'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '待还总额',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '¥4,700.00',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(context, '本期账单', '¥4,700'),
                _buildStatItem(context, '最低还款', '¥470'),
                _buildStatItem(context, '还款日', '8月25日'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBillItem(BuildContext context, String name, String amount, String dueDate, String status) {
    final isPaid = status == '已还清';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPaid ? Colors.green[50] : Colors.orange[50],
          child: Icon(
            isPaid ? Icons.check : Icons.credit_card,
            color: isPaid ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(name),
        subtitle: Text('还款日: $dueDate'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isPaid ? Colors.green : null,
              ),
            ),
            Text(
              status,
              style: TextStyle(
                color: isPaid ? Colors.green : Colors.orange,
                fontSize: 12,
              ),
            ),
          ],
        ),
        onTap: () {
          // TODO: 查看账单详情
        },
      ),
    );
  }
}
