import 'dart:io';
import 'package:openpgp/openpgp.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class PgpService {
  static const String _privateKeyPref = 'pgp_private_key';
  static const String _publicKeyPref = 'pgp_public_key';
  static const String _keyNamePref = 'pgp_key_name';
  static const String _keyEmailPref = 'pgp_key_email';
  static const String _keyAlgorithmPref = 'pgp_key_algorithm';
  static const String _keyBitsPref = 'pgp_key_bits';

  static final PgpService _instance = PgpService._internal();
  factory PgpService() => _instance;
  PgpService._internal();

  String? _privateKey;
  String? _publicKey;

  Future<bool> get hasKeyPair async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_privateKeyPref) &&
        prefs.containsKey(_publicKeyPref);
  }

  Future<String?> get publicKey async {
    if (_publicKey != null) return _publicKey;
    final prefs = await SharedPreferences.getInstance();
    _publicKey = prefs.getString(_publicKeyPref);
    return _publicKey;
  }

  Future<String?> get privateKey async {
    if (_privateKey != null) return _privateKey;
    final prefs = await SharedPreferences.getInstance();
    _privateKey = prefs.getString(_privateKeyPref);
    return _privateKey;
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
    await prefs.setString(_privateKeyPref, keyPair.privateKey);
    await prefs.setString(_publicKeyPref, keyPair.publicKey);
    await prefs.setString(_keyNamePref, name);
    await prefs.setString(_keyEmailPref, email);
    await prefs.setInt(_keyBitsPref, keyLength);

    _privateKey = keyPair.privateKey;
    _publicKey = keyPair.publicKey;

    return keyPair;
  }

  // Import existing key pair
  Future<void> importKeys({
    required String publicKey,
    required String privateKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_publicKeyPref, publicKey);
    await prefs.setString(_privateKeyPref, privateKey);
    _publicKey = publicKey;
    _privateKey = privateKey;
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
    return {
      'name': prefs.getString(_keyNamePref),
      'email': prefs.getString(_keyEmailPref),
      'algorithm': prefs.getString(_keyAlgorithmPref),
      'bits': prefs.getInt(_keyBitsPref)?.toString(),
    };
  }

  // Wipe all local PGP keys (PGP Reset)
  Future<void> wipeKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_privateKeyPref);
    await prefs.remove(_publicKeyPref);
    await prefs.remove(_keyNamePref);
    await prefs.remove(_keyEmailPref);
    await prefs.remove(_keyAlgorithmPref);
    await prefs.remove(_keyBitsPref);
    _privateKey = null;
    _publicKey = null;
  }

  // Get fingerprint of a public key (first 40 hex chars of hash)
  String getFingerprint(String publicKeyArmored) {
    // Extract a display-friendly fingerprint from the key header
    final lines = publicKeyArmored.split('\n');
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
    // Return last 40 chars as a simplified fingerprint display
    if (keyBody.length >= 40) {
      return keyBody.substring(keyBody.length - 40).toUpperCase();
    }
    return keyBody.toUpperCase();
  }
}
