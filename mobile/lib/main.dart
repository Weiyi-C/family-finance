import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/routes.dart';
import 'core/theme/app_theme.dart';
import 'data/services/api_service.dart';
import 'features/settings/providers/theme_provider.dart';
import 'features/settings/providers/color_theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService().init();
  runApp(
    const ProviderScope(
      child: FamilyFinanceApp(),
    ),
  );
}

class FamilyFinanceApp extends ConsumerWidget {
  const FamilyFinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorTheme = ref.watch(colorThemeProvider);
    final primaryColor = AppTheme.presetColors[colorTheme];

    return MaterialApp.router(
      title: '家庭记账',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(primaryColor: primaryColor),
      darkTheme: AppTheme.darkTheme(primaryColor: primaryColor),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
