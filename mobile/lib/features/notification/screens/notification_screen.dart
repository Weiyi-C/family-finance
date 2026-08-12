import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = [
      {
        'title': '预算预警',
        'content': '餐饮分类本月支出已达预算的80%',
        'time': '10分钟前',
        'type': 'warning',
        'isRead': false,
      },
      {
        'title': '还款提醒',
        'content': '工商银行信用卡还款日为明天（8月25日）',
        'time': '1小时前',
        'type': 'info',
        'isRead': false,
      },
      {
        'title': 'AI分析完成',
        'content': 'AI发现了3条新的消费建议',
        'time': '3小时前',
        'type': 'ai',
        'isRead': true,
      },
      {
        'title': '同步成功',
        'content': '数据已成功同步到服务器',
        'time': '昨天',
        'type': 'success',
        'isRead': true,
      },
      {
        'title': '周期交易执行',
        'content': '房租 ¥2,000 已自动记录',
        'time': '昨天',
        'type': 'info',
        'isRead': true,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: 全部标记已读
            },
            child: const Text('全部已读'),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notif = notifications[index];
          final type = notif['type'] as String;
          final isRead = notif['isRead'] as bool;
          
          IconData icon;
          Color color;
          
          switch (type) {
            case 'warning':
              icon = Icons.warning;
              color = Colors.orange;
              break;
            case 'info':
              icon = Icons.info;
              color = Colors.blue;
              break;
            case 'ai':
              icon = Icons.smart_toy;
              color = Colors.purple;
              break;
            case 'success':
              icon = Icons.check_circle;
              color = Colors.green;
              break;
            default:
              icon = Icons.notifications;
              color = Colors.grey;
          }

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Text(
              notif['title'] as String,
              style: TextStyle(
                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notif['content'] as String),
                const SizedBox(height: 4),
                Text(
                  notif['time'] as String,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            isThreeLine: true,
            tileColor: isRead ? null : Colors.blue.withOpacity(0.05),
            onTap: () {
              // TODO: 标记已读并跳转
            },
          );
        },
      ),
    );
  }
}
