import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReimbursementScreen extends ConsumerWidget {
  const ReimbursementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('报销管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: 创建报销单
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildReimbursementItem(
            context,
            '出差交通费',
            '¥1,200',
            '待审批',
            '2026-08-10',
            Colors.orange,
          ),
          _buildReimbursementItem(
            context,
            '办公用品',
            '¥350',
            '已审批',
            '2026-08-05',
            Colors.blue,
          ),
          _buildReimbursementItem(
            context,
            '客户招待',
            '¥800',
            '已到账',
            '2026-07-28',
            Colors.green,
          ),
          _buildReimbursementItem(
            context,
            '培训费用',
            '¥2,000',
            '已驳回',
            '2026-07-20',
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildReimbursementItem(
    BuildContext context,
    String title,
    String amount,
    String status,
    String date,
    Color statusColor,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(Icons.receipt, color: statusColor),
        ),
        title: Text(title),
        subtitle: Text('日期: $date'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status,
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
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
