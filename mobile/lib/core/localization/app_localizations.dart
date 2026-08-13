import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 支持的语言
enum AppLanguage {
  zh('zh', '中文', '🇨🇳'),
  en('en', 'English', '🇺🇸'),
  ja('ja', '日本語', '🇯🇵');

  final String code;
  final String name;
  final String flag;

  const AppLanguage(this.code, this.name, this.flag);
}

// 语言状态管理
final languageProvider = StateNotifierProvider<LanguageNotifier, AppLanguage>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<AppLanguage> {
  LanguageNotifier() : super(AppLanguage.zh) {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('language') ?? 'zh';
    state = AppLanguage.values.firstWhere(
      (lang) => lang.code == langCode,
      orElse: () => AppLanguage.zh,
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language.code);
  }
}

// 多语言文本
class AppLocalizations {
  static const Map<String, Map<String, String>> _texts = {
    'zh': {
      'app_name': '家庭记账',
      'home': '首页',
      'transactions': '账单',
      'add': '记账',
      'statistics': '统计',
      'profile': '我的',
      'settings': '设置',
      'login': '登录',
      'register': '注册',
      'phone': '手机号',
      'password': '密码',
      'nickname': '昵称',
      'logout': '退出登录',
      'income': '收入',
      'expense': '支出',
      'transfer': '转账',
      'amount': '金额',
      'category': '分类',
      'account': '账户',
      'merchant': '商户',
      'description': '备注',
      'time': '时间',
      'save': '保存',
      'cancel': '取消',
      'confirm': '确认',
      'delete': '删除',
      'edit': '编辑',
      'create': '创建',
      'search': '搜索',
      'filter': '筛选',
      'export': '导出',
      'import': '导入',
      'backup': '备份',
      'restore': '恢复',
      'sync': '同步',
      'offline': '离线模式',
      'online': '在线模式',
      'loading': '加载中...',
      'no_data': '暂无数据',
      'success': '成功',
      'failed': '失败',
      'error': '错误',
      'budget': '预算',
      'recurring': '周期交易',
      'debt': '借贷',
      'savings': '储蓄目标',
      'reimbursement': '报销',
      'credit_bill': '信用账单',
      'family': '家庭管理',
      'notification': '通知',
      'ai_assistant': 'AI助手',
      'rule_engine': '规则引擎',
      'category_management': '分类管理',
      'tag_management': '标签管理',
      'theme': '主题',
      'language': '语言',
      'server_config': '服务器配置',
      'about': '关于',
      'dark_mode': '深色模式',
      'light_mode': '浅色模式',
      'auto_mode': '跟随系统',
    },
    'en': {
      'app_name': 'Family Finance',
      'home': 'Home',
      'transactions': 'Transactions',
      'add': 'Add',
      'statistics': 'Statistics',
      'profile': 'Profile',
      'settings': 'Settings',
      'login': 'Login',
      'register': 'Register',
      'phone': 'Phone',
      'password': 'Password',
      'nickname': 'Nickname',
      'logout': 'Logout',
      'income': 'Income',
      'expense': 'Expense',
      'transfer': 'Transfer',
      'amount': 'Amount',
      'category': 'Category',
      'account': 'Account',
      'merchant': 'Merchant',
      'description': 'Description',
      'time': 'Time',
      'save': 'Save',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'delete': 'Delete',
      'edit': 'Edit',
      'create': 'Create',
      'search': 'Search',
      'filter': 'Filter',
      'export': 'Export',
      'import': 'Import',
      'backup': 'Backup',
      'restore': 'Restore',
      'sync': 'Sync',
      'offline': 'Offline Mode',
      'online': 'Online Mode',
      'loading': 'Loading...',
      'no_data': 'No Data',
      'success': 'Success',
      'failed': 'Failed',
      'error': 'Error',
      'budget': 'Budget',
      'recurring': 'Recurring',
      'debt': 'Debt',
      'savings': 'Savings Goal',
      'reimbursement': 'Reimbursement',
      'credit_bill': 'Credit Bill',
      'family': 'Family',
      'notification': 'Notification',
      'ai_assistant': 'AI Assistant',
      'rule_engine': 'Rule Engine',
      'category_management': 'Category Management',
      'tag_management': 'Tag Management',
      'theme': 'Theme',
      'language': 'Language',
      'server_config': 'Server Config',
      'about': 'About',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'auto_mode': 'Auto',
    },
    'ja': {
      'app_name': '家計簿',
      'home': 'ホーム',
      'transactions': '取引',
      'add': '追加',
      'statistics': '統計',
      'profile': 'マイページ',
      'settings': '設定',
      'login': 'ログイン',
      'register': '登録',
      'phone': '電話番号',
      'password': 'パスワード',
      'nickname': 'ニックネーム',
      'logout': 'ログアウト',
      'income': '収入',
      'expense': '支出',
      'transfer': '振替',
      'amount': '金額',
      'category': 'カテゴリ',
      'account': 'アカウント',
      'merchant': '加盟店',
      'description': 'メモ',
      'time': '時間',
      'save': '保存',
      'cancel': 'キャンセル',
      'confirm': '確認',
      'delete': '削除',
      'edit': '編集',
      'create': '作成',
      'search': '検索',
      'filter': 'フィルター',
      'export': 'エクスポート',
      'import': 'インポート',
      'backup': 'バックアップ',
      'restore': '復元',
      'sync': '同期',
      'offline': 'オフラインモード',
      'online': 'オンラインモード',
      'loading': '読み込み中...',
      'no_data': 'データなし',
      'success': '成功',
      'failed': '失敗',
      'error': 'エラー',
      'budget': '予算',
      'recurring': '定期取引',
      'debt': '借入',
      'savings': '貯蓄目標',
      'reimbursement': '経費精算',
      'credit_bill': 'クレジット請求',
      'family': '家族管理',
      'notification': '通知',
      'ai_assistant': 'AIアシスタント',
      'rule_engine': 'ルールエンジン',
      'category_management': 'カテゴリ管理',
      'tag_management': 'タグ管理',
      'theme': 'テーマ',
      'language': '言語',
      'server_config': 'サーバー設定',
      'about': 'バージョン情報',
      'dark_mode': 'ダークモード',
      'light_mode': 'ライトモード',
      'auto_mode': '自動',
    },
  };

  static String getText(String key) {
    // TODO: 从 Provider 获取当前语言
    return _texts['zh']?[key] ?? key;
  }
}
