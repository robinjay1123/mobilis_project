import 'package:flutter/material.dart';
import '../../services/database_health_service.dart';
import '../theme/app_colors.dart';

/// Modal dialog displayed when the backend database is in an unhealthy state
/// or undergoing maintenance.
class DatabaseUnhealthyModal extends StatefulWidget {
  final String? customMessage;

  const DatabaseUnhealthyModal({
    super.key,
    this.customMessage,
  });

  /// Displays the database unhealthy modal safely without stacking duplicates.
  static Future<void> show(BuildContext context, {String? message}) async {
    if (DatabaseHealthService().isModalVisible) return;
    DatabaseHealthService().setModalVisible(true);

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.75),
        builder: (dialogContext) => DatabaseUnhealthyModal(
          customMessage: message,
        ),
      );
    } finally {
      DatabaseHealthService().setModalVisible(false);
    }
  }

  @override
  State<DatabaseUnhealthyModal> createState() => _DatabaseUnhealthyModalState();
}

class _DatabaseUnhealthyModalState extends State<DatabaseUnhealthyModal>
    with SingleTickerProviderStateMixin {
  bool _isChecking = false;
  String? _statusFeedback;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleCheckHealth() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
      _statusFeedback = null;
    });

    final isRecovered = await DatabaseHealthService().checkHealth();

    if (!mounted) return;

    if (isRecovered) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('Database is back online! You can now proceed.'),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      setState(() {
        _isChecking = false;
        _statusFeedback =
            'Database is still in an unhealthy state. Please wait 1–2 minutes before trying again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 500;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          DatabaseHealthService().setModalVisible(false);
        }
      },
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(isCompact ? 22 : 28),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      blurRadius: 36,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glowing Icon with subtle pulse
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.18),
                          border: Border.all(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.dns_rounded,
                          color: Color(0xFFF59E0B),
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Status Badge Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'DATABASE HEALTH: UNHEALTHY',
                            style: TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    const Text(
                      'Database Temporarily Unavailable',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Main Explanation
                    Text(
                      widget.customMessage ??
                          'The database is currently experiencing an unhealthy state or maintenance. Your data is protected, but actions cannot be completed right now.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF94A3B8),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action Box ("Make actions again in a few minutes")
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF334155),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.access_time_filled_rounded,
                              color: Color(0xFFF59E0B),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Action Recommendation',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Please make your actions again in a few minutes.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_statusFeedback != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          _statusFeedback!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // Action Buttons
                    Row(
                      children: [
                        // Dismiss button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context, rootNavigator: true).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF94A3B8),
                              side: const BorderSide(
                                color: Color(0xFF334155),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Dismiss',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Check status button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isChecking ? null : _handleCheckHealth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: const Color(0xFF0F172A),
                              disabledBackgroundColor: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.4),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isChecking
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        Color(0xFF0F172A),
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Check Status',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
