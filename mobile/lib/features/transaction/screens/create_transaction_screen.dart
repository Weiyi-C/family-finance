import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/format_utils.dart';

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

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记一笔'),
        actions: [
          TextButton(
            onPressed: _handleSubmit,
            child: const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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

  void _handleSubmit() {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入金额')),
      );
      return;
    }
    
    // TODO: 调用创建交易API
    Navigator.pop(context);
  }
}
