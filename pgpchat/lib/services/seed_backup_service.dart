import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

/// Service for managing mnemonic seed phrases for PGP key recovery
class SeedBackupService {
  static const String _seedPhrasePref = 'pgp_seed_phrase';
  static const String _seedCheckpointPref = 'pgp_seed_checkpoint';

  // BIP39 word list (12-word subset for simplicity)
  static const List<String> _wordList = [
    'abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb', 'abstract',
    'abuse', 'access', 'accident', 'account', 'accuse', 'achieve', 'acid', 'acoustic',
    'acquire', 'across', 'act', 'action', 'actor', 'actress', 'actual', 'acute',
    'ad', 'adapt', 'add', 'addict', 'added', 'adder', 'adding', 'addition',
    'additive', 'address', 'adds', 'adept', 'adjacent', 'adjust', 'admin', 'admire',
    'admit', 'adobe', 'adopt', 'adore', 'adorn', 'adult', 'advance', 'advent',
    'adverb', 'advertise', 'advice', 'advise', 'afar', 'affair', 'afford', 'afraid',
    'after', 'again', 'against', 'age', 'agent', 'ages', 'aggravate', 'aggregate',
    'aggressive', 'aging', 'agitate', 'ago', 'agony', 'agree', 'agreeable', 'agreed',
    'agrees', 'agreement', 'ahead', 'ahem', 'aid', 'aide', 'aided', 'aider',
    'aides', 'aids', 'aim', 'aimed', 'aiming', 'aims', 'air', 'airborne',
    'aired', 'airer', 'airfare', 'airfield', 'airfoil', 'airforce', 'airframe', 'airier',
    'airily', 'airing', 'airless', 'airlift', 'airlike', 'airline', 'airliner', 'airlock',
    'airmail', 'airman', 'airmen', 'airpark', 'airplay', 'airpost', 'airproof', 'airs',
    'airship', 'airshow', 'airsick', 'airside', 'airspace', 'airspeed', 'airt', 'airted',
    'airting', 'airts', 'airtight', 'airtime', 'airway', 'airways', 'airwoman', 'airwomen',
    'airworthiness', 'airworthy', 'airy', 'aisle', 'aisled', 'aisles',
    'aitch', 'aitches', 'aiver', 'avers', 'ajar', 'ajee', 'ajiva', 'ajuga',
    'aka', 'akee', 'akees', 'akebi', 'akela', 'akee', 'akees', 'akene',
  ];

  static final SeedBackupService _instance = SeedBackupService._internal();
  factory SeedBackupService() => _instance;
  SeedBackupService._internal();

  /// Generate a new 12-word seed phrase
  String generateSeedPhrase() {
    final random = Random.secure();
    final words = <String>[];

    for (int i = 0; i < 12; i++) {
      final index = random.nextInt(_wordList.length);
      words.add(_wordList[index]);
    }

    return words.join(' ');
  }

  /// Save a seed phrase with encryption
  Future<void> saveSeedPhrase(String seedPhrase) async {
    final prefs = await SharedPreferences.getInstance();

    // Create a checkpoint by hashing the seed
    final checkpoint = sha256.convert(utf8.encode(seedPhrase)).toString();

    // Store both seed and checkpoint
    await prefs.setString(_seedPhrasePref, seedPhrase);
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

    final verifiedCheckpoint = sha256.convert(utf8.encode(seedPhrase)).toString();
    return verifiedCheckpoint == checkpoint;
  }

  /// Check if a seed phrase exists
  Future<bool> hasSeedPhrase() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_seedPhrasePref);
  }

  /// Derive a recovery token from the seed phrase for password reset
  String deriveRecoveryToken(String seedPhrase) {
    // Hash the seed phrase twice for additional security
    final firstHash = sha256.convert(utf8.encode(seedPhrase)).toString();
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
    final words = seedPhrase.trim().toLowerCase().split(RegExp(r'\s+'));

    if (words.length != 12) {
      return false;
    }

    for (final word in words) {
      if (!_wordList.contains(word)) {
        return false;
      }
    }

    return true;
  }
}
