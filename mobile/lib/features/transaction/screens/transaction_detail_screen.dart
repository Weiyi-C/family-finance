import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/models.dart';
import '../../../core/utils/format_utils.dart';
import '../providers/transaction_provider.dart';
import '../../tag/providers/tag_provider.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final Transaction transaction;
  
  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = transaction.type == 'expense';
    final isTransfer = transaction.type == 'transfer';
    final categories = ref.watch(categoriesProvider);
    final accounts = ref.watch(accountsProvider);
    final tagsState = ref.watch(tagProvider);
    
    String resolveCategory() {
      return categories.when(
        data: (list) {
          final match = list.where((c) => c.id == transaction.categoryId).toList();
          return match.isNotEmpty ? match.first.name : '-';
        },
        loading: () => '-',
        error: (_, __) => '-',
      );
    }

    String resolveAccount() {
      return accounts.when(
        data: (list) {
          final match = list.where((a) => a.id == transaction.paymentAccountId).toList();
          return match.isNotEmpty ? match.first.name : '-';
        },
        loading: () => '-',
        error: (_, __) => '-',
      );
    }

    List<Tag> resolveTags() {
      if (transaction.tagIds == null || transaction.tagIds!.isEmpty) return [];
      return tagsState.tags.where((t) => transaction.tagIds!.contains(t.id)).toList();
    }

    final resolvedTags = resolveTags();

    return Scaffold(
      appBar: AppBar(
        title: const Text('交易详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              context.push('/create-transaction', extra: transaction);
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
            _buildAmountCard(context, isExpense, isTransfer),
            const SizedBox(height: 16),
            _buildDetailCard(context, resolveCategory(), resolveAccount()),
            const SizedBox(height: 16),
            if (resolvedTags.isNotEmpty)
              _buildTagsCard(context, resolvedTags),
            if (resolvedTags.isNotEmpty)
              const SizedBox(height: 16),
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
              '$prefix${formatMoney(transaction.amount)}',
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

  Widget _buildDetailCard(BuildContext context, String categoryName, String accountName) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDetailRow(context, '时间', formatDateTime(transaction.transactionTime)),
            const Divider(),
            _buildDetailRow(context, '商户', transaction.merchantName ?? '-'),
            const Divider(),
            _buildDetailRow(context, '分类', categoryName),
            const Divider(),
            _buildDetailRow(context, '账户', accountName),
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

  Widget _buildTagsCard(BuildContext context, List<Tag> tags) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '标签',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: tags.map((tag) => Chip(
                label: Text(tag.name),
                backgroundColor: tag.color != null
                    ? Color(int.parse(tag.color!.replaceFirst('#', '0xff')))
                    : null,
              )).toList(),
            ),
          ],
        ),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除交易'),
        content: const Text('确定要删除这笔交易吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(transactionProvider.notifier).deleteTransaction(transaction.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('交易已删除'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('删除失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
