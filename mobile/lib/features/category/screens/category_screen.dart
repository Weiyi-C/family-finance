import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';
import 'package:family_finance_app/features/transaction/providers/transaction_provider.dart';
import 'package:family_finance_app/shared/widgets/confirm_dialog.dart';

const _iconOptions = <IconData>[
  Icons.restaurant,
  Icons.fastfood,
  Icons.local_cafe,
  Icons.local_grocery_store,
  Icons.shopping_bag,
  Icons.shopping_cart,
  Icons.directions_car,
  Icons.directions_bus,
  Icons.train,
  Icons.flight,
  Icons.home,
  Icons.hotel,
  Icons.local_hospital,
  Icons.school,
  Icons.sports_esports,
  Icons.movie,
  Icons.music_note,
  Icons.fitness_center,
  Icons.pets,
  Icons.card_giftcard,
  Icons.account_balance,
  Icons.work,
  Icons.trending_up,
  Icons.attach_money,
  Icons.savings,
  Icons.phone_android,
  Icons.local_library,
  Icons.brush,
  Icons.child_care,
  Icons.local_bar,
];

const _colorOptions = <Color>[
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.indigo,
  Colors.blue,
  Colors.teal,
  Colors.green,
  Colors.lime,
  Colors.orange,
  Colors.brown,
  Colors.grey,
  Colors.cyan,
];

String _colorToHex(Color color) {
  return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
}

Color _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return Colors.grey;
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return Colors.grey;
  return Color(value | 0xFF000000);
}

IconData _parseIcon(String? name) {
  if (name == null || name.isEmpty) return Icons.category;
  for (final icon in _iconOptions) {
    if (icon.codePoint.toString() == name) {
      return icon;
    }
  }
  return Icons.category;
}

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '支出'),
            Tab(text: '收入'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              final type = _tabController.index == 0 ? 'expense' : 'income';
              _showCreateDialog(context, type);
            },
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (categories) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildCategoryList(context, categories, 'expense'),
              _buildCategoryList(context, categories, 'income'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    List<Category> categories,
    String type,
  ) {
    final filtered =
        categories.where((c) => c.type == type && c.level == 1).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('暂无分类'));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final cat = filtered[index];
        final children = cat.children ?? [];
        final isSystem = cat.familyId == null;
        final color = _parseColor(cat.color);

        return ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(_parseIcon(cat.icon), color: color, size: 20),
          ),
          title: Row(
            children: [
              Flexible(child: Text(cat.name)),
              if (isSystem) ...[
                const SizedBox(width: 6),
                Icon(Icons.lock, size: 14, color: Colors.grey[400]),
              ],
            ],
          ),
          subtitle: Text('${children.length}个子分类'),
          trailing: isSystem
              ? null
              : PopupMenuButton<String>(
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('编辑')),
                    const PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditDialog(context, cat);
                    } else if (value == 'delete') {
                      _showDeleteDialog(context, cat);
                    }
                  },
                ),
          children: children
              .map((child) => _buildChildTile(context, child))
              .toList(),
        );
      },
    );
  }

  Widget _buildChildTile(BuildContext context, Category child) {
    final isSystem = child.familyId == null;
    final color = _parseColor(child.color);

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(_parseIcon(child.icon), color: color, size: 16),
      ),
      title: Row(
        children: [
          Flexible(child: Text(child.name)),
          if (isSystem) ...[
            const SizedBox(width: 6),
            Icon(Icons.lock, size: 14, color: Colors.grey[400]),
          ],
        ],
      ),
      trailing: isSystem
          ? null
          : PopupMenuButton<String>(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditDialog(context, child);
                } else if (value == 'delete') {
                  _showDeleteDialog(context, child);
                }
              },
            ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, String type) async {
    final nameController = TextEditingController();
    IconData selectedIcon = Icons.category;
    Color selectedColor = _colorOptions.first;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('新建分类'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '分类名称',
                        hintText: '请输入分类名称',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('图标'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _iconOptions.map((icon) {
                        final isSelected = icon == selectedIcon;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedIcon = icon),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.1)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Icon(icon,
                                size: 20,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey[700]),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('颜色'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _colorOptions.map((color) {
                        final isSelected = color == selectedColor;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedColor = color),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      width: 3,
                                    )
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('创建'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created != true) return;
    if (!context.mounted) return;
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入分类名称')));
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.createCategory({
        'name': name,
        'icon': selectedIcon.codePoint.toString(),
        'color': _colorToHex(selectedColor),
        'type': type,
      });
      ref.invalidate(categoriesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('创建成功')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('创建失败: $e')));
    }
  }

  Future<void> _showEditDialog(BuildContext context, Category category) async {
    final nameController = TextEditingController(text: category.name);
    IconData selectedIcon = _parseIcon(category.icon);
    Color selectedColor = _parseColor(category.color);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('编辑分类'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: '分类名称'),
                    ),
                    const SizedBox(height: 16),
                    const Text('图标'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _iconOptions.map((icon) {
                        final isSelected = icon == selectedIcon;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedIcon = icon),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.1)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Icon(icon,
                                size: 20,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey[700]),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('颜色'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _colorOptions.map((color) {
                        final isSelected = color == selectedColor;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedColor = color),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      width: 3,
                                    )
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;
    if (!context.mounted) return;
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入分类名称')));
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.updateCategory(category.id, {
        'name': name,
        'icon': selectedIcon.codePoint.toString(),
        'color': _colorToHex(selectedColor),
      });
      ref.invalidate(categoriesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('更新成功')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('更新失败: $e')));
    }
  }

  Future<void> _showDeleteDialog(
      BuildContext context, Category category) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '删除分类',
      content: '确定要删除「${category.name}」吗？',
      confirmText: '删除',
      isDestructive: true,
    );

    if (!confirmed) return;
    if (!context.mounted) return;

    try {
      final api = ref.read(apiServiceProvider);
      await api.deleteCategory(category.id);
      ref.invalidate(categoriesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已删除')));
    } on DioException catch (e) {
      if (!context.mounted) return;
      final statusCode = e.response?.statusCode;
      if (statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('系统分类不能删除')));
      } else if (statusCode == 400) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('该分类下有子分类，请先删除子分类')));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }
}
