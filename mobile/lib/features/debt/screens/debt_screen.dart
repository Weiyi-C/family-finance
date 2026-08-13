import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DebtScreen extends ConsumerWidget {
  const DebtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('借贷管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: 创建借贷记录
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 借贷汇总
            _buildSummaryCard(context),
            const SizedBox(height: 16),
            // 借出列表
            Text(
              '借出',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildDebtItem(context, '张三', '¥5,000', '2026-06-01', true),
            _buildDebtItem(context, '李四', '¥2,000', '2026-07-15', true),
            const SizedBox(height: 16),
            // 借入列表
            Text(
              '借入',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildDebtItem(context, '王五', '¥3,000', '2026-05-20', false),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem(context, '借出总额', '¥7,000', Colors.red),
            _buildSummaryItem(context, '借入总额', '¥3,000', Colors.green),
            _buildSummaryItem(context, '净借出', '¥4,000', Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, String amount, Color color) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          amount,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDebtItem(BuildContext context, String name, String amount, String date, bool isLend) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isLend ? Colors.red[50] : Colors.green[50],
          child: Icon(
            isLend ? Icons.arrow_upward : Icons.arrow_downward,
            color: isLend ? Colors.red : Colors.green,
          ),
        ),
        title: Text(name),
        subtitle: Text('日期: $date'),
        trailing: Text(
          amount,
          style: TextStyle(
            color: isLend ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () {
          // TODO: 查看详情
        },
      ),
    );
  }
}
