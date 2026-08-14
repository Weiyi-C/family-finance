import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';
import 'package:family_finance_app/features/transaction/providers/transaction_provider.dart';
import 'package:family_finance_app/data/models/models.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(transactionProvider.notifier).loadTransactions(refresh: true);
  }

  Future<void> _onRefresh() async {
    ref.read(transactionProvider.notifier).loadTransactions(refresh: true);
    ref.invalidate(accountsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final transactionState = ref.watch(transactionProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final userName = authState.user?.nickname ?? '用户';

    final now = DateTime.now();
    final monthlyTransactions = transactionState.transactions.where((t) {
      return t.transactionTime.year == now.year &&
          t.transactionTime.month == now.month;
    }).toList();

    int monthlyIncome = 0;
    int monthlyExpense = 0;
    for (final t in monthlyTransactions) {
      if (t.type == 'income') {
        monthlyIncome += t.amount;
      } else if (t.type == 'expense') {
        monthlyExpense += t.amount;
      }
    }
    final monthlyBalance = monthlyIncome - monthlyExpense;

    final recentTransactions = transactionState.transactions.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('$userName 的账本'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverviewCard(context, monthlyIncome, monthlyExpense, monthlyBalance),
              const SizedBox(height: 16),
              _buildAccountsCard(context, accountsAsync),
              const SizedBox(height: 16),
              _buildRecentTransactions(context, recentTransactions, transactionState.isLoading),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    int income,
    int expense,
    int balance,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本月收支',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAmountItem(
                    context,
                    '收入',
                    '¥${(income / 100).toStringAsFixed(2)}',
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildAmountItem(
                    context,
                    '支出',
                    '¥${(expense / 100).toStringAsFixed(2)}',
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildAmountItem(
                    context,
                    '结余',
                    '¥${(balance / 100).toStringAsFixed(2)}',
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountItem(
    BuildContext context,
    String label,
    String amount,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
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

  Widget _buildAccountsCard(BuildContext context, AsyncValue<List<Account>> accountsAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '我的账户',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            accountsAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('暂无账户', style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }
                return Column(
                  children: accounts.map((account) => _buildAccountItem(context, account)).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('加载失败: $e', style: const TextStyle(color: Colors.red)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountItem(BuildContext context, Account account) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          _getAccountIcon(account.typeCode),
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(account.name),
      subtitle: account.bankName != null ? Text(account.bankName!) : null,
      trailing: Text(
        '¥${account.balanceYuan.toStringAsFixed(2)}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  IconData _getAccountIcon(String typeCode) {
    switch (typeCode) {
      case 'cash':
        return Icons.money;
      case 'debit_card':
      case 'credit_card':
        return Icons.credit_card;
      case 'alipay':
        return Icons.account_balance_wallet;
      case 'wechat':
        return Icons.chat;
      default:
        return Icons.account_balance;
    }
  }

  Widget _buildRecentTransactions(
    BuildContext context,
    List<Transaction> transactions,
    bool isLoading,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '最近账单',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('查看全部'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isLoading && transactions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (transactions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('暂无交易记录', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ...transactions.map((t) => _buildTransactionItem(context, t)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, Transaction transaction) {
    final isIncome = transaction.type == 'income';
    final sign = isIncome ? '+' : '-';
    final amount = '$sign¥${transaction.amountYuan.toStringAsFixed(2)}';
    final title = transaction.description ?? transaction.merchantName ?? transaction.typeDisplay;
    final subtitle = transaction.merchantName ?? '';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isIncome ? Colors.green[50] : Colors.red[50],
        child: Icon(
          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: isIncome ? Colors.green : Colors.red,
          size: 20,
        ),
      ),
      title: Text(title),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: Text(
        amount,
        style: TextStyle(
          color: isIncome ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
