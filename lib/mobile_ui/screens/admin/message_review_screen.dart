import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/message_filter_service.dart';
import '../../../services/notification_service.dart';
import '../../theme/app_colors.dart';

class AdminMessageReviewScreen extends StatefulWidget {
  final bool isDarkMode;

  const AdminMessageReviewScreen({super.key, this.isDarkMode = true});

  @override
  State<AdminMessageReviewScreen> createState() =>
      _AdminMessageReviewScreenState();
}

class _AdminMessageReviewScreenState extends State<AdminMessageReviewScreen> {
  int _selectedTab =
      0; // 0: Pending, 1: Confirmed, 2: Dismissed, 3: Filter Words, 4: Violated Users
  List<Map<String, dynamic>> _flags = [];
  List<String> _filterWords = [];
  List<Map<String, dynamic>> _violatingUsers = [];
  final TextEditingController _filterWordController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _filterWordsLoaded = false;
  bool _flagsLoaded = false;
  bool _violatingUsersLoaded = false;
  String? _flagsError;
  final Set<String> _busyFlagIds = {};
  final Set<String> _busyUnbanUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadFlags();
    _loadFilterWords();
    _loadViolatingUsers();
  }

  @override
  void dispose() {
    _filterWordController.dispose();
    super.dispose();
  }

  Future<void> _loadFlags() async {
    if (mounted) {
      setState(() {
        _flagsLoaded = false;
        _flagsError = null;
      });
    }
    try {
      final flags = await MessageFilterService.getFlags();
      if (!mounted) return;
      setState(() {
        _flags = flags;
        _flagsLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading message flags: $e');
      if (!mounted) return;
      setState(() {
        _flagsError = e.toString();
        _flagsLoaded = true;
      });
    }
  }

  Future<void> _loadViolatingUsers() async {
    try {
      final users = await MessageFilterService.getViolatingUsers();
      if (mounted) {
        setState(() {
          _violatingUsers = users;
          _violatingUsersLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading violating users: $e');
      if (mounted) {
        setState(() => _violatingUsersLoaded = true);
      }
    }
  }

  List<Map<String, dynamic>> _flagsWithStatus(String status) =>
      _flags.where((flag) => flag['status']?.toString() == status).toList();

  int _countForTab(int index) {
    if (index == 0) return _flagsWithStatus('pending_review').length;
    if (index == 1) return _flagsWithStatus('confirmed').length;
    if (index == 2) return _flagsWithStatus('dismissed').length;
    if (index == 3) return _filterWords.length;
    return _violatingUsers.length;
  }

  Future<void> _loadFilterWords() async {
    try {
      final response = await _supabase
          .from('filter_words')
          .select('word')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _filterWords = (response as List)
              .map((item) => item['word'] as String)
              .toList();
          _filterWordsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading filter words: $e');
      if (mounted) {
        setState(() => _filterWordsLoaded = true);
      }
    }
  }

  Future<void> _addFilterWord(String word) async {
    try {
      await _supabase.from('filter_words').insert({
        'word': word.toLowerCase(),
        'created_by': _supabase.auth.currentUser?.id,
      });

      if (mounted) {
        setState(() {
          _filterWords.add(word.toLowerCase());
          _filterWordController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Filter word added'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeFilterWord(String word) async {
    try {
      await _supabase.from('filter_words').delete().eq('word', word);

      if (mounted) {
        setState(() {
          _filterWords.remove(word);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Filter word removed'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final textColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Message Review Hub',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh review queue',
            onPressed: _flagsLoaded ? _loadFlags : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Tab navigation
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? AppColors.borderColor
                      : AppColors.lightBorderColor,
                ),
              ),
            ),
            child: Row(
              children: [
                _buildTab('Pending', 0, isDark, textColor),
                _buildTab('Confirmed', 1, isDark, textColor),
                _buildTab('Dismissed', 2, isDark, textColor),
                _buildTab('Filter Words', 3, isDark, textColor),
                _buildTab('Violators', 4, isDark, textColor),
              ],
            ),
          ),

          // Flags list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _loadFlags(),
                  _loadFilterWords(),
                  _loadViolatingUsers(),
                ]);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_selectedTab == 0)
                    _buildPendingFlags(isDark, cardColor, textColor),
                  if (_selectedTab == 1)
                    _buildConfirmedFlags(isDark, cardColor, textColor),
                  if (_selectedTab == 2)
                    _buildDismissedFlags(isDark, cardColor, textColor),
                  if (_selectedTab == 3)
                    _buildFilterWordsTab(isDark, cardColor, textColor),
                  if (_selectedTab == 4)
                    _buildViolatedUsersTab(isDark, cardColor, textColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, bool isDark, Color textColor) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppColors.primary : Colors.transparent,
                width: isActive ? 3 : 0,
              ),
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? AppColors.primary : textColor,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary.withValues(alpha: 0.18)
                        : textColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_countForTab(index)}',
                    style: TextStyle(
                      color: isActive ? AppColors.primary : textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingFlags(bool isDark, Color cardColor, Color textColor) {
    final pendingFlags = _flagsWithStatus('pending_review');
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.warning),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.warning, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Review flagged messages and decide action',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildFlagsBody(
          pendingFlags,
          isDark: isDark,
          cardColor: cardColor,
          textColor: textColor,
          emptyMessage: 'No pending warnings to review',
          showActions: true,
        ),
      ],
    );
  }

  Widget _buildConfirmedFlags(bool isDark, Color cardColor, Color textColor) {
    return _buildFlagsBody(
      _flagsWithStatus('confirmed'),
      isDark: isDark,
      cardColor: cardColor,
      textColor: textColor,
      emptyMessage: 'No confirmed warnings yet',
    );
  }

  Widget _buildDismissedFlags(bool isDark, Color cardColor, Color textColor) {
    return _buildFlagsBody(
      _flagsWithStatus('dismissed'),
      isDark: isDark,
      cardColor: cardColor,
      textColor: textColor,
      emptyMessage: 'No dismissed warnings yet',
    );
  }

  Widget _buildFlagsBody(
    List<Map<String, dynamic>> flags, {
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required String emptyMessage,
    bool showActions = false,
  }) {
    if (!_flagsLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_flagsError != null) {
      return _buildLoadError(textColor);
    }

    if (flags.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.mark_chat_read_outlined,
                size: 42,
                color: textColor.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                style: TextStyle(color: textColor, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: flags
          .map(
            (flag) => _buildFlagFromData(
              flag,
              isDark: isDark,
              cardColor: cardColor,
              textColor: textColor,
              showActions: showActions,
            ),
          )
          .toList(),
    );
  }

  Widget _buildLoadError(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 38),
            const SizedBox(height: 10),
            Text(
              'Could not load the review queue',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loadFlags,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlagFromData(
    Map<String, dynamic> flag, {
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required bool showActions,
  }) {
    final senderValue = flag['sender'];
    final sender = senderValue is Map
        ? Map<String, dynamic>.from(senderValue)
        : <String, dynamic>{};
    final content = flag['message_content']?.toString().trim() ?? '';
    final analysis = MessageFilterService.analyzeMessage(content);
    final reason = flag['flag_reason']?.toString().trim() ?? '';
    final keywords = List<String>.from(
      analysis['found_keywords'] as List? ?? const <String>[],
    );
    if (keywords.isEmpty && reason.contains(':')) {
      keywords.addAll(
        reason
            .split(':')
            .last
            .split(',')
            .map((word) => word.trim())
            .where((word) => word.isNotEmpty),
      );
    }

    final createdAt = DateTime.tryParse(
      flag['created_at']?.toString() ?? '',
    )?.toLocal();
    final name = sender['full_name']?.toString().trim().isNotEmpty == true
        ? sender['full_name'].toString().trim()
        : sender['name']?.toString().trim().isNotEmpty == true
        ? sender['name'].toString().trim()
        : sender['email']?.toString().trim().isNotEmpty == true
        ? sender['email'].toString().trim()
        : 'Unknown user';
    final riskLevel =
        flag['risk_level']?.toString().trim().toLowerCase().isNotEmpty == true
        ? flag['risk_level'].toString().trim().toLowerCase()
        : analysis['risk_level']?.toString() ?? 'low';
    final status = flag['status']?.toString() ?? 'pending_review';

    return _buildFlagCard(
      isDark,
      cardColor,
      textColor,
      flagId: flag['id']?.toString() ?? '',
      userName: name,
      userId:
          sender['email']?.toString() ?? flag['sender_id']?.toString() ?? '',
      userMeta:
          '${sender['role']?.toString().toUpperCase() ?? 'USER'}  •  ${sender['off_platform_flag_count'] ?? 0} warning(s)${sender['is_blocked'] == true ? '  •  BLOCKED' : ''}',
      messageContent: content.isEmpty ? 'Message content unavailable' : content,
      flagReason: reason,
      riskLevel: riskLevel,
      keywords: keywords,
      timestamp: createdAt == null
          ? 'Date unavailable'
          : DateFormat('MMM d, yyyy • h:mm a').format(createdAt),
      status: status,
      adminNotes: flag['admin_notes']?.toString(),
      isBusy: _busyFlagIds.contains(flag['id']?.toString()),
      showActions: showActions,
      onApprove: () => _requestReview(flag, 'approve'),
      onDismiss: () => _requestReview(flag, 'dismiss'),
    );
  }

  Future<void> _requestReview(Map<String, dynamic> flag, String action) async {
    final isConfirm = action == 'approve';
    final notesController = TextEditingController(
      text: isConfirm
          ? 'Confirmed policy warning. The sender was notified.'
          : 'Dismissed as a false positive.',
    );
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isConfirm ? 'Confirm warning?' : 'Dismiss warning?'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isConfirm
                    ? 'This confirms the violation and sends a safety warning to the user.'
                    : 'This removes the message from the pending review queue.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Admin notes',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isConfirm ? 'Confirm & Warn' : 'Dismiss'),
          ),
        ],
      ),
    );
    final notes = notesController.text.trim();
    notesController.dispose();
    if (shouldContinue != true) return;
    await _reviewFlag(flag, action, notes);
  }

  Future<void> _reviewFlag(
    Map<String, dynamic> flag,
    String action,
    String notes,
  ) async {
    final flagId = flag['id']?.toString() ?? '';
    final senderId = flag['sender_id']?.toString() ?? '';
    if (flagId.isEmpty) return;

    setState(() => _busyFlagIds.add(flagId));
    try {
      final result = await MessageFilterService.reviewFlaggedMessage(
        flagId: flagId,
        action: action,
        adminNotes: notes,
      );
      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'The review could not be saved.');
      }

      var notificationFailed = false;
      if (action == 'approve' && senderId.isNotEmpty) {
        try {
          await NotificationService().createNotification(
            userId: senderId,
            title: 'Safety Policy Warning',
            message:
                'A recent message was confirmed as a safety-policy violation. Keep contact details and payments inside Mobilis. Repeated violations may restrict your account.',
            type: 'safety_warning',
            data: {
              'event': 'safety_policy_warning_confirmed',
              'flag_id': flagId,
            },
          );
        } catch (e) {
          notificationFailed = true;
          debugPrint('Warning notification failed: $e');
        }
      }

      await _loadFlags();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notificationFailed
                ? 'Review saved, but the warning notification could not be sent.'
                : action == 'approve'
                ? 'Warning confirmed and the user was notified.'
                : 'Warning dismissed.',
          ),
          backgroundColor: notificationFailed
              ? AppColors.warning
              : AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update warning: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyFlagIds.remove(flagId));
    }
  }

  Widget _buildFilterWordsTab(bool isDark, Color cardColor, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.success),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.success, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add words to filter and flag inappropriate messages',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Add new filter word
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? AppColors.borderColor
                  : AppColors.lightBorderColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New Filter Word',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _filterWordController,
                      decoration: InputDecoration(
                        hintText: 'Enter word to filter...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey.shade500,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkBg
                            : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.borderColor
                                : Colors.grey.shade300,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.borderColor
                                : Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: AppColors.success,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: AppColors.success,
                      onSubmitted: (value) {
                        final word = value.trim().toLowerCase();
                        if (word.isNotEmpty && !_filterWords.contains(word)) {
                          _addFilterWord(word);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.success, Color(0xFF27AE60)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final word = _filterWordController.text
                            .trim()
                            .toLowerCase();
                        if (word.isNotEmpty && !_filterWords.contains(word)) {
                          _addFilterWord(word);
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Filter words list
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? AppColors.borderColor
                  : AppColors.lightBorderColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Words (${_filterWords.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (_filterWords.isNotEmpty)
                    Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.success,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_filterWordsLoaded)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_filterWords.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No filter words added yet',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textTertiary
                            : AppColors.lightTextTertiary,
                      ),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _filterWords.map((word) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.success),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            word,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              _removeFilterWord(word);
                            },
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlagCard(
    bool isDark,
    Color cardColor,
    Color textColor, {
    required String flagId,
    required String userName,
    required String userId,
    required String userMeta,
    required String messageContent,
    required String flagReason,
    required String riskLevel,
    required List<String> keywords,
    required String timestamp,
    required String status,
    required String? adminNotes,
    required bool isBusy,
    required bool showActions,
    required VoidCallback onApprove,
    required VoidCallback onDismiss,
  }) {
    final riskColor = riskLevel == 'high'
        ? AppColors.error
        : riskLevel == 'medium'
        ? AppColors.warning
        : AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    if (userId.isNotEmpty)
                      Text(
                        userId,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textTertiary
                              : AppColors.lightTextTertiary,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      userMeta,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textTertiary
                            : AppColors.lightTextTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  _buildStatusChip(status),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: riskColor),
                    ),
                    child: Text(
                      '${riskLevel.toUpperCase()} RISK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: riskColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (flagReason.isNotEmpty) ...[
            Text(
              flagReason,
              style: TextStyle(
                color: riskColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Message content
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBgSecondary : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              messageContent,
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Keywords
          if (keywords.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: keywords
                  .map(
                    (keyword) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: riskColor, width: 0.5),
                      ),
                      child: Text(
                        keyword,
                        style: TextStyle(
                          fontSize: 11,
                          color: riskColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (keywords.isNotEmpty) const SizedBox(height: 12),

          // Timestamp
          Text(
            timestamp,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.textTertiary
                  : AppColors.lightTextTertiary,
            ),
          ),
          if (adminNotes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              'Admin notes: ${adminNotes!.trim()}',
              style: TextStyle(
                fontSize: 12,
                color: textColor.withValues(alpha: 0.72),
              ),
            ),
          ],
          if (showActions) const SizedBox(height: 16),

          // Actions
          if (showActions)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isBusy ? null : onApprove,
                    icon: isBusy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.gpp_good_rounded),
                    label: const Text('Confirm & Warn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onDismiss,
                    icon: const Icon(Icons.close),
                    label: const Text('Dismiss'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? AppColors.textPrimary
                          : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isConfirmed = status == 'confirmed';
    final isDismissed = status == 'dismissed';
    final color = isConfirmed
        ? AppColors.success
        : isDismissed
        ? Colors.grey
        : AppColors.warning;
    final label = isConfirmed
        ? 'CONFIRMED'
        : isDismissed
        ? 'DISMISSED'
        : 'PENDING';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildViolatedUsersTab(
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.error),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppColors.error, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Users flagged or restricted for message policy violations. Use Unban to restore access.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (!_violatingUsersLoaded)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_violatingUsers.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 48,
                    color: isDark ? AppColors.textTertiary : AppColors.lightTextTertiary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No policy-violating users found',
                    style: TextStyle(
                      color: isDark ? AppColors.textTertiary : AppColors.lightTextTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._violatingUsers.map(
            (user) => _buildViolatingUserCard(user, isDark, cardColor, textColor),
          ),
      ],
    );
  }

  Widget _buildViolatingUserCard(
    Map<String, dynamic> user,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    final userId = user['id']?.toString() ?? '';
    final name = (user['full_name'] ?? user['name'])?.toString().trim();
    final displayName = (name != null && name.isNotEmpty) ? name : 'User #$userId';
    final email = user['email']?.toString().trim() ?? '';
    final role = user['role']?.toString().toUpperCase() ?? 'USER';
    final isBlocked = user['is_blocked'] == true || user['is_active'] == false;
    final flagCount = (user['flag_count'] as num?)?.toInt() ?? 0;
    final latestReason = user['latest_reason']?.toString() ?? 'Message policy violation';
    final suspensionReason = user['suspension_reason']?.toString();
    final isBusy = _busyUnbanUserIds.contains(userId);
    final avatarUrl = (user['avatar_url'] ?? user['profile_picture_url'])?.toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBlocked
              ? AppColors.error.withValues(alpha: 0.5)
              : (isDark ? AppColors.borderColor : AppColors.lightBorderColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textTertiary
                              : AppColors.lightTextTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isBlocked ? AppColors.error : AppColors.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isBlocked ? AppColors.error : AppColors.warning,
                  ),
                ),
                child: Text(
                  isBlocked ? 'BANNED' : 'FLAGGED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isBlocked ? AppColors.error : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            color: isDark
                ? AppColors.borderColor
                : AppColors.lightBorderColor,
            height: 1,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.flag_rounded,
                size: 16,
                color: flagCount > 0 ? AppColors.error : AppColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                '$flagCount Violation Flag${flagCount == 1 ? '' : 's'} Recorded',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: flagCount > 0 ? AppColors.error : AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Reason: ${(suspensionReason?.isNotEmpty == true) ? suspensionReason : latestReason}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondary : Colors.black87,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isBusy ? null : () => _confirmUnbanUser(user, displayName),
              icon: isBusy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_open_rounded, size: 18),
              label: Text(
                isBlocked ? 'Unban & Reactivate User' : 'Reset Violation Flags & Clear Status',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmUnbanUser(
    Map<String, dynamic> user,
    String displayName,
  ) async {
    final userId = user['id']?.toString() ?? '';
    if (userId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: widget.isDarkMode ? AppColors.darkCard : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.lock_open_rounded, color: AppColors.success),
            const SizedBox(width: 10),
            Text(
              'Unban $displayName?',
              style: TextStyle(
                color: widget.isDarkMode ? AppColors.textPrimary : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'This will reactivate $displayName\'s account, remove restriction blocks, and clear message violation counts.',
          style: TextStyle(
            color: widget.isDarkMode ? AppColors.textSecondary : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Unban'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busyUnbanUserIds.add(userId));
    try {
      final res = await MessageFilterService.unbanUser(userId);
      if (res['success'] != true) {
        throw Exception(res['error'] ?? 'Could not unban user.');
      }

      await Future.wait([_loadViolatingUsers(), _loadFlags()]);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$displayName has been unbanned and reactivated.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unban user: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyUnbanUserIds.remove(userId));
      }
    }
  }
}
