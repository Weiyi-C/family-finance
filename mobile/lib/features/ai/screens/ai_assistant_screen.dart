import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';


class AIAssistantScreen extends ConsumerStatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  ConsumerState<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends ConsumerState<AIAssistantScreen> {
  final _messageController = TextEditingController();
  final _messages = <Map<String, dynamic>>[];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'assistant',
      'content': '你好！我是AI记账助手。你可以用自然语言告诉我一笔消费，比如"午饭花了35块"，我来帮你记录。',
      'time': DateTime.now(),
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 助手'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            tooltip: '查看建议',
            onPressed: () => _showSuggestions(context),
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: '消费分析',
            onPressed: _triggerAnalysis,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'AI 设置',
            onPressed: () => context.push('/ai-settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message['role'] == 'user';
                return _buildMessageBubble(context, message, isUser);
              },
            ),
          ),
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, Map<String, dynamic> message, bool isUser) {
    final time = message['time'] as DateTime;
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? Theme.of(context).colorScheme.primary : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message['type'] == 'parsed') ...[
              _buildParsedResult(context, message['data'] as Map<String, dynamic>),
            ] else if (message['type'] == 'suggestions') ...[
              _buildSuggestionsList(context, message['data'] as List<dynamic>),
            ] else if (message['type'] == 'analysis') ...[
              _buildAnalysisResult(context, message['data'] as Map<String, dynamic>),
            ] else ...[
              Text(
                message['content'] as String,
                style: TextStyle(color: isUser ? Colors.white : Colors.black87),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(fontSize: 10, color: isUser ? Colors.white70 : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParsedResult(BuildContext context, Map<String, dynamic> data) {
    final amount = data['amount'];
    final merchant = data['merchant'] ?? data['description'] ?? '';
    final category = data['category'] ?? data['suggested_category'] ?? '';
    final date = data['date'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('解析结果', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 8),
        if (amount != null) _infoRow('金额', '¥$amount'),
        if (merchant.toString().isNotEmpty) _infoRow('商户/描述', merchant.toString()),
        if (category.toString().isNotEmpty) _infoRow('分类建议', category.toString()),
        if (date.toString().isNotEmpty) _infoRow('日期', date.toString()),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 16),
            label: const Text('保存交易'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onPressed: () => _saveTransaction(data),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(BuildContext context, List<dynamic> suggestions) {
    if (suggestions.isEmpty) {
      return const Text('暂无待处理的建议', style: TextStyle(color: Colors.black54));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AI 建议 (${suggestions.length})', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 8),
        ...suggestions.map((s) => _buildSuggestionItem(context, s)),
      ],
    );
  }

  Widget _buildSuggestionItem(BuildContext context, dynamic suggestion) {
    final id = suggestion.id as int;
    final type = suggestion.type as String;
    final status = suggestion.status as String;
    final reason = suggestion.reason as String? ?? '';
    final sugData = suggestion.suggestion as Map<String, dynamic>? ?? {};
    final description = sugData['description'] ?? sugData['title'] ?? reason;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _typeColor(type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(type, style: TextStyle(fontSize: 11, color: _typeColor(type))),
              ),
              const SizedBox(width: 6),
              Text(status, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          Text(description.toString(), style: const TextStyle(fontSize: 13)),
          if (status == 'pending') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _rejectSuggestion(id),
                    child: const Text('忽略', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _acceptSuggestion(id),
                    child: const Text('接受', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'budget_alert':
        return Colors.orange;
      case 'category_suggestion':
        return Colors.blue;
      case 'saving_tip':
        return Colors.green;
      case 'duplicate_warning':
        return Colors.red;
      default:
        return Colors.purple;
    }
  }

  Widget _buildAnalysisResult(BuildContext context, Map<String, dynamic> data) {
    final summary = data['summary'] ?? data['analysis'] ?? data;
    if (summary is Map<String, dynamic>) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('消费分析', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 8),
          ...summary.entries.map((e) => _infoRow(e.key.toString(), e.value.toString())),
        ],
      );
    }
    return Text(summary.toString(), style: const TextStyle(color: Colors.black87));
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: '输入消费记录，如"午饭35元"...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _isLoading ? Colors.grey : Theme.of(context).colorScheme.primary,
            child: IconButton(
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text, 'time': DateTime.now()});
      _isLoading = true;
    });
    _messageController.clear();

    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.parseTransactionText(text);
      setState(() {
        _messages.add({
          'role': 'assistant',
          'type': 'parsed',
          'data': result,
          'content': '',
          'time': DateTime.now(),
        });
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': '解析失败: ${e.toString()}',
          'time': DateTime.now(),
        });
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTransaction(Map<String, dynamic> parsed) async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = <String, dynamic>{
        if (parsed['amount'] != null) 'amount': parsed['amount'],
        if (parsed['merchant'] != null) 'description': parsed['merchant'],
        if (parsed['description'] != null) 'description': parsed['description'],
        if (parsed['category'] != null) 'category_name': parsed['category'],
        if (parsed['suggested_category'] != null) 'category_name': parsed['suggested_category'],
        if (parsed['date'] != null) 'date': parsed['date'],
        'type': parsed['type'] ?? 'expense',
      };
      await api.createTransaction(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('交易已保存')));
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': '交易已成功保存！',
            'time': DateTime.now(),
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  Future<void> _showSuggestions(BuildContext context) async {
    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': '正在获取AI建议...',
        'time': DateTime.now(),
      });
    });

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getAISuggestions();
      setState(() {
        _messages.removeLast();
        _messages.add({
          'role': 'assistant',
          'type': 'suggestions',
          'data': data.map((json) => _SuggestionWrapper.fromJson(json)).toList(),
          'content': '',
          'time': DateTime.now(),
        });
      });
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add({
          'role': 'assistant',
          'content': '获取建议失败: $e',
          'time': DateTime.now(),
        });
      });
    }
  }

  Future<void> _acceptSuggestion(int id) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.acceptAISuggestion(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已接受建议')));
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': '建议已接受并应用。',
            'time': DateTime.now(),
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  Future<void> _rejectSuggestion(int id) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.rejectAISuggestion(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已忽略建议')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  Future<void> _triggerAnalysis() async {
    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': '正在进行消费分析...',
        'time': DateTime.now(),
      });
    });

    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.triggerAIAnalysis();
      setState(() {
        _messages.removeLast();
        _messages.add({
          'role': 'assistant',
          'type': 'analysis',
          'data': result,
          'content': '',
          'time': DateTime.now(),
        });
      });
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add({
          'role': 'assistant',
          'content': '分析失败: $e',
          'time': DateTime.now(),
        });
      });
    }
  }
}

class _SuggestionWrapper {
  final int id;
  final String type;
  final String status;
  final String? reason;
  final Map<String, dynamic>? suggestion;

  _SuggestionWrapper({
    required this.id,
    required this.type,
    required this.status,
    this.reason,
    this.suggestion,
  });

  factory _SuggestionWrapper.fromJson(Map<String, dynamic> json) {
    return _SuggestionWrapper(
      id: json['id'] as int,
      type: json['type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      reason: json['reason'] as String?,
      suggestion: json['suggestion'] as Map<String, dynamic>?,
    );
  }
}
