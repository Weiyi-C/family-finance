import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TagScreen extends ConsumerWidget {
  const TagScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = [
      {'name': '外卖', 'count': 45, 'color': Colors.orange},
      {'name': '可报销', 'count': 12, 'color': Colors.green},
      {'name': '日常', 'count': 128, 'color': Colors.blue},
      {'name': '旅行', 'count': 23, 'color': Colors.purple},
      {'name': '礼物', 'count': 8, 'color': Colors.pink},
      {'name': '投资', 'count': 15, 'color': Colors.teal},
      {'name': '借贷', 'count': 5, 'color': Colors.red},
      {'name': '家庭', 'count': 67, 'color': Colors.brown},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tags.length,
        itemBuilder: (context, index) {
          final tag = tags[index];
          
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (tag['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.tag, color: tag['color'] as Color),
              ),
              title: Text(tag['name'] as String),
              subtitle: Text('${tag['count']}笔交易'),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('编辑')),
                  const PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditDialog(context, tag['name'] as String);
                  } else if (value == 'delete') {
                    _showDeleteDialog(context, tag['name'] as String);
                  }
                },
              ),
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
        title: const Text('新建标签'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: '标签名称',
            hintText: '请输入标签名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: 创建标签
              Navigator.pop(context);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, String tagName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑标签'),
        content: TextField(
          decoration: const InputDecoration(labelText: '标签名称'),
          controller: TextEditingController(text: tagName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: 更新标签
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String tagName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('确定要删除标签"$tagName"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // TODO: 删除标签
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
