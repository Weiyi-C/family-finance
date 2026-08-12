import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/models.dart';
import '../../../core/utils/format_utils.dart';

class AccountListScreen extends ConsumerWidget {
  const AccountListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('资金账户'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: 创建账户
            },
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载失败: $error')),
        data: (accounts) {
          final parentAccounts = accounts.where((a) => a.parentId == null).toList();
          final childAccounts = accounts.where((a) => a.parentId != null).toList();
          
          return ListView.builder(
            itemCount: parentAccounts.length,
            itemBuilder: (context, index) {
              final parent = parentAccounts[index];
              final children = childAccounts.where((a) => a.parentId == parent.id).toList();
              
              if (children.isEmpty) {
                return _buildAccountTile(context, parent);
              }
              
              return _buildAccountGroup(context, parent, children);
            },
          );
        },
      ),
    );
  }

  Widget _buildAccountGroup(BuildContext context, Account parent, List<Account> children) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.folder,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  parent.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          ...children.map((child) => _buildAccountTile(context, child, isChild: true)),
        ],
      ),
    );
  }

  Widget _buildAccountTile(BuildContext context, Account account, {bool isChild = false}) {
    return ListTile(
      contentPadding: EdgeInsets.only(
        left: isChild ? 48 : 16,
        right: 16,
      ),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          _getAccountIcon(account.typeCode),
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(account.name),
      subtitle: account.cardTail != null ? Text('尾号 ${account.cardTail}') : null,
      trailing: Text(
        formatMoney(account.balance ?? account.initialBalance),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () {
        // TODO: 打开账户详情
      },
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
}

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  // TODO: 从API获取账户列表
  return [];
});
