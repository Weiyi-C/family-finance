import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/format_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../data/models/models.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/recurring_provider.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('周期交易'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: '手动处理',
            onPressed: () => _processRecurring(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/recurring-create'),
          ),
        ],
      ),
      body: recurringAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (recurrings) {
          if (recurrings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.repeat, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('暂无周期交易', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('点击右上角 + 创建周期交易', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recurrings.length,
            itemBuilder: (context, index) {
              final item = recurrings[index];
              return _buildRecurringItem(context, ref, item);
            },
          );
        },
      ),
    );
  }

  Widget _buildRecurringItem(
    BuildContext context,
    WidgetRef ref,
    RecurringTransaction item,
  ) {
    final isExpense = item.type == 'expense';
    final color = isExpense ? Colors.red : Colors.green;
    final icon = isExpense ? Icons.arrow_downward : Icons.arrow_upward;
    final typeLabel = isExpense ? '支出' : '收入';
    final frequencyLabel = _frequencyLabel(item.frequency, item.dayOfMonth);

    return Dismissible(
      key: ValueKey(item.id),
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
          title: '删除周期交易',
          content: '确定要删除「${item.description ?? '未命名'}」吗？',
          confirmText: '删除',
          isDestructive: true,
        );
      },
      onDismissed: (_) async {
        try {
          final api = ref.read(apiServiceProvider);
          await api.deleteRecurring(item.id);
          ref.invalidate(recurringProvider);
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
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color),
          ),
          title: Text(item.description ?? typeLabel),
          subtitle: Text('$frequencyLabel · $typeLabel'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(item.amount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (item.nextRunDate != null)
                    Text(
                      '下次: ${formatDate(item.nextRunDate!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Switch(
                value: item.isActive,
                onChanged: (value) => _toggleActive(context, ref, item, value),
              ),
            ],
          ),
          onTap: () => _showDetail(context, ref, item),
        ),
      ),
    );
  }

  String _frequencyLabel(String frequency, int? dayOfMonth) {
    switch (frequency) {
      case 'monthly':
        return dayOfMonth != null ? '每月$dayOfMonth号' : '每月';
      case 'weekly':
        return '每周';
      case 'yearly':
        return '每年';
      default:
        return frequency;
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    RecurringTransaction item,
    bool value,
  ) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateRecurring(item.id, {'is_active': value});
      ref.invalidate(recurringProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
    }
  }

  Future<void> _processRecurring(BuildContext context, WidgetRef ref) async {
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.processRecurring();
      ref.invalidate(recurringProvider);
      if (context.mounted) {
        final count = result['processed'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已处理 $count 条周期交易')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('处理失败: $e')));
      }
    }
  }

  void _showDetail(
    BuildContext context,
    WidgetRef ref,
    RecurringTransaction item,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _RecurringDetailSheet(item: item),
    );
  }
}

class _RecurringDetailSheet extends ConsumerStatefulWidget {
  final RecurringTransaction item;

  const _RecurringDetailSheet({required this.item});

  @override
  ConsumerState<_RecurringDetailSheet> createState() => _RecurringDetailSheetState();
}

class _RecurringDetailSheetState extends ConsumerState<_RecurringDetailSheet> {
  List<dynamic>? _logs;
  bool _isLoadingLogs = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoadingLogs = true);
    try {
      final api = ref.read(apiServiceProvider);
      final logs = await api.getRecurringLogs(widget.item.id);
      setState(() {
        _logs = logs;
        _isLoadingLogs = false;
      });
    } catch (e) {
      setState(() => _isLoadingLogs = false);
    }
  }

  Future<void> _generate() async {
    setState(() => _isGenerating = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.generateFromRecurring(widget.item.id);
      ref.invalidate(recurringProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已生成交易')));
        _loadLogs();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('生成失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isExpense = item.type == 'expense';
    final color = isExpense ? Colors.red : Colors.green;
    final typeLabel = isExpense ? '支出' : '收入';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
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
              Text(
                item.description ?? typeLabel,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                formatMoney(item.amount),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow('类型', typeLabel),
              _buildInfoRow('频率', _frequencyLabel(item.frequency, item.dayOfMonth)),
              _buildInfoRow('分类ID', item.categoryId?.toString() ?? '-'),
              _buildInfoRow('账户ID', item.accountId?.toString() ?? '-'),
              _buildInfoRow('状态', item.isActive ? '启用' : '停用'),
              if (item.nextRunDate != null)
                _buildInfoRow('下次执行', formatDate(item.nextRunDate!)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generate,
                  icon: _isGenerating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_arrow),
                  label: const Text('立即生成交易'),
                ),
              ),
              const SizedBox(height: 24),
              Text('执行日志', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_isLoadingLogs)
                const Center(child: CircularProgressIndicator())
              else if (_logs == null || _logs!.isEmpty)
                Text('暂无日志', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey))
              else
                ...(_logs!.map((log) => _buildLogItem(log))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildLogItem(dynamic log) {
    final createdAt = log['created_at'] != null ? DateTime.parse(log['created_at']) : null;
    final status = log['status'] ?? '';
    final message = log['message'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(
          status == 'success' ? Icons.check_circle : Icons.error,
          color: status == 'success' ? Colors.green : Colors.red,
          size: 20,
        ),
        title: Text(message.isEmpty ? status : message),
        subtitle: createdAt != null ? Text(formatDateTime(createdAt)) : null,
      ),
    );
  }

  String _frequencyLabel(String frequency, int? dayOfMonth) {
    switch (frequency) {
      case 'monthly':
        return dayOfMonth != null ? '每月$dayOfMonth号' : '每月';
      case 'weekly':
        return '每周';
      case 'yearly':
        return '每年';
      default:
        return frequency;
    }
  }
}
