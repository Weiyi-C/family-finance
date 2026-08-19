import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';
import 'package:family_finance_app/features/auth/providers/offline_auth_provider.dart';
import 'package:family_finance_app/core/network/network_status.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;
    final isOffline = ref.read(networkStatusProvider) == NetworkStatus.offline;
    if (isOffline) {
      ref.read(offlineAuthProvider.notifier).login(
            _phoneController.text.trim(),
            _passwordController.text,
          );
    } else {
      ref.read(authProvider.notifier).login(
            _phoneController.text.trim(),
            _passwordController.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final offlineAuthState = ref.watch(offlineAuthProvider);
    final isOffline = ref.watch(networkStatusProvider) == NetworkStatus.offline;

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.user != null) {
        context.go('/');
      } else if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    ref.listen<OfflineAuthState>(offlineAuthProvider, (prev, next) {
      if (next.status == OfflineAuthStatus.offlineSuccess) {
        ScaffoldMessenger.of(context).clearSnackBars();
        context.go('/');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('离线模式已登录，联网后数据将自动同步'),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (next.status == OfflineAuthStatus.onlineSuccess) {
        ScaffoldMessenger.of(context).clearSnackBars();
        context.go('/');
      } else if (next.status == OfflineAuthStatus.error && next.error != null) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: next.error!.contains('离线模式') ? SnackBarAction(
              label: '去设置',
              textColor: Colors.white,
              onPressed: () => context.push('/server-config'),
            ) : null,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '服务器设置',
            onPressed: () => context.push('/server-config'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '欢迎回来',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '手机号',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入手机号';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入密码';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (authState.isLoading || offlineAuthState.status == OfflineAuthStatus.loading) ? null : _handleLogin,
                  child: (authState.isLoading || offlineAuthState.status == OfflineAuthStatus.loading)
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isOffline ? '离线登录' : '登录'),
                ),
                if (isOffline) ...[
                  const SizedBox(height: 8),
                  Text(
                    '当前无网络，将使用本地账户登录',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('没有账号？去注册'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
