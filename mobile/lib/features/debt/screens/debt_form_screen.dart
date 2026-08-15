import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';
import '../providers/debt_provider.dart';

class DebtFormScreen extends ConsumerStatefulWidget {
  const DebtFormScreen({super.key});

  @override
  ConsumerState<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends ConsumerState<DebtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _personController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _type = 'lend';
  DateTime? _dueDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final amountCents = (double.parse(_amountController.text) * 100).round();
      final data = {
        'type': _type,
        'person_name': _personController.text.trim(),
        'amount': amountCents,
        if (_descController.text.trim().isNotEmpty) 'description': _descController.text.trim(),
        if (_dueDate != null) 'due_date': _dueDate!.toIso8601String().split('T')[0],
      };

      final api = ref.read(apiServiceProvider);
      await api.createDebt(data);

      ref.invalidate(debtsProvider);
      ref.invalidate(debtSummaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已创建'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建借贷')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'lend', label: Text('借出'), icon: Icon(Icons.arrow_upward)),
                ButtonSegment(value: 'borrow', label: Text('借入'), icon: Icon(Icons.arrow_downward)),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _personController,
              decoration: const InputDecoration(
                labelText: '对方姓名',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请输入对方姓名';
                return null;
              },
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
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(_dueDate == null ? '选择到期日（可选）' : '到期日: ${_formatDate(_dueDate!)}'),
              onPressed: _pickDueDate,
            ),
            if (_dueDate != null) ...[
              TextButton(
                onPressed: () => setState(() => _dueDate = null),
                child: const Text('清除到期日'),
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
                    : const Text('创建'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
