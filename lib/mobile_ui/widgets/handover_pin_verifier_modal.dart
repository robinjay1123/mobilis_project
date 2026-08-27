import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/handover_verification_service.dart';

class HandoverPinVerifierModal extends StatefulWidget {
  final String bookingId;
  final String verifierId;
  final String verifierRole; // 'driver', 'operator', 'partner'
  final String? vehicleName;
  final String? renterName;
  final String mode; // 'release' or 'return'

  const HandoverPinVerifierModal({
    super.key,
    required this.bookingId,
    required this.verifierId,
    required this.verifierRole,
    this.vehicleName,
    this.renterName,
    this.mode = 'release',
  });

  static Future<bool?> show(
    BuildContext context, {
    required String bookingId,
    required String verifierId,
    required String verifierRole,
    String? vehicleName,
    String? renterName,
    String mode = 'release',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => HandoverPinVerifierModal(
        bookingId: bookingId,
        verifierId: verifierId,
        verifierRole: verifierRole,
        vehicleName: vehicleName,
        renterName: renterName,
        mode: mode,
      ),
    );
  }

  @override
  State<HandoverPinVerifierModal> createState() =>
      _HandoverPinVerifierModalState();
}

class _HandoverPinVerifierModalState extends State<HandoverPinVerifierModal> {
  final HandoverVerificationService _verificationService =
      HandoverVerificationService();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _qrPayloadController = TextEditingController();

  int _selectedTab = 0; // 0: PIN, 1: Scan/Paste QR Code
  late String _activeMode; // 'release' or 'return'

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _activeMode = widget.mode;
  }

  Future<void> _submitVerification() async {
    String pinToVerify = _pinController.text.trim();
    String targetBookingId = widget.bookingId;

    if (_selectedTab == 1) {
      final rawQr = _qrPayloadController.text.trim();
      if (rawQr.isEmpty) {
        setState(() => _errorMessage = 'Please enter or paste QR Code payload');
        return;
      }
      final parsed = _verificationService.parseQrPayload(rawQr);
      if (parsed != null) {
        if (parsed['pin'] != null) {
          pinToVerify = parsed['pin']!;
        }
        if (parsed['booking_id'] != null && parsed['booking_id']!.isNotEmpty) {
          targetBookingId = parsed['booking_id']!;
        }
      } else {
        setState(() => _errorMessage = 'Invalid QR Code payload format');
        return;
      }
    }

    if (pinToVerify.length != 6) {
      setState(() => _errorMessage = 'Please enter a valid 6-digit PIN code');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final bool isSuccess;
      if (_activeMode == 'return') {
        isSuccess = await _verificationService.verifyReturnPass(
          bookingId: targetBookingId,
          enteredPin: pinToVerify,
          verifierId: widget.verifierId,
          verifierRole: widget.verifierRole,
        );
      } else {
        isSuccess = await _verificationService.verifyHandoverPass(
          bookingId: targetBookingId,
          enteredPin: pinToVerify,
          verifierId: widget.verifierId,
          verifierRole: widget.verifierRole,
        );
      }

      if (mounted) {
        if (isSuccess) {
          Navigator.pop(context, true);
          final label = _activeMode == 'return' ? 'Return' : 'Handover';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  Text('$label pass verified successfully!'),
                ],
              ),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          setState(() {
            _isSubmitting = false;
            _errorMessage =
                'Invalid PIN code or QR pass. Please check renter pass and try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _qrPayloadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRelease = _activeMode == 'release';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isRelease
                          ? const Color(0xFFEFF6FF)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isRelease
                          ? Icons.verified_user_rounded
                          : Icons.assignment_turned_in_rounded,
                      color: isRelease
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFD97706),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRelease
                              ? 'Verify Handover (Release)'
                              : 'Verify Vehicle Return',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Role: ${widget.verifierRole.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Mode Switcher (Release vs Return)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _activeMode = 'release';
                            _errorMessage = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isRelease
                                ? const Color(0xFF2563EB)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '🚗 Releasing Vehicle',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isRelease
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _activeMode = 'return';
                            _errorMessage = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !isRelease
                                ? const Color(0xFFD97706)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '🏁 Returning Vehicle',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: !isRelease
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (widget.vehicleName != null || widget.renterName != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      if (widget.vehicleName != null)
                        Row(
                          children: [
                            const Icon(Icons.directions_car,
                                size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.vehicleName!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (widget.renterName != null) ...[
                        if (widget.vehicleName != null)
                          const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.person,
                                size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Renter: ${widget.renterName}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Verification Method Selector Tabs (6-Digit PIN vs Scan/Paste QR)
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pin, size: 16),
                          SizedBox(width: 6),
                          Text('6-Digit PIN'),
                        ],
                      ),
                      selected: _selectedTab == 0,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedTab = 0;
                            _errorMessage = null;
                          });
                        }
                      },
                      selectedColor: const Color(0xFFEFF6FF),
                      labelStyle: TextStyle(
                        color: _selectedTab == 0
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner, size: 16),
                          SizedBox(width: 6),
                          Text('Scan / Paste QR'),
                        ],
                      ),
                      selected: _selectedTab == 1,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedTab = 1;
                            _errorMessage = null;
                          });
                        }
                      },
                      selectedColor: const Color(0xFFEFF6FF),
                      labelStyle: TextStyle(
                        color: _selectedTab == 1
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_selectedTab == 0) ...[
                const Text(
                  'Enter Renter 6-Digit Security PIN',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade300,
                      letterSpacing: 8,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Color(0xFF2563EB), width: 2),
                    ),
                  ),
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                ),
              ] else ...[
                const Text(
                  'Scan or Paste QR Code Payload',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _qrPayloadController,
                  maxLines: 3,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Paste QR Code JSON string here (e.g. {"app":"MOBILIS_PSDC", "pin":"..."})',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Color(0xFF2563EB), width: 2),
                    ),
                  ),
                  onChanged: (text) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                    // Auto-parse if valid QR JSON pasted
                    final parsed = _verificationService.parseQrPayload(text);
                    if (parsed != null && parsed['pin'] != null) {
                      _pinController.text = parsed['pin']!;
                    }
                  },
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRelease
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFD97706),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          isRelease
                              ? 'Verify & Confirm Release'
                              : 'Verify & Confirm Return',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
