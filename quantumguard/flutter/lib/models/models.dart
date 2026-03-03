// lib/models/approval_request.dart
class ApprovalRequest {
  final int did;
  final String farmerAddress;
  final String? ipfsHash;
  final String status;

  ApprovalRequest({
    required this.did,
    required this.farmerAddress,
    this.ipfsHash,
    required this.status,
  });

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    return ApprovalRequest(
      did: json['did'] as int,
      farmerAddress: json['farmerAddress'] as String,
      ipfsHash: json['ipfsHash'] as String?,
      status: json['status'] as String? ?? 'pending',
    );
  }
}

// lib/models/identity_model.dart
class IdentityModel {
  final String? id;
  final String walletAddress;
  final int? did;
  final String status;
  final String? ipfsHash;
  final int approvalCount;
  final bool biometricVerified;

  IdentityModel({
    this.id,
    required this.walletAddress,
    this.did,
    required this.status,
    this.ipfsHash,
    this.approvalCount = 0,
    this.biometricVerified = false,
  });

  factory IdentityModel.fromJson(Map<String, dynamic> json) {
    return IdentityModel(
      id: json['id'] as String?,
      walletAddress: json['walletAddress'] as String,
      did: json['did'] as int?,
      status: json['status'] as String,
      ipfsHash: json['ipfsHash'] as String?,
      approvalCount: json['approvalCount'] as int? ?? 0,
      biometricVerified: json['biometricVerified'] as bool? ?? false,
    );
  }

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending' || status == 'under_review';
}


// lib/services/identity_service.dart
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../models/identity_model.dart';

class IdentityService extends ChangeNotifier {
  IdentityModel? _identity;
  bool _isLoading = false;

  IdentityModel? get identity => _identity;
  bool get isLoading => _isLoading;

  Future<void> loadIdentity() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.instance.getMyIdentity();
      _identity = IdentityModel.fromJson(data);
    } catch (e) {
      print('[IdentityService] Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> registerIdentity(
    Map<String, dynamic> profileData,
    List<String> validators,
    String biometricHash,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiService.instance.registerIdentity({
        'encryptedProfile': profileData.toString(),
        'nominatedValidators': validators,
        'biometricHash': biometricHash,
        'recoveryAddresses': [],
      });
      await loadIdentity();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
