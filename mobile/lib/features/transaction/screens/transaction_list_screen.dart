import 'package:flutter/material.dart';

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: 打开搜索
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: 打开筛选
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 20,
        itemBuilder: (context, index) {
          return _buildTransactionItem(context, index);
        },
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, int index) {
    final isExpense = index % 3 != 0;
    final amounts = [
      ('午饭', '肯德基', 3500),
      ('打车', '滴滴', 2500),
      ('工资', '工商银行', 150000),
      ('咖啡', '瑞幸', 990),
      ('购物', '淘宝', 29900),
    ];
    final item = amounts[index % amounts.length];
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isExpense ? Colors.red[50] : Colors.green[50],
        child: Icon(
          isExpense ? Icons.arrow_downward : Icons.arrow_upward,
          color: isExpense ? Colors.red : Colors.green,
          size: 20,
        ),
      ),
      title: Text(item.$1),
      subtitle: Text(item.$2),
      trailing: Text(
        '${isExpense ? '-' : '+'}¥${(item.$3 / 100).toStringAsFixed(2)}',
        style: TextStyle(
          color: isExpense ? Colors.red : Colors.green,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
