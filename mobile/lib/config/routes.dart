import 'package:go_router/go_router.dart';
import '../features/home/screens/home_screen.dart';
import '../features/transaction/screens/transaction_list_screen.dart';
import '../features/transaction/screens/create_transaction_screen.dart';
import '../features/statistics/screens/statistics_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/server_config_screen.dart';
import '../features/sync/screens/sync_status_screen.dart';
import '../features/splash/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import 'main_layout.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => MainLayout(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/transactions',
          builder: (context, state) => const TransactionListScreen(),
        ),
        GoRoute(
          path: '/statistics',
          builder: (context, state) => const StatisticsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/create-transaction',
      builder: (context, state) => const CreateTransactionScreen(),
    ),
    GoRoute(
      path: '/server-config',
      builder: (context, state) => const ServerConfigScreen(),
    ),
    GoRoute(
      path: '/sync-status',
      builder: (context, state) => const SyncStatusScreen(),
    ),
  ],
);
