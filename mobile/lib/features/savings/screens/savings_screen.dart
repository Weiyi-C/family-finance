import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/models.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/savings_provider.dart';

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingsGoalsProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('储蓄目标'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/savings-create'),
          ),
        ],
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (goals) {
          if (goals.isEmpty) {
            return const Center(child: Text('暂无储蓄目标'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              return _buildGoalCard(context, ref, goal);
            },
          );
        },
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, WidgetRef ref, SavingsGoal goal) {
    final color = goal.color != null
        ? Color(int.parse(goal.color!.replaceFirst('#', '0xff')))
        : Colors.blue;
    final icon = _parseIcon(goal.icon);
    final progress = goal.progress;
    final isAchieved = goal.status == 'achieved';
    final isAbandoned = goal.status == 'abandoned';

    return Dismissible(
      key: ValueKey(goal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定要删除「${goal.name}」吗？'),
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
        final api = ref.read(apiServiceProvider);
        await api.deleteSavingsGoal(goal.id);
        ref.invalidate(savingsGoalsProvider);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showGoalDetail(context, ref, goal),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isAbandoned ? Colors.grey[200] : color.withValues(alpha: 0.1),
                      child: Icon(icon, color: isAbandoned ? Colors.grey : color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  goal.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: isAbandoned ? Colors.grey : null,
                                  ),
                                ),
                              ),
                              if (isAchieved)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    '已达成',
                                    style: TextStyle(color: Colors.green, fontSize: 12),
                                  ),
                                ),
                              if (isAbandoned)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    '已放弃',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          if (goal.deadline != null)
                            Text(
                              '截止: ${_formatDate(goal.deadline!)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isAbandoned ? Colors.grey : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isAbandoned ? Colors.grey : color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isAbandoned ? Colors.grey : (isAchieved ? Colors.green : color),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '已存: ¥${goal.currentAmountYuan.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isAbandoned ? Colors.grey : null,
                      ),
                    ),
                    Text(
                      '目标: ¥${goal.targetAmountYuan.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isAbandoned ? Colors.grey : null,
                      ),
                    ),
                  ],
                ),
                if (!isAchieved && !isAbandoned) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _showDepositDialog(context, ref, goal),
                      icon: const Icon(Icons.savings, size: 18),
                      label: const Text('存款'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGoalDetail(BuildContext context, WidgetRef ref, SavingsGoal goal) {
    final color = goal.color != null
        ? Color(int.parse(goal.color!.replaceFirst('#', '0xff')))
        : Colors.blue;
    final isAchieved = goal.status == 'achieved';
    final isAbandoned = goal.status == 'abandoned';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Icon(_parseIcon(goal.icon), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(goal.name, style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow('目标金额', '¥${goal.targetAmountYuan.toStringAsFixed(2)}'),
            _detailRow('当前金额', '¥${goal.currentAmountYuan.toStringAsFixed(2)}'),
            _detailRow('进度', '${(goal.progress * 100).toInt()}%'),
            if (goal.deadline != null) _detailRow('截止日期', _formatDate(goal.deadline!)),
            _detailRow('状态', _statusDisplay(goal.status)),
            const SizedBox(height: 20),
            if (!isAchieved && !isAbandoned) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showDepositDialog(context, ref, goal);
                      },
                      icon: const Icon(Icons.savings),
                      label: const Text('存款'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('确认放弃'),
                            content: Text('确定要放弃「${goal.name}」吗？'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('取消')),
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx, true),
                                child: const Text('放弃', style: TextStyle(color: Colors.orange)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final api = ref.read(apiServiceProvider);
                          await api.abandonGoal(goal.id);
                          ref.invalidate(savingsGoalsProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                      icon: const Icon(Icons.cancel, color: Colors.orange),
                      label: const Text('放弃', style: TextStyle(color: Colors.orange)),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showDepositDialog(BuildContext context, WidgetRef ref, SavingsGoal goal) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('存款'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '存款金额（元）',
              border: OutlineInputBorder(),
              prefixText: '¥ ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            validator: (v) {
              if (v == null || v.isEmpty) return '请输入金额';
              final n = double.tryParse(v);
              if (n == null || n <= 0) return '请输入有效金额';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final amountCents = (double.parse(controller.text) * 100).round();
              final api = ref.read(apiServiceProvider);
              await api.depositToGoal(goal.id, {'amount': amountCents});
              ref.invalidate(savingsGoalsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _statusDisplay(String status) {
    switch (status) {
      case 'active':
        return '进行中';
      case 'achieved':
        return '已达成';
      case 'abandoned':
        return '已放弃';
      default:
        return status;
    }
  }

  IconData _parseIcon(String? iconName) {
    switch (iconName) {
      case 'flight':
        return Icons.flight;
      case 'computer':
        return Icons.computer;
      case 'savings':
        return Icons.savings;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'home':
        return Icons.home;
      case 'directions_car':
        return Icons.directions_car;
      case 'school':
        return Icons.school;
      case 'phone_android':
        return Icons.phone_android;
      case 'pets':
        return Icons.pets;
      case 'favorite':
        return Icons.favorite;
      default:
        return Icons.savings;
    }
  }
}
