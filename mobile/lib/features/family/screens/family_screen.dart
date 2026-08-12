import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = [
      {'name': '小明', 'role': '拥有者', 'avatar': 'M', 'isOnline': true},
      {'name': '小红', 'role': '管理员', 'avatar': 'H', 'isOnline': true},
      {'name': '爸爸', 'role': '成员', 'avatar': 'B', 'isOnline': false},
      {'name': '妈妈', 'role': '成员', 'avatar': 'M', 'isOnline': false},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('家庭管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showInviteDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 家庭信息卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                              Text(
                                '温馨小家',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '邀请码: ABC123',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            // TODO: 复制邀请码
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 成员列表
            Text(
              '家庭成员 (${members.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...members.map((member) => _buildMemberTile(context, member)),
            const SizedBox(height: 16),
            // 权限设置
            Card(
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
                    _buildPermissionSwitch('允许成员导入账单', false),
                    _buildPermissionSwitch('允许成员导出数据', false),
                    _buildPermissionSwitch('允许成员管理预算', true),
                    _buildPermissionSwitch('允许成员查看所有账户', true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(BuildContext context, Map<String, dynamic> member) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: member['isOnline'] as bool
              ? Colors.green.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          child: Text(member['avatar'] as String),
        ),
        title: Text(member['name'] as String),
        subtitle: Text(member['role'] as String),
        trailing: member['role'] == '拥有者'
            ? null
            : PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'role', child: Text('修改角色')),
                  const PopupMenuItem(value: 'remove', child: Text('移除成员')),
                ],
                onSelected: (value) {
                  if (value == 'remove') {
                    _showRemoveDialog(context, member['name'] as String);
                  }
                },
              ),
      ),
    );
  }

  Widget _buildPermissionSwitch(String title, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Switch(
            value: value,
            onChanged: (newValue) {
              // TODO: 更新权限
            },
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('邀请成员'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('分享邀请码给家人：'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'ABC123',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: 分享邀请码
            },
            child: const Text('分享'),
          ),
        ],
      ),
    );
  }

  void _showRemoveDialog(BuildContext context, String memberName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除成员'),
        content: Text('确定要移除"$memberName"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // TODO: 移除成员
              Navigator.pop(context);
            },
            child: const Text('移除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
