import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/message_filter_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';

class AdminMessageReviewScreen extends StatefulWidget {
  final bool isDarkMode;

  const AdminMessageReviewScreen({super.key, this.isDarkMode = true});

  @override
  State<AdminMessageReviewScreen> createState() =>
      _AdminMessageReviewScreenState();
}

class _AdminMessageReviewScreenState extends State<AdminMessageReviewScreen> {
  int _selectedTab =
      0; // 0: Pending, 1: Confirmed, 2: Dismissed, 3: Filter Words
  late Future<List<Map<String, dynamic>>> _flagsFuture;
  List<String> _filterWords = [];
  final TextEditingController _filterWordController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _filterWordsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadFlags();
    _loadFilterWords();
  }

  @override
  void dispose() {
    _filterWordController.dispose();
    super.dispose();
  }

  void _loadFlags() {
    // This would ideally load all flags filtered by status from the service
    // For now, this is a placeholder
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
              ],
            ),
          ),

          // Flags list
          Expanded(
            child: ListView(
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
              ],
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
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primary : textColor,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingFlags(bool isDark, Color cardColor, Color textColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
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
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'No pending flags',
              style: TextStyle(color: textColor, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmedFlags(bool isDark, Color cardColor, Color textColor) {
    return Column(
      children: [
        Text('No confirmed flags yet', style: TextStyle(color: textColor)),
      ],
    );
  }

  Widget _buildDismissedFlags(bool isDark, Color cardColor, Color textColor) {
    return Column(
      children: [
        Text('No dismissed flags yet', style: TextStyle(color: textColor)),
      ],
    );
  }

  Widget _buildFilterWordsTab(bool isDark, Color cardColor, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
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
                          color: isDark
                              ? AppColors.textTertiary
                              : AppColors.lightTextTertiary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: TextStyle(color: textColor, fontSize: 14),
                      cursorColor: textColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      final word = _filterWordController.text.trim();
                      if (word.isNotEmpty && !_filterWords.contains(word)) {
                        _addFilterWord(word);
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
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
              if (_filterWords.isEmpty)
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
                        color: AppColors.success.withOpacity(0.1),
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
    required String messageContent,
    required String riskLevel,
    required List<String> keywords,
    required String timestamp,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
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
                  Text(
                    userId,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: riskColor),
                ),
                child: Text(
                  riskLevel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

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
          Wrap(
            spacing: 8,
            children: keywords
                .map(
                  (keyword) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.1),
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
          const SizedBox(height: 12),

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
          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Confirm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDismiss,
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
}
