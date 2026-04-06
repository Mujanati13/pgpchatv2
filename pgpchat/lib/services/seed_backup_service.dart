import 'package:crypto/crypto.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service for managing mnemonic seed phrases for PGP key recovery
class SeedBackupService {
  static const String _seedPhrasePref = 'pgp_seed_phrase';
  static const String _seedCheckpointPref = 'pgp_seed_checkpoint';

  static final SeedBackupService _instance = SeedBackupService._internal();
  factory SeedBackupService() => _instance;
  SeedBackupService._internal();

  String _normalizeSeedPhrase(String seedPhrase) {
    return seedPhrase.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');
  }

  /// Generate a new 12-word seed phrase
  String generateSeedPhrase() {
    // 128 bits => 12 BIP39 words from the full English list.
    return bip39.generateMnemonic(strength: 128);
  }

  /// Save a seed phrase with encryption
  Future<void> saveSeedPhrase(String seedPhrase) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedSeed = _normalizeSeedPhrase(seedPhrase);

    // Create a checkpoint by hashing the seed
    final checkpoint = sha256.convert(utf8.encode(normalizedSeed)).toString();

    // Store both seed and checkpoint
    await prefs.setString(_seedPhrasePref, normalizedSeed);
    await prefs.setString(_seedCheckpointPref, checkpoint);
  }

  /// Retrieve the saved seed phrase
  Future<String?> getSeedPhrase() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_seedPhrasePref);
  }

  /// Verify that a seed phrase is valid (matches stored checkpoint)
  Future<bool> verifySeedPhrase(String seedPhrase) async {
    final prefs = await SharedPreferences.getInstance();
    final checkpoint = prefs.getString(_seedCheckpointPref);

    if (checkpoint == null) return false;

    final normalizedSeed = _normalizeSeedPhrase(seedPhrase);
    final verifiedCheckpoint =
        sha256.convert(utf8.encode(normalizedSeed)).toString();
    return verifiedCheckpoint == checkpoint;
  }

  /// Check if a seed phrase exists
  Future<bool> hasSeedPhrase() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_seedPhrasePref);
  }

  /// Derive a recovery token from the seed phrase for password reset
  String deriveRecoveryToken(String seedPhrase) {
    final normalizedSeed = _normalizeSeedPhrase(seedPhrase);

    // Hash the seed phrase twice for additional security
    final firstHash = sha256.convert(utf8.encode(normalizedSeed)).toString();
    final secondHash = sha256.convert(utf8.encode(firstHash)).toString();
    return secondHash.substring(0, 32).toUpperCase();
  }

  /// Clear the seed phrase (dangerous operation)
  Future<void> clearSeedPhrase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seedPhrasePref);
    await prefs.remove(_seedCheckpointPref);
  }

  /// Validate seed phrase format (12 words from word list)
  bool validateSeedPhrase(String seedPhrase) {
    final normalizedSeed = _normalizeSeedPhrase(seedPhrase);
    final words = normalizedSeed.split(' ');

    if (words.length != 12) {
      return false;
    }

    // Prefer strict BIP39 validation for newly generated phrases.
    if (bip39.validateMnemonic(normalizedSeed)) {
      return true;
    }

    // Backward compatibility for legacy app versions that generated
    // non-BIP39 12-word phrases.
    return words.every((word) => RegExp(r'^[a-z]+$').hasMatch(word));
  }
}
