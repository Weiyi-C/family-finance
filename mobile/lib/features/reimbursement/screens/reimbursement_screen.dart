import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';
import '../providers/reimbursement_provider.dart';

class ReimbursementScreen extends ConsumerWidget {
  const ReimbursementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reimbursementsAsync = ref.watch(reimbursementsProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('报销管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/reimbursement-create'),
          ),
        ],
      ),
      body: reimbursementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (reimbursements) {
          if (reimbursements.isEmpty) {
            return const Center(child: Text('暂无报销单'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(reimbursementsProvider(null)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reimbursements.length,
              itemBuilder: (context, index) {
                final r = reimbursements[index];
                return _buildReimbursementItem(context, ref, r);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildReimbursementItem(
    BuildContext context,
    WidgetRef ref,
    Reimbursement r,
  ) {
    final statusInfo = _statusInfo(r.status);

    return Dismissible(
      key: ValueKey(r.id),
      direction: r.status == 'draft'
          ? DismissDirection.endToStart
          : DismissDirection.none,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定删除报销单"${r.title}"吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
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
          await api.deleteReimbursement(r.id);
          ref.invalidate(reimbursementsProvider(null));
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('删除失败: $e')),
            );
          }
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: statusInfo.$2.withOpacity(0.1),
            child: Icon(statusInfo.$3, color: statusInfo.$2),
          ),
          title: Text(r.title),
          subtitle: Text(
            r.submitDate != null
                ? '提交日期: ${r.submitDate!.toString().substring(0, 10)}'
                : '草稿',
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${r.totalAmountYuan.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusInfo.$2.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusInfo.$1,
                  style: TextStyle(color: statusInfo.$2, fontSize: 12),
                ),
              ),
            ],
          ),
          onTap: () => _showDetail(context, ref, r),
        ),
      ),
    );
  }

  (String, Color, IconData) _statusInfo(String status) {
    switch (status) {
      case 'draft':
        return ('草稿', Colors.grey, Icons.edit_note);
      case 'submitted':
        return ('已提交', Colors.blue, Icons.send);
      case 'approved':
        return ('已审批', Colors.green, Icons.check_circle);
      case 'received':
        return ('已到账', Colors.green, Icons.account_balance_wallet);
      default:
        return (status, Colors.grey, Icons.receipt);
    }
  }

  void _showDetail(BuildContext context, WidgetRef ref, Reimbursement r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(r.title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    '总金额: ¥${r.totalAmountYuan.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('状态: ${_statusInfo(r.status).$1}'),
                  if (r.submitDate != null)
                    Text('提交日期: ${r.submitDate!.toString().substring(0, 10)}'),
                  const SizedBox(height: 16),
                  if (r.items != null && r.items!.isNotEmpty) ...[
                    Text('报销明细', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...r.items!.map((item) => Card(
                      child: ListTile(
                        title: Text(item.description),
                        subtitle: item.date != null
                            ? Text(item.date!.toString().substring(0, 10))
                            : null,
                        trailing: Text(
                          '¥${item.amountYuan.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )),
                    const SizedBox(height: 16),
                  ],
                  _buildActions(context, ref, r),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref, Reimbursement r) {
    final api = ref.read(apiServiceProvider);

    Future<void> handleAction(Future<Map<String, dynamic>> Function() action) async {
      try {
        await action();
        ref.invalidate(reimbursementsProvider(null));
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('操作失败: $e')),
          );
        }
      }
    }

    switch (r.status) {
      case 'draft':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => handleAction(() => api.submitReimbursement(r.id)),
            child: const Text('提交'),
          ),
        );
      case 'submitted':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => handleAction(() => api.approveReimbursement(r.id)),
            child: const Text('审批'),
          ),
        );
      case 'approved':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => handleAction(() => api.receiveReimbursement(r.id, {})),
            child: const Text('确认到账'),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
