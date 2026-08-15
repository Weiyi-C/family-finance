import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

class AISettingsScreen extends ConsumerStatefulWidget {
  const AISettingsScreen({super.key});

  @override
  ConsumerState<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends ConsumerState<AISettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();
  String? _selectedProvider;
  bool _enabled = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  List<dynamic> _providers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final api = ref.read(apiServiceProvider);
      final results = await Future.wait([
        api.getAISettings(),
        api.getAIProviders(),
      ]);
      final settings = results[0] as Map<String, dynamic>;
      final providers = results[1] as List<dynamic>;
      setState(() {
        _providers = providers;
        _selectedProvider = settings['provider'] as String?;
        _apiKeyController.text = settings['api_key'] as String? ?? '';
        _baseUrlController.text = settings['base_url'] as String? ?? '';
        _modelController.text = settings['model'] as String? ?? '';
        _enabled = settings['enabled'] as bool? ?? false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 设置')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection('基本配置', [
                  SwitchListTile(
                    title: const Text('启用 AI 功能'),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProvider,
                    decoration: const InputDecoration(
                      labelText: 'AI 提供商',
                      border: OutlineInputBorder(),
                    ),
                    items: _providers.map((p) {
                      final name = p is Map ? (p['name'] ?? p['id'] ?? p.toString()) : p.toString();
                      return DropdownMenuItem(value: name.toString(), child: Text(name.toString()));
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedProvider = v),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSection('连接配置', [
                  TextField(
                    controller: _apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      border: OutlineInputBorder(),
                      hintText: 'https://api.openai.com/v1',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: '模型名称',
                      border: OutlineInputBorder(),
                      hintText: 'gpt-4o-mini',
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: _isTesting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.wifi_tethering),
                        label: const Text('测试连接'),
                        onPressed: _isTesting ? null : _testConnection,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save),
                        label: const Text('保存'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isSaving ? null : _save,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('删除 AI 配置', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                    onPressed: _delete,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.testAIConnection();
      if (mounted) {
        final success = result['success'] ?? result['status'] == 'ok';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? '连接成功' : '连接失败: ${result['message'] ?? ''}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('测试失败: $e')));
      }
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateAISettings({
        'provider': _selectedProvider,
        'api_key': _apiKeyController.text.trim(),
        'base_url': _baseUrlController.text.trim(),
        'model': _modelController.text.trim(),
        'enabled': _enabled,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('设置已保存')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除 AI 配置吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final api = ref.read(apiServiceProvider);
      await api.deleteAISettings();
      setState(() {
        _selectedProvider = null;
        _apiKeyController.clear();
        _baseUrlController.clear();
        _modelController.clear();
        _enabled = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配置已删除')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }
}
