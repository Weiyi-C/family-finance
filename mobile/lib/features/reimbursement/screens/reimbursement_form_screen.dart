import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';
import '../providers/reimbursement_provider.dart';

class ReimbursementFormScreen extends ConsumerStatefulWidget {
  const ReimbursementFormScreen({super.key});

  @override
  ConsumerState<ReimbursementFormScreen> createState() =>
      _ReimbursementFormScreenState();
}

class _ReimbursementFormScreenState
    extends ConsumerState<ReimbursementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final List<_ItemEntry> _items = [_ItemEntry()];
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_ItemEntry()));
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _pickDate(int index) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _items[index].date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _items[index].date = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final itemsData = <Map<String, dynamic>>[];
    for (final item in _items) {
      final amountCents = (double.parse(item.amountController.text) * 100).round();
      final entry = <String, dynamic>{
        'description': item.descController.text,
        'amount': amountCents,
      };
      if (item.date != null) {
        entry['date'] = item.date!.toIso8601String().substring(0, 10);
      }
      itemsData.add(entry);
    }

    setState(() => _isSaving = true);

    try {
      final api = ref.read(apiServiceProvider);
      await api.createReimbursement({
        'title': _titleController.text,
        'items': itemsData,
      });

      ref.invalidate(reimbursementsProvider(null));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已创建')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建报销单')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '报销单标题',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? '请输入标题' : null,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('报销明细',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _addItem,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text('明细 ${i + 1}',
                              style: Theme.of(context).textTheme.titleSmall),
                          const Spacer(),
                          if (_items.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red),
                              onPressed: () => _removeItem(i),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: item.descController,
                        decoration: const InputDecoration(
                          labelText: '描述',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? '请输入描述'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: item.amountController,
                        decoration: const InputDecoration(
                          labelText: '金额（元）',
                          border: OutlineInputBorder(),
                          prefixText: '¥ ',
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return '请输入金额';
                          final n = double.tryParse(v);
                          if (n == null || n <= 0) return '请输入有效金额';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _pickDate(i),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '日期（可选）',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            item.date != null
                                ? item.date!.toString().substring(0, 10)
                                : '选择日期',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('创建'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemEntry {
  final descController = TextEditingController();
  final amountController = TextEditingController();
  DateTime? date;

  void dispose() {
    descController.dispose();
    amountController.dispose();
  }
}
