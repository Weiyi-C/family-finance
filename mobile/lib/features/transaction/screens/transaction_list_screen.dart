import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/features/transaction/providers/transaction_provider.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionProvider.notifier).loadTransactions(refresh: true);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = ref.read(transactionProvider);
      if (!state.isLoading && state.hasMore) {
        ref.read(transactionProvider.notifier).loadTransactions();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('账单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, TransactionState state) {
    if (state.isLoading && state.transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (state.error != null && state.transactions.isEmpty) {
      return _buildErrorState(context, state.error!);
    }

    if (state.transactions.isEmpty) {
      return _buildEmptyState(context);
    }

    final groupedTransactions = _groupByDate(state.transactions);

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(transactionProvider.notifier).loadTransactions(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: groupedTransactions.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == groupedTransactions.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final group = groupedTransactions[index];
          return _buildDateGroup(context, group);
        },
      ),
    );
  }

  List<_DateGroup> _groupByDate(List<Transaction> transactions) {
    final map = <String, List<Transaction>>{};
    for (final t in transactions) {
      final key = '${t.transactionTime.year}-${t.transactionTime.month.toString().padLeft(2, '0')}-${t.transactionTime.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(t);
    }
    return map.entries.map((e) {
      final date = DateTime.parse(e.key);
      int dayIncome = 0;
      int dayExpense = 0;
      for (final t in e.value) {
        if (t.type == 'income') dayIncome += t.amount;
        if (t.type == 'expense') dayExpense += t.amount;
      }
      return _DateGroup(date: date, transactions: e.value, income: dayIncome, expense: dayExpense);
    }).toList();
  }

  Widget _buildDateGroup(BuildContext context, _DateGroup group) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groupDate = DateTime(group.date.year, group.date.month, group.date.day);

    String dateLabel;
    if (groupDate == today) {
      dateLabel = '今天';
    } else if (groupDate == today.subtract(const Duration(days: 1))) {
      dateLabel = '昨天';
    } else {
      dateLabel = '${group.date.month}月${group.date.day}日';
    }

    final weekday = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][group.date.weekday - 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    dateLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    weekday,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (group.income > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        '+¥${(group.income / 100).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.green[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (group.expense > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        '-¥${(group.expense / 100).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.red[500],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: group.transactions.asMap().entries.map((entry) {
              final isLast = entry.key == group.transactions.length - 1;
              return _buildTransactionItem(context, entry.value, isLast);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '暂无账单记录',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击 + 开始记账',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/create-transaction'),
            icon: const Icon(Icons.add),
            label: const Text('记一笔'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请检查网络连接后重试',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref
                .read(transactionProvider.notifier)
                .loadTransactions(refresh: true),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, Transaction transaction, bool isLast) {
    final isTransfer = transaction.type == 'transfer';
    final isIncome = transaction.type == 'income';

    Color iconColor;
    IconData iconData;
    if (isTransfer) {
      iconColor = const Color(0xFF6C5CE7);
      iconData = Icons.swap_horiz;
    } else if (isIncome) {
      iconColor = const Color(0xFF00B894);
      iconData = Icons.arrow_downward_rounded;
    } else {
      iconColor = const Color(0xFFFF6B6B);
      iconData = Icons.arrow_upward_rounded;
    }

    final title = transaction.merchantName ?? transaction.typeDisplay;
    final subtitle = transaction.description ?? '';

    final time = '${transaction.transactionTime.hour.toString().padLeft(2, '0')}:${transaction.transactionTime.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () => context.push('/create-transaction', extra: transaction),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: isLast ? null : BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        time,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${isIncome ? '+' : isTransfer ? '' : '-'}¥${transaction.amountYuan.toStringAsFixed(2)}',
              style: TextStyle(
                color: isTransfer ? Theme.of(context).textTheme.bodyLarge?.color : iconColor,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('搜索账单'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入商户名或备注',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final keyword = controller.text.trim();
              if (keyword.isNotEmpty) {
                ref.read(transactionProvider.notifier).loadTransactions(refresh: true, keyword: keyword);
              }
            },
            child: const Text('搜索'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    String? selectedType;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('筛选'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String?>(
                title: const Text('全部'),
                value: null,
                groupValue: selectedType,
                onChanged: (v) => setState(() => selectedType = v),
              ),
              RadioListTile<String?>(
                title: const Text('支出'),
                value: 'expense',
                groupValue: selectedType,
                onChanged: (v) => setState(() => selectedType = v),
              ),
              RadioListTile<String?>(
                title: const Text('收入'),
                value: 'income',
                groupValue: selectedType,
                onChanged: (v) => setState(() => selectedType = v),
              ),
              RadioListTile<String?>(
                title: const Text('转账'),
                value: 'transfer',
                groupValue: selectedType,
                onChanged: (v) => setState(() => selectedType = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(transactionProvider.notifier).loadTransactions(refresh: true, type: selectedType);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateGroup {
  final DateTime date;
  final List<Transaction> transactions;
  final int income;
  final int expense;

  const _DateGroup({
    required this.date,
    required this.transactions,
    required this.income,
    required this.expense,
  });
}
