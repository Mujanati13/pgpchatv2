import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:openpgp/openpgp.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class PgpService extends ChangeNotifier {
  static const String _privateKeyBase = 'pgp_private_key';
  static const String _publicKeyBase = 'pgp_public_key';
  static const String _keyNameBase = 'pgp_key_name';
  static const String _keyEmailBase = 'pgp_key_email';
  static const String _keyAlgorithmBase = 'pgp_key_algorithm';
  static const String _keyBitsBase = 'pgp_key_bits';

  static final PgpService _instance = PgpService._internal();
  factory PgpService() => _instance;
  PgpService._internal();

  String? _privateKey;
  String? _publicKey;
  String? _activeScopeKey;

  bool _isPresent(String? value) => value != null && value.trim().isNotEmpty;

  String _scopedPref(String base, String scopeKey) => '${base}::$scopeKey';

  String? _normalizedUserId(String? value) {
    final id = value?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  String? _normalizedUsername(String? value) {
    final username = value?.trim().toLowerCase();
    if (username == null || username.isEmpty) return null;
    return username;
  }

  Future<List<String>> _resolveScopeKeys(
    SharedPreferences prefs, {
    String? userId,
    String? username,
  }) async {
    final scopes = <String>[];

    final resolvedUsername = _normalizedUsername(username) ??
        _normalizedUsername(prefs.getString('username'));
    if (resolvedUsername != null) {
      scopes.add('usr:$resolvedUsername');
    }

    final resolvedUserId =
        _normalizedUserId(userId) ?? _normalizedUserId(prefs.getString('user_id'));
    if (resolvedUserId != null) {
      final userIdScope = 'uid:$resolvedUserId';
      if (!scopes.contains(userIdScope)) scopes.add(userIdScope);
    }

    return scopes;
  }

  String? _primaryScopeKey(List<String> scopeKeys) {
    if (scopeKeys.isEmpty) return null;
    return scopeKeys.first;
  }

  void _syncScopeCacheFromScopes(List<String> scopeKeys) {
    _syncScopeCache(_primaryScopeKey(scopeKeys));
  }

  Future<bool> _hasAnyScopedKeyPair(
    SharedPreferences prefs,
    List<String> scopeKeys,
  ) async {
    for (final scope in scopeKeys) {
      if (await _hasScopedKeyPair(prefs, scope)) return true;
    }
    return false;
  }

  Future<String?> _firstPublicKeyForScopes(
    SharedPreferences prefs,
    List<String> scopeKeys,
  ) async {
    for (final scope in scopeKeys) {
      final pub = await _publicKeyForScope(prefs, scope);
      if (_isPresent(pub)) return pub;
    }

    return null;
  }

  Future<String?> _firstPrivateKeyForScopes(
    SharedPreferences prefs,
    List<String> scopeKeys,
  ) async {
    for (final scope in scopeKeys) {
      final priv = await _privateKeyForScope(prefs, scope);
      if (_isPresent(priv)) return priv;
    }

    return null;
  }

  void _syncScopeCache(String? scopeKey) {
    if (_activeScopeKey == scopeKey) return;
    _activeScopeKey = scopeKey;
    _privateKey = null;
    _publicKey = null;
  }

  bool _armoredKeysEqual(String a, String b) {
    final left = a.replaceAll(RegExp(r'\s+'), '');
    final right = b.replaceAll(RegExp(r'\s+'), '');
    return left == right;
  }

  Future<bool> _hasScopedKeyPair(
    SharedPreferences prefs,
    String? scopeKey,
  ) async {
    if (scopeKey == null) return false;
    final priv = prefs.getString(_scopedPref(_privateKeyBase, scopeKey));
    final pub = prefs.getString(_scopedPref(_publicKeyBase, scopeKey));
    return _isPresent(priv) && _isPresent(pub);
  }

  Future<String?> _publicKeyForScope(
    SharedPreferences prefs,
    String? scopeKey,
  ) async {
    if (scopeKey == null) return null;
    return prefs.getString(_scopedPref(_publicKeyBase, scopeKey));
  }

  Future<String?> _privateKeyForScope(
    SharedPreferences prefs,
    String? scopeKey,
  ) async {
    if (scopeKey == null) return null;
    return prefs.getString(_scopedPref(_privateKeyBase, scopeKey));
  }

  Future<void> _storeScopedMetadata({
    required SharedPreferences prefs,
    required String scopeKey,
    required String name,
    required String email,
    required int keyLength,
  }) async {
    await prefs.setString(_scopedPref(_keyNameBase, scopeKey), name);
    await prefs.setString(_scopedPref(_keyEmailBase, scopeKey), email);
    await prefs.setInt(_scopedPref(_keyBitsBase, scopeKey), keyLength);
  }

  Future<bool> get hasKeyPair async {
    final prefs = await SharedPreferences.getInstance();
    final scopeKeys = await _resolveScopeKeys(prefs);
    _syncScopeCacheFromScopes(scopeKeys);
    return _hasAnyScopedKeyPair(prefs, scopeKeys);
  }

  Future<bool> get hasPublicKey async {
    final prefs = await SharedPreferences.getInstance();
    final scopeKeys = await _resolveScopeKeys(prefs);
    _syncScopeCacheFromScopes(scopeKeys);
    final pub = await _firstPublicKeyForScopes(prefs, scopeKeys);
    return _isPresent(pub);
  }

  Future<bool> hasKeyPairForAccount({
    String? userId,
    String? username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final scopeKeys =
        await _resolveScopeKeys(prefs, userId: userId, username: username);
    return _hasAnyScopedKeyPair(prefs, scopeKeys);
  }

  Future<String?> get publicKey async {
    final prefs = await SharedPreferences.getInstance();
    final scopeKeys = await _resolveScopeKeys(prefs);
    _syncScopeCacheFromScopes(scopeKeys);
    if (_publicKey != null) return _publicKey;
    _publicKey = await _firstPublicKeyForScopes(prefs, scopeKeys);
    return _publicKey;
  }

  Future<String?> get privateKey async {
    final prefs = await SharedPreferences.getInstance();
    final scopeKeys = await _resolveScopeKeys(prefs);
    _syncScopeCacheFromScopes(scopeKeys);
    if (_privateKey != null) return _privateKey;
    _privateKey = await _firstPrivateKeyForScopes(prefs, scopeKeys);
    return _privateKey;
  }

  Future<String?> publicKeyForAccount({
    String? userId,
    String? username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final scopeKeys =
        await _resolveScopeKeys(prefs, userId: userId, username: username);
    return _firstPublicKeyForScopes(prefs, scopeKeys);
  }

  Future<String?> privateKeyForAccount({
    String? userId,
    String? username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final scopeKeys =
        await _resolveScopeKeys(prefs, userId: userId, username: username);
    return _firstPrivateKeyForScopes(prefs, scopeKeys);
  }

  Future<bool> maybeAdoptLegacyKeysForCurrentAccount({
    String? expectedPublicKey,
  }) async {
    if (!_isPresent(expectedPublicKey)) return false;

    final prefs = await SharedPreferences.getInstance();
    final scopeKeys = await _resolveScopeKeys(prefs);
    final scopeKey = _primaryScopeKey(scopeKeys);
    _syncScopeCache(scopeKey);
    if (scopeKey == null) return false;

    final alreadyScoped = await _hasAnyScopedKeyPair(prefs, scopeKeys);
    if (alreadyScoped) return false;

    final legacyPublic = prefs.getString(_publicKeyBase);
    final legacyPrivate = prefs.getString(_privateKeyBase);
    if (!_isPresent(legacyPublic) || !_isPresent(legacyPrivate)) return false;

    if (!_armoredKeysEqual(legacyPublic!, expectedPublicKey!)) return false;

    for (final scoped in scopeKeys) {
      await prefs.setString(_scopedPref(_publicKeyBase, scoped), legacyPublic);
      await prefs.setString(_scopedPref(_privateKeyBase, scoped), legacyPrivate!);
    }

    final legacyName = prefs.getString(_keyNameBase);
    final legacyEmail = prefs.getString(_keyEmailBase);
    final legacyAlgo = prefs.getString(_keyAlgorithmBase);
    final legacyBits = prefs.getInt(_keyBitsBase);
    for (final scoped in scopeKeys) {
      if (legacyName != null) {
        await prefs.setString(_scopedPref(_keyNameBase, scoped), legacyName);
      }
      if (legacyEmail != null) {
        await prefs.setString(_scopedPref(_keyEmailBase, scoped), legacyEmail);
      }
      if (legacyAlgo != null) {
        await prefs.setString(_scopedPref(_keyAlgorithmBase, scoped), legacyAlgo);
      }
      if (legacyBits != null) {
        await prefs.setInt(_scopedPref(_keyBitsBase, scoped), legacyBits);
      }
    }

    _privateKey = legacyPrivate;
    _publicKey = legacyPublic;
    notifyListeners();
    return true;
  }

  // Generate a new PGP key pair
  Future<KeyPair> generateKeyPair({
    required String name,
    required String email,
    required String passphrase,
    int keyLength = 4096,
  }) async {
    final options = Options()
      ..name = name
      ..email = email
      ..passphrase = passphrase
      ..keyOptions = (KeyOptions()..rsaBits = keyLength);

    final keyPair = await OpenPGP.generate(options: options);

    // Store keys locally
    final prefs = await SharedPreferences.getInstance();
    final scopeKeys = await _resolveScopeKeys(prefs);
    final scopeKey = _primaryScopeKey(scopeKeys);
    _syncScopeCache(scopeKey);
    if (scopeKey == null) {
      throw Exception('No authenticated account context for key generation');
    }

    for (final scoped in scopeKeys) {
      await prefs.setString(_scopedPref(_privateKeyBase, scoped), keyPair.privateKey);
      await prefs.setString(_scopedPref(_publicKeyBase, scoped), keyPair.publicKey);
      await _storeScopedMetadata(
        prefs: prefs,
        scopeKey: scoped,
        name: name,
        email: email,
        keyLength: keyLength,
      );
    }

    _privateKey = keyPair.privateKey;
    _publicKey = keyPair.publicKey;

    notifyListeners();
    return keyPair;
  }

  // Import existing key pair
  Future<void> importKeys({
    required String publicKey,
    required String privateKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final scopeKeys = await _resolveScopeKeys(prefs);
    final scopeKey = _primaryScopeKey(scopeKeys);
    _syncScopeCache(scopeKey);
    if (scopeKey == null) {
      throw Exception(
        'No authenticated account context. Please log in again before importing keys.',
      );
    }

    final normalizedPublic = publicKey.trim();
    final normalizedPrivate = privateKey.trim();

    // Validate key format before saving
    if (normalizedPublic.isNotEmpty &&
        !normalizedPublic.contains('BEGIN PGP PUBLIC KEY')) {
      throw FormatException(
        'The file does not contain a valid PGP public key block.',
      );
    }
    if (normalizedPrivate.isNotEmpty &&
        !normalizedPrivate.contains('BEGIN PGP PRIVATE KEY')) {
      throw FormatException(
        'The file does not contain a valid PGP private key block.',
      );
    }

    if (normalizedPublic.isEmpty) {
      for (final scoped in scopeKeys) {
        await prefs.remove(_scopedPref(_publicKeyBase, scoped));
      }
      _publicKey = null;
    } else {
      for (final scoped in scopeKeys) {
        await prefs.setString(_scopedPref(_publicKeyBase, scoped), normalizedPublic);
      }
      _publicKey = normalizedPublic;
    }

    if (normalizedPrivate.isEmpty) {
      for (final scoped in scopeKeys) {
        await prefs.remove(_scopedPref(_privateKeyBase, scoped));
      }
      _privateKey = null;
    } else {
      for (final scoped in scopeKeys) {
        await prefs.setString(_scopedPref(_privateKeyBase, scoped), normalizedPrivate);
      }
      _privateKey = normalizedPrivate;
    }

    notifyListeners();
  }

  // Encrypt a message with the recipient's public key
  Future<String> encrypt(String message, String recipientPublicKey) async {
    return OpenPGP.encrypt(message, recipientPublicKey);
  }

  // Decrypt a message with our private key
  Future<String> decrypt(String encryptedMessage, String passphrase) async {
    final privKey = await privateKey;
    if (privKey == null) throw Exception('No private key available');
    return OpenPGP.decrypt(encryptedMessage, privKey, passphrase);
  }

  Future<String> decryptForAccount(
    String encryptedMessage,
    String passphrase, {
    String? userId,
    String? username,
  }) async {
    final privKey = await privateKeyForAccount(userId: userId, username: username);
    if (privKey == null || privKey.trim().isEmpty) {
      throw Exception('No private key available');
    }
    return OpenPGP.decrypt(encryptedMessage, privKey, passphrase);
  }

  // Sign a message
  Future<String> sign(String message, String passphrase) async {
    final privKey = await privateKey;
    if (privKey == null) throw Exception('No private key available');
    return OpenPGP.sign(message, privKey, passphrase);
  }

  // Verify a signed message
  Future<bool> verify(
      String signature, String message, String signerPublicKey) async {
    try {
      final result = await OpenPGP.verify(signature, message, signerPublicKey);
      return result;
    } catch (_) {
      return false;
    }
  }

  // Export public key to file
  Future<File> exportPublicKey() async {
    final pubKey = await publicKey;
    if (pubKey == null) throw Exception('No public key available');
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/pgp_public_key.asc');
    return file.writeAsString(pubKey);
  }

  // Export private key to file (for backup)
  Future<File> exportPrivateKey() async {
    final privKey = await privateKey;
    if (privKey == null) throw Exception('No private key available');
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/pgp_private_key.asc');
    return file.writeAsString(privKey);
  }

  // Get key metadata
  Future<Map<String, String?>> getKeyMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    final scopeKeys = await _resolveScopeKeys(prefs);
    final scopeKey = _primaryScopeKey(scopeKeys);
    if (scopeKey == null) {
      return {
        'name': null,
        'email': null,
        'algorithm': null,
        'bits': null,
      };
    }
    return {
      'name': prefs.getString(_scopedPref(_keyNameBase, scopeKey)),
      'email': prefs.getString(_scopedPref(_keyEmailBase, scopeKey)),
      'algorithm': prefs.getString(_scopedPref(_keyAlgorithmBase, scopeKey)),
      'bits': prefs.getInt(_scopedPref(_keyBitsBase, scopeKey))?.toString(),
    };
  }

  // Wipe all local PGP keys (PGP Reset)
  Future<void> wipeKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final scopeKeys = await _resolveScopeKeys(prefs);
    final scopeKey = _primaryScopeKey(scopeKeys);
    _syncScopeCache(scopeKey);
    if (scopeKey == null) {
      _privateKey = null;
      _publicKey = null;
      notifyListeners();
      return;
    }

    for (final scoped in scopeKeys) {
      await prefs.remove(_scopedPref(_privateKeyBase, scoped));
      await prefs.remove(_scopedPref(_publicKeyBase, scoped));
      await prefs.remove(_scopedPref(_keyNameBase, scoped));
      await prefs.remove(_scopedPref(_keyEmailBase, scoped));
      await prefs.remove(_scopedPref(_keyAlgorithmBase, scoped));
      await prefs.remove(_scopedPref(_keyBitsBase, scoped));
    }
    _privateKey = null;
    _publicKey = null;
    notifyListeners();
  }

  // Get fingerprint of a public key (first 40 hex chars of hash)
  String getFingerprint(String publicKeyArmored) {
    try {
      // Split on both \n and \r\n to handle all platforms
      final lines = publicKeyArmored.split(RegExp(r'\r?\n'));
      String keyBody = '';
      bool inBody = false;
      for (final line in lines) {
        if (line.startsWith('-----BEGIN')) {
          inBody = true;
          continue;
        }
        if (line.startsWith('-----END')) break;
        if (inBody && line.trim().isNotEmpty && !line.contains(':')) {
          keyBody += line.trim();
        }
      }
      if (keyBody.length >= 40) {
        return keyBody.substring(keyBody.length - 40).toUpperCase();
      }
      if (keyBody.isNotEmpty) return keyBody.toUpperCase();
    } catch (_) {}
    // Fallback: strip armor headers and whitespace, use last 40 chars
    final raw = publicKeyArmored
        .replaceAll(RegExp(r'-----[^\n]+-----'), '')
        .replaceAll(RegExp(r'[\s]'), '');
    if (raw.length >= 40) return raw.substring(raw.length - 40).toUpperCase();
    return raw.toUpperCase();
  }
}
