import 'package:flutter/material.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_month),
            onSelected: (value) {
              // TODO: 切换时间范围
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'week', child: Text('本周')),
              const PopupMenuItem(value: 'month', child: Text('本月')),
              const PopupMenuItem(value: 'year', child: Text('本年')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 收支概览
            _buildOverviewCard(context),
            const SizedBox(height: 16),
            // 分类占比
            _buildCategoryCard(context),
            const SizedBox(height: 16),
            // 支出排行
            _buildRankingCard(context),
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
                  child: _buildStatItem(context, '收入', '¥15,000', Colors.green),
                ),
                Expanded(
                  child: _buildStatItem(context, '支出', '¥8,500', Colors.red),
                ),
                Expanded(
                  child: _buildStatItem(context, '结余', '¥6,500', Colors.blue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String amount, Color color) {
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

  Widget _buildCategoryCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '分类占比',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            // TODO: 添加饼图
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('饼图区域'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingCard(BuildContext context) {
    final categories = [
      ('餐饮', 3200, 0.38),
      ('交通', 1500, 0.18),
      ('服饰', 1200, 0.14),
      ('住房', 1000, 0.12),
      ('娱乐', 800, 0.09),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '支出排行',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...categories.map((item) => _buildRankItem(
              context,
              item.$1,
              '¥${item.$2}',
              item.$3,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRankItem(
    BuildContext context,
    String category,
    String amount,
    double percentage,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category),
              Text('$amount (${(percentage * 100).toInt()}%)'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
