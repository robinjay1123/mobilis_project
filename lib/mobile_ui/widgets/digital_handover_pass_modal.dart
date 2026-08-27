import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/handover_verification_service.dart';

class DigitalHandoverPassModal extends StatefulWidget {
  final Map<String, dynamic> booking;

  const DigitalHandoverPassModal({
    super.key,
    required this.booking,
  });

  static Future<void> show(BuildContext context, Map<String, dynamic> booking) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DigitalHandoverPassModal(booking: booking),
    );
  }

  @override
  State<DigitalHandoverPassModal> createState() =>
      _DigitalHandoverPassModalState();
}

class _DigitalHandoverPassModalState extends State<DigitalHandoverPassModal> {
  final HandoverVerificationService _verificationService =
      HandoverVerificationService();

  late String _bookingId;
  late String _renterId;
  late String _vehicleId;
  late String _vehicleName;
  late String _handoverPin;
  late String _qrPayload;

  bool _isCopied = false;
  Map<String, dynamic>? _verificationStatus;
  bool _isLoadingStatus = true;

  @override
  void initState() {
    super.initState();
    _initData();
    _checkStatus();
  }

  void _initData() {
    _bookingId = widget.booking['id']?.toString() ?? '';
    _renterId = widget.booking['user_id']?.toString() ??
        widget.booking['renter_id']?.toString() ??
        '';

    final vehicle = widget.booking['vehicles'] as Map<String, dynamic>?;
    _vehicleId = widget.booking['vehicle_id']?.toString() ??
        vehicle?['id']?.toString() ??
        '';
    _vehicleName = vehicle != null
        ? '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}'.trim()
        : widget.booking['vehicle_name']?.toString() ?? 'Reserved Vehicle';

    _handoverPin = _verificationService.generateHandoverPin(_bookingId, _renterId);
    _qrPayload = _verificationService.generateQrPayload(
      bookingId: _bookingId,
      renterId: _renterId,
      vehicleId: _vehicleId,
      vehicleName: _vehicleName,
    );
  }

  Future<void> _checkStatus() async {
    final status = await _verificationService.getHandoverStatus(_bookingId);
    if (mounted) {
      setState(() {
        _verificationStatus = status;
        _isLoadingStatus = false;
      });
    }
  }

  void _copyPin() {
    Clipboard.setData(ClipboardData(text: _handoverPin));
    setState(() => _isCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Handover PIN copied to clipboard'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF1E293B),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = _verificationStatus?['handover_verified_at'] != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 18),

          // Header Badge & Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isVerified
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVerified ? Icons.verified_user : Icons.qr_code_2_rounded,
                  color: isVerified
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF2563EB),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAlignment.start,
                children: [
                  const Text(
                    'Digital Handover Pass',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    _vehicleName,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Status Alert Banner if Verified
          if (isVerified)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Handover verified by ${_verificationStatus?['handover_verifier_role']?.toString().toUpperCase() ?? 'Staff'}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // High Contrast QR Code Display Container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                // QR Graphic Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: CustomPaint(
                    size: const Size(180, 180),
                    painter: SimpleQrPainter(data: _qrPayload),
                  ),
                ),
                const SizedBox(height: 16),

                // PIN Code Display Block
                const Text(
                  'SHOW OR SHARE THIS 6-DIGIT PIN',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),

                GestureDetector(
                  onTap: _copyPin,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _handoverPin.split('').join('  '),
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          _isCopied ? Icons.check : Icons.copy_rounded,
                          color: const Color(0xFF94A3B8),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Instructions Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFF64748B), size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Present this QR Code or 6-digit PIN to the Driver or Operator at vehicle pickup & return to verify your handover.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Close Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Close Pass',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom QR Matrix Painter to render deterministic high-contrast QR pattern
class SimpleQrPainter extends CustomPainter {
  final String data;

  SimpleQrPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final bytes = utf8.encode(data);
    const matrixSize = 21; // Standard V1 QR matrix density
    final cellSize = size.width / matrixSize;

    // Draw positioning corner boxes (Top-Left, Top-Right, Bottom-Left)
    _drawPositionFinder(canvas, paint, 0, 0, cellSize);
    _drawPositionFinder(canvas, paint, (matrixSize - 7) * cellSize, 0, cellSize);
    _drawPositionFinder(canvas, paint, 0, (matrixSize - 7) * cellSize, cellSize);

    // Draw matrix data dots based on payload hash
    for (int r = 0; r < matrixSize; r++) {
      for (int c = 0; c < matrixSize; c++) {
        // Skip corner finder zones
        if ((r < 7 && c < 7) ||
            (r < 7 && c >= matrixSize - 7) ||
            (r >= matrixSize - 7 && c < 7)) {
          continue;
        }

        final index = (r * matrixSize + c) % bytes.length;
        final byteVal = bytes[index];
        final isFilled = (byteVal ^ (r + c * 3)) % 2 == 0;

        if (isFilled) {
          final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(
              c * cellSize + 0.5,
              r * cellSize + 0.5,
              cellSize - 1,
              cellSize - 1,
            ),
            const Radius.circular(1.5),
          );
          canvas.drawRRect(rect, paint);
        }
      }
    }
  }

  void _drawPositionFinder(
      Canvas canvas, Paint paint, double x, double y, double cellSize) {
    // Outer border 7x7
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, cellSize * 7, cellSize * 7),
      const Radius.circular(6),
    );
    canvas.drawRRect(outerRect, paint);

    // Inner white cutout 5x5
    final whitePaint = Paint()..color = Colors.white;
    final innerWhiteRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          x + cellSize, y + cellSize, cellSize * 5, cellSize * 5),
      const Radius.circular(4),
    );
    canvas.drawRRect(innerWhiteRect, whitePaint);

    // Center solid block 3x3
    final centerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          x + cellSize * 2, y + cellSize * 2, cellSize * 3, cellSize * 3),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(centerRect, paint);
  }

  @override
  bool shouldRepaint(covariant SimpleQrPainter oldDelegate) =>
      oldDelegate.data != data;
}
