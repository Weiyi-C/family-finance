import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';
import 'package:family_finance_app/core/utils/format_utils.dart';
import '../providers/debt_provider.dart';

class DebtScreen extends ConsumerWidget {
  const DebtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsProvider((type: null, status: null)));
    final summaryAsync = ref.watch(debtSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('借贷管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/debt-create'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(debtsProvider);
          ref.invalidate(debtSummaryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummaryCard(context, summaryAsync),
            const SizedBox(height: 16),
            debtsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('加载失败: $e'),
                ),
              ),
              data: (debts) {
                if (debts.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('暂无借贷记录'),
                    ),
                  );
                }
                final lends = debts.where((d) => d.type == 'lend').toList();
                final borrows = debts.where((d) => d.type == 'borrow').toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (lends.isNotEmpty) ...[
                      Text('借出', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...lends.map((d) => _buildDebtItem(context, ref, d)),
                      const SizedBox(height: 16),
                    ],
                    if (borrows.isNotEmpty) ...[
                      Text('借入', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...borrows.map((d) => _buildDebtItem(context, ref, d)),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, AsyncValue<Map<String, dynamic>> summaryAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: summaryAsync.when(
          loading: () => const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text('汇总加载失败: $e'),
          data: (summary) {
            final lendTotal = (summary['lend_total'] ?? 0) as int;
            final borrowTotal = (summary['borrow_total'] ?? 0) as int;
            final net = lendTotal - borrowTotal;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(context, '借出总额', formatMoney(lendTotal), Colors.red),
                _buildSummaryItem(context, '借入总额', formatMoney(borrowTotal), Colors.green),
                _buildSummaryItem(context, '净借出', formatMoney(net), Colors.blue),
              ],
            );
          },
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

  Widget _buildDebtItem(BuildContext context, WidgetRef ref, Debt debt) {
    final isLend = debt.type == 'lend';
    final progress = debt.amount > 0 ? (debt.repaidAmount / debt.amount).clamp(0.0, 1.0) : 0.0;
    final statusText = _statusText(debt.status);

    return Dismissible(
      key: ValueKey(debt.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除借贷'),
            content: const Text('确定要删除这条借贷记录吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        try {
          final api = ref.read(apiServiceProvider);
          await api.deleteDebt(debt.id);
          ref.invalidate(debtsProvider);
          ref.invalidate(debtSummaryProvider);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
            );
          }
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isLend ? Colors.red[50] : Colors.green[50],
            child: Icon(
              isLend ? Icons.arrow_upward : Icons.arrow_downward,
              color: isLend ? Colors.red : Colors.green,
            ),
          ),
          title: Text(debt.personName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$statusText · ${debt.dueDate != null ? _formatDate(debt.dueDate!) : '无期限'}'),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        color: progress >= 1 ? Colors.green : (isLend ? Colors.red : Colors.blue),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${formatMoney(debt.repaidAmount)} / ${formatMoney(debt.amount)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          trailing: Text(
            formatMoney(debt.amount),
            style: TextStyle(
              color: isLend ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          onTap: () => _showDebtDetail(context, ref, debt),
        ),
      ),
    );
  }

  void _showDebtDetail(BuildContext context, WidgetRef ref, Debt debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => _DebtDetailSheet(
          debt: debt,
          scrollController: scrollController,
        ),
      ),
    );
  }

  String _statusText(String status) {
    switch (status) {
      case 'pending': return '待还';
      case 'partial': return '部分还款';
      case 'repaid': return '已还清';
      default: return status;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _DebtDetailSheet extends ConsumerWidget {
  final Debt debt;
  final ScrollController scrollController;

  const _DebtDetailSheet({
    required this.debt,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repaymentsAsync = ref.watch(debtRepaymentsProvider(debt.id));
    final isLend = debt.type == 'lend';
    final progress = debt.amount > 0 ? (debt.repaidAmount / debt.amount).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isLend ? Colors.red[50] : Colors.green[50],
                child: Icon(
                  isLend ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isLend ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(debt.personName, style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      isLend ? '借出' : '借入',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isLend ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('总额', style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    formatMoney(debt.amount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('已还', style: Theme.of(context).textTheme.bodyMedium),
                  Text(formatMoney(debt.repaidAmount)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('剩余', style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    formatMoney(debt.amount - debt.repaidAmount),
                    style: TextStyle(color: isLend ? Colors.red : Colors.green),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                color: progress >= 1 ? Colors.green : (isLend ? Colors.red : Colors.blue),
              ),
              if (debt.description != null && debt.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('备注: ', style: Theme.of(context).textTheme.bodyMedium),
                    Expanded(child: Text(debt.description!)),
                  ],
                ),
              ],
              if (debt.dueDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('到期日', style: Theme.of(context).textTheme.bodyMedium),
                    Text(_formatDate(debt.dueDate!)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('还款记录', style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加还款'),
                onPressed: () => _showAddRepayment(context, ref),
              ),
            ],
          ),
        ),
        Expanded(
          child: repaymentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
            data: (repayments) {
              if (repayments.isEmpty) {
                return const Center(child: Text('暂无还款记录'));
              }
              return ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: repayments.length,
                itemBuilder: (ctx, i) {
                  final r = repayments[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.payment, size: 20),
                    title: Text(formatMoney(r.amount)),
                    subtitle: Text(_formatDate(r.repayDate)),
                    trailing: r.description != null && r.description!.isNotEmpty
                        ? Text(r.description!, style: Theme.of(context).textTheme.bodySmall)
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddRepayment(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加还款'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: '还款金额（元）',
                  border: OutlineInputBorder(),
                  prefixText: '¥ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入金额';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return '请输入有效金额';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final api = ref.read(apiServiceProvider);
                final amountCents = (double.parse(amountController.text) * 100).round();
                await api.addRepayment(debt.id, {
                  'amount': amountCents,
                  if (descController.text.isNotEmpty) 'description': descController.text,
                });
                ref.invalidate(debtRepaymentsProvider(debt.id));
                ref.invalidate(debtsProvider);
                ref.invalidate(debtSummaryProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('还款失败: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
