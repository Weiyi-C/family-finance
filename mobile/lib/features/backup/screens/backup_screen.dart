import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';
import 'package:family_finance_app/features/backup/providers/backup_provider.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(backupConfigsProvider);
    final logsAsync = ref.watch(backupLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('备份恢复'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAutoBackupSection(context, ref, configsAsync),
            const SizedBox(height: 16),
            _buildManualBackupSection(context, ref),
            const SizedBox(height: 16),
            _buildBackupHistorySection(context, ref, logsAsync),
            const SizedBox(height: 16),
            _buildRestoreSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoBackupSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Map<String, dynamic>>> configsAsync,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('自动备份', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            configsAsync.when(
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              )),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (configs) {
                if (configs.isEmpty) {
                  return Column(
                    children: [
                      Text('未配置自动备份', style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _createDefaultConfig(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('启用自动备份'),
                      ),
                    ],
                  );
                }
                final config = configs.first;
                final enabled = config['enabled'] as bool? ?? false;
                final retainDays = config['retain_days'] as int? ?? 30;
                return Column(
                  children: [
                    SwitchListTile(
                      title: const Text('启用自动备份'),
                      subtitle: Text('每天凌晨3点自动备份，保留${retainDays}天'),
                      value: enabled,
                      onChanged: (value) async {
                        final api = ref.read(apiServiceProvider);
                        await api.createBackupConfig({
                          'enabled': value,
                          'retain_days': retainDays,
                          'schedule': '0 3 * * *',
                          'backup_type': 'full',
                          'target': 'local',
                        });
                        ref.invalidate(backupConfigsProvider);
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualBackupSection(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('立即备份', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text('将当前数据备份到服务器', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _triggerBackup(context, ref),
                icon: const Icon(Icons.backup),
                label: const Text('立即备份'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupHistorySection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Map<String, dynamic>>> logsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('备份历史', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e')),
          data: (logs) {
            if (logs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('暂无备份记录', style: TextStyle(color: Colors.grey[500])),
                ),
              );
            }
            return Column(
              children: logs.map((log) => _buildLogItem(context, ref, log)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLogItem(BuildContext context, WidgetRef ref, Map<String, dynamic> log) {
    final status = log['status'] as String? ?? 'unknown';
    final isSuccess = status == 'success';
    final createdAt = log['created_at'] as String? ?? '';
    final fileSize = log['file_size'] as int? ?? 0;
    final sizeStr = fileSize > 1024 * 1024
        ? '${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB'
        : '${(fileSize / 1024).toStringAsFixed(1)} KB';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSuccess ? Colors.green[50] : Colors.red[50],
          child: Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? Colors.green : Colors.red,
            size: 20,
          ),
        ),
        title: Text(_formatTime(createdAt)),
        subtitle: Text('大小: $sizeStr'),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleLogAction(context, ref, log, action),
          itemBuilder: (_) => [
            if (isSuccess) const PopupMenuItem(value: 'download', child: Text('下载')),
            const PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreSection(BuildContext context) {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text('恢复数据', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.orange[700],
                )),
              ],
            ),
            const SizedBox(height: 8),
            Text('从备份文件恢复数据将覆盖当前数据，请谨慎操作',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showRestoreInfo(context),
                icon: const Icon(Icons.restore),
                label: const Text('恢复数据'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createDefaultConfig(BuildContext context, WidgetRef ref) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.createBackupConfig({
        'enabled': true,
        'retain_days': 30,
        'schedule': '0 3 * * *',
        'backup_type': 'full',
        'target': 'local',
      });
      ref.invalidate(backupConfigsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('自动备份已启用'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _triggerBackup(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在备份...'),
          ],
        ),
      ),
    );

    try {
      final api = ref.read(apiServiceProvider);
      await api.triggerBackup();
      ref.invalidate(backupLogsProvider);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('备份成功'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handleLogAction(BuildContext context, WidgetRef ref, Map<String, dynamic> log, String action) {
    final logId = log['id'] as int;
    switch (action) {
      case 'download':
        final api = ref.read(apiServiceProvider);
        final url = api.getBackupDownloadUrl(logId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载链接: $url')),
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('确认删除'),
            content: const Text('确定删除此备份记录？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    final api = ref.read(apiServiceProvider);
                    await api.deleteBackupLog(logId);
                    ref.invalidate(backupLogsProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        break;
    }
  }

  void _showRestoreInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('恢复数据'),
        content: const Text('请在 Web 端管理后台下载备份文件后，通过"导入导出"功能恢复数据。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
        ],
      ),
    );
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}
