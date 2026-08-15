import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:family_finance_app/features/tag/providers/tag_provider.dart';
import 'package:family_finance_app/data/models/models.dart';

class TagScreen extends ConsumerStatefulWidget {
  const TagScreen({super.key});

  @override
  ConsumerState<TagScreen> createState() => _TagScreenState();
}

class _TagScreenState extends ConsumerState<TagScreen> {
  static const _presetColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.brown,
    Colors.grey,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    ref.read(tagProvider.notifier).loadTags();
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.blue;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return Colors.blue;
    return Color(value | 0xFF000000);
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2)}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _createTag(String name, Color color) async {
    try {
      await ref.read(tagProvider.notifier).createTag({
        'name': name,
        'color': _colorToHex(color),
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        _showError('标签名称已存在');
      } else {
        _showError('创建失败');
      }
    } catch (e) {
      _showError('创建失败');
    }
  }

  Future<void> _updateTag(int id, String name, Color color) async {
    try {
      await ref.read(tagProvider.notifier).updateTag(id, {
        'name': name,
        'color': _colorToHex(color),
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        _showError('标签名称已存在');
      } else {
        _showError('更新失败');
      }
    } catch (e) {
      _showError('更新失败');
    }
  }

  Future<void> _deleteTag(int id) async {
    try {
      await ref.read(tagProvider.notifier).deleteTag(id);
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        _showError('标签已被交易使用，无法删除');
      } else {
        _showError('删除失败');
      }
    } catch (e) {
      _showError('删除失败');
    }
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    Color selectedColor = _presetColors[0];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('新建标签'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '标签名称',
                      hintText: '请输入标签名称',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '标签颜色',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presetColors.map((c) {
                      final isSelected = c.toARGB32() == selectedColor.toARGB32();
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = c),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.black, width: 2)
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 20)
                              : null,
                        ),
                      );
                    }).toList(),
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
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入标签名称')),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    _createTag(name, selectedColor);
                  },
                  child: const Text('创建'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog(Tag tag) {
    final nameController = TextEditingController(text: tag.name);
    Color selectedColor = _parseColor(tag.color);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('编辑标签'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '标签名称'),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '标签颜色',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presetColors.map((c) {
                      final isSelected = c.toARGB32() == selectedColor.toARGB32();
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = c),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.black, width: 2)
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 20)
                              : null,
                        ),
                      );
                    }).toList(),
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
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入标签名称')),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    _updateTag(tag.id, name, selectedColor);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(Tag tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('确定要删除标签"${tag.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTag(tag.id);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tagState = ref.watch(tagProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      body: tagState.isLoading && tagState.tags.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : tagState.tags.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tag, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('暂无标签', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('点击右上角 + 创建第一个标签',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(tagProvider.notifier).loadTags(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tagState.tags.length,
                    itemBuilder: (context, index) {
                      final tag = tagState.tags[index];
                      final tagColor = _parseColor(tag.color);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: tagColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.tag, color: tagColor),
                          ),
                          title: Text(tag.name),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('编辑')),
                              const PopupMenuItem(value: 'delete', child: Text('删除')),
                            ],
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showEditDialog(tag);
                              } else if (value == 'delete') {
                                _showDeleteDialog(tag);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
