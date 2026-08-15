import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';
import 'package:family_finance_app/features/import/providers/import_provider.dart';

class ImportExportScreen extends ConsumerStatefulWidget {
  const ImportExportScreen({super.key});

  @override
  ConsumerState<ImportExportScreen> createState() => _ImportExportScreenState();
}

const _sourceLabels = {
  'auto': '自动识别',
  'alipay': '支付宝',
  'wechat': '微信',
  'icbc': '工商银行',
  'ccb': '建设银行',
  'meituan': '美团',
};

class _ImportExportScreenState extends ConsumerState<ImportExportScreen> {
  String _selectedSource = 'auto';
  String _selectedExportType = 'transactions';
  String _selectedFormat = 'csv';
  bool _isExporting = false;
  bool _isImporting = false;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('导入/导出'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '导入'),
              Tab(text: '导出'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildImportTab(context),
            _buildExportTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildImportTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择账单来源',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSourceChip('自动识别', 'auto'),
                      _buildSourceChip('支付宝', 'alipay'),
                      _buildSourceChip('微信', 'wechat'),
                      _buildSourceChip('工商银行', 'icbc'),
                      _buildSourceChip('建设银行', 'ccb'),
                      _buildSourceChip('美团', 'meituan'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '文件路径',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: '输入文件路径（如 /sdcard/Download/alipay.csv）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (value) => _uploadFile(value),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isImporting
                          ? null
                          : () {
                              final controller = TextEditingController();
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('输入文件路径'),
                                  content: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(
                                      hintText: '/sdcard/Download/alipay.csv',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('取消'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _uploadFile(controller.text);
                                      },
                                      child: const Text('导入'),
                                    ),
                                  ],
                                ),
                              );
                            },
                      icon: _isImporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(_isImporting ? '导入中...' : '上传文件'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '导入历史',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ref.watch(importsProvider).when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('加载失败: $e'),
                  ),
                ),
                data: (records) {
                  if (records.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('暂无导入记录')),
                      ),
                    );
                  }
                  return Column(
                    children: records
                        .map((r) => _buildImportHistoryItem(r))
                        .toList(),
                  );
                },
              ),
        ],
      ),
    );
  }

  Widget _buildSourceChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedSource == value,
      onSelected: (selected) {
        setState(() {
          _selectedSource = value;
        });
      },
    );
  }

  Widget _buildImportHistoryItem(ImportRecord record) {
    final isSuccess = record.status == 'success' || record.status == 'completed';
    final isPending = record.status == 'pending';
    final isPartial = record.status == 'partial';
    final displaySource = _sourceLabels[record.source] ?? record.source;
    final dateStr =
        '${record.createdAt.year}-${record.createdAt.month.toString().padLeft(2, '0')}-${record.createdAt.day.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSuccess
              ? Colors.green[50]
              : isPending
                  ? Colors.blue[50]
                  : isPartial
                      ? Colors.orange[50]
                      : Colors.red[50],
          child: Icon(
            isSuccess
                ? Icons.check_circle
                : isPending
                    ? Icons.hourglass_empty
                    : isPartial
                        ? Icons.warning
                        : Icons.error,
            color: isSuccess
                ? Colors.green
                : isPending
                    ? Colors.blue
                    : isPartial
                        ? Colors.orange
                        : Colors.red,
            size: 20,
          ),
        ),
        title: Text(record.filename),
        subtitle: Text('$displaySource · $dateStr · ${record.itemCount}条记录'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _statusLabel(record.status),
              style: TextStyle(
                color: isSuccess
                    ? Colors.green
                    : isPending
                        ? Colors.blue
                        : isPartial
                            ? Colors.orange
                            : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isPending) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green, size: 20),
                onPressed: () => _confirmImport(record.id),
                tooltip: '确认导入',
              ),
            ],
            PopupMenuButton<String>(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'detail', child: Text('查看详情')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
              onSelected: (value) {
                if (value == 'detail') _showImportDetail(record);
                if (value == 'delete') _deleteImport(record.id);
              },
            ),
          ],
        ),
        onTap: () => _showImportDetail(record),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'success':
      case 'completed':
        return '成功';
      case 'pending':
        return '待确认';
      case 'partial':
        return '部分成功';
      case 'failed':
      case 'error':
        return '失败';
      default:
        return status;
    }
  }

  Future<void> _uploadFile(String filePath) async {
    if (filePath.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入文件路径')),
      );
      return;
    }
    setState(() => _isImporting = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.uploadImport(_selectedSource, filePath.trim());
      ref.invalidate(importsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('导入成功'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导入失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _confirmImport(int id) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.confirmImport(id);
      ref.invalidate(importsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('确认成功'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('确认失败: $e')),
      );
    }
  }

  Future<void> _deleteImport(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条导入记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final api = ref.read(apiServiceProvider);
      await api.deleteImport(id);
      ref.invalidate(importsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('删除成功'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
      );
    }
  }

  Future<void> _showImportDetail(ImportRecord record) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollController) => _ImportDetailSheet(
          record: record,
          scrollController: scrollController,
        ),
      ),
    );
  }

  Widget _buildExportTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '导出类型',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildExportOption(
                      context, '交易记录', Icons.receipt_long, 'transactions'),
                  _buildExportOption(
                      context, '资金账户', Icons.account_balance_wallet, 'accounts'),
                  _buildExportOption(
                      context, '分类管理', Icons.category, 'categories'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '导出格式',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('CSV'),
                        selected: _selectedFormat == 'csv',
                        onSelected: (selected) {
                          setState(() {
                            _selectedFormat = 'csv';
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('JSON'),
                        selected: _selectedFormat == 'json',
                        onSelected: (selected) {
                          setState(() {
                            _selectedFormat = 'json';
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Excel'),
                        selected: _selectedFormat == 'xlsx',
                        onSelected: (selected) {
                          setState(() {
                            _selectedFormat = 'xlsx';
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_selectedExportType == 'transactions') ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '时间范围',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isStart: true),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(_startDate != null
                                ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}'
                                : '开始日期'),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('至'),
                        ),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isStart: false),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(_endDate != null
                                ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
                                : '结束日期'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportData,
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_isExporting ? '导出中...' : '导出数据'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOption(
      BuildContext context, String title, IconData icon, String value) {
    return RadioListTile<String>(
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      value: value,
      groupValue: _selectedExportType,
      onChanged: (newValue) {
        setState(() {
          _selectedExportType = newValue!;
        });
      },
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? now) : (_endDate ?? now),
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      final api = ref.read(apiServiceProvider);
      switch (_selectedExportType) {
        case 'transactions':
          await api.exportTransactions(
            startDate: _startDate?.toIso8601String().split('T').first,
            endDate: _endDate?.toIso8601String().split('T').first,
            format: _selectedFormat,
          );
          break;
        case 'accounts':
          await api.exportAccounts();
          break;
        case 'categories':
          await api.exportCategories();
          break;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('导出成功，文件已保存'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

class _ImportDetailSheet extends ConsumerStatefulWidget {
  final ImportRecord record;
  final ScrollController scrollController;

  const _ImportDetailSheet({
    required this.record,
    required this.scrollController,
  });

  @override
  ConsumerState<_ImportDetailSheet> createState() => _ImportDetailSheetState();
}

class _ImportDetailSheetState extends ConsumerState<_ImportDetailSheet> {
  late Future<List<dynamic>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _fetchItems();
  }

  Future<List<dynamic>> _fetchItems() async {
    final api = ref.read(apiServiceProvider);
    return api.getImportItems(widget.record.id);
  }

  @override
  Widget build(BuildContext context) {
    final displaySource =
        _sourceLabels[widget.record.source] ?? widget.record.source;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.record.filename,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('来源: $displaySource'),
          Text('状态: ${_statusLabel(widget.record.status)}'),
          Text('记录数: ${widget.record.itemCount}'),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            '导入明细',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _itemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('加载失败: ${snapshot.error}'));
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(child: Text('暂无明细'));
                }
                return ListView.builder(
                  controller: widget.scrollController,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index] as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      title: Text(item['description']?.toString() ?? '无描述'),
                      subtitle: Text(item['date']?.toString() ?? ''),
                      trailing: Text(
                        item['amount']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'success':
      case 'completed':
        return '成功';
      case 'pending':
        return '待确认';
      case 'partial':
        return '部分成功';
      case 'failed':
      case 'error':
        return '失败';
      default:
        return status;
    }
  }
}
