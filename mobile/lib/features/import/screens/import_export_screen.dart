import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ImportExportScreen extends ConsumerStatefulWidget {
  const ImportExportScreen({super.key});

  @override
  ConsumerState<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends ConsumerState<ImportExportScreen> {
  String _selectedSource = 'auto';
  String _selectedFormat = 'csv';
  bool _isExporting = false;
  bool _isImporting = false;

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
          // 来源选择
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
          // 文件上传区域
          Card(
            child: InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey[300]!,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '点击选择文件',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '支持 CSV、Excel、PDF、TXT 格式',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 导入历史
          Text(
            '导入历史',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildImportHistoryItem(context, '支付宝账单', '2026-08-01', 156, '成功'),
          _buildImportHistoryItem(context, '微信账单', '2026-07-15', 89, '成功'),
          _buildImportHistoryItem(context, '工商银行账单', '2026-07-01', 234, '部分成功'),
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

  Widget _buildImportHistoryItem(
    BuildContext context,
    String source,
    String date,
    int count,
    String status,
  ) {
    final isSuccess = status == '成功';
    final isPartial = status == '部分成功';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSuccess
              ? Colors.green[50]
              : isPartial
                  ? Colors.orange[50]
                  : Colors.red[50],
          child: Icon(
            isSuccess
                ? Icons.check_circle
                : isPartial
                    ? Icons.warning
                    : Icons.error,
            color: isSuccess
                ? Colors.green
                : isPartial
                    ? Colors.orange
                    : Colors.red,
            size: 20,
          ),
        ),
        title: Text(source),
        subtitle: Text('$date · $count条记录'),
        trailing: Text(
          status,
          style: TextStyle(
            color: isSuccess
                ? Colors.green
                : isPartial
                    ? Colors.orange
                    : Colors.red,
            fontWeight: FontWeight.bold,
          ),
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
          // 导出类型
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
                  _buildExportOption(context, '交易记录', Icons.receipt_long, 'transactions'),
                  _buildExportOption(context, '资金账户', Icons.account_balance_wallet, 'accounts'),
                  _buildExportOption(context, '分类管理', Icons.category, 'categories'),
                  _buildExportOption(context, '预算数据', Icons.savings, 'budgets'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 导出格式
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
          const SizedBox(height: 16),
          // 时间范围
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
                          onPressed: () {
                            // TODO: 选择开始日期
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: const Text('开始日期'),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('至'),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // TODO: 选择结束日期
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: const Text('结束日期'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 导出按钮
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

  Widget _buildExportOption(BuildContext context, String title, IconData icon, String value) {
    return RadioListTile<String>(
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      value: value,
      groupValue: 'transactions',
      onChanged: (newValue) {
        // TODO: 切换导出类型
      },
    );
  }

  Future<void> _pickFile() async {
    // TODO: 使用 file_picker 选择文件
    setState(() {
      _isImporting = true;
    });

    // 模拟导入过程
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isImporting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('导入成功，共导入156条记录'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _exportData() async {
    setState(() {
      _isExporting = true;
    });

    // 模拟导出过程
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isExporting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('导出成功，文件已保存'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
