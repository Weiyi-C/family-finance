import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/network/network_status.dart';
import '../providers/offline_transaction_provider.dart';

class CreateTransactionScreen extends ConsumerStatefulWidget {
  const CreateTransactionScreen({super.key});

  @override
  ConsumerState<CreateTransactionScreen> createState() => _CreateTransactionScreenState();
}

class _CreateTransactionScreenState extends ConsumerState<CreateTransactionScreen> {
  String _type = 'expense';
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _categoryId;
  int? _accountId;
  DateTime _transactionTime = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final networkStatus = ref.watch(networkStatusProvider);
    final isOffline = networkStatus == NetworkStatus.offline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('记一笔'),
        actions: [
          if (isOffline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('离线', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 离线提示
            if (isOffline)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '当前处于离线模式，交易将保存在本地，联网后自动同步',
                        style: TextStyle(color: Colors.orange[700], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            // 类型选择
            _buildTypeSelector(),
            const SizedBox(height: 24),
            // 金额输入
            _buildAmountInput(),
            const SizedBox(height: 16),
            // 分类选择
            _buildCategorySelector(),
            const SizedBox(height: 16),
            // 账户选择
            _buildAccountSelector(),
            const SizedBox(height: 16),
            // 商户输入
            TextFormField(
              controller: _merchantController,
              decoration: const InputDecoration(
                labelText: '商户',
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const SizedBox(height: 16),
            // 时间选择
            _buildTimeSelector(),
            const SizedBox(height: 16),
            // 备注输入
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '备注',
                prefixIcon: Icon(Icons.note),
              ),
            ),
            const SizedBox(height: 24),
            // 保存按钮
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
                  : const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'expense', label: Text('支出')),
        ButtonSegment(value: 'income', label: Text('收入')),
        ButtonSegment(value: 'transfer', label: Text('转账')),
      ],
      selected: {_type},
      onSelectionChanged: (types) {
        setState(() => _type = types.first);
      },
    );
  }

  Widget _buildAmountInput() {
    return TextFormField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      style: Theme.of(context).textTheme.headlineMedium,
      decoration: InputDecoration(
        labelText: '金额',
        prefixText: '¥ ',
        prefixStyle: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }

  Widget _buildCategorySelector() {
    return InkWell(
      onTap: () {
        // TODO: 打开分类选择器
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '分类',
          prefixIcon: Icon(Icons.category),
        ),
        child: Text(_categoryId != null ? '已选择分类' : '点击选择分类'),
      ),
    );
  }

  Widget _buildAccountSelector() {
    return InkWell(
      onTap: () {
        // TODO: 打开账户选择器
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: _type == 'transfer' ? '转出账户' : '资金来源',
          prefixIcon: const Icon(Icons.account_balance_wallet),
        ),
        child: Text(_accountId != null ? '已选择账户' : '点击选择账户'),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _transactionTime,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (date != null && mounted) {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(_transactionTime),
          );
          if (time != null && mounted) {
            setState(() {
              _transactionTime = DateTime(
                date.year, date.month, date.day,
                time.hour, time.minute,
              );
            });
          }
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '时间',
          prefixIcon: Icon(Icons.access_time),
        ),
        child: Text(formatDateTime(_transactionTime)),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入金额')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final data = {
        'type': _type,
        'amount': (amount * 100).toInt(), // 转为分
        'merchant_name': _merchantController.text.isNotEmpty ? _merchantController.text : null,
        'description': _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        'category_id': _categoryId,
        'payment_account_id': _accountId,
        'transaction_time': _transactionTime.toIso8601String(),
        'book_id': 1, // TODO: 从用户设置获取
      };

      await ref.read(offlineTransactionProvider.notifier).createTransaction(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(networkStatusProvider) == NetworkStatus.online
                ? '交易已保存并同步'
                : '交易已保存，将在联网后同步'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
