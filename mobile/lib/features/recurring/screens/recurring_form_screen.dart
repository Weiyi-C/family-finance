import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/models.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/transaction/providers/transaction_provider.dart';
import '../providers/recurring_provider.dart';

class RecurringFormScreen extends ConsumerStatefulWidget {
  final RecurringTransaction? recurring;

  const RecurringFormScreen({super.key, this.recurring});

  @override
  ConsumerState<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _type = 'expense';
  int? _selectedCategoryId;
  int? _selectedAccountId;
  String _frequency = 'monthly';
  int _dayOfMonth = 1;
  bool _isSaving = false;

  bool get isEditing => widget.recurring != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final r = widget.recurring!;
      _type = r.type;
      _selectedCategoryId = r.categoryId;
      _selectedAccountId = r.accountId;
      _descriptionController.text = r.description ?? '';
      _amountController.text = (r.amount / 100).toStringAsFixed(2);
      _frequency = r.frequency;
      _dayOfMonth = r.dayOfMonth ?? 1;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final amountCents = (double.parse(_amountController.text) * 100).round();
      final data = {
        'type': _type,
        'amount': amountCents,
        'category_id': _selectedCategoryId,
        'account_id': _selectedAccountId,
        'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
        'frequency': _frequency,
        'day_of_month': _frequency == 'monthly' ? _dayOfMonth : null,
      };

      final api = ref.read(apiServiceProvider);
      if (isEditing) {
        await api.updateRecurring(widget.recurring!.id, data);
      } else {
        await api.createRecurring(data);
      }

      ref.invalidate(recurringProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? '已更新' : '已创建')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑周期交易' : '创建周期交易'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('支出')),
                ButtonSegment(value: 'income', label: Text('收入')),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '金额（元）',
                border: OutlineInputBorder(),
                prefixText: '¥ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return '请输入金额';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return '请输入有效金额';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '描述（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('加载分类失败: $e'),
              data: (categories) {
                final filtered = categories.where((c) => c.type == _type).toList();
                return DropdownButtonFormField<int>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(labelText: '分类', border: OutlineInputBorder()),
                  items: filtered.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                );
              },
            ),
            const SizedBox(height: 16),
            accountsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('加载账户失败: $e'),
              data: (accounts) {
                return DropdownButtonFormField<int>(
                  initialValue: _selectedAccountId,
                  decoration: const InputDecoration(labelText: '账户', border: OutlineInputBorder()),
                  items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                  onChanged: (v) => setState(() => _selectedAccountId = v),
                );
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: '频率', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'monthly', child: Text('每月')),
                DropdownMenuItem(value: 'weekly', child: Text('每周')),
                DropdownMenuItem(value: 'yearly', child: Text('每年')),
              ],
              onChanged: (v) => setState(() => _frequency = v!),
            ),
            if (_frequency == 'monthly') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _dayOfMonth,
                decoration: const InputDecoration(labelText: '每月几号', border: OutlineInputBorder()),
                items: List.generate(28, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}号'))),
                onChanged: (v) => setState(() => _dayOfMonth = v!),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isEditing ? '保存' : '创建'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
