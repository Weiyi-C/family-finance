import 'package:go_router/go_router.dart';
import '../data/models/models.dart';
import '../features/home/screens/home_screen.dart';
import '../features/transaction/screens/transaction_list_screen.dart';
import '../features/transaction/screens/create_transaction_screen.dart';
import '../features/statistics/screens/statistics_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/server_config_screen.dart';
import '../features/settings/screens/language_screen.dart';
import '../features/sync/screens/sync_status_screen.dart';
import '../features/sync/screens/conflict_resolution_screen.dart';
import '../features/splash/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/recurring/screens/recurring_screen.dart';
import '../features/recurring/screens/recurring_form_screen.dart';
import '../features/debt/screens/debt_screen.dart';
import '../features/debt/screens/debt_form_screen.dart';
import '../features/savings/screens/savings_screen.dart';
import '../features/savings/screens/savings_form_screen.dart';
import '../features/reimbursement/screens/reimbursement_screen.dart';
import '../features/reimbursement/screens/reimbursement_form_screen.dart';
import '../features/credit_bill/screens/credit_bill_screen.dart';
import '../features/category/screens/category_screen.dart';
import '../features/tag/screens/tag_screen.dart';
import '../features/notification/screens/notification_screen.dart';
import '../features/family/screens/family_screen.dart';
import '../features/rule/screens/rule_screen.dart';
import '../features/ai/screens/ai_assistant_screen.dart';
import '../features/ai/screens/ai_settings_screen.dart';
import '../features/backup/screens/backup_screen.dart';
import '../features/import/screens/import_export_screen.dart';
import '../features/budget/screens/budget_screen.dart';
import '../features/budget/screens/budget_form_screen.dart';
import '../features/account/screens/account_list_screen.dart';
import '../features/account/screens/account_detail_screen.dart';
import '../features/account/screens/account_form_screen.dart';
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
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
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
      builder: (context, state) {
        final transaction = state.extra as Transaction?;
        return CreateTransactionScreen(transaction: transaction);
      },
    ),
    GoRoute(
      path: '/server-config',
      builder: (context, state) => const ServerConfigScreen(),
    ),
    GoRoute(
      path: '/sync-status',
      builder: (context, state) => const SyncStatusScreen(),
    ),
    GoRoute(
      path: '/conflict-resolution',
      builder: (context, state) => const ConflictResolutionScreen(),
    ),
    GoRoute(
      path: '/recurring',
      builder: (context, state) => const RecurringScreen(),
    ),
    GoRoute(
      path: '/recurring-create',
      builder: (context, state) => const RecurringFormScreen(),
    ),
    GoRoute(
      path: '/recurring/:id/edit',
      builder: (context, state) {
        final recurring = state.extra as RecurringTransaction;
        return RecurringFormScreen(recurring: recurring);
      },
    ),
    GoRoute(
      path: '/debts',
      builder: (context, state) => const DebtScreen(),
    ),
    GoRoute(
      path: '/debt-create',
      builder: (context, state) => const DebtFormScreen(),
    ),
    GoRoute(
      path: '/savings',
      builder: (context, state) => const SavingsScreen(),
    ),
    GoRoute(
      path: '/savings-create',
      builder: (context, state) => const SavingsFormScreen(),
    ),
    GoRoute(
      path: '/savings/:id/edit',
      builder: (context, state) {
        final goal = state.extra as SavingsGoal;
        return SavingsFormScreen(goal: goal);
      },
    ),
    GoRoute(
      path: '/reimbursements',
      builder: (context, state) => const ReimbursementScreen(),
    ),
    GoRoute(
      path: '/reimbursement-create',
      builder: (context, state) => const ReimbursementFormScreen(),
    ),
    GoRoute(
      path: '/credit-bills',
      builder: (context, state) => const CreditBillScreen(),
    ),
    GoRoute(
      path: '/categories',
      builder: (context, state) => const CategoryScreen(),
    ),
    GoRoute(
      path: '/tags',
      builder: (context, state) => const TagScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationScreen(),
    ),
    GoRoute(
      path: '/family',
      builder: (context, state) => const FamilyScreen(),
    ),
    GoRoute(
      path: '/rules',
      builder: (context, state) => const RuleScreen(),
    ),
    GoRoute(
      path: '/ai-assistant',
      builder: (context, state) => const AIAssistantScreen(),
    ),
    GoRoute(
      path: '/ai-settings',
      builder: (context, state) => const AISettingsScreen(),
    ),
    GoRoute(
      path: '/backup',
      builder: (context, state) => const BackupScreen(),
    ),
    GoRoute(
      path: '/import-export',
      builder: (context, state) => const ImportExportScreen(),
    ),
    GoRoute(
      path: '/language',
      builder: (context, state) => const LanguageScreen(),
    ),
    GoRoute(
      path: '/budgets',
      builder: (context, state) => const BudgetScreen(),
    ),
    GoRoute(
      path: '/budget-create',
      builder: (context, state) => const BudgetFormScreen(),
    ),
    GoRoute(
      path: '/budget/:id/edit',
      builder: (context, state) {
        final budget = state.extra as Budget;
        return BudgetFormScreen(budget: budget);
      },
    ),
    GoRoute(
      path: '/accounts',
      builder: (context, state) => const AccountListScreen(),
    ),
    GoRoute(
      path: '/account-create',
      builder: (context, state) => const AccountFormScreen(),
    ),
    GoRoute(
      path: '/account/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return AccountDetailScreen(accountId: id);
      },
    ),
    GoRoute(
      path: '/account/:id/edit',
      builder: (context, state) {
        final account = state.extra as Account;
        return AccountFormScreen(account: account);
      },
    ),
  ],
);
