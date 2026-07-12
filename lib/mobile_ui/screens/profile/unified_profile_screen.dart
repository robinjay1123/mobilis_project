import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../../../services/verification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/optimized_network_image.dart';
import '../../widgets/role_ui.dart';
import 'emergency_contact_screen.dart';
import 'ratings_reviews_screen.dart';

class ProfileStatItem {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const ProfileStatItem({required this.label, required this.value, this.onTap});
}

class UnifiedProfileScreen extends StatefulWidget {
  final String role;
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;
  final List<ProfileStatItem> stats;
  final VoidCallback? onLogout;
  final VoidCallback? onOpenSupport;
  final VoidCallback? onOpenVerification;
  final VoidCallback? onProfileUpdated;

  const UnifiedProfileScreen({
    super.key,
    required this.role,
    required this.stats,
    this.onThemeToggle,
    this.isDarkMode = true,
    this.onLogout,
    this.onOpenSupport,
    this.onOpenVerification,
    this.onProfileUpdated,
  });

  @override
  State<UnifiedProfileScreen> createState() => _UnifiedProfileScreenState();
}

class _UnifiedProfileScreenState extends State<UnifiedProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _verification;
  bool _isLoading = true;
  late final ScrollController _scrollController;
  late final AnimationController _photoController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _photoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 340),
    );
    _loadProfile();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  bool _handleProfileScroll(ScrollNotification notification) {
    if (notification is OverscrollNotification) {
      if (notification.overscroll > 0 &&
          _photoController.status != AnimationStatus.completed) {
        _photoController.forward();
      } else if (notification.overscroll < 0 &&
          _photoController.status != AnimationStatus.dismissed) {
        _photoController.reverse();
      }
      return false;
    }
    if (notification is! ScrollUpdateNotification ||
        notification.dragDetails == null) {
      return false;
    }

    final delta = notification.scrollDelta ?? 0;
    if (delta > 1 && _photoController.status != AnimationStatus.completed) {
      _photoController.forward();
    } else if (delta < -1 &&
        _photoController.status != AnimationStatus.dismissed) {
      _photoController.reverse();
    }
    return false;
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final profile = await AuthService().getCurrentUserProfile();
    Map<String, dynamic>? verification;
    final userId = AuthService().currentUser?.id;
    if (userId != null) {
      verification = await VerificationService.getUserVerification(userId);
    }
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _verification = verification;
      _isLoading = false;
    });
  }

  void _toggleProfilePhoto() {
    if (_photoController.status == AnimationStatus.completed ||
        _photoController.value > 0.5) {
      _photoController.reverse();
    } else {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      _photoController.forward();
    }
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UnifiedEditProfileScreen(
          initialProfile: _profile ?? const {},
          role: widget.role,
        ),
      ),
    );
    if (updated == true && mounted) {
      await _loadProfile();
      widget.onProfileUpdated?.call();
    }
  }

  Future<void> _openProfilePictureUpload() async {
    final updated = await Navigator.pushNamed(
      context,
      '/profile-picture-upload',
    );
    if (updated == true && mounted) {
      await _loadProfile();
      widget.onProfileUpdated?.call();
    }
  }

  void _openRatings() {
    final userId = AuthService().currentUser?.id;
    if (userId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RatingsReviewsScreen(userId: userId, title: 'Ratings & Reviews'),
      ),
    );
  }

  void _openEmergencyContact() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmergencyContactScreen(isDarkMode: widget.isDarkMode),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    if (widget.onLogout != null) {
      widget.onLogout!();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        title: const Text(
          'Logout',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/auth-processing',
        (route) => false,
        arguments: {'mode': 'logout'},
      );
    }
  }

  void _openHelpCenter() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.darkBgSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _squareIcon(Icons.help_outline),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Help Center',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._roleFaqs().map(
                (faq) => _HelpFaqTile(question: faq.$1, answer: faq.$2),
              ),
              const SizedBox(height: 12),
              _sheetAction(
                icon: Icons.support_agent,
                label: 'Customer Support',
                onTap: () {
                  Navigator.pop(context);
                  widget.onOpenSupport?.call();
                },
              ),
              _sheetAction(
                icon: Icons.report_problem_outlined,
                label: 'Report an Issue',
                onTap: () {
                  Navigator.pop(context);
                  widget.onOpenSupport?.call();
                },
              ),
              _sheetAction(
                icon: Icons.description_outlined,
                label: 'Terms and Conditions',
                onTap: () => Navigator.pop(context),
              ),
              _sheetAction(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<(String, String)> _roleFaqs() {
    switch (widget.role.toLowerCase()) {
      case 'partner':
        return const [
          (
            'What documents are needed?',
            'Prepare your valid ID, business/ownership documents, OR/CR, and clear vehicle photos.',
          ),
          (
            'How do I update pricing?',
            'Use the price-change request flow so admin and operator can review the rate.',
          ),
          (
            'When can my car be booked?',
            'Only approved and available vehicles are shown to renters.',
          ),
        ];
      case 'driver':
        return const [
          (
            'How do I apply as a driver?',
            'Open Application, complete your personal details, license expiry, NBI, signature, and required photos.',
          ),
          (
            'How do I receive jobs?',
            'Approved drivers can set availability and receive booking assignments from operators.',
          ),
          (
            'Why renew documents?',
            'The system reminds you before your license or documents expire.',
          ),
        ];
      default:
        return const [
          (
            'How do I rent a vehicle?',
            'Search for a vehicle, choose dates, set pickup/destination, submit requirements, and wait for confirmation.',
          ),
          (
            'Why is verification required?',
            'Identity and emergency contact details help PSDC protect renters, drivers, and partners.',
          ),
          (
            'Can I track an ongoing trip?',
            'Tracking appears only for active trips where authorized tracking is available.',
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Column(
        children: [
          _profileHeaderBar(),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    final profile = _profile ?? {};
    final name = _displayName(profile);
    final email =
        _value(profile['email']) ??
        AuthService().currentUser?.email ??
        'Not set';
    final phone =
        _value(profile['phone'] ?? profile['phone_number']) ?? 'Not set';
    final location =
        _value(profile['location'] ?? profile['address']) ?? 'Not set';
    final avatarUrl = _firstValue([
      profile['avatar_url'],
      profile['profile_picture_url'],
      AuthService().currentUser?.userMetadata?['avatar_url'],
      AuthService().currentUser?.userMetadata?['profile_picture_url'],
      AuthService().currentUser?.userMetadata?['picture'],
    ]);

    return Column(
      children: [
        _profileHeaderBar(),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleProfileScroll,
            child: RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                children: [
                  _profileCard(
                    name: name,
                    email: email,
                    phone: phone,
                    location: location,
                    avatarUrl: avatarUrl,
                  ),
                  const SizedBox(height: 18),
                  _settingsTile(
                    icon: widget.isDarkMode
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    title: 'Appearance',
                    subtitle: widget.isDarkMode ? 'Dark Mode' : 'Light Mode',
                    trailing: Switch(
                      value: widget.isDarkMode,
                      activeThumbColor: AppColors.primary,
                      onChanged: widget.onThemeToggle,
                    ),
                  ),
                  _settingsTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Verification and Documents',
                    subtitle: _verificationSubtitle(),
                    onTap:
                        widget.onOpenVerification ?? _openVerificationSummary,
                  ),
                  _settingsTile(
                    icon: Icons.star_outline_rounded,
                    title: 'Ratings and Reviews',
                    subtitle: 'View ratings and renter reviews',
                    onTap: _openRatings,
                  ),
                  _settingsTile(
                    icon: Icons.help_outline,
                    title: 'Help Center',
                    subtitle: 'FAQs, support, reports, terms, and privacy',
                    onTap: _openHelpCenter,
                  ),
                  _settingsTile(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Emergency Contact',
                    subtitle: 'Safety contact for trips and incidents',
                    onTap: _openEmergencyContact,
                  ),
                  _settingsTile(
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Sign out of this device',
                    iconColor: AppColors.error,
                    textColor: AppColors.error,
                    onTap: _confirmLogout,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileHeaderBar() {
    return RolePageHeader(
      title: 'Profile',
      trailing: IconButton(
        onPressed: _openRatings,
        tooltip: 'Ratings and Reviews',
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: const Icon(
          Icons.star_outline_rounded,
          color: Colors.black,
          size: 24,
        ),
      ),
    );
  }

  String? _firstValue(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  Widget _profileCard({
    required String name,
    required String email,
    required String phone,
    required String location,
    required String? avatarUrl,
  }) {
    return AnimatedBuilder(
      animation: _photoController,
      builder: (context, _) {
        final progress = Curves.easeInOutCubic.transform(
          _photoController.value,
        );
        final compactOpacity = (1 - (progress * 1.8)).clamp(0.0, 1.0);
        final expandedOpacity = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compactHeight = 238.0;
            final expandedHeight = (width * 1.08).clamp(350.0, 430.0);
            final height =
                compactHeight + ((expandedHeight - compactHeight) * progress);
            final avatarRect = Rect.lerp(
              const Rect.fromLTWH(18, 18, 74, 74),
              Rect.fromLTWH(0, 0, width, height),
              progress,
            )!;
            final radius = BorderRadius.lerp(
              BorderRadius.circular(20),
              BorderRadius.circular(22),
              progress,
            )!;

            return SizedBox(
              height: height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: AppColors.darkBgSecondary),
                    Positioned.fromRect(
                      rect: avatarRect,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _toggleProfilePhoto,
                        child: ClipRRect(
                          borderRadius: radius,
                          child: ColoredBox(
                            color: AppColors.primary,
                            child: avatarUrl != null && avatarUrl.isNotEmpty
                                ? OptimizedNetworkImage(
                                    imageUrl: avatarUrl,
                                    fit: BoxFit.cover,
                                    isThumbnail: progress < 0.25,
                                    errorWidget: _initialBox(name),
                                  )
                                : _initialBox(name),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Opacity(
                        opacity: expandedOpacity,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(0x22000000),
                                Color(0xE6000000),
                              ],
                              stops: [0.35, 0.58, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 106,
                      top: 14,
                      right: 10,
                      child: IgnorePointer(
                        ignoring: compactOpacity < 0.5,
                        child: Opacity(
                          opacity: compactOpacity,
                          child: _compactProfileDetails(
                            name: name,
                            email: email,
                            phone: phone,
                            location: location,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 82,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: expandedOpacity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              _roleBadge(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            AppColors.darkBgSecondary,
                            Colors.black.withValues(alpha: 0.58),
                            progress,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: _profileStats(),
                      ),
                    ),
                    Positioned(
                      left: 22,
                      top: 22,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: compactOpacity * 0.9,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.58),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(
                              Icons.open_in_full_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 70,
                      top: 70,
                      child: IgnorePointer(
                        ignoring: compactOpacity < 0.5,
                        child: Opacity(
                          opacity: compactOpacity,
                          child: _profileAction(
                            icon: Icons.edit_outlined,
                            tooltip: 'Change profile photo',
                            onTap: _openProfilePictureUpload,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: IgnorePointer(
                        ignoring: expandedOpacity < 0.5,
                        child: Opacity(
                          opacity: expandedOpacity,
                          child: Row(
                            children: [
                              _profileAction(
                                icon: Icons.add_a_photo_outlined,
                                tooltip: 'Change profile photo',
                                onTap: _openProfilePictureUpload,
                              ),
                              const SizedBox(width: 8),
                              _profileAction(
                                icon: Icons.edit_outlined,
                                tooltip: 'Edit profile',
                                onTap: _openEditProfile,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _compactProfileDetails({
    required String name,
    required String email,
    required String phone,
    required String location,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _openEditProfile,
              icon: const Icon(
                Icons.edit_square,
                color: AppColors.primary,
                size: 20,
              ),
              tooltip: 'Edit Profile',
            ),
          ],
        ),
        _roleBadge(),
        const SizedBox(height: 9),
        _profileInfo(Icons.mail_outline, email),
        _profileInfo(Icons.phone_outlined, phone),
        _profileInfo(Icons.location_on_outlined, location),
      ],
    );
  }

  Widget _profileStats() {
    return Row(
      children: [
        for (var index = 0; index < widget.stats.length; index++) ...[
          Expanded(child: _stat(widget.stats[index])),
          if (index != widget.stats.length - 1)
            Container(height: 42, width: 1, color: AppColors.borderColor),
        ],
      ],
    );
  }

  Widget _profileAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.58),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Tooltip(
          message: tooltip,
          child: SizedBox.square(
            dimension: 36,
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _initialBox(String name) {
    return Center(
      child: Text(
        name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _roleBadge() {
    final role = widget.role.toLowerCase();
    final label = role == 'partner'
        ? 'Mobilis by PSDC Certified Partner'
        : role == 'driver'
        ? 'Mobilis by PSDC Certified Driver'
        : 'Verified Renter';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.success,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _profileInfo(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textTertiary, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(ProfileStatItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Column(
          children: [
            Text(
              item.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Row(
            children: [
              _squareIcon(icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor ?? AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right,
                    color: textColor ?? AppColors.textTertiary,
                    size: 22,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _squareIcon(IconData icon, {Color? color}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: (color ?? AppColors.primary).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color ?? AppColors.primary, size: 22),
    );
  }

  Widget _sheetAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  String _verificationSubtitle() {
    final status =
        _verification?['status']?.toString() ??
        _verification?['verification_status']?.toString() ??
        'Not submitted';
    return 'Status: ${_titleCase(status)}';
  }

  void _openVerificationSummary() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final docs = _verificationDocuments();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verification and Documents',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                if (docs.isEmpty)
                  const Text(
                    'No submitted verification files yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  ...docs.map(
                    (doc) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.darkBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.insert_drive_file_outlined,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              doc,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _statusChip(_verificationSubtitle()),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> _verificationDocuments() {
    final record = _verification;
    if (record == null) return const [];
    final docs = <String>[];
    const keys = {
      'id_front_url': 'ID Front',
      'id_back_url': 'ID Back',
      'face_selfie_url': 'Face Selfie',
      'selfie_with_id_url': 'Selfie Holding ID',
      'signature_url': 'Digital Signature',
      'driver_signature_url': 'Digital Signature',
      'nbi_file_url': 'NBI Clearance',
      'driver_nbi_url': 'NBI Clearance',
    };
    for (final entry in keys.entries) {
      if (_value(record[entry.key]) != null) docs.add(entry.value);
    }
    return docs.toSet().toList();
  }

  Widget _statusChip(String text) {
    final normalized = text.toLowerCase();
    final color =
        normalized.contains('approved') || normalized.contains('verified')
        ? AppColors.success
        : normalized.contains('reject') || normalized.contains('expired')
        ? AppColors.error
        : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text.replaceFirst('Status: ', ''),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _displayName(Map<String, dynamic> profile) {
    return _value(profile['full_name'] ?? profile['name']) ??
        AuthService().currentUser?.email?.split('@').first ??
        'Profile';
  }

  String? _value(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String _titleCase(String value) {
    if (value.trim().isEmpty) return 'Not submitted';
    final normalized = value.replaceAll('_', ' ').trim();
    return normalized
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

class UnifiedEditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> initialProfile;
  final String role;

  const UnifiedEditProfileScreen({
    super.key,
    required this.initialProfile,
    required this.role,
  });

  @override
  State<UnifiedEditProfileScreen> createState() =>
      _UnifiedEditProfileScreenState();
}

class _UnifiedEditProfileScreenState extends State<UnifiedEditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: _text(
        widget.initialProfile['full_name'] ?? widget.initialProfile['name'],
      ),
    );
    _emailController = TextEditingController(
      text: _text(
        widget.initialProfile['email'] ?? AuthService().currentUser?.email,
      ),
    );
    _phoneController = TextEditingController(
      text: _text(
        widget.initialProfile['phone'] ?? widget.initialProfile['phone_number'],
      ),
    );
    _locationController = TextEditingController(
      text: _text(
        widget.initialProfile['location'] ?? widget.initialProfile['address'],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = AuthService().currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final payload = {
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
      };
      try {
        await supabase.from('users').update(payload).eq('id', user.id);
      } catch (error) {
        final message = error.toString().toLowerCase();
        if (message.contains('location')) {
          final fallback = Map<String, dynamic>.from(payload)
            ..remove('location');
          await supabase.from('users').update(fallback).eq('id', user.id);
        } else {
          rethrow;
        }
      }

      await supabase.auth.updateUser(
        UserAttributes(
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          data: {
            ...?user.userMetadata,
            'phone': _phoneController.text.trim(),
            'location': _locationController.text.trim(),
          },
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _field(
            label: 'Verified Name',
            controller: _nameController,
            icon: Icons.badge_outlined,
            enabled: false,
            helper: 'Verified names cannot be edited.',
          ),
          _field(
            label: 'Email',
            controller: _emailController,
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          _field(
            label: 'Phone Number',
            controller: _phoneController,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          _field(
            label: 'Location',
            controller: _locationController,
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              _isSaving ? 'Saving...' : 'Save Changes',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
    String? helper,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          prefixIcon: Icon(icon, color: AppColors.primary),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          helperStyle: const TextStyle(color: AppColors.textTertiary),
          filled: true,
          fillColor: AppColors.darkBgSecondary,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';
}

class _HelpFaqTile extends StatefulWidget {
  final String question;
  final String answer;

  const _HelpFaqTile({required this.question, required this.answer});

  @override
  State<_HelpFaqTile> createState() => _HelpFaqTileState();
}

class _HelpFaqTileState extends State<_HelpFaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                Text(
                  widget.answer,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
