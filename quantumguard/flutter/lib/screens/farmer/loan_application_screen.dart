// lib/screens/farmer/qr_identity_screen.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

class QRIdentityScreen extends StatelessWidget {
  final int did;
  final String verificationToken;
  final String walletAddress;

  const QRIdentityScreen({
    super.key,
    required this.did,
    required this.verificationToken,
    required this.walletAddress,
  });

  @override
  Widget build(BuildContext context) {
    final qrData = jsonEncode({
      'did': did,
      'token': verificationToken,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: const Text('My Digital Identity', style: TextStyle(color: Colors.white)),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // DID Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3A5C),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade700),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Text('DID #$did', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // QR Code
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)],
                ),
                child: QrImageView(data: qrData, version: QrVersions.auto, size: 220),
              ),
              const SizedBox(height: 24),

              const Text('Show this QR code to banks and institutions',
                  style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Valid for 1 hour', style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 32),

              // Wallet address
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2E45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text('Wallet Address', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(walletAddress, style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ─── Loan Application Screen ───────────────────────────────────────────────

// lib/screens/farmer/loan_application_screen.dart
class LoanApplicationScreen extends StatefulWidget {
  const LoanApplicationScreen({super.key});
  @override
  State<LoanApplicationScreen> createState() => _LoanApplicationScreenState();
}

class _LoanApplicationScreenState extends State<LoanApplicationScreen> {
  final _amountCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  String _selectedTerm = '12';
  String _selectedInstitution = 'SBI Grameen Bank';
  bool _isLoading = false;

  final _institutions = ['SBI Grameen Bank', 'NABARD', 'IFFCO Kisan', 'Cooperative Bank'];
  final _terms = ['6', '12', '18', '24', '36'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: const Text('Apply for Microloan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Credit score card
            _buildCreditScoreCard(score: 680),
            const SizedBox(height: 24),

            const Text('Loan Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Amount
            _buildTextField(_amountCtrl, 'Loan Amount (₹)', Icons.currency_rupee,
                keyboardType: TextInputType.number),
            const SizedBox(height: 16),

            // Purpose
            _buildTextField(_purposeCtrl, 'Purpose (e.g. seeds, fertilizer)', Icons.agriculture),
            const SizedBox(height: 16),

            // Term
            _buildDropdown('Repayment Term (months)', _terms, _selectedTerm, (v) => setState(() => _selectedTerm = v!)),
            const SizedBox(height: 16),

            // Institution
            _buildDropdown('Financial Institution', _institutions, _selectedInstitution,
                (v) => setState(() => _selectedInstitution = v!)),
            const SizedBox(height: 32),

            // Eligibility note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade800),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.green, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('Your DID will be verified on Polygon blockchain during loan processing.',
                    style: TextStyle(color: Colors.green, fontSize: 12))),
              ]),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitApplication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Application', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditScoreCard({required int score}) {
    final color = score >= 650 ? Colors.green : score >= 550 ? Colors.orange : Colors.red;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF1A2E45), Color.lerp(const Color(0xFF1A2E45), color, 0.2)!]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60, height: 60,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(value: score / 850, color: color, strokeWidth: 6, backgroundColor: Colors.white12),
              Text(score.toString(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Credit Score', style: TextStyle(color: Colors.white54, fontSize: 12)),
            Text(score >= 650 ? 'Good' : score >= 550 ? 'Fair' : 'Poor',
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Max eligible: ₹${(score * 200).toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
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
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A2E45),
          hint: Text(label, style: const TextStyle(color: Colors.white54)),
          style: const TextStyle(color: Colors.white),
          onChanged: onChanged,
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        ),
      ),
    );
  }

  Future<void> _submitApplication() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2)); // Simulate API call
    setState(() => _isLoading = false);
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A2E45),
          title: const Text('Application Submitted!', style: TextStyle(color: Colors.white)),
          content: const Text('Your loan application is under review. The bank will verify your DID on Polygon.',
              style: TextStyle(color: Colors.white70)),
          actions: [ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
  }
}
