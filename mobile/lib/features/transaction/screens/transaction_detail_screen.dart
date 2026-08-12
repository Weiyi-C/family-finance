import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/models.dart';
import '../../../core/utils/format_utils.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final Transaction transaction;
  
  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = transaction.type == 'expense';
    final isTransfer = transaction.type == 'transfer';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('交易详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: 编辑交易
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              _showDeleteDialog(context, ref);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 金额卡片
            _buildAmountCard(context, isExpense, isTransfer),
            const SizedBox(height: 16),
            // 详情卡片
            _buildDetailCard(context),
            const SizedBox(height: 16),
            // 备注卡片
            if (transaction.description != null && transaction.description!.isNotEmpty)
              _buildDescriptionCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(BuildContext context, bool isExpense, bool isTransfer) {
    Color color;
    String prefix;
    
    if (isTransfer) {
      color = Colors.blue;
      prefix = '';
    } else if (isExpense) {
      color = Colors.red;
      prefix = '-';
    } else {
      color = Colors.green;
      prefix = '+';
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              transaction.typeDisplay,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '$prefix¥${transaction.amountYuan.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDetailRow(context, '时间', formatDateTime(transaction.transactionTime)),
            const Divider(),
            _buildDetailRow(context, '商户', transaction.merchantName ?? '-'),
            const Divider(),
            _buildDetailRow(context, '分类', transaction.categoryId?.toString() ?? '-'),
            const Divider(),
            _buildDetailRow(context, '账户', transaction.paymentAccountId?.toString() ?? '-'),
            const Divider(),
            _buildDetailRow(context, '状态', transaction.completionStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '备注',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              transaction.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除交易'),
        content: const Text('确定要删除这笔交易吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              // TODO: 调用删除API
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
