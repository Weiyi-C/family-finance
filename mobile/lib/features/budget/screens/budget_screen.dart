import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/format_utils.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('预算管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: 创建预算
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 本月预算总览
          _buildOverviewCard(context),
          const SizedBox(height: 16),
          // 分类预算列表
          _buildBudgetItem(context, '餐饮', 300000, 240000, Colors.orange),
          _buildBudgetItem(context, '交通', 80000, 32000, Colors.blue),
          _buildBudgetItem(context, '购物', 150000, 90000, Colors.purple),
          _buildBudgetItem(context, '住房', 200000, 50000, Colors.green),
          _buildBudgetItem(context, '娱乐', 50000, 45000, Colors.red),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '本月预算',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(context, '总预算', '¥8,100'),
                _buildStatItem(context, '已花费', '¥4,570'),
                _buildStatItem(context, '剩余', '¥3,530'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String amount) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          amount,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetItem(
    BuildContext context,
    String category,
    int total,
    int spent,
    Color color,
  ) {
    final progress = spent / total;
    final isOver = progress > 0.8;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${formatMoney(spent)} / ${formatMoney(total)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.clamp(0, 1),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver ? Colors.red : color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '剩余 ${formatMoney(total - spent)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isOver ? Colors.red : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
