import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/network/network_status.dart';
import '../../../data/models/models.dart';
import '../providers/offline_transaction_provider.dart';
import '../providers/transaction_provider.dart';

class CreateTransactionScreen extends ConsumerStatefulWidget {
  final Transaction? transaction;

  const CreateTransactionScreen({super.key, this.transaction});

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
  late DateTime _transactionTime = DateTime.now();
  bool _isSubmitting = false;
  bool _initialized = false;

  bool get _isEditMode => widget.transaction != null;

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initFromTransaction() {
    if (_initialized || !_isEditMode) return;
    final t = widget.transaction!;
    _type = t.type;
    _amountController.text = t.amountYuan.toStringAsFixed(2);
    _merchantController.text = t.merchantName ?? '';
    _descriptionController.text = t.description ?? '';
    _categoryId = t.categoryId;
    _accountId = t.paymentAccountId;
    _transactionTime = t.transactionTime;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    _initFromTransaction();

    final networkStatus = ref.watch(networkStatusProvider);
    final isOffline = networkStatus == NetworkStatus.offline;
    final categories = ref.watch(categoriesProvider);
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '编辑交易' : '记一笔'),
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
            onPressed: _isSubmitting ? null : () => _handleSubmit(ref),
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
            _buildTypeSelector(),
            const SizedBox(height: 24),
            _buildAmountInput(),
            const SizedBox(height: 16),
            _buildCategorySelector(categories),
            const SizedBox(height: 16),
            _buildAccountSelector(accounts),
            const SizedBox(height: 16),
            TextFormField(
              controller: _merchantController,
              decoration: const InputDecoration(
                labelText: '商户',
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const SizedBox(height: 16),
            _buildTimeSelector(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '备注',
                prefixIcon: Icon(Icons.note),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : () => _handleSubmit(ref),
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

  Widget _buildCategorySelector(AsyncValue<List<Category>> categories) {
    String displayText = '点击选择分类';
    categories.whenData((list) {
      if (_categoryId != null) {
        final match = list.where((c) => c.id == _categoryId).toList();
        if (match.isNotEmpty) displayText = match.first.name;
      }
    });

    return InkWell(
      onTap: () => _showCategoryPicker(categories),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '分类',
          prefixIcon: Icon(Icons.category),
        ),
        child: Text(displayText),
      ),
    );
  }

  void _showCategoryPicker(AsyncValue<List<Category>> categories) {
    categories.whenData((list) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '选择分类',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: list.length,
                  itemBuilder: (ctx, index) {
                    final category = list[index];
                    final selected = category.id == _categoryId;
                    return ListTile(
                      leading: category.icon != null
                          ? Text(category.icon!, style: const TextStyle(fontSize: 24))
                          : const Icon(Icons.category),
                      title: Text(category.name),
                      trailing: selected
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () {
                        setState(() => _categoryId = category.id);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildAccountSelector(AsyncValue<List<Account>> accounts) {
    String displayText = '点击选择账户';
    accounts.whenData((list) {
      if (_accountId != null) {
        final match = list.where((a) => a.id == _accountId).toList();
        if (match.isNotEmpty) displayText = match.first.name;
      }
    });

    return InkWell(
      onTap: () => _showAccountPicker(accounts),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: _type == 'transfer' ? '转出账户' : '资金来源',
          prefixIcon: const Icon(Icons.account_balance_wallet),
        ),
        child: Text(displayText),
      ),
    );
  }

  void _showAccountPicker(AsyncValue<List<Account>> accounts) {
    accounts.whenData((list) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '选择账户',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: list.length,
                  itemBuilder: (ctx, index) {
                    final account = list[index];
                    final selected = account.id == _accountId;
                    return ListTile(
                      leading: Icon(
                        Icons.account_balance_wallet,
                        color: account.color != null
                            ? Color(int.parse(account.color!.replaceFirst('#', '0xff')))
                            : null,
                      ),
                      title: Text(account.name),
                      subtitle: account.bankName != null ? Text(account.bankName!) : null,
                      trailing: selected
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () {
                        setState(() => _accountId = account.id);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    });
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

  Future<void> _handleSubmit(WidgetRef ref) async {
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
        'amount': (amount * 100).toInt(),
        'merchant_name': _merchantController.text.isNotEmpty ? _merchantController.text : null,
        'description': _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        'category_id': _categoryId,
        'payment_account_id': _accountId,
        'transaction_time': _transactionTime.toIso8601String(),
        'book_id': 1,
      };

      if (_isEditMode) {
        await ref.read(offlineTransactionProvider.notifier).updateTransaction(
          widget.transaction!.id,
          data,
        );
        ref.read(transactionProvider.notifier).loadTransactions(refresh: true);
      } else {
        await ref.read(offlineTransactionProvider.notifier).createTransaction(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? '交易已更新'
                : (ref.read(networkStatusProvider) == NetworkStatus.online
                    ? '交易已保存并同步'
                    : '交易已保存，将在联网后同步')),
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
