import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/services/api_service.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final tagProvider = StateNotifierProvider<TagNotifier, TagState>((ref) {
  return TagNotifier(ref.read(apiServiceProvider));
});

class TagState {
  final List<Tag> tags;
  final bool isLoading;
  final String? error;
  
  TagState({
    this.tags = const [],
    this.isLoading = false,
    this.error,
  });
  
  TagState copyWith({
    List<Tag>? tags,
    bool? isLoading,
    String? error,
  }) {
    return TagState(
      tags: tags ?? this.tags,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class TagNotifier extends StateNotifier<TagState> {
  final ApiService _api;
  
  TagNotifier(this._api) : super(TagState());
  
  Future<void> loadTags() async {
    if (state.isLoading) return;
    
    state = state.copyWith(isLoading: true);
    
    try {
      final data = await _api.getTags();
      final items = data.map((json) => Tag.fromJson(json)).toList();
      state = state.copyWith(
        tags: items,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
  
  Future<void> createTag(Map<String, dynamic> data) async {
    try {
      await _api.createTag(data);
      await loadTags();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
  
  Future<void> updateTag(int id, Map<String, dynamic> data) async {
    try {
      await _api.updateTag(id, data);
      await loadTags();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
  
  Future<void> deleteTag(int id) async {
    try {
      await _api.deleteTag(id);
      state = state.copyWith(
        tags: state.tags.where((t) => t.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}
