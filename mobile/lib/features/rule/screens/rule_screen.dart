import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RuleScreen extends ConsumerWidget {
  const RuleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = [
      {
        'name': '餐饮自动分类',
        'description': '包含"外卖"、"美团"的交易自动分类为餐饮',
        'type': 'classify',
        'isActive': true,
        'hitCount': 156,
      },
      {
        'name': '交通自动分类',
        'description': '包含"滴滴"、"地铁"的交易自动分类为交通',
        'type': 'classify',
        'isActive': true,
        'hitCount': 89,
      },
      {
        'name': '工资识别',
        'description': '每月15号收入自动标记为工资',
        'type': 'classify',
        'isActive': true,
        'hitCount': 12,
      },
      {
        'name': '大额支出预警',
        'description': '单笔支出超过1000元发送通知',
        'type': 'notify',
        'isActive': true,
        'hitCount': 23,
      },
      {
        'name': '周末娱乐标签',
        'description': '周末消费自动添加"娱乐"标签',
        'type': 'tag',
        'isActive': false,
        'hitCount': 45,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('规则引擎'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rules.length,
        itemBuilder: (context, index) {
          final rule = rules[index];
          final type = rule['type'] as String;
          final isActive = rule['isActive'] as bool;
          
          IconData icon;
          Color color;
          
          switch (type) {
            case 'classify':
              icon = Icons.category;
              color = Colors.blue;
              break;
            case 'notify':
              icon = Icons.notifications;
              color = Colors.orange;
              break;
            case 'tag':
              icon = Icons.label;
              color = Colors.green;
              break;
            default:
              icon = Icons.rule;
              color = Colors.grey;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 20),
              ),
              title: Text(
                rule['name'] as String,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isActive ? null : Colors.grey,
                ),
              ),
              subtitle: Text(rule['description'] as String),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${rule['hitCount']}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: color,
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
                    onChanged: (value) {
                      // TODO: 切换规则状态
                    },
                  ),
                ],
              ),
              onTap: () {
                // TODO: 查看规则详情
              },
            ),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建规则'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: '规则名称',
                hintText: '请输入规则名称',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: '规则类型'),
              items: const [
                DropdownMenuItem(value: 'classify', child: Text('自动分类')),
                DropdownMenuItem(value: 'tag', child: Text('自动标签')),
                DropdownMenuItem(value: 'notify', child: Text('通知提醒')),
              ],
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: 创建规则
              Navigator.pop(context);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}
