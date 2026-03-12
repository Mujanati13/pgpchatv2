import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrlKey = 'api_base_url';
  static const String _tokenKey = 'auth_token';
  static const String _defaultBaseUrl = 'http://93.127.129.90:3000/api';

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Called whenever any API request receives a 401. Wire this up from AuthProvider.
  static void Function()? onUnauthorized;

  String? _token;
  String? _baseUrl;

  Future<String> get baseUrl async {
    if (_baseUrl != null) return _baseUrl!;
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
    return _baseUrl!;
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }

  void resetBaseUrlCache() {
    _baseUrl = null;
  }

  Future<String?> get token async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    return _token;
  }

  Future<void> setToken(String? t) async {
    _token = t;
    final prefs = await SharedPreferences.getInstance();
    if (t == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, t);
    }
  }

  Future<Map<String, String>> _headers() async {
    final t = await token;
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    if (response.statusCode == 401) {
      await setToken(null); // clear stored token immediately
      onUnauthorized?.call();
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: body['error'] as String? ?? 'Unknown error',
    );
  }

  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? queryParams}) async {
    final url = Uri.parse('${await baseUrl}$path')
        .replace(queryParameters: queryParams);
    final response = await http.get(url, headers: await _headers());
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? body}) async {
    final url = Uri.parse('${await baseUrl}$path');
    final response = await http.post(
      url,
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String path,
      {Map<String, dynamic>? body}) async {
    final url = Uri.parse('${await baseUrl}$path');
    final response = await http.put(
      url,
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final url = Uri.parse('${await baseUrl}$path');
    final response = await http.delete(url, headers: await _headers());
    return _handleResponse(response);
  }

  // ========== Users ==========

  Future<Map<String, dynamic>> searchUsers(String query) async {
    return get('/users/search', queryParams: {'q': query});
  }

  // ========== Auth ==========

  Future<Map<String, dynamic>> register(
      String username, String password) async {
    final result = await post('/auth/register', body: {
      'username': username,
      'password': password,
    });
    await setToken(result['token'] as String);
    return result;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final result = await post('/auth/login', body: {
      'username': username,
      'password': password,
    });
    await setToken(result['token'] as String);
    return result;
  }

  Future<void> logout() async {
    try {
      await post('/auth/logout');
    } finally {
      await setToken(null);
    }
  }

  Future<Map<String, dynamic>> updatePublicKey(String publicKey) async {
    return put('/auth/public-key', body: {'publicKey': publicKey});
  }

  Future<Map<String, dynamic>> resetPgp() async {
    return post('/auth/reset-pgp');
  }

  Future<Map<String, dynamic>> requestRecovery(String username) async {
    return post('/auth/recover-request', body: {'username': username});
  }

  Future<Map<String, dynamic>> confirmRecovery(
      String username, String challenge, String newPassword) async {
    return post('/auth/recover-confirm', body: {
      'username': username,
      'challenge': challenge,
      'newPassword': newPassword,
    });
  }

  // ========== Messages ==========

  Future<Map<String, dynamic>> getMessages(String otherUserId,
      {int? before, int limit = 50}) async {
    final params = <String, String>{
      'contactId': otherUserId,
      'limit': limit.toString(),
    };
    if (before != null) params['before'] = before.toString();
    return get('/messages', queryParams: params);
  }

  Future<Map<String, dynamic>> sendMessage({
    required String recipientId,
    required String encryptedBody,
    String? signature,
  }) async {
    return post('/messages', body: {
      'recipientId': recipientId,
      'encryptedBody': encryptedBody,
      if (signature != null) 'signature': signature,
    });
  }

  Future<Map<String, dynamic>> getConversations() async {
    return get('/messages/conversations');
  }

  Future<Map<String, dynamic>> clearChat(String otherUserId) async {
    return delete('/messages/$otherUserId');
  }

  Future<void> markConversationRead(String otherUserId) async {
    try {
      await put('/messages/$otherUserId/read');
    } catch (_) {} // best-effort, don't block the UI
  }

  /// Notify server that a screenshot attempt was detected
  Future<void> sendScreenshotAlert(String recipientId) async {
    try {
      await post('/messages/screenshot-alert', body: {
        'recipientId': recipientId,
      });
    } catch (_) {} // best-effort
  }

  // ========== Uploads ==========

  Future<String> uploadImage(Uint8List bytes, String filename) async {
    final url = Uri.parse('${await baseUrl}/uploads');
    final request = http.MultipartRequest('POST', url);
    final t = await token;
    if (t != null) request.headers['Authorization'] = 'Bearer $t';
    // Derive MIME type from filename extension so multer accepts it
    final ext = filename.split('.').last.toLowerCase();
    final mime = <String, String>{
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
      'png': 'image/png', 'gif': 'image/gif', 'webp': 'image/webp',
    }[ext] ?? 'image/jpeg';
    request.files.add(http.MultipartFile.fromBytes(
      'image', bytes,
      filename: filename,
      contentType: MediaType.parse(mime),
    ));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401) {
      await setToken(null);
      onUnauthorized?.call();
      throw const ApiException(statusCode: 401, message: 'Unauthorized');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        statusCode: response.statusCode,
        message: body['error'] as String? ?? 'Upload failed',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['filename'] as String;
  }

  Future<String> getImageUrl(String filename) async {
    return '${await baseUrl}/uploads/$filename';
  }

  Future<Map<String, String>> getAuthHeaders() async {
    return _headers();
  }

  // ========== Contacts ==========

  Future<Map<String, dynamic>> getContacts() async {
    return get('/contacts');
  }

  Future<Map<String, dynamic>> addContact(String usernameOrId) async {
    // Send as username so the backend can look up by display name
    return post('/contacts', body: {'username': usernameOrId});
  }

  Future<Map<String, dynamic>> removeContact(String contactId) async {
    return delete('/contacts/$contactId');
  }

  Future<Map<String, dynamic>> toggleBlock(
      String contactId, bool blocked) async {
    return put('/contacts/$contactId/block', body: {'blocked': blocked});
  }

  Future<Map<String, dynamic>> blockByKey(String pgpKeyFragment) async {
    return post('/contacts/block-key', body: {
      'pgpKeyFragment': pgpKeyFragment,
    });
  }

  // ========== Sessions ==========

  Future<Map<String, dynamic>> getSessions() async {
    return get('/sessions');
  }

  Future<Map<String, dynamic>> terminateSession(String sessionId) async {
    return delete('/sessions/$sessionId');
  }

  Future<Map<String, dynamic>> terminateAllSessions() async {
    return delete('/sessions');
  }

  // ========== Settings ==========

  Future<Map<String, dynamic>> getSettings() async {
    return get('/settings');
  }

  Future<Map<String, dynamic>> updateSettings(
      Map<String, dynamic> settings) async {
    return put('/settings', body: settings);
  }

  Future<Map<String, dynamic>> autoDeleteNow({int? hours}) async {
    return post('/settings/auto-delete-now',
        body: hours != null ? {'hours': hours} : null);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
