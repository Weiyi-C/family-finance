import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/core/utils/format_utils.dart';
import 'package:family_finance_app/features/sync/providers/conflict_provider.dart';

class ConflictResolutionScreen extends ConsumerStatefulWidget {
  const ConflictResolutionScreen({super.key});

  @override
  ConsumerState<ConflictResolutionScreen> createState() => _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState extends ConsumerState<ConflictResolutionScreen> {
  @override
  Widget build(BuildContext context) {
    final conflictState = ref.watch(conflictProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('冲突解决'),
        actions: [
          if (conflictState.pendingConflicts.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) => _handleBatchAction(value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'server',
                  child: Text('全部使用服务器数据'),
                ),
                const PopupMenuItem(
                  value: 'local',
                  child: Text('全部使用本地数据'),
                ),
              ],
            ),
        ],
      ),
      body: conflictState.pendingConflicts.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: conflictState.pendingConflicts.length,
              itemBuilder: (context, index) {
                final conflict = conflictState.pendingConflicts[index];
                return _buildConflictCard(context, conflict);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green[300],
          ),
          const SizedBox(height: 16),
          Text(
            '没有待解决的冲突',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '所有数据已同步',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictCard(BuildContext context, SyncConflict conflict) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 冲突标题
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '交易 #${conflict.recordId}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  _formatTime(conflict.detectedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 冲突字段
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '冲突字段: ${conflict.conflictingFields.join(", ")}',
                      style: TextStyle(color: Colors.orange[700], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 数据对比
            _buildDataComparison(context, conflict),
            const SizedBox(height: 16),
            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _resolveConflict(conflict, ConflictResolution.serverWins),
                    icon: const Icon(Icons.cloud, size: 16),
                    label: const Text('使用服务器'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _resolveConflict(conflict, ConflictResolution.clientWins),
                    icon: const Icon(Icons.phone_android, size: 16),
                    label: const Text('使用本地'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showMergeDialog(context, conflict),
                    icon: const Icon(Icons.merge, size: 16),
                    label: const Text('合并'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataComparison(BuildContext context, SyncConflict conflict) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 表头
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '本地数据',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '服务器数据',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 数据行
          ...conflict.conflictingFields.map((field) {
            final localValue = _formatFieldValue(field, conflict.localData[field]);
            final serverValue = _formatFieldValue(field, conflict.serverData[field]);
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      localValue,
                      style: TextStyle(
                        color: localValue != serverValue ? Colors.green[700] : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      serverValue,
                      style: TextStyle(
                        color: localValue != serverValue ? Colors.blue[700] : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatFieldValue(String field, dynamic value) {
    if (value == null) return '-';
    
    switch (field) {
      case 'amount':
        return formatMoney(value as int);
      case 'type':
        final types = {'expense': '支出', 'income': '收入', 'transfer': '转账'};
        return types[value] ?? value.toString();
      case 'transaction_time':
        return value.toString().substring(0, 16);
      default:
        return value.toString();
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _resolveConflict(SyncConflict conflict, ConflictResolution resolution) async {
    await ref.read(conflictProvider.notifier).resolveManually(conflict, resolution);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('冲突已解决'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleBatchAction(String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action == 'server' ? '全部使用服务器数据' : '全部使用本地数据'),
        content: const Text('此操作不可撤销，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (action == 'server') {
        await ref.read(conflictProvider.notifier).resolveAllServerWins();
      } else {
        await ref.read(conflictProvider.notifier).resolveAllClientWins();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('所有冲突已解决'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showMergeDialog(BuildContext context, SyncConflict conflict) async {
    // 简化的合并对话框：让用户选择每个冲突字段使用哪个版本
    final selectedVersions = <String, String>{};
    
    for (final field in conflict.conflictingFields) {
      selectedVersions[field] = 'server'; // 默认使用服务器
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('合并数据'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('为每个冲突字段选择数据来源:'),
                const SizedBox(height: 16),
                ...conflict.conflictingFields.map((field) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: Text('本地: ${_formatFieldValue(field, conflict.localData[field])}'),
                                selected: selectedVersions[field] == 'local',
                                onSelected: (selected) {
                                  setState(() {
                                    selectedVersions[field] = 'local';
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: Text('服务器: ${_formatFieldValue(field, conflict.serverData[field])}'),
                                selected: selectedVersions[field] == 'server',
                                onSelected: (selected) {
                                  setState(() {
                                    selectedVersions[field] = 'server';
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedVersions),
              child: const Text('合并'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      // 合并数据
      final mergedData = Map<String, dynamic>.from(conflict.serverData);
      for (final entry in result.entries) {
        if (entry.value == 'local') {
          mergedData[entry.key] = conflict.localData[entry.key];
        }
      }
      
      await ref.read(conflictProvider.notifier).resolveManually(
        conflict,
        ConflictResolution.merge,
        mergedData: mergedData,
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('数据已合并'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
