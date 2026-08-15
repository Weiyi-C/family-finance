import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';
import 'package:family_finance_app/features/transaction/providers/transaction_provider.dart';

class AccountFormScreen extends ConsumerStatefulWidget {
  final Account? account;

  const AccountFormScreen({super.key, this.account});

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _cardTailController = TextEditingController();
  final _initialBalanceController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _billingDayController = TextEditingController();
  final _dueDayController = TextEditingController();

  String _typeCode = 'cash';
  bool _isSubmitting = false;

  bool get _isEditMode => widget.account != null;

  bool get _isCreditCard =>
      _typeCode == 'bank_credit' ||
      _typeCode == 'alipay_huabei' ||
      _typeCode == 'alipay_jiebei';

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final a = widget.account!;
      _nameController.text = a.name;
      _typeCode = a.typeCode;
      _bankNameController.text = a.bankName ?? '';
      _cardTailController.text = a.cardTail ?? '';
      _initialBalanceController.text = (a.initialBalance / 100).toStringAsFixed(2);
      _creditLimitController.text =
          a.creditLimit != null ? (a.creditLimit! / 100).toStringAsFixed(2) : '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankNameController.dispose();
    _cardTailController.dispose();
    _initialBalanceController.dispose();
    _creditLimitController.dispose();
    _billingDayController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '编辑账户' : '创建账户'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _handleSubmit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '账户名称 *',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '请输入账户名称' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _typeCode,
                decoration: const InputDecoration(
                  labelText: '账户类型',
                  prefixIcon: Icon(Icons.category),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('现金')),
                  DropdownMenuItem(value: 'bank_savings', child: Text('储蓄卡')),
                  DropdownMenuItem(value: 'bank_credit', child: Text('信用卡')),
                  DropdownMenuItem(value: 'alipay_balance', child: Text('支付宝余额')),
                  DropdownMenuItem(value: 'alipay_yuebao', child: Text('余额宝')),
                  DropdownMenuItem(value: 'alipay_huabei', child: Text('花呗')),
                  DropdownMenuItem(value: 'alipay_jiebei', child: Text('借呗')),
                  DropdownMenuItem(value: 'wechat_balance', child: Text('微信余额')),
                  DropdownMenuItem(value: 'wechat_lingqian', child: Text('微信零钱')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _typeCode = v);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bankNameController,
                decoration: const InputDecoration(
                  labelText: '银行名称',
                  prefixIcon: Icon(Icons.account_balance),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cardTailController,
                decoration: const InputDecoration(
                  labelText: '卡号后四位',
                  prefixIcon: Icon(Icons.credit_card),
                ),
                keyboardType: TextInputType.number,
                maxLength: 4,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _initialBalanceController,
                decoration: const InputDecoration(
                  labelText: '初始余额',
                  prefixText: '¥ ',
                  prefixIcon: Icon(Icons.money),
                ),
                keyboardType: TextInputType.number,
              ),
              if (_isCreditCard) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _creditLimitController,
                  decoration: const InputDecoration(
                    labelText: '信用额度',
                    prefixText: '¥ ',
                    prefixIcon: Icon(Icons.credit_score),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _billingDayController,
                  decoration: const InputDecoration(
                    labelText: '账单日',
                    prefixIcon: Icon(Icons.calendar_today),
                    hintText: '1-28',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dueDayController,
                  decoration: const InputDecoration(
                    labelText: '还款日',
                    prefixIcon: Icon(Icons.event),
                    hintText: '1-28',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('保存中...'),
                        ],
                      )
                    : Text(_isEditMode ? '保存修改' : '创建账户'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiServiceProvider);
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'type_code': _typeCode,
        'bank_name': _bankNameController.text.isNotEmpty ? _bankNameController.text.trim() : null,
        'card_tail': _cardTailController.text.isNotEmpty ? _cardTailController.text.trim() : null,
        'initial_balance': ((double.tryParse(_initialBalanceController.text) ?? 0) * 100).toInt(),
      };

      if (_isCreditCard) {
        if (_creditLimitController.text.isNotEmpty) {
          data['credit_limit'] =
              ((double.tryParse(_creditLimitController.text) ?? 0) * 100).toInt();
        }
        if (_billingDayController.text.isNotEmpty) {
          data['billing_day'] = int.tryParse(_billingDayController.text);
        }
        if (_dueDayController.text.isNotEmpty) {
          data['due_day'] = int.tryParse(_dueDayController.text);
        }
      }

      if (_isEditMode) {
        await api.updateAccount(widget.account!.id, data);
      } else {
        await api.createAccount(data);
      }

      ref.invalidate(accountsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? '账户已更新' : '账户已创建'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
