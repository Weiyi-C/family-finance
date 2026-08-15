import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';
import '../providers/family_provider.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(familyProvider);
    final membersAsync = ref.watch(familyMembersProvider);
    final currentUser = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('家庭管理'),
        actions: [
          familyAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (family) => membersAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (members) {
                if (!_canManage(currentUser, members)) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: () => _showAddMemberDialog(context, ref),
                );
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(familyProvider);
          ref.invalidate(familyMembersProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFamilyCard(context, ref, familyAsync),
              const SizedBox(height: 16),
              _buildMembersSection(context, ref, membersAsync, currentUser),
              const SizedBox(height: 16),
              membersAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (members) {
                  if (!_canManage(currentUser, members)) {
                    return const SizedBox.shrink();
                  }
                  return _buildPermissionCard(context, ref, familyAsync);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canManage(User? user, List<FamilyMember> members) {
    if (user == null) return false;
    final me = members.where((m) => m.phone == user.phone).toList();
    if (me.isEmpty) return false;
    return me.first.role == 'owner' || me.first.role == 'admin';
  }

  Widget _buildFamilyCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Family> familyAsync,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: familyAsync.when(
          loading: () => const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text('加载失败: $e'),
          data: (family) => Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.home, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _showEditNameDialog(context, ref, family),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              family.name,
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '邀请码: ${family.inviteCode ?? '无'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: family.inviteCode == null
                    ? null
                    : () {
                        Clipboard.setData(
                          ClipboardData(text: family.inviteCode!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('邀请码已复制')),
                        );
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<FamilyMember>> membersAsync,
    User? currentUser,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        membersAsync.when(
          loading: () => Text(
            '家庭成员',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          error: (_, _) => Text(
            '家庭成员',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          data: (members) => Text(
            '家庭成员 (${members.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        membersAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('加载失败: $e'),
            ),
          ),
          data: (members) {
            if (members.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('暂无成员'),
                ),
              );
            }
            final canManage = _canManage(currentUser, members);
            return Column(
              children: members
                  .map((m) => _buildMemberTile(context, ref, m, canManage))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMemberTile(
    BuildContext context,
    WidgetRef ref,
    FamilyMember member,
    bool canManage,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: member.isActive
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          child: Text(
            member.nickname.isNotEmpty ? member.nickname[0] : '?',
          ),
        ),
        title: Text(member.nickname),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _roleColor(member.role).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _roleLabel(member.role),
                style: TextStyle(
                  fontSize: 12,
                  color: _roleColor(member.role),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (member.phone != null) ...[
              const SizedBox(width: 8),
              Text(
                member.phone!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        trailing: (!canManage || member.role == 'owner')
            ? null
            : PopupMenuButton<String>(
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'role', child: Text('修改角色')),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('移除成员', style: TextStyle(color: Colors.red)),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'role') {
                    _showChangeRoleDialog(context, ref, member);
                  } else if (value == 'remove') {
                    _showRemoveDialog(context, ref, member);
                  }
                },
              ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'owner':
        return Colors.amber[700]!;
      case 'admin':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'owner':
        return '拥有者';
      case 'admin':
        return '管理员';
      default:
        return '成员';
    }
  }

  Widget _buildPermissionCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Family> familyAsync,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '权限设置',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            familyAsync.when(
              loading: () => const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, _) => const Text('加载失败'),
              data: (family) {
                return Column(
                  children: [
                    _buildPermissionSwitch(
                      context,
                      ref,
                      '允许成员导入账单',
                      true,
                      'allowImport',
                    ),
                    _buildPermissionSwitch(
                      context,
                      ref,
                      '允许成员导出数据',
                      true,
                      'allowExport',
                    ),
                    _buildPermissionSwitch(
                      context,
                      ref,
                      '允许成员管理预算',
                      true,
                      'allowBudgetManage',
                    ),
                    _buildPermissionSwitch(
                      context,
                      ref,
                      '允许成员查看所有账户',
                      true,
                      'allowViewAllAccounts',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionSwitch(
    BuildContext context,
    WidgetRef ref,
    String title,
    bool value,
    String key,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Switch(
            value: value,
            onChanged: (newValue) async {
              try {
                final api = ref.read(apiServiceProvider);
                await api.updateFamily({key: newValue});
                ref.invalidate(familyProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('权限已更新')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('更新失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(
    BuildContext context,
    WidgetRef ref,
    Family family,
  ) {
    final controller = TextEditingController(text: family.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改家庭名称'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '家庭名称',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '请输入名称';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final api = ref.read(apiServiceProvider);
                await api.updateFamily({'name': controller.text.trim()});
                ref.invalidate(familyProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('修改失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, WidgetRef ref) {
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加成员'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: '手机号',
              border: OutlineInputBorder(),
              prefixText: '+86 ',
            ),
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '请输入手机号';
              if (v.trim().length < 11) return '请输入正确的手机号';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final api = ref.read(apiServiceProvider);
                await api.addFamilyMember({'phone': phoneController.text.trim()});
                ref.invalidate(familyMembersProvider);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('成员已添加')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('添加失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showChangeRoleDialog(
    BuildContext context,
    WidgetRef ref,
    FamilyMember member,
  ) {
    String selectedRole = member.role;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改角色'),
        content: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('为 ${member.nickname} 选择角色：'),
              const SizedBox(height: 16),
              RadioListTile<String>(
                title: const Text('管理员'),
                subtitle: const Text('可管理成员和设置'),
                value: 'admin',
                groupValue: selectedRole,
                onChanged: (v) => setState(() => selectedRole = v!),
              ),
              RadioListTile<String>(
                title: const Text('成员'),
                subtitle: const Text('基本使用权'),
                value: 'member',
                groupValue: selectedRole,
                onChanged: (v) => setState(() => selectedRole = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final api = ref.read(apiServiceProvider);
                await api.updateMemberRole(member.id, {'role': selectedRole});
                ref.invalidate(familyMembersProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('修改失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showRemoveDialog(
    BuildContext context,
    WidgetRef ref,
    FamilyMember member,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除成员'),
        content: Text('确定要移除"${member.nickname}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final api = ref.read(apiServiceProvider);
                await api.removeFamilyMember(member.id);
                ref.invalidate(familyMembersProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('移除失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('移除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
