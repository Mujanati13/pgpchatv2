import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String? _error;
  Timer? _conversationPollTimer;
  Timer? _messagePollTimer;
  String? _currentChatUserId;

  List<Map<String, dynamic>> get conversations => _conversations;
  List<Map<String, dynamic>> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Conversations polling ──

  void startConversationPolling() {
    stopConversationPolling();
    loadConversations();
    _conversationPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshConversations(),
    );
  }

  void stopConversationPolling() {
    _conversationPollTimer?.cancel();
    _conversationPollTimer = null;
  }

  Future<void> _refreshConversations() async {
    try {
      final result = await _api.getConversations();
      final updated = List<Map<String, dynamic>>.from(
          result['conversations'] as List? ?? []);
      if (!listEquals(_conversations.map((c) => c.toString()).toList(),
          updated.map((c) => c.toString()).toList())) {
        _conversations = updated;
        notifyListeners();
      }
    } catch (_) {}
  }

  // ── Messages polling ──

  void startMessagePolling(String otherUserId) {
    stopMessagePolling();
    _currentChatUserId = otherUserId;
    loadMessages(otherUserId);
    _messagePollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshMessages(),
    );
  }

  void stopMessagePolling() {
    _messagePollTimer?.cancel();
    _messagePollTimer = null;
    _currentChatUserId = null;
  }

  Future<void> _refreshMessages() async {
    if (_currentChatUserId == null) return;
    try {
      final result = await _api.getMessages(_currentChatUserId!);
      final updated = List<Map<String, dynamic>>.from(
          result['messages'] as List? ?? []);
      if (updated.length != _messages.length ||
          (updated.isNotEmpty &&
              _messages.isNotEmpty &&
              updated.first['id'] != _messages.first['id'])) {
        _messages = updated;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> loadConversations() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _api.getConversations();
      _conversations = List<Map<String, dynamic>>.from(
          result['conversations'] as List? ?? []);
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to load conversations';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMessages(String otherUserId, {int? before}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result =
          await _api.getMessages(otherUserId, before: before);
      final newMessages = List<Map<String, dynamic>>.from(
          result['messages'] as List? ?? []);
      if (before != null) {
        _messages.addAll(newMessages);
      } else {
        _messages = newMessages;
      }
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to load messages';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> sendMessage({
    required String recipientId,
    required String encryptedBody,
    String? signature,
  }) async {
    try {
      await _api.sendMessage(
        recipientId: recipientId,
        encryptedBody: encryptedBody,
        signature: signature,
      );
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to send message';
      notifyListeners();
      return false;
    }
  }

  void clearMessages() {
    _messages = [];
    notifyListeners();
  }
}
