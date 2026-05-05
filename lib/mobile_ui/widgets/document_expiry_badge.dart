import 'package:flutter/material.dart';
import '../../../services/notification_service.dart';

class DocumentExpiryBadge extends StatefulWidget {
  final String userId;
  final VoidCallback? onTap;
  final int daysThreshold;

  const DocumentExpiryBadge({
    Key? key,
    required this.userId,
    this.onTap,
    this.daysThreshold = 30,
  }) : super(key: key);

  @override
  State<DocumentExpiryBadge> createState() => _DocumentExpiryBadgeState();
}

class _DocumentExpiryBadgeState extends State<DocumentExpiryBadge> {
  final notificationService = NotificationService();
  int _badgeCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBadgeCount();
    // Refresh every 5 minutes
    Future.delayed(const Duration(minutes: 5), _loadBadgeCount);
  }

  Future<void> _loadBadgeCount() async {
    try {
      final count = await notificationService.getExpiringDocumentsBadgeCount(
        userId: widget.userId,
        daysThreshold: widget.daysThreshold,
      );

      if (mounted) {
        setState(() {
          _badgeCount = count;
        });
      }
    } catch (e) {
      // Error loading badge count, just display 0
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_badgeCount == 0) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_none, size: 24),
            if (_badgeCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    _badgeCount > 99 ? '99+' : '$_badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
