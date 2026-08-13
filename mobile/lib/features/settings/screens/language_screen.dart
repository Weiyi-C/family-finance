import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/core/localization/app_localizations.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(languageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('语言设置'),
      ),
      body: ListView(
        children: AppLanguage.values.map((language) {
          final isSelected = currentLanguage == language;
          
          return ListTile(
            leading: Text(
              language.flag,
              style: const TextStyle(fontSize: 24),
            ),
            title: Text(language.name),
            subtitle: Text(language.code),
            trailing: isSelected
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () {
              ref.read(languageProvider.notifier).setLanguage(language);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('语言已切换为 ${language.name}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}
