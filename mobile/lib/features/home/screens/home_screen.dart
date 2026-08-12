import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('家庭记账'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: 打开通知页面
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 本月收支概览
            _buildOverviewCard(context),
            const SizedBox(height: 16),
            // 预算进度
            _buildBudgetCard(context),
            const SizedBox(height: 16),
            // 最近账单
            _buildRecentTransactions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本月收支',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAmountItem(
                    context,
                    '收入',
                    '¥15,000.00',
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildAmountItem(
                    context,
                    '支出',
                    '¥8,500.00',
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildAmountItem(
                    context,
                    '结余',
                    '¥6,500.00',
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountItem(
    BuildContext context,
    String label,
    String amount,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
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

  Widget _buildBudgetCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本月预算',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildBudgetItem(context, '餐饮', 0.8, '¥2,400/¥3,000'),
            const SizedBox(height: 8),
            _buildBudgetItem(context, '交通', 0.4, '¥320/¥800'),
            const SizedBox(height: 8),
            _buildBudgetItem(context, '购物', 0.6, '¥900/¥1,500'),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetItem(
    BuildContext context,
    String category,
    double progress,
    String amount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(category),
            Text(amount, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            progress > 0.8 ? Colors.red : Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '最近账单',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () {
                    // TODO: 查看全部账单
                  },
                  child: const Text('查看全部'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildTransactionItem(context, '午饭', '肯德基', '-¥35.00', Icons.restaurant),
            _buildTransactionItem(context, '打车', '滴滴', '-¥25.00', Icons.directions_car),
            _buildTransactionItem(context, '咖啡', '瑞幸', '-¥9.90', Icons.coffee),
            _buildTransactionItem(context, '工资', '工商银行', '+¥15,000', Icons.account_balance, isIncome: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    String title,
    String subtitle,
    String amount,
    IconData icon, {
    bool isIncome = false,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isIncome ? Colors.green[50] : Colors.red[50],
        child: Icon(
          icon,
          color: isIncome ? Colors.green : Colors.red,
          size: 20,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        amount,
        style: TextStyle(
          color: isIncome ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
