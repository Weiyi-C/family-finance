import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';
import 'package:family_finance_app/features/notification/providers/notification_provider.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          TextButton(
            onPressed: () async {
              final api = ref.read(apiServiceProvider);
              await api.markAllNotificationsRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: const Text('全部已读'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text('加载失败: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(notificationsProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('暂无通知', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return _NotificationTile(notif: notif);
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final Map<String, dynamic> notif;

  const _NotificationTile({required this.notif});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = notif['title'] as String? ?? '';
    final content = notif['content'] as String? ?? '';
    final type = notif['type'] as String? ?? 'info';
    final isRead = notif['is_read'] as bool? ?? true;
    final createdAt = notif['created_at'] as String?;

    IconData icon;
    Color color;

    switch (type) {
      case 'warning':
        icon = Icons.warning;
        color = Colors.orange;
      case 'budget_alert':
        icon = Icons.account_balance_wallet;
        color = Colors.red;
      case 'ai':
        icon = Icons.smart_toy;
        color = Colors.purple;
      case 'success':
        icon = Icons.check_circle;
        color = Colors.green;
      case 'sync':
        icon = Icons.sync;
        color = Colors.blue;
      case 'recurring':
        icon = Icons.repeat;
        color = Colors.teal;
      default:
        icon = Icons.info;
        color = Colors.blue;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(content, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (createdAt != null) ...[
            const SizedBox(height: 4),
            Text(_formatTime(createdAt), style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
      isThreeLine: createdAt != null,
      tileColor: isRead ? null : Colors.blue.withValues(alpha: 0.05),
      onTap: () async {
        if (!isRead) {
          final id = notif['id'] as int;
          final api = ref.read(apiServiceProvider);
          await api.markNotificationRead(id);
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadCountProvider);
        }
        if (context.mounted) {
          _navigateToRelated(context, notif);
        }
      },
    );
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      if (diff.inDays < 2) return '昨天';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return '${date.month}-${date.day}';
    } catch (_) {
      return dateStr;
    }
  }

  void _navigateToRelated(BuildContext context, Map<String, dynamic> notif) {
    final relatedType = notif['related_type'] as String?;
    final relatedId = notif['related_id'] as int?;

    if (relatedType == null || relatedId == null) return;

    switch (relatedType) {
      case 'transaction':
        context.push('/transactions');
      case 'budget':
        context.push('/budgets');
      case 'debt':
        context.push('/debts');
      case 'savings':
        context.push('/savings');
      case 'recurring':
        context.push('/recurring');
      case 'reimbursement':
        context.push('/reimbursements');
      case 'credit_bill':
        context.push('/credit-bills');
    }
  }
}
