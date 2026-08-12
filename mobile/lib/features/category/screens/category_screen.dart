import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('分类管理'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '支出'),
              Tab(text: '收入'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showCreateDialog(context),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildCategoryList(context, 'expense'),
            _buildCategoryList(context, 'income'),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context, String type) {
    final categories = type == 'expense'
        ? [
            {'name': '餐饮', 'icon': Icons.restaurant, 'color': Colors.orange, 'children': ['早饭', '午饭', '晚饭', '下午茶']},
            {'name': '交通', 'icon': Icons.directions_car, 'color': Colors.blue, 'children': ['打车', '地铁', '公交']},
            {'name': '购物', 'icon': Icons.shopping_bag, 'color': Colors.pink, 'children': ['服饰', '日用品', '数码']},
            {'name': '住房', 'icon': Icons.home, 'color': Colors.brown, 'children': ['房租', '水电', '物业']},
            {'name': '娱乐', 'icon': Icons.sports_esports, 'color': Colors.purple, 'children': ['电影', '游戏', '旅行']},
            {'name': '医疗', 'icon': Icons.local_hospital, 'color': Colors.red, 'children': ['看病', '药品']},
            {'name': '教育', 'icon': Icons.school, 'color': Colors.teal, 'children': ['课程', '书籍']},
          ]
        : [
            {'name': '工资薪酬', 'icon': Icons.account_balance, 'color': Colors.green, 'children': ['工资', '奖金']},
            {'name': '副业收入', 'icon': Icons.work, 'color': Colors.blue, 'children': ['兼职', ' freelance']},
            {'name': '投资收益', 'icon': Icons.trending_up, 'color': Colors.orange, 'children': ['股票', '基金']},
            {'name': '红包收入', 'icon': Icons.card_giftcard, 'color': Colors.red, 'children': ['红包', '礼金']},
          ];

    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final children = cat['children'] as List<String>;
        
        return ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: (cat['color'] as Color).withOpacity(0.1),
            child: Icon(cat['icon'] as IconData, color: cat['color'] as Color),
          ),
          title: Text(cat['name'] as String),
          subtitle: Text('${children.length}个子分类'),
          children: children.map((child) => ListTile(
            contentPadding: const EdgeInsets.only(left: 72),
            title: Text(child),
            trailing: IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () {
                // TODO: 编辑子分类
              },
            ),
          )).toList(),
        );
      },
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建分类'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: '分类名称',
                hintText: '请输入分类名称',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('图标: '),
                IconButton(
                  icon: const Icon(Icons.emoji_emotions),
                  onPressed: () {
                    // TODO: 选择图标
                  },
                ),
                const SizedBox(width: 16),
                const Text('颜色: '),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
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
              // TODO: 创建分类
              Navigator.pop(context);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}
