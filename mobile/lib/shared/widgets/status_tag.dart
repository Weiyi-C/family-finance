import 'package:flutter/material.dart';

/// 状态标签组件
class StatusTag extends StatelessWidget {
  final String status;
  final Map<String, String> statusMap;
  final Map<String, Color> colorMap;

  const StatusTag({
    super.key,
    required this.status,
    required this.statusMap,
    required this.colorMap,
  });

  @override
  Widget build(BuildContext context) {
    final label = statusMap[status] ?? status;
    final color = colorMap[status] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
