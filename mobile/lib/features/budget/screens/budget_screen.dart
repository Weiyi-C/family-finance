import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/format_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../data/models/models.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/budget_provider.dart';
import '../../transaction/providers/transaction_provider.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final budgetsAsync = ref.watch(budgetsProvider((year: now.year, month: now.month)));
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('预算管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/budget-create'),
          ),
        ],
      ),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (budgets) {
          if (budgets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.savings_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('暂无预算', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('点击右上角 + 创建预算', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                ],
              ),
            );
          }

          final totalBudget = budgets.fold<int>(0, (sum, b) => sum + b.amount);
          final totalSpent = budgets.fold<int>(0, (sum, b) => sum + (b.spent ?? 0));
          final totalRemaining = totalBudget - totalSpent;

          return categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载分类失败: $e')),
            data: (categories) {
              final categoryMap = {for (var c in categories) c.id: c};

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildOverviewCard(context, totalBudget, totalSpent, totalRemaining),
                  const SizedBox(height: 16),
                  ...budgets.map((budget) => _buildBudgetItem(
                    context, ref, budget, categoryMap,
                  )),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context, int totalBudget, int totalSpent, int totalRemaining) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('本月预算', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(context, '总预算', formatMoney(totalBudget)),
                _buildStatItem(context, '已花费', formatMoney(totalSpent)),
                _buildStatItem(context, '剩余', formatMoney(totalRemaining)),
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBudgetItem(
    BuildContext context,
    WidgetRef ref,
    Budget budget,
    Map<int, Category> categoryMap,
  ) {
    final category = budget.categoryId != null ? categoryMap[budget.categoryId] : null;
    final categoryName = category?.name ?? '未分类';
    final spent = budget.spent ?? 0;
    final progress = budget.amount > 0 ? (spent / budget.amount).clamp(0.0, 1.0) : 0.0;
    final isOver = budget.amount > 0 && (spent / budget.amount) > budget.alertThreshold;

    return Dismissible(
      key: ValueKey(budget.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await ConfirmDialog.show(
          context: context,
          title: '删除预算',
          content: '确定要删除「$categoryName」的预算吗？',
          confirmText: '删除',
          isDestructive: true,
        );
      },
      onDismissed: (_) async {
        try {
          final api = ref.read(apiServiceProvider);
          await api.deleteBudget(budget.id);
          ref.invalidate(budgetsProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
          }
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => context.push('/budget/${budget.id}/edit', extra: budget),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(categoryName, style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      '${formatMoney(spent)} / ${formatMoney(budget.amount)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(isOver ? Colors.red : Colors.blue),
                ),
                const SizedBox(height: 4),
                Text(
                  '剩余 ${formatMoney(budget.amount - spent)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isOver ? Colors.red : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
