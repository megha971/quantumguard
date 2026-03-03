// lib/services/offline_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';

/// Offline-first service: encrypts all local data with AES-256
/// and syncs to backend when connectivity is restored.
class OfflineService extends ChangeNotifier {
  static final OfflineService instance = OfflineService._();
  OfflineService._();

  static const _keyBoxName = 'qg_keys';
  static const _identityBoxName = 'qg_identity';
  static const _syncQueueBoxName = 'qg_sync_queue';
  static const _aesKeyName = 'aes_encryption_key';

  late Box _identityBox;
  late Box _syncQueue;
  final _secureStorage = const FlutterSecureStorage();
  
  enc.Encrypter? _encrypter;
  enc.IV? _iv;
  bool _isOnline = true;

  Future<void> init() async {
    await Hive.initFlutter();
    _identityBox = await Hive.openBox(_identityBoxName);
    _syncQueue   = await Hive.openBox(_syncQueueBoxName);
    
    await _initEncryption();
    _monitorConnectivity();
  }

  // ─── AES-256 Encryption ──────────────────────────────────────────────

  Future<void> _initEncryption() async {
    String? storedKey = await _secureStorage.read(key: _aesKeyName);
    
    if (storedKey == null) {
      // Generate new 256-bit key
      final key = enc.Key.fromSecureRandom(32);
      storedKey = base64.encode(key.bytes);
      await _secureStorage.write(key: _aesKeyName, value: storedKey);
    }

    final keyBytes = base64.decode(storedKey);
    final key = enc.Key(Uint8List.fromList(keyBytes));
    _iv = enc.IV.fromSecureRandom(16);
    _encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
  }

  String _encrypt(String plaintext) {
    if (_encrypter == null) throw StateError('Encrypter not initialized');
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(plaintext, iv: iv);
    // Prepend IV to ciphertext
    return '${base64.encode(iv.bytes)}:${encrypted.base64}';
  }

  String _decrypt(String ciphertext) {
    if (_encrypter == null) throw StateError('Encrypter not initialized');
    final parts = ciphertext.split(':');
    if (parts.length != 2) throw FormatException('Invalid ciphertext format');
    final iv = enc.IV(base64.decode(parts[0]));
    final encrypted = enc.Encrypted.fromBase64(parts[1]);
    return _encrypter!.decrypt(encrypted, iv: iv);
  }

  // ─── Identity Storage ────────────────────────────────────────────────

  Future<void> saveIdentity(Map<String, dynamic> identityData) async {
    final plaintext = jsonEncode(identityData);
    final encrypted = _encrypt(plaintext);
    await _identityBox.put('current_identity', encrypted);
    notifyListeners();
  }

  Map<String, dynamic>? loadIdentity() {
    final encrypted = _identityBox.get('current_identity');
    if (encrypted == null) return null;
    try {
      final plaintext = _decrypt(encrypted as String);
      return jsonDecode(plaintext) as Map<String, dynamic>;
    } catch (e) {
      print('[OfflineService] Decryption error: $e');
      return null;
    }
  }

  Future<void> saveBiometricToken(String token) async {
    await _secureStorage.write(key: 'biometric_token', value: token);
  }

  Future<String?> loadBiometricToken() async {
    return _secureStorage.read(key: 'biometric_token');
  }

  Future<void> saveJWT(String token) async {
    await _secureStorage.write(key: 'jwt_token', value: token);
  }

  Future<String?> loadJWT() async {
    return _secureStorage.read(key: 'jwt_token');
  }

  Future<void> clearAll() async {
    await _identityBox.clear();
    await _syncQueue.clear();
    await _secureStorage.deleteAll();
  }

  // ─── Sync Queue ──────────────────────────────────────────────────────

  Future<void> queueAction(String type, Map<String, dynamic> payload) async {
    final item = {
      'type': type,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
      'attempts': 0,
    };
    await _syncQueue.add(jsonEncode(item));
    
    if (_isOnline) {
      await _processSyncQueue();
    }
  }

  Future<void> _processSyncQueue() async {
    final keys = _syncQueue.keys.toList();
    for (final key in keys) {
      final raw = _syncQueue.get(key);
      if (raw == null) continue;
      
      try {
        final item = jsonDecode(raw as String) as Map<String, dynamic>;
        await ApiService.instance.syncAction(item['type'] as String, item['payload'] as Map);
        await _syncQueue.delete(key);
      } catch (e) {
        print('[OfflineService] Sync error: $e');
      }
    }
    notifyListeners();
  }

  int get pendingSyncCount => _syncQueue.length;

  // ─── Connectivity ────────────────────────────────────────────────────

  void _monitorConnectivity() {
    Connectivity().onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
      if (_isOnline && _syncQueue.isNotEmpty) {
        _processSyncQueue();
      }
      notifyListeners();
    });
  }

  bool get isOnline => _isOnline;
}
