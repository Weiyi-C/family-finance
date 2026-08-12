import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/core/network/network_status.dart';
import 'package:family_finance_app/features/transaction/providers/offline_transaction_provider.dart';

class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkStatus = ref.watch(networkStatusProvider);
    final offlineState = ref.watch(offlineTransactionProvider);
    final isOffline = networkStatus == NetworkStatus.offline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('同步状态'),
        actions: [
          if (!isOffline)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(offlineTransactionProvider.notifier).syncPendingTransactions();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 网络状态卡片
            _buildNetworkCard(context, isOffline),
            const SizedBox(height: 16),
            // 同步状态卡片
            _buildSyncCard(context, offlineState, isOffline),
            const SizedBox(height: 16),
            // 待同步交易列表
            _buildPendingTransactions(context, offlineState),
          ],
        ),
      ),
      floatingActionButton: !isOffline && offlineState.pendingTransactions.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                ref.read(offlineTransactionProvider.notifier).syncPendingTransactions();
              },
              icon: const Icon(Icons.sync),
              label: const Text('立即同步'),
            )
          : null,
    );
  }

  Widget _buildNetworkCard(BuildContext context, bool isOffline) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isOffline ? Colors.orange[100] : Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isOffline ? Icons.wifi_off : Icons.wifi,
                color: isOffline ? Colors.orange : Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOffline ? '离线模式' : '在线模式',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOffline ? '数据将保存在本地，联网后自动同步' : '数据将实时同步到服务器',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncCard(BuildContext context, OfflineTransactionState state, bool isOffline) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '同步状态',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSyncStat(
                  context,
                  '待同步',
                  '${state.pendingTransactions.length}',
                  Colors.orange,
                ),
                _buildSyncStat(
                  context,
                  '同步中',
                  state.isSyncing ? '是' : '否',
                  state.isSyncing ? Colors.blue : Colors.grey,
                ),
                _buildSyncStat(
                  context,
                  '状态',
                  isOffline ? '离线' : '在线',
                  isOffline ? Colors.red : Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStat(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildPendingTransactions(BuildContext context, OfflineTransactionState state) {
    if (state.pendingTransactions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: Colors.green[300],
                ),
                const SizedBox(height: 16),
                Text(
                  '所有交易已同步',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '待同步交易',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...state.pendingTransactions.take(10).map((txn) {
              final type = txn['type'] as String? ?? 'expense';
              final amount = txn['amount'] as int? ?? 0;
              final merchant = txn['merchant_name'] as String? ?? '未知商户';
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: type == 'expense' ? Colors.red[50] : Colors.green[50],
                  child: Icon(
                    type == 'expense' ? Icons.arrow_downward : Icons.arrow_upward,
                    color: type == 'expense' ? Colors.red : Colors.green,
                    size: 20,
                  ),
                ),
                title: Text(merchant),
                subtitle: Text(type == 'expense' ? '支出' : '收入'),
                trailing: Text(
                  '¥${(amount / 100).toStringAsFixed(2)}',
                  style: TextStyle(
                    color: type == 'expense' ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
            if (state.pendingTransactions.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '还有 ${state.pendingTransactions.length - 10} 笔交易...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
