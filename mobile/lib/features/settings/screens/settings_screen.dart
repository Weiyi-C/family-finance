import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
      ),
      body: ListView(
        children: [
          // 用户信息卡片
          _buildUserCard(context),
          const SizedBox(height: 16),
          // 资产总览
          _buildAssetCard(context),
          const SizedBox(height: 16),
          // 功能入口
          _buildFunctionGrid(context),
          const SizedBox(height: 16),
          // 设置选项
          _buildSettingsSection(context, ref, themeMode),
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.person, size: 30, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '小明',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '家庭：温馨小家 · 3人',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                // TODO: 编辑个人信息
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '资产总览',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '¥125,000.00',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildAssetItem(context, '现金', '¥2,000'),
                _buildAssetItem(context, '银行卡', '¥85,000'),
                _buildAssetItem(context, '支付宝', '¥18,000'),
                _buildAssetItem(context, '微信', '¥20,000'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetItem(BuildContext context, String label, String amount) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(amount, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildFunctionGrid(BuildContext context) {
    final functions = [
      ('资金账户', Icons.account_balance_wallet, () => context.push('/accounts')),
      ('信用账单', Icons.credit_card, () => context.push('/credit-bills')),
      ('预算管理', Icons.savings, () => context.push('/budgets')),
      ('借贷管理', Icons.money, () => context.push('/debts')),
      ('储蓄目标', Icons.flag, () => context.push('/savings')),
      ('周期交易', Icons.repeat, () => context.push('/recurring')),
      ('报销管理', Icons.receipt, () => context.push('/reimbursements')),
      ('规则引擎', Icons.settings, () {}),
      ('AI助手', Icons.smart_toy, () {}),
      ('家庭管理', Icons.family_restroom, () {}),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemCount: functions.length,
          itemBuilder: (context, index) {
            return InkWell(
              onTap: functions[index].$3,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    functions[index].$2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    functions[index].$1,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context,
    WidgetRef ref,
    ThemeMode themeMode,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('主题设置'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
                ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
                ButtonSegment(value: ThemeMode.system, label: Text('自动')),
              ],
              selected: {themeMode},
              onSelectionChanged: (modes) {
                ref.read(themeModeProvider.notifier).setThemeMode(modes.first);
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.dns),
            title: const Text('服务器配置'),
            subtitle: const Text('http://192.168.1.100:8080'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/server-config');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('数据同步'),
            subtitle: const Text('最后同步：2026-08-13 16:30'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/sync-status');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 打开关于页面
            },
          ),
        ],
      ),
    );
  }
}
