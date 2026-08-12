import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('储蓄目标'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: 创建储蓄目标
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGoalItem(
            context,
            '旅行基金',
            '¥10,000',
            '¥6,500',
            0.65,
            Icons.flight,
            Colors.blue,
          ),
          _buildGoalItem(
            context,
            '新电脑',
            '¥8,000',
            '¥3,200',
            0.4,
            Icons.computer,
            Colors.purple,
          ),
          _buildGoalItem(
            context,
            '应急基金',
            '¥20,000',
            '¥18,000',
            0.9,
            Icons.savings,
            Colors.green,
          ),
          _buildGoalItem(
            context,
            '生日礼物',
            '¥2,000',
            '¥2,000',
            1.0,
            Icons.card_giftcard,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalItem(
    BuildContext context,
    String title,
    String target,
    String current,
    double progress,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '目标: $target',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('已存: $current', style: Theme.of(context).textTheme.bodySmall),
                Text('剩余: ¥${(double.parse(target.substring(1)) - double.parse(current.substring(1))).toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
