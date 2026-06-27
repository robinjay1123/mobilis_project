import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../../services/auth_service.dart';
import 'ratings_reviews_screen.dart';
import 'emergency_contact_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;
  final VoidCallback? onBack;

  const SettingsScreen({
    super.key,
    this.onThemeToggle,
    this.isDarkMode = true,
    this.onBack,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = true;
  bool emailNotifications = true;
  String? currentRole;
  Map<String, dynamic>? currentProfile;
  bool isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentRole();
  }

  void _loadCurrentRole() async {
    try {
      final authService = AuthService();
      final role = await authService.getUserRole();
      final profile = await authService.getCurrentUserProfile();
      setState(() {
        currentRole = role;
        currentProfile = profile;
        isLoadingRole = false;
      });
    } catch (e) {
      setState(() {
        isLoadingRole = false;
      });
    }
  }

  void _switchRole(String newRole) async {
    try {
      final authService = AuthService();
      await authService.updateUserRole(newRole);

      setState(() {
        currentRole = newRole;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Switched to ${newRole == 'partner' ? 'Partner' : 'Renter'} role',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate to appropriate home screen after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            if (newRole == 'partner') {
              Navigator.of(context).pushReplacementNamed('/owner-verification');
            } else {
              Navigator.of(context).pushReplacementNamed('/dashboard');
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching role: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: _backgroundColor(context),
      child: Column(
        children: [
          // Header
          Container(
            color: _cardColor(context),
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 12,
              16,
              12,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onBack,
                  child: Icon(
                    Icons.arrow_back,
                    color: _secondaryTextColor(context),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _primaryTextColor(context),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Appearance section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appearance',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSettingOption(
                          icon: isDark ? Icons.dark_mode : Icons.light_mode,
                          title: 'Theme',
                          subtitle: isDark ? 'Dark Mode' : 'Light Mode',
                          trailing: Switch(
                            value: isDark,
                            onChanged: widget.onThemeToggle,
                            activeThumbColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Notifications section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSettingOption(
                          icon: Icons.notifications,
                          title: 'Push Notifications',
                          subtitle: 'Booking updates & alerts',
                          trailing: Switch(
                            value: notificationsEnabled,
                            onChanged: (value) {
                              setState(() {
                                notificationsEnabled = value;
                              });
                            },
                            activeThumbColor: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSettingOption(
                          icon: Icons.mail,
                          title: 'Email Notifications',
                          subtitle: 'Promotional & updates',
                          trailing: Switch(
                            value: emailNotifications,
                            onChanged: (value) {
                              setState(() {
                                emailNotifications = value;
                              });
                            },
                            activeThumbColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Privacy section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Privacy & Security',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSettingTile(
                          icon: Icons.lock,
                          title: 'Change Password',
                          onTap: () {},
                        ),
                        const SizedBox(height: 8),
                        _buildSettingTile(
                          icon: Icons.privacy_tip,
                          title: 'Privacy Policy',
                          onTap: () {},
                        ),
                        const SizedBox(height: 8),
                        _buildSettingTile(
                          icon: Icons.star_outline_rounded,
                          title: 'Ratings & Reviews',
                          onTap: () {
                            final userId = AuthService().currentUser?.id;
                            if (userId == null) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RatingsReviewsScreen(
                                  userId: userId,
                                  title: 'My Ratings & Reviews',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildSettingTile(
                          icon: Icons.health_and_safety_outlined,
                          title: 'Emergency Contact',
                          subtitle: 'Required for renter and driver safety',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EmergencyContactScreen(
                                  isDarkMode: widget.isDarkMode,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Role section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (isLoadingRole)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _cardColor(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _borderColor(context)),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Loading role...'),
                              ],
                            ),
                          )
                        else ...[
                          if (currentRole != 'admin') ...[
                            _buildProfileCard(),
                            const SizedBox(height: 12),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: _cardColor(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _borderColor(context)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    currentRole == 'partner'
                                        ? Icons.store
                                        : Icons.person,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Current Role',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _primaryTextColor(context),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        currentRole == 'partner'
                                            ? 'Partner'
                                            : 'Renter',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _secondaryTextColor(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (String role) {
                                    if (currentRole != role) {
                                      _switchRole(role);
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => [
                                    PopupMenuItem<String>(
                                      value: 'user',
                                      enabled: currentRole != 'user',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            color: _secondaryTextColor(context),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('Switch to Renter'),
                                          if (currentRole == 'user') ...[
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.check,
                                              color: AppColors.success,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.more_vert,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // About section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSettingTile(
                          icon: Icons.info,
                          title: 'App Version',
                          subtitle: '1.0.0',
                          onTap: () {},
                        ),
                        const SizedBox(height: 8),
                        _buildSettingTile(
                          icon: Icons.help,
                          title: 'Help & Support',
                          onTap: () {},
                        ),
                        const SizedBox(height: 8),
                        _buildSettingTile(
                          icon: Icons.feedback,
                          title: 'Send Feedback',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingOption({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _primaryTextColor(context),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: _secondaryTextColor(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _cardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _primaryTextColor(context),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: _secondaryTextColor(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: _tertiaryTextColor(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final profile = currentProfile ?? {};
    final name = profile['full_name']?.toString().trim().isNotEmpty == true
        ? profile['full_name'].toString().trim()
        : profile['name']?.toString().trim().isNotEmpty == true
        ? profile['name'].toString().trim()
        : profile['email']?.toString().trim().isNotEmpty == true
        ? profile['email'].toString().trim()
        : 'Profile';
    final role = _displayRole(currentRole ?? profile['role']?.toString());
    final email = profile['email']?.toString().trim() ?? '';
    final phone = profile['phone']?.toString().trim().isNotEmpty == true
        ? profile['phone'].toString().trim()
        : profile['phone_number']?.toString().trim() ?? '';
    final location = profile['location']?.toString().trim() ?? '';
    final avatarUrl =
        profile['avatar_url']?.toString().trim().isNotEmpty == true
        ? profile['avatar_url'].toString().trim()
        : profile['profile_picture_url']?.toString().trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.18),
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl.isEmpty
                ? Text(
                    _initials(name),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _primaryTextColor(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                if (email.isNotEmpty)
                  _buildProfileMeta(Icons.mail_outline, email),
                if (phone.isNotEmpty)
                  _buildProfileMeta(Icons.phone_outlined, phone),
                if (location.isNotEmpty)
                  _buildProfileMeta(Icons.location_on_outlined, location),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMeta(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: _secondaryTextColor(context)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: _secondaryTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _displayRole(String? role) {
    switch (role?.toLowerCase().trim()) {
      case 'operator':
        return 'Operator / Agent';
      case 'partner':
      case 'owner':
        return 'Partner';
      case 'driver':
        return 'Driver';
      case 'renter':
      case 'user':
        return 'Renter';
      default:
        return 'Profile';
    }
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Color _backgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkBg
        : AppColors.lightBg;
  }

  Color _cardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkBgSecondary
        : AppColors.lightBgSecondary;
  }

  Color _primaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
  }

  Color _secondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;
  }

  Color _tertiaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.textTertiary
        : AppColors.lightTextTertiary;
  }

  Color _borderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.borderColor
        : AppColors.lightBorderColor;
  }
}
