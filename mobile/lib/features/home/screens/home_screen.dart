import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';
import 'package:family_finance_app/features/transaction/providers/transaction_provider.dart';
import 'package:family_finance_app/features/budget/providers/budget_provider.dart';
import 'package:family_finance_app/core/utils/format_utils.dart';
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

  Future<void> _pickAndParseImage(BuildContext context) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    final image = await picker.pickImage(source: source, imageQuality: 85);
    if (image == null || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在识别账单...'),
          ],
        ),
      ),
    );

    try {
      final api = ref.read(apiServiceProvider);
      final transactions = await api.parseBillImage(image.path);
      if (!context.mounted) return;
      Navigator.pop(context);

      if (transactions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未识别到账单信息'), backgroundColor: Colors.orange),
        );
        return;
      }

      final first = transactions.first;
      context.push('/create-transaction', extra: Transaction.fromJson(first));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('识别到 ${transactions.length} 条账单'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('识别失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final transactionState = ref.watch(transactionProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final userName = authState.user?.nickname ?? '用户';

    final now = DateTime.now();
    final budgetsAsync = ref.watch(budgetsProvider((year: now.year, month: now.month)));
    final categoriesAsync = ref.watch(categoriesProvider);
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
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildGradientHeader(context, userName, monthlyIncome, monthlyExpense, monthlyBalance, now),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildQuickActions(context),
                  const SizedBox(height: 16),
                  _buildBudgetSection(context, budgetsAsync, categoriesAsync),
                  const SizedBox(height: 16),
                  _buildAccountsCard(context, accountsAsync),
                  const SizedBox(height: 16),
                  _buildRecentTransactions(context, recentTransactions, transactionState.isLoading),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientHeader(
    BuildContext context,
    String userName,
    int income,
    int expense,
    int balance,
    DateTime now,
  ) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor,
              primaryColor.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$userName 的账本',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${now.year}年${now.month}月',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                      onPressed: () => context.push('/notifications'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '本月结余',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${now.month}月',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '¥${(balance / 100).toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildHeaderAmountItem('收入', income, true),
                          ),
                          Container(
                            width: 1,
                            height: 32,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          Expanded(
                            child: _buildHeaderAmountItem('支出', expense, false),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAmountItem(String label, int amount, bool isIncome) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: Colors.white70,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '¥${(amount / 100).toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      ('记账', Icons.add_circle_outline, () => context.push('/create-transaction')),
      ('拍照记账', Icons.camera_alt_outlined, () => _pickAndParseImage(context)),
      ('更多', Icons.grid_view, () => context.go('/settings')),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((action) {
          return GestureDetector(
            onTap: action.$3,
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    action.$2,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  action.$1,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBudgetSection(
    BuildContext context,
    AsyncValue<List<Budget>> budgetsAsync,
    AsyncValue<List<Category>> categoriesAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '预算概览',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.push('/budgets'),
                child: const Text('查看全部'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          budgetsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('加载失败', style: TextStyle(color: Colors.grey[500])),
              ),
            ),
            data: (budgets) {
              if (budgets.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Icon(Icons.savings_outlined, size: 40, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('暂无预算', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ),
                );
              }
              final displayBudgets = budgets.take(3).toList();
              return categoriesAsync.when(
                loading: () => const SizedBox(),
                error: (e, _) => const SizedBox(),
                data: (categories) {
                  final categoryMap = {for (var c in categories) c.id: c};
                  return Column(
                    children: displayBudgets
                        .map((budget) => _buildBudgetProgressItem(context, budget, categoryMap))
                        .toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetProgressItem(
    BuildContext context,
    Budget budget,
    Map<int, Category> categoryMap,
  ) {
    final category = budget.categoryId != null ? categoryMap[budget.categoryId] : null;
    final categoryName = category?.name ?? '未分类';
    final spent = budget.spent ?? 0;
    final progress = budget.amount > 0 ? (spent / budget.amount).clamp(0.0, 1.0) : 0.0;
    final ratio = budget.amount > 0 ? spent / budget.amount : 0.0;

    Color progressColor;
    if (ratio > budget.alertThreshold) {
      progressColor = const Color(0xFFFF6B6B);
    } else if (ratio >= 0.8) {
      progressColor = const Color(0xFFFFB347);
    } else {
      progressColor = const Color(0xFF4ECDC4);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                categoryName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${formatMoney(spent)} / ${formatMoney(budget.amount)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[100],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsCard(BuildContext context, AsyncValue<List<Account>> accountsAsync) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '我的账户',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          accountsAsync.when(
            data: (accounts) {
              if (accounts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 40, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('暂无账户', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: accounts.take(3).map((account) => _buildAccountItem(context, account)).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('加载失败', style: TextStyle(color: Colors.grey[500])),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountItem(BuildContext context, Account account) {
    final icon = _getAccountIcon(account.typeCode);
    final iconColor = _getAccountColor(account.typeCode);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (account.bankName != null)
                  Text(
                    account.bankName!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '¥${account.balanceYuan.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAccountIcon(String typeCode) {
    switch (typeCode) {
      case 'cash':
        return Icons.payments_outlined;
      case 'debit_card':
        return Icons.credit_card_outlined;
      case 'credit_card':
        return Icons.credit_card;
      case 'alipay':
        return Icons.account_balance_wallet_outlined;
      case 'wechat':
        return Icons.chat_bubble_outline;
      default:
        return Icons.account_balance_outlined;
    }
  }

  Color _getAccountColor(String typeCode) {
    switch (typeCode) {
      case 'cash':
        return const Color(0xFF4ECDC4);
      case 'debit_card':
        return const Color(0xFF6C5CE7);
      case 'credit_card':
        return const Color(0xFFFF6B6B);
      case 'alipay':
        return const Color(0xFF00B894);
      case 'wechat':
        return const Color(0xFF00B894);
      default:
        return const Color(0xFF6C5CE7);
    }
  }

  Widget _buildRecentTransactions(
    BuildContext context,
    List<Transaction> transactions,
    bool isLoading,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '最近账单',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.go('/transactions'),
                child: const Text('查看全部'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoading && transactions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (transactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text('暂无交易记录', style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
            )
          else
            ...transactions.map((t) => _buildTransactionItem(context, t)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, Transaction transaction) {
    final isIncome = transaction.type == 'income';
    final isTransfer = transaction.type == 'transfer';
    final title = transaction.description ?? transaction.merchantName ?? transaction.typeDisplay;
    final subtitle = transaction.merchantName ?? '';

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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}¥${transaction.amountYuan.toStringAsFixed(2)}',
            style: TextStyle(
              color: iconColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
