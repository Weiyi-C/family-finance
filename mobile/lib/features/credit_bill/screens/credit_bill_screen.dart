import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/models.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/credit_bill_provider.dart';

class CreditBillScreen extends ConsumerWidget {
  const CreditBillScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(creditBillsProvider);
    final summaryAsync = ref.watch(creditBillSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('信用账单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(creditBillsProvider);
              ref.invalidate(creditBillSummaryProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              try {
                final api = ref.read(apiServiceProvider);
                await api.generateCreditBills();
                ref.invalidate(creditBillsProvider);
                ref.invalidate(creditBillSummaryProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('账单已生成')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('生成失败: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: billsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (bills) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSummaryCard(context, summaryAsync),
              const SizedBox(height: 16),
              Text('账单列表', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (bills.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('暂无账单', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else
                ...bills.map((bill) => _buildBillItem(context, ref, bill)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, AsyncValue<Map<String, dynamic>> summaryAsync) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: summaryAsync.when(
          loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => SizedBox(
            height: 80,
            child: Center(child: Text('汇总加载失败', style: TextStyle(color: Colors.grey))),
          ),
          data: (summary) {
            final totalDue = summary['total_due'] ?? summary['total_amount'] ?? 0;
            return Column(
              children: [
                Text('待还总额', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text(
                  formatMoney(totalDue is int ? totalDue : (totalDue as num).toInt()),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBillItem(BuildContext context, WidgetRef ref, CreditBill bill) {
    final isPaid = bill.status == 'paid';
    final isOverdue = bill.status == 'overdue';
    final statusColor = isPaid ? Colors.green : (isOverdue ? Colors.red : Colors.orange);
    final statusText = isPaid ? '已还清' : (isOverdue ? '已逾期' : '待还款');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(
            isPaid ? Icons.check : Icons.credit_card,
            color: statusColor,
          ),
        ),
        title: Text(bill.accountName ?? '未知账户'),
        subtitle: Text('还款日: ${bill.dueDate != null ? formatDate(bill.dueDate!) : '未设置'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(bill.totalAmount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isPaid ? Colors.green : null,
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
              ],
            ),
            if (!isPaid) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.payment, color: Theme.of(context).colorScheme.primary),
                onPressed: () async {
                  try {
                    final api = ref.read(apiServiceProvider);
                    await api.payCreditBill(bill.id, {'amount': bill.totalAmount - bill.paidAmount});
                    ref.invalidate(creditBillsProvider);
                    ref.invalidate(creditBillSummaryProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('还款成功')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('还款失败: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ],
        ),
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(bill.accountName ?? '账单详情'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('账单周期', '${bill.year}年${bill.month}月'),
                  _buildDetailRow('账单金额', formatMoney(bill.totalAmount)),
                  _buildDetailRow('已还金额', formatMoney(bill.paidAmount)),
                  _buildDetailRow('剩余金额', formatMoney(bill.totalAmount - bill.paidAmount)),
                  _buildDetailRow('还款日', bill.dueDate != null ? formatDate(bill.dueDate!) : '未设置'),
                  _buildDetailRow('状态', statusText),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
