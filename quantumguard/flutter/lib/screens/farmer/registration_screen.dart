// lib/screens/farmer/registration_screen.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../../services/biometric_service.dart';
import '../../services/identity_service.dart';
import '../../services/offline_service.dart';
import '../../widgets/step_indicator.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  final _biometricService = BiometricService();

  // Form fields
  final _nameController = TextEditingController();
  final _villageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _validator1Controller = TextEditingController();
  final _validator2Controller = TextEditingController();
  final _validator3Controller = TextEditingController();

  String? _capturedSelfieHash;
  bool _fingerprintDone = false;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _steps = [
    'Personal Info',
    'Biometrics',
    'Validators',
    'Review & Submit',
  ];

  @override
  void initState() {
    super.initState();
    _biometricService.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: const Text('Create Digital Identity',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Step indicator
          Padding(
            padding: const EdgeInsets.all(16),
            child: StepIndicator(steps: _steps, currentStep: _currentStep),
          ),
          
          // Offline banner
          Consumer<OfflineService>(
            builder: (_, offline, __) => offline.isOnline
                ? const SizedBox.shrink()
                : Container(
                    color: Colors.orange.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                    child: const Row(children: [
                      Icon(Icons.wifi_off, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('Offline mode — data saved locally', style: TextStyle(color: Colors.white)),
                    ]),
                  ),
          ),

          // Step content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildStepContent(),
            ),
          ),

          // Error message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
            ),

          // Navigation buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _currentStep--),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white54),
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            _currentStep == _steps.length - 1 ? 'Submit Identity' : 'Continue',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalInfoStep();
      case 1:
        return _buildBiometricsStep();
      case 2:
        return _buildValidatorsStep();
      case 3:
        return _buildReviewStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildPersonalInfoStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tell us about yourself',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('This information will be encrypted and stored securely.',
              style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 28),
          _buildTextField(_nameController, 'Full Name', Icons.person),
          const SizedBox(height: 16),
          _buildTextField(_villageController, 'Village / District', Icons.location_on),
          const SizedBox(height: 16),
          _buildTextField(_phoneController, 'Phone Number', Icons.phone,
              keyboardType: TextInputType.phone),
        ],
      ),
    );
  }

  Widget _buildBiometricsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Capture Biometrics',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Biometric data never leaves your device. Only a secure hash is stored.',
            style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 28),

        // Selfie capture
        _buildBiometricCard(
          icon: Icons.face,
          title: 'Selfie Photo',
          subtitle: _capturedSelfieHash != null ? 'Captured successfully' : 'Tap to take a selfie',
          isDone: _capturedSelfieHash != null,
          onTap: _captureSelfie,
        ),
        const SizedBox(height: 16),

        // Fingerprint
        _buildBiometricCard(
          icon: Icons.fingerprint,
          title: 'Fingerprint',
          subtitle: _fingerprintDone ? 'Verified successfully' : 'Tap to scan fingerprint',
          isDone: _fingerprintDone,
          onTap: _captureFingerprint,
        ),
      ],
    );
  }

  Widget _buildValidatorsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nominate 3 Validators',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Validators are trusted community members who will verify your identity.',
            style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 28),
        _buildTextField(_validator1Controller, 'Validator 1 Wallet Address', Icons.verified_user),
        const SizedBox(height: 16),
        _buildTextField(_validator2Controller, 'Validator 2 Wallet Address', Icons.verified_user),
        const SizedBox(height: 16),
        _buildTextField(_validator3Controller, 'Validator 3 Wallet Address', Icons.verified_user),
      ],
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Review Your Identity',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildReviewCard('Personal Info', [
            {'Name': _nameController.text},
            {'Village': _villageController.text},
            {'Phone': _phoneController.text},
          ]),
          const SizedBox(height: 16),
          _buildReviewCard('Biometrics', [
            {'Face': _capturedSelfieHash != null ? 'Captured' : 'Missing'},
            {'Fingerprint': _fingerprintDone ? 'Verified' : 'Missing'},
          ]),
          const SizedBox(height: 16),
          _buildReviewCard('Validators', [
            {'Validator 1': '${_validator1Controller.text.substring(0, 8)}...'},
            {'Validator 2': '${_validator2Controller.text.substring(0, 8)}...'},
            {'Validator 3': '${_validator3Controller.text.substring(0, 8)}...'},
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A5C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade700),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your data will be AES-256 encrypted and only the IPFS hash stored on blockchain.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helper Widgets ─────────────────────────────────────────────────────

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF1A2E45),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4CAF50)),
        ),
      ),
      validator: (v) => v?.isEmpty == true ? 'Required' : null,
    );
  }

  Widget _buildBiometricCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDone,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFF1A3A1A) : const Color(0xFF1A2E45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDone ? Colors.green : Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, color: isDone ? Colors.green : Colors.white54, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(color: isDone ? Colors.green : Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Icon(isDone ? Icons.check_circle : Icons.arrow_forward_ios,
                color: isDone ? Colors.green : Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(String title, List<Map<String, String>> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white12, height: 16),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.keys.first, style: const TextStyle(color: Colors.white54)),
                Text(item.values.first, style: const TextStyle(color: Colors.white)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _captureSelfie() async {
    // Navigate to camera screen and get selfie hash
    final result = await Navigator.pushNamed(context, '/camera');
    if (result != null) {
      final hash = await _biometricService.processFaceImage(result as String);
      setState(() => _capturedSelfieHash = hash);
    }
  }

  Future<void> _captureFingerprint() async {
    final authenticated = await _biometricService.authenticateWithDevice(
      reason: 'Scan fingerprint to register biometrics',
    );
    setState(() => _fingerprintDone = authenticated);
  }

  Future<void> _handleNext() async {
    setState(() => _errorMessage = null);

    if (_currentStep < _steps.length - 1) {
      if (_currentStep == 0 && !(_formKey.currentState?.validate() ?? false)) return;
      if (_currentStep == 1) {
        if (_capturedSelfieHash == null || !_fingerprintDone) {
          setState(() => _errorMessage = 'Please complete all biometric captures');
          return;
        }
      }
      setState(() => _currentStep++);
    } else {
      await _submitIdentity();
    }
  }

  Future<void> _submitIdentity() async {
    setState(() => _isLoading = true);

    try {
      final identityService = context.read<IdentityService>();
      final offlineService = context.read<OfflineService>();

      final profileData = {
        'name': _nameController.text,
        'village': _villageController.text,
        'phone': _phoneController.text,
        'biometricHash': _capturedSelfieHash,
        'createdAt': DateTime.now().toIso8601String(),
      };

      final validators = [
        _validator1Controller.text,
        _validator2Controller.text,
        _validator3Controller.text,
      ];

      if (offlineService.isOnline) {
        await identityService.registerIdentity(profileData, validators, _capturedSelfieHash!);
      } else {
        // Queue for later sync
        await offlineService.queueAction('register', {
          'profile': profileData,
          'validators': validators,
          'biometricHash': _capturedSelfieHash,
        });
        await offlineService.saveIdentity(profileData);
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/farmer/dashboard');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _villageController.dispose();
    _phoneController.dispose();
    _validator1Controller.dispose();
    _validator2Controller.dispose();
    _validator3Controller.dispose();
    super.dispose();
  }
}
