import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';
import 'package:family_finance_app/features/transaction/providers/transaction_provider.dart';
import 'package:family_finance_app/core/utils/format_utils.dart';

class AccountDetailScreen extends ConsumerWidget {
  final int accountId;

  const AccountDetailScreen({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('账户详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              final account = _findAccount(ref);
              if (account != null) {
                context.push('/account/${account.id}/edit', extra: account);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showDeleteDialog(context, ref),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载失败: $error')),
        data: (accounts) {
          final account = accounts.where((a) => a.id == accountId).firstOrNull;
          if (account == null) {
            return const Center(child: Text('账户不存在'));
          }
          return _buildContent(context, account);
        },
      ),
    );
  }

  Account? _findAccount(WidgetRef ref) {
    final async = ref.read(accountsProvider);
    return async.valueOrNull?.where((a) => a.id == accountId).firstOrNull;
  }

  Widget _buildContent(BuildContext context, Account account) {
    final isCredit = account.typeCode == 'bank_credit' ||
        account.typeCode == 'alipay_huabei' ||
        account.typeCode == 'alipay_jiebei';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBalanceCard(context, account),
          const SizedBox(height: 16),
          _buildDetailCard(context, account),
          if (isCredit) ...[
            const SizedBox(height: 16),
            _buildCreditCard(context, account),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, Account account) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              _getAccountIcon(account.typeCode),
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              account.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              formatMoney(account.balance ?? account.initialBalance),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context, Account account) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDetailRow(context, '账户类型', _getTypeName(account.typeCode)),
            if (account.bankName != null && account.bankName!.isNotEmpty) ...[
              const Divider(),
              _buildDetailRow(context, '银行', account.bankName!),
            ],
            if (account.cardTail != null && account.cardTail!.isNotEmpty) ...[
              const Divider(),
              _buildDetailRow(context, '尾号', account.cardTail!),
            ],
            const Divider(),
            _buildDetailRow(context, '初始余额', formatMoney(account.initialBalance)),
            const Divider(),
            _buildDetailRow(context, '状态', account.isActive ? '正常' : '已停用'),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditCard(BuildContext context, Account account) {
    final usedAmount = account.initialBalance - (account.balance ?? account.initialBalance);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '信用信息',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (account.creditLimit != null) ...[
              _buildDetailRow(context, '信用额度', formatMoney(account.creditLimit!)),
              const Divider(),
              _buildDetailRow(context, '已用额度', formatMoney(usedAmount)),
              const Divider(),
              _buildDetailRow(context, '可用额度', formatMoney(account.creditLimit! - usedAmount)),
            ],
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

  IconData _getAccountIcon(String typeCode) {
    switch (typeCode) {
      case 'alipay_balance':
      case 'alipay_yuebao':
        return Icons.account_balance_wallet;
      case 'alipay_huabei':
      case 'alipay_jiebei':
        return Icons.credit_card;
      case 'wechat_balance':
      case 'wechat_lingqian':
        return Icons.chat;
      case 'bank_savings':
        return Icons.account_balance;
      case 'bank_credit':
        return Icons.credit_card;
      case 'cash':
        return Icons.money;
      default:
        return Icons.account_balance_wallet;
    }
  }

  String _getTypeName(String typeCode) {
    switch (typeCode) {
      case 'cash':
        return '现金';
      case 'bank_savings':
        return '储蓄卡';
      case 'bank_credit':
        return '信用卡';
      case 'alipay_balance':
        return '支付宝余额';
      case 'alipay_yuebao':
        return '余额宝';
      case 'alipay_huabei':
        return '花呗';
      case 'alipay_jiebei':
        return '借呗';
      case 'wechat_balance':
        return '微信余额';
      case 'wechat_lingqian':
        return '微信零钱';
      default:
        return typeCode;
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账户'),
        content: const Text('确定要删除这个账户吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final api = ref.read(apiServiceProvider);
                await api.deleteAccount(accountId);
                ref.invalidate(accountsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('账户已删除'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  context.pop();
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
