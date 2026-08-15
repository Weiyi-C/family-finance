import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/rule_provider.dart';

class RuleScreen extends ConsumerWidget {
  const RuleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(rulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('规则引擎'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (rules) {
          if (rules.isEmpty) {
            return const EmptyState(
              icon: Icons.rule,
              title: '暂无规则',
              subtitle: '点击右上角 + 创建自动化规则',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return _buildRuleItem(context, ref, rule);
            },
          );
        },
      ),
    );
  }

  Widget _buildRuleItem(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> rule,
  ) {
    final name = rule['name'] as String? ?? '未命名规则';
    final isActive = rule['is_active'] as bool? ?? false;
    final hitCount = rule['hit_count'] as int? ?? 0;
    final conditions = rule['conditions'];
    final actions = rule['actions'];

    final summary = _buildSummary(conditions, actions);

    return Dismissible(
      key: ValueKey(rule['id']),
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
          title: '删除规则',
          content: '确定要删除「$name」吗？',
          confirmText: '删除',
          isDestructive: true,
        );
      },
      onDismissed: (_) async {
        try {
          final api = ref.read(apiServiceProvider);
          await api.deleteRule(rule['id'] as int);
          ref.invalidate(rulesProvider);
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
            backgroundColor: Colors.blue.withValues(alpha: 0.1),
            child: const Icon(Icons.rule, color: Colors.blue, size: 20),
          ),
          title: Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isActive ? null : Colors.grey,
            ),
          ),
          subtitle: Text(
            summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$hitCount',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '命中',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Switch(
                value: isActive,
                onChanged: (value) => _toggleActive(context, ref, rule, value),
              ),
            ],
          ),
          onTap: () => _showDetail(context, ref, rule),
        ),
      ),
    );
  }

  String _buildSummary(dynamic conditions, dynamic actions) {
    final parts = <String>[];

    if (conditions is List) {
      for (final c in conditions) {
        if (c is Map) {
          final field = c['field'] ?? '';
          final op = c['operator'] ?? '';
          final value = c['value'] ?? '';
          parts.add('$field $op $value');
        }
      }
    } else if (conditions is Map) {
      conditions.forEach((key, value) {
        parts.add('$key: $value');
      });
    }

    if (actions is List) {
      for (final a in actions) {
        if (a is Map) {
          final type = a['type'] ?? '';
          final target = a['target'] ?? a['value'] ?? '';
          parts.add('→ $type $target');
        }
      }
    } else if (actions is Map) {
      actions.forEach((key, value) {
        parts.add('→ $key: $value');
      });
    }

    return parts.isEmpty ? '无条件' : parts.join(' | ');
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> rule,
    bool value,
  ) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateRule(rule['id'] as int, {'is_active': value});
      ref.invalidate(rulesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
    }
  }

  void _showDetail(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> rule,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _RuleDetailSheet(rule: rule),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final conditionsController = TextEditingController();
    final actionsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建规则'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '规则名称',
                  hintText: '请输入规则名称',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: conditionsController,
                decoration: const InputDecoration(
                  labelText: '条件 (JSON)',
                  hintText: '[{"field":"category","operator":"=","value":"餐饮"}]',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: actionsController,
                decoration: const InputDecoration(
                  labelText: '动作 (JSON)',
                  hintText: '[{"type":"set_category","target":"餐饮"}]',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('请输入规则名称')),
                );
                return;
              }

              dynamic conditions;
              dynamic actions;
              try {
                if (conditionsController.text.trim().isNotEmpty) {
                  conditions = jsonDecode(conditionsController.text.trim());
                }
                if (actionsController.text.trim().isNotEmpty) {
                  actions = jsonDecode(actionsController.text.trim());
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('JSON 格式不正确')),
                  );
                }
                return;
              }

              try {
                final api = ref.read(apiServiceProvider);
                await api.createRule({
                  'name': name,
                  if (conditions != null) 'conditions': conditions,
                  if (actions != null) 'actions': actions,
                });
                ref.invalidate(rulesProvider);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已创建')));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('创建失败: $e')));
                }
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}

class _RuleDetailSheet extends ConsumerWidget {
  final Map<String, dynamic> rule;

  const _RuleDetailSheet({required this.rule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = rule['name'] as String? ?? '未命名规则';
    final isActive = rule['is_active'] as bool? ?? false;
    final hitCount = rule['hit_count'] as int? ?? 0;
    final conditions = rule['conditions'];
    final actions = rule['actions'];
    final createdAt = rule['created_at'] as String?;

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
                name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildInfoRow('状态', isActive ? '启用' : '停用'),
              _buildInfoRow('命中次数', '$hitCount'),
              if (createdAt != null) _buildInfoRow('创建时间', createdAt),
              const SizedBox(height: 16),
              Text('条件', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _buildJsonCard(conditions),
              const SizedBox(height: 16),
              Text('动作', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _buildJsonCard(actions),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _testRule(context, ref),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('测试规则'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _editRule(context, ref),
                      icon: const Icon(Icons.edit),
                      label: const Text('编辑'),
                    ),
                  ),
                ],
              ),
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
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildJsonCard(dynamic data) {
    if (data == null) return const Text('无', style: TextStyle(color: Colors.grey));

    String pretty;
    try {
      pretty = const JsonEncoder.withIndent('  ').convert(data);
    } catch (e) {
      pretty = data.toString();
    }

    return Card(
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          pretty,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    );
  }

  Future<void> _testRule(BuildContext context, WidgetRef ref) async {
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.testRule({
        'conditions': rule['conditions'],
        'actions': rule['actions'],
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('测试结果: ${result['matched_count'] ?? 0} 条匹配')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('测试失败: $e')));
      }
    }
  }

  void _editRule(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: rule['name'] as String? ?? '');
    final conditionsText = rule['conditions'] != null
        ? const JsonEncoder.withIndent('  ').convert(rule['conditions'])
        : '';
    final actionsText = rule['actions'] != null
        ? const JsonEncoder.withIndent('  ').convert(rule['actions'])
        : '';
    final conditionsController = TextEditingController(text: conditionsText);
    final actionsController = TextEditingController(text: actionsText);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑规则'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '规则名称'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: conditionsController,
                decoration: const InputDecoration(labelText: '条件 (JSON)'),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: actionsController,
                decoration: const InputDecoration(labelText: '动作 (JSON)'),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('请输入规则名称')),
                );
                return;
              }

              dynamic conditions;
              dynamic actions;
              try {
                if (conditionsController.text.trim().isNotEmpty) {
                  conditions = jsonDecode(conditionsController.text.trim());
                }
                if (actionsController.text.trim().isNotEmpty) {
                  actions = jsonDecode(actionsController.text.trim());
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('JSON 格式不正确')),
                  );
                }
                return;
              }

              try {
                final api = ref.read(apiServiceProvider);
                await api.updateRule(rule['id'] as int, {
                  'name': name,
                  if (conditions != null) 'conditions': conditions,
                  if (actions != null) 'actions': actions,
                });
                ref.invalidate(rulesProvider);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已更新')));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('更新失败: $e')));
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
