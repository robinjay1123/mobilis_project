import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/notification_service.dart';
import '../../../services/admin_service.dart';

class DocumentExpiryNotificationsScreen extends StatefulWidget {
  const DocumentExpiryNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<DocumentExpiryNotificationsScreen> createState() =>
      _DocumentExpiryNotificationsScreenState();
}

class _DocumentExpiryNotificationsScreenState
    extends State<DocumentExpiryNotificationsScreen> {
  final supabase = Supabase.instance.client;
  final notificationService = NotificationService();
  final adminService = AdminService();

  List<Map<String, dynamic>> _expiringDocuments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExpiringDocuments();
  }

  Future<void> _loadExpiringDocuments() async {
    try {
      setState(() => _isLoading = true);

      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Get notifications related to document expiry
      final notifications = await notificationService.getNotifications(user.id);
      final expiryNotifications = notifications
          .where((n) => n['type'] == 'document_expiry')
          .toList();

      setState(() {
        _expiringDocuments = expiryNotifications;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading documents: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      _loadExpiringDocuments();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error marking as read: $e')));
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await supabase.from('notifications').delete().eq('id', notificationId);

      _loadExpiringDocuments();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notification deleted')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
    }
  }

  String _getDocumentColor(int daysUntilExpiry) {
    if (daysUntilExpiry < 0) return 'red'; // Expired
    if (daysUntilExpiry <= 7) return 'darkred'; // Critical
    if (daysUntilExpiry <= 14) return 'orange'; // Warning
    return 'green'; // OK
  }

  IconData _getDocumentIcon(String documentType) {
    switch (documentType.toLowerCase()) {
      case 'license':
      case 'driver_license':
        return Icons.card_membership;
      case 'nbi':
        return Icons.verified_user;
      case 'insurance':
        return Icons.shield;
      case 'registration':
      case 'vehicle_registration':
        return Icons.directions_car;
      case 'verification':
        return Icons.badge;
      default:
        return Icons.document_scanner;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Expiry Notifications'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadExpiringDocuments,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _expiringDocuments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No expiring documents',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'All your documents are up to date',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadExpiringDocuments,
              child: ListView.builder(
                itemCount: _expiringDocuments.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final notification = _expiringDocuments[index];
                  final data = notification['data'] as Map<String, dynamic>?;
                  final documentType =
                      data?['document_type'] as String? ?? 'Document';
                  final daysUntilExpiry =
                      data?['days_until_expiry'] as int? ?? 0;
                  final isRead = notification['is_read'] as bool;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            _getDocumentColor(daysUntilExpiry) == 'red'
                            ? Colors.red
                            : _getDocumentColor(daysUntilExpiry) == 'darkred'
                            ? Colors.deepOrange
                            : _getDocumentColor(daysUntilExpiry) == 'orange'
                            ? Colors.orange
                            : Colors.green,
                        child: Icon(
                          _getDocumentIcon(documentType),
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        notification['title'] as String? ?? 'Document Expiring',
                        style: TextStyle(
                          fontWeight: isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            notification['body'] as String? ??
                                'Document expiry notification',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Document Type: $documentType',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (daysUntilExpiry < 0)
                            Text(
                              'EXPIRED ${daysUntilExpiry.abs()} days ago',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else if (daysUntilExpiry == 0)
                            const Text(
                              'Expires TODAY',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            Text(
                              'Expires in $daysUntilExpiry days',
                              style: TextStyle(
                                fontSize: 12,
                                color: daysUntilExpiry <= 7
                                    ? Colors.red
                                    : daysUntilExpiry <= 14
                                    ? Colors.orange
                                    : Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          if (!isRead)
                            PopupMenuItem(
                              onTap: () => _markAsRead(notification['id']),
                              child: const Row(
                                children: [
                                  Icon(Icons.done, size: 20),
                                  SizedBox(width: 8),
                                  Text('Mark as Read'),
                                ],
                              ),
                            ),
                          PopupMenuItem(
                            onTap: () =>
                                _deleteNotification(notification['id']),
                            child: const Row(
                              children: [
                                Icon(Icons.delete, size: 20),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
