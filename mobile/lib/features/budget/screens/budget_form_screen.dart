import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/models.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/budget_provider.dart';
import '../../transaction/providers/transaction_provider.dart';

class BudgetFormScreen extends ConsumerStatefulWidget {
  final Budget? budget;

  const BudgetFormScreen({super.key, this.budget});

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  int? _selectedCategoryId;
  String _period = 'monthly';
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  double _alertThreshold = 0.8;
  bool _rollover = false;
  bool _isSaving = false;

  bool get isEditing => widget.budget != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final b = widget.budget!;
      _selectedCategoryId = b.categoryId;
      _amountController.text = (b.amount / 100).toStringAsFixed(2);
      _period = b.period;
      _year = b.year;
      _month = b.month;
      _alertThreshold = b.alertThreshold;
      _rollover = b.rollover;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择分类')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final amountCents = (double.parse(_amountController.text) * 100).round();
      final data = {
        'category_id': _selectedCategoryId,
        'amount': amountCents,
        'period': _period,
        'year': _year,
        'month': _period == 'monthly' ? _month : 1,
        'alert_threshold': _alertThreshold,
        'rollover': _rollover,
      };

      final api = ref.read(apiServiceProvider);
      if (isEditing) {
        await api.updateBudget(widget.budget!.id, data);
      } else {
        await api.createBudget(data);
      }

      ref.invalidate(budgetsProvider);

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

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑预算' : '创建预算'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('加载分类失败: $e'),
              data: (categories) {
                final expenseCategories = categories.where((c) => c.type == 'expense').toList();
                return DropdownButtonFormField<int>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(labelText: '预算分类', border: OutlineInputBorder()),
                  items: expenseCategories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: isEditing ? null : (v) => setState(() => _selectedCategoryId = v),
                  validator: (v) => v == null ? '请选择分类' : null,
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '预算金额（元）',
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
            DropdownButtonFormField<String>(
              initialValue: _period,
              decoration: const InputDecoration(labelText: '周期', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'monthly', child: Text('月度')),
                DropdownMenuItem(value: 'weekly', child: Text('周度')),
                DropdownMenuItem(value: 'yearly', child: Text('年度')),
              ],
              onChanged: (v) => setState(() => _period = v!),
            ),
            if (_period == 'monthly') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _year,
                      decoration: const InputDecoration(labelText: '年', border: OutlineInputBorder()),
                      items: List.generate(5, (i) {
                        final y = DateTime.now().year - 2 + i;
                        return DropdownMenuItem(value: y, child: Text('$y'));
                      }),
                      onChanged: (v) => setState(() => _year = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _month,
                      decoration: const InputDecoration(labelText: '月', border: OutlineInputBorder()),
                      items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}月'))),
                      onChanged: (v) => setState(() => _month = v!),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text('预警阈值: ${(_alertThreshold * 100).toInt()}%', style: Theme.of(context).textTheme.bodyMedium),
            Slider(
              value: _alertThreshold,
              min: 0.5,
              max: 1.0,
              divisions: 10,
              label: '${(_alertThreshold * 100).toInt()}%',
              onChanged: (v) => setState(() => _alertThreshold = v),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('结转'),
              subtitle: const Text('未用完的预算结转到下期'),
              value: _rollover,
              onChanged: (v) => setState(() => _rollover = v),
            ),
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
