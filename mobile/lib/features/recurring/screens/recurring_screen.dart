import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('周期交易'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: 创建周期交易
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildRecurringItem(
            context,
            '房租',
            '每月1号',
            '¥2,000.00',
            Icons.home,
            Colors.blue,
            true,
          ),
          _buildRecurringItem(
            context,
            '工资',
            '每月15号',
            '¥15,000.00',
            Icons.account_balance,
            Colors.green,
            true,
          ),
          _buildRecurringItem(
            context,
            '话费',
            '每月5号',
            '¥50.00',
            Icons.phone,
            Colors.orange,
            true,
          ),
          _buildRecurringItem(
            context,
            '视频会员',
            '每月20号',
            '¥25.00',
            Icons.movie,
            Colors.purple,
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringItem(
    BuildContext context,
    String title,
    String frequency,
    String amount,
    IconData icon,
    Color color,
    bool isActive,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(frequency),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              amount,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: isActive,
              onChanged: (value) {
                // TODO: 切换启用状态
              },
            ),
          ],
        ),
        onTap: () {
          // TODO: 查看详情
        },
      ),
    );
  }
}
