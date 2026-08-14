import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_finance_app/core/utils/format_utils.dart';
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
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/create-transaction'),
          ),
        ],
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, TransactionState state) {
    if (state.isLoading && state.transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.transactions.isEmpty) {
      return _buildErrorState(context, state.error!);
    }

    if (state.transactions.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(transactionProvider.notifier).loadTransactions(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: state.transactions.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.transactions.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildTransactionItem(context, state.transactions[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '暂无账单记录',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 创建第一笔账单',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[500]),
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
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref
                .read(transactionProvider.notifier)
                .loadTransactions(refresh: true),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, Transaction transaction) {
    final isExpense = transaction.type == 'expense';
    final isTransfer = transaction.type == 'transfer';
    final color = isTransfer
        ? Colors.blue
        : isExpense
            ? Colors.red
            : Colors.green;
    final icon = isTransfer
        ? Icons.swap_horiz
        : isExpense
            ? Icons.arrow_downward
            : Icons.arrow_upward;
    final prefix = isTransfer ? '' : (isExpense ? '-' : '+');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(transaction.merchantName ?? transaction.typeDisplay),
      subtitle: Text(formatDateTime(transaction.transactionTime)),
      trailing: Text(
        '$prefix¥${transaction.amountYuan.toStringAsFixed(2)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
