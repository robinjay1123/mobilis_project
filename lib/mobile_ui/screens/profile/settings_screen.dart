import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/auth_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/terms_service.dart';
import '../../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.onThemeToggle,
    this.isDarkMode = true,
    this.onBack,
    this.onOpenSupport,
    this.onProfileUpdated,
  });

  final Function(bool)? onThemeToggle;
  final bool isDarkMode;
  final VoidCallback? onBack;
  final VoidCallback? onOpenSupport;
  final VoidCallback? onProfileUpdated;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic> _profile = const {};
  String _role = 'renter';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    try {
      final auth = AuthService();
      final results = await Future.wait([
        auth.getCurrentUserProfile(),
        auth.getUserRole(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>? ?? const {};
        _role = (results[1] as String? ?? 'renter').toLowerCase();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _openAccountSecurity() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _AccountSecurityScreen()));
  }

  Future<void> _openAddresses() async {
    final currentAddress = _firstText([
      AuthService().currentUser?.userMetadata?['default_address'],
      _profile['location'],
      _profile['address'],
      AuthService().currentUser?.userMetadata?['location'],
      AuthService().currentUser?.userMetadata?['address'],
    ]);
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _MyAddressesScreen(initialAddress: currentAddress),
      ),
    );
    if (updated == true && mounted) {
      await _loadAccount();
      widget.onProfileUpdated?.call();
    }
  }

  void _openNotificationSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _PreferenceSettingsScreen(
          title: 'Notification Settings',
          description: 'Choose how Mobilis keeps you informed.',
          items: [
            _PreferenceItem(
              keyName: 'settings_push_notifications',
              icon: Icons.notifications_active_outlined,
              title: 'Push Notifications',
              subtitle: 'Booking, trip, message, and account updates',
              defaultValue: true,
            ),
            _PreferenceItem(
              keyName: 'settings_email_notifications',
              icon: Icons.alternate_email_rounded,
              title: 'Email Notifications',
              subtitle: 'Important account and service notices',
              defaultValue: true,
            ),
          ],
        ),
      ),
    );
  }

  void _openPrivacySettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _PreferenceSettingsScreen(
          title: 'Privacy Settings',
          description: 'Control optional data and location preferences.',
          items: [
            _PreferenceItem(
              keyName: 'settings_active_trip_location',
              icon: Icons.location_on_outlined,
              title: 'Active Trip Location',
              subtitle: 'Allow authorized tracking during active bookings',
              defaultValue: true,
            ),
            _PreferenceItem(
              keyName: 'settings_usage_analytics',
              icon: Icons.analytics_outlined,
              title: 'Usage Analytics',
              subtitle: 'Help improve Mobilis through anonymous diagnostics',
              defaultValue: false,
            ),
          ],
        ),
      ),
    );
  }

  void _openHelpCentre() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (helpContext) => _HelpCentreScreen(
          role: _role,
          onContactSupport: () {
            Navigator.of(helpContext).pop();
            if (widget.onOpenSupport != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onOpenSupport!.call();
              });
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Open Messages and select Customer Service to contact support.',
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _openAccountDeletionRequest() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            _AccountDeletionRequestScreen(profile: _profile, role: _role),
      ),
    );
    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deletion request sent to admin support.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _openTerms() async {
    final content = await TermsService().getRentalTerms();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LegalDocumentScreen(
          title: 'Terms and Conditions',
          icon: Icons.description_outlined,
          content: content,
        ),
      ),
    );
  }

  void _openPrivacyPolicy() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _LegalDocumentScreen(
          title: 'Privacy Policy',
          icon: Icons.privacy_tip_outlined,
          content:
              'Mobilis by PSDC collects account, verification, booking, location, emergency-contact, and payment-related information only to operate rentals, protect users, and meet service requirements.\n\n'
              'Identity documents and live trip locations are limited to authorized workflows. They should only be viewed by people responsible for verification, active bookings, safety, or customer support.\n\n'
              'Profile and booking information must not be shared outside Mobilis without a valid service or safety reason. Contact Customer Service to report incorrect information, request assistance, or raise a privacy concern.',
        ),
      ),
    );
  }

  Future<void> _rateMobilis() async {
    var launched = false;
    try {
      final uri = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.example.mobilis_by_psdc_app',
      );
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mobilis is not available for rating yet.'),
        ),
      );
    }
  }

  void _openAbout() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _AboutMobilisScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _backgroundColor(context),
      child: Column(
        children: [
          _SettingsHeader(title: 'Settings', onBack: _goBack),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
                    children: [
                      _SettingsSection(
                        title: 'My Account',
                        children: [
                          _SettingsMenuRow(
                            icon: Icons.shield_outlined,
                            title: 'Account & Security',
                            subtitle: 'Email, password, and account protection',
                            onTap: _openAccountSecurity,
                          ),
                          _SettingsMenuRow(
                            icon: Icons.location_on_outlined,
                            title: 'My Addresses',
                            subtitle: _addressSubtitle,
                            onTap: _openAddresses,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SettingsSection(
                        title: 'Settings',
                        children: [
                          _SettingsMenuRow(
                            icon: Icons.notifications_none_rounded,
                            title: 'Notification Settings',
                            subtitle: 'Push and email preferences',
                            onTap: _openNotificationSettings,
                          ),
                          _SettingsMenuRow(
                            icon: Icons.lock_outline_rounded,
                            title: 'Privacy Settings',
                            subtitle: 'Location and data preferences',
                            onTap: _openPrivacySettings,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SettingsSection(
                        title: 'Support',
                        children: [
                          _SettingsMenuRow(
                            icon: Icons.help_outline_rounded,
                            title: 'Help Centre',
                            subtitle: 'FAQs and customer service',
                            onTap: _openHelpCentre,
                          ),
                          _SettingsMenuRow(
                            icon: Icons.person_remove_outlined,
                            title: 'Request Account Deletion',
                            subtitle:
                                'Ask admin support to review and delete your account',
                            foregroundColor: AppColors.error,
                            onTap: _openAccountDeletionRequest,
                          ),
                          _SettingsMenuRow(
                            icon: Icons.article_outlined,
                            title: 'Terms and Conditions',
                            onTap: _openTerms,
                          ),
                          _SettingsMenuRow(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy Policy',
                            onTap: _openPrivacyPolicy,
                          ),
                          _SettingsMenuRow(
                            icon: Icons.star_outline_rounded,
                            title: 'Rate Mobilis',
                            subtitle: 'Share your experience',
                            onTap: _rateMobilis,
                          ),
                          _SettingsMenuRow(
                            icon: Icons.info_outline_rounded,
                            title: 'About Mobilis',
                            subtitle: 'Version 1.0.0',
                            onTap: _openAbout,
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String get _addressSubtitle {
    final address = _firstText([
      AuthService().currentUser?.userMetadata?['default_address'],
      _profile['location'],
      _profile['address'],
      AuthService().currentUser?.userMetadata?['location'],
      AuthService().currentUser?.userMetadata?['address'],
    ]);
    return address.isEmpty ? 'Add your primary address' : address;
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surfaceColor(context),
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.paddingOf(context).top + 8,
        12,
        10,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            style: IconButton.styleFrom(
              backgroundColor: _backgroundColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: _primaryTextColor(context),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: _primaryTextColor(context),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 68,
                    color: _borderColor(context),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsMenuRow extends StatelessWidget {
  const _SettingsMenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.foregroundColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (foregroundColor ?? AppColors.primary).withValues(
                      alpha: 0.14,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    color: foregroundColor ?? AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: foregroundColor ?? _primaryTextColor(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _secondaryTextColor(context),
                            fontSize: 11.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _secondaryTextColor(context),
                  size: 23,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsDetailScaffold extends StatelessWidget {
  const _SettingsDetailScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor(context),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: _surfaceColor(context),
        foregroundColor: _primaryTextColor(context),
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: child,
    );
  }
}

class _AccountSecurityScreen extends StatefulWidget {
  const _AccountSecurityScreen();

  @override
  State<_AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<_AccountSecurityScreen> {
  bool _isSending = false;

  Future<void> _sendPasswordReset() async {
    final email = AuthService().currentUser?.email?.trim() ?? '';
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email address is linked to this account.'),
        ),
      );
      return;
    }
    setState(() => _isSending = true);
    try {
      await AuthService().resetPassword(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send reset link: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService().currentUser?.email ?? 'No email set';
    return _SettingsDetailScaffold(
      title: 'Account & Security',
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _DetailCard(
            icon: Icons.alternate_email_rounded,
            title: 'Account Email',
            subtitle: email,
          ),
          const SizedBox(height: 12),
          _DetailCard(
            icon: Icons.password_rounded,
            title: 'Password',
            subtitle: 'Send a secure reset link to your account email.',
            action: FilledButton(
              onPressed: _isSending ? null : _sendPasswordReset,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('Reset Password'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyAddressesScreen extends StatefulWidget {
  const _MyAddressesScreen({required this.initialAddress});

  final String initialAddress;

  @override
  State<_MyAddressesScreen> createState() => _MyAddressesScreenState();
}

class _MyAddressesScreenState extends State<_MyAddressesScreen> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAddress);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    final address = _controller.text.trim();
    final user = AuthService().currentUser;
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your complete address.')),
      );
      return;
    }
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('users')
          .update({'location': address})
          .eq('id', user.id);
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            ...?user.userMetadata,
            'default_address': address,
            'location': address,
            'address': address,
          },
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default address updated'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update address: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailScaffold(
      title: 'My Addresses',
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            'Default Address',
            style: TextStyle(
              color: _primaryTextColor(context),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This is your default account and booking address. You can update it whenever your location changes.',
            style: TextStyle(
              color: _secondaryTextColor(context),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 5,
            style: TextStyle(color: _primaryTextColor(context)),
            decoration: InputDecoration(
              hintText: 'House number, street, barangay, city, province',
              hintStyle: TextStyle(color: _secondaryTextColor(context)),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 54),
                child: Icon(
                  Icons.location_on_outlined,
                  color: AppColors.primary,
                ),
              ),
              filled: true,
              fillColor: _surfaceColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _borderColor(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _borderColor(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveAddress,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'Saving...' : 'Save Address'),
          ),
        ],
      ),
    );
  }
}

class _AccountDeletionRequestScreen extends StatefulWidget {
  const _AccountDeletionRequestScreen({
    required this.profile,
    required this.role,
  });

  final Map<String, dynamic> profile;
  final String role;

  @override
  State<_AccountDeletionRequestScreen> createState() =>
      _AccountDeletionRequestScreenState();
}

class _AccountDeletionRequestScreenState
    extends State<_AccountDeletionRequestScreen> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final reason = _reasonController.text.trim();
    if (reason.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please provide a short reason of at least 10 characters.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request account deletion?'),
        content: const Text(
          'Your account will remain active while admin support reviews this request. No account data will be deleted immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Account'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final user = AuthService().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again and retry.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final displayName = _firstText([
        widget.profile['full_name'],
        widget.profile['name'],
        user.userMetadata?['full_name'],
        user.email?.split('@').first,
      ]);
      final chatService = ChatService();
      final conversation = await chatService
          .getOrCreateCustomerServiceConversation(
            userId: user.id,
            userName: displayName,
            userRole: widget.role,
          );
      final conversationId = conversation['id']?.toString().trim() ?? '';
      if (conversationId.isEmpty) {
        throw Exception('Could not create an admin support request');
      }

      await chatService.sendMessage(
        conversationId: conversationId,
        senderId: user.id,
        content:
            'ACCOUNT DELETION REQUEST\n'
            'Account: ${user.email ?? user.id}\n'
            'Role: ${widget.role.toUpperCase()}\n'
            'Reason: $reason\n\n'
            'Please review this request and contact me before taking action.',
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send deletion request: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailScaffold(
      title: 'Request Account Deletion',
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This sends a review request to Mobilis admin support. Your account stays active until an admin confirms the request with you.',
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Reason for deletion',
            style: TextStyle(
              color: _primaryTextColor(context),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            minLines: 4,
            maxLines: 7,
            maxLength: 500,
            style: TextStyle(color: _primaryTextColor(context)),
            decoration: InputDecoration(
              hintText:
                  'Tell admin support why you want to delete your account',
              hintStyle: TextStyle(color: _secondaryTextColor(context)),
              filled: true,
              fillColor: _surfaceColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _borderColor(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _borderColor(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.error,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submitRequest,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(
              _isSubmitting ? 'Sending Request...' : 'Request Deletion',
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceItem {
  const _PreferenceItem({
    required this.keyName,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.defaultValue,
  });

  final String keyName;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool defaultValue;
}

class _PreferenceSettingsScreen extends StatefulWidget {
  const _PreferenceSettingsScreen({
    required this.title,
    required this.description,
    required this.items,
  });

  final String title;
  final String description;
  final List<_PreferenceItem> items;

  @override
  State<_PreferenceSettingsScreen> createState() =>
      _PreferenceSettingsScreenState();
}

class _PreferenceSettingsScreenState extends State<_PreferenceSettingsScreen> {
  final Map<String, bool> _values = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final item in widget.items) {
        _values[item.keyName] =
            preferences.getBool(item.keyName) ?? item.defaultValue;
      }
      _isLoading = false;
    });
  }

  Future<void> _update(_PreferenceItem item, bool value) async {
    setState(() => _values[item.keyName] = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(item.keyName, value);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailScaffold(
      title: widget.title,
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  widget.description,
                  style: TextStyle(
                    color: _secondaryTextColor(context),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: _surfaceColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _borderColor(context)),
                  ),
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < widget.items.length;
                        index++
                      ) ...[
                        _PreferenceRow(
                          item: widget.items[index],
                          value: _values[widget.items[index].keyName] ?? false,
                          onChanged: (value) =>
                              _update(widget.items[index], value),
                        ),
                        if (index != widget.items.length - 1)
                          Divider(
                            height: 1,
                            indent: 66,
                            color: _borderColor(context),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.item,
    required this.value,
    required this.onChanged,
  });

  final _PreferenceItem item;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: AppColors.primary, size: 19),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    color: _secondaryTextColor(context),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _HelpCentreScreen extends StatelessWidget {
  const _HelpCentreScreen({required this.role, required this.onContactSupport});

  final String role;
  final VoidCallback onContactSupport;

  @override
  Widget build(BuildContext context) {
    final faqs = _faqsForRole(role);
    return _SettingsDetailScaffold(
      title: 'Help Centre',
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.primary,
                  size: 30,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need more help?',
                        style: TextStyle(
                          color: _primaryTextColor(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Chat directly with the Mobilis admin support team.',
                        style: TextStyle(
                          color: _secondaryTextColor(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onContactSupport,
                  child: const Text('Contact'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Frequently Asked Questions',
            style: TextStyle(
              color: _primaryTextColor(context),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...faqs.map(
            (faq) => Container(
              margin: const EdgeInsets.only(bottom: 9),
              decoration: BoxDecoration(
                color: _surfaceColor(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _borderColor(context)),
              ),
              child: ExpansionTile(
                iconColor: AppColors.primary,
                collapsedIconColor: _secondaryTextColor(context),
                title: Text(
                  faq.$1,
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(
                    faq.$2,
                    style: TextStyle(
                      color: _secondaryTextColor(context),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({
    required this.title,
    required this.icon,
    required this.content,
  });

  final String title;
  final IconData icon;
  final String content;

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailScaffold(
      title: title,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _surfaceColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  content.trim().isEmpty
                      ? 'This document is currently unavailable.'
                      : content,
                  style: TextStyle(
                    color: _secondaryTextColor(context),
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutMobilisScreen extends StatelessWidget {
  const _AboutMobilisScreen();

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailScaffold(
      title: 'About Mobilis',
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _surfaceColor(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor(context)),
            ),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    color: Colors.black,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mobilis by PSDC',
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Version 1.0.0 (1)',
                  style: TextStyle(
                    color: _secondaryTextColor(context),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Mobilis connects renters, certified drivers, PSDC operators, and vehicle partners through one secure booking and trip-management platform.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _secondaryTextColor(context),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _secondaryTextColor(context),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 10), action!],
        ],
      ),
    );
  }
}

List<(String, String)> _faqsForRole(String role) {
  switch (role.toLowerCase()) {
    case 'partner':
    case 'owner':
      return const [
        (
          'What documents are required to become a partner?',
          'Prepare a valid ID, ownership or business documents, OR/CR, and clear photos for every vehicle submitted.',
        ),
        (
          'Why is my vehicle still pending?',
          'New vehicles and edited vehicle details must be reviewed before they can be listed for rental.',
        ),
        (
          'How do I change a vehicle price?',
          'Send a price-change request through Customer Service. The admin and assigned operator will review it.',
        ),
      ];
    case 'driver':
      return const [
        (
          'How do I become a certified driver?',
          'Complete identity verification, submit the driver application and required documents, then wait for approval.',
        ),
        (
          'How do I receive assignments?',
          'Certified drivers must enable availability and select their available dates before operators can assign trips.',
        ),
        (
          'When should I renew my license?',
          'Mobilis sends renewal reminders before your license expires. Open the application section to submit updated documents.',
        ),
      ];
    default:
      return const [
        (
          'How do I rent a vehicle?',
          'Choose an approved available vehicle, select your dates and time, complete the required traveler information, then submit the booking.',
        ),
        (
          'How is the delivery fee calculated?',
          'Vehicle delivery is calculated from the selected delivery distance using the displayed per-kilometer rate.',
        ),
        (
          'How can I cancel a booking?',
          'Pending bookings can be cancelled from My Bookings. Approved bookings require assistance from Customer Service.',
        ),
      ];
  }
}

String _firstText(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return '';
}

Color _backgroundColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.darkBg
      : AppColors.lightBg;
}

Color _surfaceColor(BuildContext context) {
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

Color _borderColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.borderColor
      : AppColors.lightBorderColor;
}
