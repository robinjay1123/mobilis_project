import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _imagePicker = ImagePicker();

  int _selectedTab = 0; // 0: PIN, 1: Scan QR / Camera
  late String _activeMode; // 'release' or 'return'

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _activeMode = widget.mode;
  }

  Future<void> _openCameraToScan() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo == null) return;

      // Note: On platforms without native QR decoder, prompt to use the 6-digit PIN
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'QR image captured. Enter the 6-digit PIN shown on the renter pass to verify.',
            ),
            backgroundColor: Color(0xFF2563EB),
            duration: Duration(seconds: 3),
          ),
        );
        setState(() {
          _selectedTab = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Camera unavailable or permission denied. Please enter the 6-digit PIN.',
            ),
            backgroundColor: const Color(0xFFD97706),
          ),
        );
        setState(() {
          _selectedTab = 0;
        });
      }
    }
  }

  Future<void> _submitVerification() async {
    final pinToVerify = _pinController.text.trim();
    final targetBookingId = widget.bookingId;

    if (pinToVerify.length != 6) {
      setState(() => _errorMessage = 'Please enter a valid 6-digit security PIN code');
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

              // Verification Method Selector Tabs (6-Digit PIN vs Camera Scan)
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
                          Icon(Icons.camera_alt_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Camera / QR'),
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFBFDBFE),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 38,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Access Camera to Scan QR',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Point your device camera at the renter\'s digital handover pass QR code, or use the 6-digit PIN below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _openCameraToScan,
                              icon: const Icon(Icons.camera_alt, size: 16),
                              label: const Text('Open Camera'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() => _selectedTab = 0);
                            },
                            icon: const Icon(Icons.pin, size: 16),
                            label: const Text('Use PIN'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(
                                color: Color(0xFFBFDBFE),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_pinController.text.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'PIN Loaded: ${_pinController.text}',
                                style: const TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
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
