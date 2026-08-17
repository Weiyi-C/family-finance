import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../providers/color_theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/models.dart' hide Family;
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/transaction/providers/transaction_provider.dart';
import '../../../features/family/providers/family_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _serverUrl = '';

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverUrl = prefs.getString('server_url') ?? 'http://localhost:8080';
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final familyAsync = ref.watch(familyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
      ),
      body: ListView(
        children: [
          _buildUserCard(context, authState, familyAsync),
          const SizedBox(height: 16),
          _buildAssetCard(context, accountsAsync),
          const SizedBox(height: 16),
          _buildFunctionGrid(context),
          const SizedBox(height: 16),
          _buildSettingsSection(context, ref, themeMode),
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, AuthState authState, AsyncValue familyAsync) {
    final userName = authState.user?.nickname ?? '未登录';
    String familyName = '未加入家庭';
    familyAsync.whenData((f) {
      if (f is Map && f.containsKey('name')) {
        familyName = f['name'] ?? familyName;
      } else {
        try {
          familyName = (f as dynamic).name ?? familyName;
        } catch (_) {}
      }
    });

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                userName.isNotEmpty ? userName[0] : '?',
                style: const TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '家庭：$familyName',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => context.push('/family'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetCard(BuildContext context, AsyncValue<List<Account>> accountsAsync) {
    final accounts = accountsAsync.whenOrNull(data: (a) => a) ?? [];
    final totalBalance = accounts.fold<double>(0, (sum, a) => sum + a.balanceYuan);

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
              formatMoney((totalBalance * 100).toInt()),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (accounts.isEmpty)
              Text('暂无账户数据', style: Theme.of(context).textTheme.bodySmall)
            else
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: accounts.take(6).map((a) => _buildAssetItem(
                  context,
                  a.name,
                  formatMoney(a.balance ?? a.initialBalance),
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetItem(BuildContext context, String label, String amount) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(amount, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
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
      ('分类管理', Icons.category, () => context.push('/categories')),
      ('标签管理', Icons.label, () => context.push('/tags')),
      ('规则引擎', Icons.rule, () => context.push('/rules')),
      ('AI助手', Icons.smart_toy, () => context.push('/ai-assistant')),
      ('导入导出', Icons.import_export, () => context.push('/import-export')),
      ('家庭管理', Icons.family_restroom, () => context.push('/family')),
      ('通知', Icons.notifications, () => context.push('/notifications')),
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

  Widget _buildColorThemeSection(BuildContext context, WidgetRef ref) {
    final colorKey = ref.watch(colorThemeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '主题颜色',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: AppTheme.presetColors.length,
            itemBuilder: (context, index) {
              final entry = AppTheme.presetColors.entries.elementAt(index);
              final isSelected = entry.key == colorKey;
              return GestureDetector(
                onTap: () {
                  ref.read(colorThemeProvider.notifier).setColor(entry.key);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: entry.value,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface,
                                width: 3,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: entry.value.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 22)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _colorName(entry.key),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _colorName(String key) {
    const names = {
      'sakura': '樱花粉',
      'mint': '薄荷绿',
      'lavender': '薰衣草紫',
      'sunset': '日落橙',
      'ocean': '海洋蓝',
      'forest': '森林绿',
    };
    return names[key] ?? key;
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
          _buildColorThemeSection(context, ref),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('语言设置'),
            subtitle: const Text('中文'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/language');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.dns),
            title: const Text('服务器配置'),
            subtitle: Text(_serverUrl),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await context.push('/server-config');
              _loadServerUrl();
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('数据同步'),
            subtitle: const Text('查看同步状态'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/sync-status');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('备份恢复'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/backup');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: '家庭记账',
                applicationVersion: '1.0.0',
                children: const [Text('治愈系萌趣记账APP')],
              );
            },
          ),
        ],
      ),
    );
  }
}
