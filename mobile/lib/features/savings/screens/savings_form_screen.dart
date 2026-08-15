import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/models.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/savings_provider.dart';

class SavingsFormScreen extends ConsumerStatefulWidget {
  final SavingsGoal? goal;

  const SavingsFormScreen({super.key, this.goal});

  @override
  ConsumerState<SavingsFormScreen> createState() => _SavingsFormScreenState();
}

class _SavingsFormScreenState extends ConsumerState<SavingsFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _deadline;
  String _selectedIcon = 'savings';
  String _selectedColor = '#2196F3';
  bool _isSaving = false;

  bool get isEditing => widget.goal != null;

  static const _iconOptions = [
    {'name': 'savings', 'icon': Icons.savings, 'label': '储蓄'},
    {'name': 'flight', 'icon': Icons.flight, 'label': '旅行'},
    {'name': 'computer', 'icon': Icons.computer, 'label': '电脑'},
    {'name': 'home', 'icon': Icons.home, 'label': '房子'},
    {'name': 'directions_car', 'icon': Icons.directions_car, 'label': '汽车'},
    {'name': 'school', 'icon': Icons.school, 'label': '教育'},
    {'name': 'phone_android', 'icon': Icons.phone_android, 'label': '手机'},
    {'name': 'card_giftcard', 'icon': Icons.card_giftcard, 'label': '礼物'},
    {'name': 'pets', 'icon': Icons.pets, 'label': '宠物'},
    {'name': 'favorite', 'icon': Icons.favorite, 'label': '爱心'},
  ];

  static const _colorOptions = [
    '#2196F3',
    '#4CAF50',
    '#FF9800',
    '#9C27B0',
    '#F44336',
    '#00BCD4',
    '#E91E63',
    '#3F51B5',
    '#009688',
    '#FF5722',
  ];

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final g = widget.goal!;
      _nameController.text = g.name;
      _amountController.text = (g.targetAmount / 100).toStringAsFixed(2);
      _deadline = g.deadline;
      _selectedIcon = g.icon ?? 'savings';
      _selectedColor = g.color ?? '#2196F3';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final amountCents = (double.parse(_amountController.text) * 100).round();
      final data = {
        'name': _nameController.text.trim(),
        'target_amount': amountCents,
        'deadline': _deadline?.toIso8601String(),
        'icon': _selectedIcon,
        'color': _selectedColor,
      };

      final api = ref.read(apiServiceProvider);
      if (isEditing) {
        await api.updateSavingsGoal(widget.goal!.id, data);
      } else {
        await api.createSavingsGoal(data);
      }

      ref.invalidate(savingsGoalsProvider);

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
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑储蓄目标' : '创建储蓄目标'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '目标名称',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请输入名称';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '目标金额（元）',
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
            InkWell(
              onTap: _pickDeadline,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '截止日期（可选）',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _deadline != null
                      ? '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}'
                      : '点击选择',
                  style: TextStyle(
                    color: _deadline != null ? null : Colors.grey,
                  ),
                ),
              ),
            ),
            if (_deadline != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _deadline = null),
                  child: const Text('清除日期', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('图标', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _iconOptions.map((opt) {
                final isSelected = _selectedIcon == opt['name'];
                final color = Color(int.parse(_selectedColor.replaceFirst('#', '0xff')));
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = opt['name'] as String),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.2) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected ? Border.all(color: color, width: 2) : null,
                    ),
                    child: Icon(
                      opt['icon'] as IconData,
                      color: isSelected ? color : Colors.grey,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('颜色', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colorOptions.map((hex) {
                final color = Color(int.parse(hex.replaceFirst('#', '0xff')));
                final isSelected = _selectedColor == hex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 3)
                          : Border.all(color: Colors.grey[300]!),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
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
