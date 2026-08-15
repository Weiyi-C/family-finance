import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('备份恢复'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 备份状态
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '备份状态',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildStatusRow('最后备份', '2026-08-13 03:00'),
                    _buildStatusRow('备份大小', '15.2 MB'),
                    _buildStatusRow('备份状态', '成功'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 立即备份
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '立即备份',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '将当前数据备份到服务器',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showBackupDialog(context);
                        },
                        icon: const Icon(Icons.backup),
                        label: const Text('立即备份'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 自动备份设置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自动备份',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('启用自动备份'),
                      subtitle: const Text('每天凌晨3点自动备份'),
                      value: true,
                      onChanged: (value) {
                        // TODO: 切换自动备份
                      },
                    ),
                    ListTile(
                      title: const Text('备份保留天数'),
                      trailing: const Text('30天'),
                      onTap: () {
                        // TODO: 修改保留天数
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 备份历史
            Text(
              '备份历史',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildBackupHistoryItem(context, '2026-08-13 03:00', '15.2 MB', '成功'),
            _buildBackupHistoryItem(context, '2026-08-12 03:00', '14.8 MB', '成功'),
            _buildBackupHistoryItem(context, '2026-08-11 03:00', '14.5 MB', '成功'),
            _buildBackupHistoryItem(context, '2026-08-10 03:00', '14.2 MB', '失败'),
            const SizedBox(height: 16),
            // 恢复数据
            Card(
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
                        Text(
                          '恢复数据',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '从备份文件恢复数据将覆盖当前数据，请谨慎操作',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showRestoreDialog(context);
                        },
                        icon: const Icon(Icons.restore),
                        label: const Text('恢复数据'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBackupHistoryItem(BuildContext context, String time, String size, String status) {
    final isSuccess = status == '成功';
    
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
        title: Text(time),
        subtitle: Text('大小: $size'),
        trailing: Text(
          status,
          style: TextStyle(
            color: isSuccess ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('正在备份'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('正在备份数据，请稍候...'),
          ],
        ),
      ),
    );

    // 模拟备份完成
    Future.delayed(const Duration(seconds: 2), () {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('备份成功'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  void _showRestoreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复数据'),
        content: const Text('确定要从备份恢复数据吗？当前数据将被覆盖。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 执行恢复
            },
            child: const Text('确定恢复', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
