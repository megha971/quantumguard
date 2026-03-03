// lib/services/api_service.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'offline_service.dart';
import '../models/approval_request.dart';

class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  static const baseUrl = 'https://your-backend.railway.app'; // Update before deploy
  
  late final Dio _dio;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await OfflineService.instance.loadJWT();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) {
        print('[API] Error: ${error.message}');
        handler.next(error);
      },
    ));
  }

  Future<Map<String, dynamic>> getNonce(String address) async {
    final res = await _dio.get('/api/auth/nonce/$address');
    return res.data;
  }

  Future<Map<String, dynamic>> verifySignature(String address, String signature, String nonce) async {
    final res = await _dio.post('/api/auth/verify', data: {
      'address': address, 'signature': signature, 'nonce': nonce
    });
    return res.data;
  }

  Future<Map<String, dynamic>> registerIdentity(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/identity/register', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> getMyIdentity() async {
    final res = await _dio.get('/api/identity/me');
    return res.data;
  }

  Future<List<ApprovalRequest>> getValidatorQueue() async {
    final res = await _dio.get('/api/validator/queue');
    final list = res.data['queue'] as List;
    return list.map((e) => ApprovalRequest.fromJson(e)).toList();
  }

  Future<void> approveIdentity(int did, {String? notes}) async {
    await _dio.post('/api/validator/approve', data: {'did': did, 'notes': notes});
  }

  Future<void> rejectIdentity(int did, {String? reason}) async {
    await _dio.post('/api/validator/reject', data: {'did': did, 'reason': reason});
  }

  Future<Map<String, dynamic>> getCreditScore(int did) async {
    final res = await _dio.get('/api/credit/score/$did');
    return res.data;
  }

  Future<Map<String, dynamic>> applyForLoan(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/credit/loans', data: data);
    return res.data;
  }

  Future<void> syncAction(String type, Map payload) async {
    await _dio.post('/api/identity/sync', data: {
      'actions': [{'type': type, 'payload': payload}],
      'deviceId': 'device_id_here',
    });
  }
}
