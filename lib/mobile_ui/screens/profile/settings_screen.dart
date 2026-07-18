import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    this.showHeader = true,
    this.showAppearance = false,
    this.showSignOut = false,
    this.onBack,
    this.onOpenSupport,
    this.onProfileUpdated,
    this.onSignOut,
  });

  final Function(bool)? onThemeToggle;
  final bool isDarkMode;
  final bool showHeader;
  final bool showAppearance;
  final bool showSignOut;
  final VoidCallback? onBack;
  final VoidCallback? onOpenSupport;
  final VoidCallback? onProfileUpdated;
  final VoidCallback? onSignOut;

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
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _MyAddressesScreen(initialAddress: currentAddress),
      ),
    );
    if (mounted) {
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
    return DefaultTextStyle.merge(
      style: const TextStyle(decoration: TextDecoration.none),
      child: ColoredBox(
        color: _backgroundColor(context),
        child: Column(
          children: [
            if (widget.showHeader)
              _SettingsHeader(title: 'Settings', onBack: _goBack),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
                      children: [
                        if (widget.showAppearance) ...[
                          _SettingsSection(
                            title: 'Appearance',
                            children: [
                              _SettingsMenuRow(
                                icon: widget.isDarkMode
                                    ? Icons.dark_mode_outlined
                                    : Icons.light_mode_outlined,
                                title: 'Dark Mode',
                                subtitle: widget.isDarkMode
                                    ? 'Dark appearance is enabled'
                                    : 'Light appearance is enabled',
                                trailing: Switch(
                                  value: widget.isDarkMode,
                                  onChanged: widget.onThemeToggle,
                                  activeThumbColor: AppColors.primary,
                                ),
                                onTap: () => widget.onThemeToggle?.call(
                                  !widget.isDarkMode,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                        _SettingsSection(
                          title: 'My Account',
                          children: [
                            _SettingsMenuRow(
                              icon: Icons.shield_outlined,
                              title: 'Account & Security',
                              subtitle:
                                  'Email, password, and account protection',
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
                        if (widget.showSignOut) ...[
                          const SizedBox(height: 24),
                          _SettingsSection(
                            title: 'Account',
                            children: [
                              _SettingsMenuRow(
                                icon: Icons.logout_rounded,
                                title: 'Sign Out',
                                subtitle: 'Sign out of the operator portal',
                                foregroundColor: AppColors.error,
                                showChevron: false,
                                onTap: widget.onSignOut ?? () {},
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
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
              decoration: TextDecoration.none,
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
              decoration: TextDecoration.none,
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
    this.trailing,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? foregroundColor;
  final Widget? trailing;
  final bool showChevron;
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
                          decoration: TextDecoration.none,
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
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (trailing != null)
                  trailing!
                else if (showChevron)
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
  bool _isSavingMpin = false;
  bool _mpinEnabled = false;
  String _mpinHash = '';
  String _mpinSalt = '';

  @override
  void initState() {
    super.initState();
    final metadata = AuthService().currentUser?.userMetadata;
    _mpinEnabled = metadata?['mpin_enabled'] == true;
    _mpinHash = metadata?['mpin_hash']?.toString() ?? '';
    _mpinSalt = metadata?['mpin_salt']?.toString() ?? '';
  }

  bool get _hasMpin =>
      _mpinEnabled && _mpinHash.isNotEmpty && _mpinSalt.isNotEmpty;

  String _hashMpin(String mpin, String salt) {
    return sha256.convert(utf8.encode('$salt:$mpin')).toString();
  }

  bool _matchesCurrentMpin(String mpin) {
    return _mpinSalt.isNotEmpty &&
        _mpinHash.isNotEmpty &&
        _hashMpin(mpin, _mpinSalt) == _mpinHash;
  }

  String _newMpinSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  Future<void> _configureMpin() async {
    final wasConfigured = _hasMpin;
    final result = await showDialog<_MpinSetupResult>(
      context: context,
      builder: (_) => _MpinSetupDialog(requiresCurrentMpin: wasConfigured),
    );
    if (result == null || !mounted) return;
    if (wasConfigured && !_matchesCurrentMpin(result.currentMpin ?? '')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The current MPIN is incorrect.')),
      );
      return;
    }

    setState(() => _isSavingMpin = true);
    try {
      final user = AuthService().currentUser;
      if (user == null) throw Exception('No signed-in user found');
      final salt = _newMpinSalt();
      final hash = _hashMpin(result.newMpin, salt);
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            ...?user.userMetadata,
            'mpin_enabled': true,
            'mpin_salt': salt,
            'mpin_hash': hash,
            'mpin_updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        ),
      );
      if (!mounted) return;
      setState(() {
        _mpinEnabled = true;
        _mpinSalt = salt;
        _mpinHash = hash;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasConfigured ? 'MPIN updated successfully.' : 'MPIN set.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update MPIN: $error')));
    } finally {
      if (mounted) setState(() => _isSavingMpin = false);
    }
  }

  Future<void> _removeMpin() async {
    final currentMpin = await showDialog<String>(
      context: context,
      builder: (_) => const _CurrentMpinDialog(),
    );
    if (currentMpin == null || !mounted) return;
    if (!_matchesCurrentMpin(currentMpin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The current MPIN is incorrect.')),
      );
      return;
    }

    setState(() => _isSavingMpin = true);
    try {
      final user = AuthService().currentUser;
      if (user == null) throw Exception('No signed-in user found');
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            ...?user.userMetadata,
            'mpin_enabled': false,
            'mpin_hash': null,
            'mpin_salt': null,
            'mpin_updated_at': null,
          },
        ),
      );
      if (!mounted) return;
      setState(() {
        _mpinEnabled = false;
        _mpinHash = '';
        _mpinSalt = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MPIN removed.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not remove MPIN: $error')));
    } finally {
      if (mounted) setState(() => _isSavingMpin = false);
    }
  }

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
          const SizedBox(height: 12),
          _DetailCard(
            icon: Icons.pin_outlined,
            title: 'MPIN',
            subtitle: _hasMpin
                ? 'A 6-digit MPIN protects sensitive account actions.'
                : 'Set a 6-digit MPIN for additional account protection.',
            action: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _isSavingMpin ? null : _configureMpin,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: _isSavingMpin
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(_hasMpin ? 'Change MPIN' : 'Set MPIN'),
                ),
                if (_hasMpin)
                  OutlinedButton(
                    onPressed: _isSavingMpin ? null : _removeMpin,
                    child: const Text('Remove'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MpinSetupResult {
  const _MpinSetupResult({required this.newMpin, this.currentMpin});

  final String newMpin;
  final String? currentMpin;
}

class _MpinSetupDialog extends StatefulWidget {
  const _MpinSetupDialog({required this.requiresCurrentMpin});

  final bool requiresCurrentMpin;

  @override
  State<_MpinSetupDialog> createState() => _MpinSetupDialogState();
}

class _MpinSetupDialogState extends State<_MpinSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateMpin(String? value) {
    final pin = value?.trim() ?? '';
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) return 'Enter exactly 6 digits.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    Widget pinField(
      TextEditingController controller,
      String label, {
      String? Function(String?)? validator,
    }) {
      return TextFormField(
        controller: controller,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label, counterText: ''),
        validator: validator ?? _validateMpin,
      );
    }

    return AlertDialog(
      title: Text(widget.requiresCurrentMpin ? 'Change MPIN' : 'Set MPIN'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.requiresCurrentMpin) ...[
                pinField(_currentController, 'Current 6-digit MPIN'),
                const SizedBox(height: 10),
              ],
              pinField(_newController, 'New 6-digit MPIN'),
              const SizedBox(height: 10),
              pinField(
                _confirmController,
                'Confirm new MPIN',
                validator: (value) {
                  final validation = _validateMpin(value);
                  if (validation != null) return validation;
                  return value == _newController.text
                      ? null
                      : 'MPINs do not match.';
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(
              _MpinSetupResult(
                currentMpin: widget.requiresCurrentMpin
                    ? _currentController.text
                    : null,
                newMpin: _newController.text,
              ),
            );
          },
          child: const Text('Save MPIN'),
        ),
      ],
    );
  }
}

class _CurrentMpinDialog extends StatefulWidget {
  const _CurrentMpinDialog();

  @override
  State<_CurrentMpinDialog> createState() => _CurrentMpinDialogState();
}

class _CurrentMpinDialogState extends State<_CurrentMpinDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Remove MPIN'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Current 6-digit MPIN',
            counterText: '',
          ),
          validator: (value) => RegExp(r'^\d{6}$').hasMatch(value ?? '')
              ? null
              : 'Enter exactly 6 digits.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(_controller.text);
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Remove MPIN'),
        ),
      ],
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
  List<Map<String, dynamic>> _addresses = [];
  int _defaultIndex = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;
    final saved = user?.userMetadata?['saved_addresses'];
    if (saved is List) {
      _addresses = saved
          .whereType<Map>()
          .map((entry) {
            return entry.map((key, value) => MapEntry(key.toString(), value));
          })
          .where((entry) {
            return (entry['address']?.toString().trim() ?? '').isNotEmpty;
          })
          .toList();
    }

    if (widget.initialAddress.trim().isNotEmpty &&
        !_addresses.any(
          (entry) =>
              entry['address']?.toString().trim() ==
              widget.initialAddress.trim(),
        )) {
      _addresses.insert(0, {
        'label': 'Home',
        'recipient_name': _firstText([
          user?.userMetadata?['full_name'],
          user?.userMetadata?['name'],
        ]),
        'phone': _firstText([
          user?.userMetadata?['phone_number'],
          user?.userMetadata?['phone'],
        ]),
        'address': widget.initialAddress.trim(),
        'is_default': true,
      });
    }

    final savedDefault = _addresses.indexWhere(
      (entry) => entry['is_default'] == true,
    );
    _defaultIndex = savedDefault < 0 ? 0 : savedDefault;
  }

  Future<bool> _persistAddresses(
    List<Map<String, dynamic>> addresses,
    int defaultIndex,
  ) async {
    final user = AuthService().currentUser;
    if (user == null || addresses.isEmpty) return false;

    final safeDefaultIndex = defaultIndex.clamp(0, addresses.length - 1);
    final normalized = <Map<String, dynamic>>[
      for (var index = 0; index < addresses.length; index++)
        {...addresses[index], 'is_default': index == safeDefaultIndex},
    ];
    final defaultAddress =
        normalized[safeDefaultIndex]['address']?.toString().trim() ?? '';

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('users')
          .update({'location': defaultAddress})
          .eq('id', user.id);
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            ...?user.userMetadata,
            'saved_addresses': normalized,
            'default_address': defaultAddress,
            'location': defaultAddress,
            'address': defaultAddress,
          },
        ),
      );
      if (!mounted) return false;
      setState(() {
        _addresses = normalized;
        _defaultIndex = safeDefaultIndex;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update address: $error')),
      );
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectDefaultAddress(int index) async {
    if (_isSaving || index == _defaultIndex) return;
    final saved = await _persistAddresses(
      List<Map<String, dynamic>>.from(_addresses),
      index,
    );
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Default address updated'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _openAddressEditor({int? index}) async {
    if (_isSaving) return;
    final user = AuthService().currentUser;
    final existing = index == null ? null : _addresses[index];
    final formKey = GlobalKey<FormState>();
    final recipientController = TextEditingController(
      text:
          existing?['recipient_name']?.toString() ??
          _firstText([
            user?.userMetadata?['full_name'],
            user?.userMetadata?['name'],
          ]),
    );
    final phoneController = TextEditingController(
      text:
          existing?['phone']?.toString() ??
          _firstText([
            user?.userMetadata?['phone_number'],
            user?.userMetadata?['phone'],
          ]),
    );
    final addressController = TextEditingController(
      text: existing?['address']?.toString() ?? '',
    );
    var label = existing?['label']?.toString() ?? 'Home';
    var setAsDefault = index == null
        ? _addresses.isEmpty
        : index == _defaultIndex;

    InputDecoration decoration(String labelText, IconData icon) {
      return InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: _backgroundColor(context),
        labelStyle: TextStyle(color: _secondaryTextColor(context)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _borderColor(context),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      index == null ? 'Add New Address' : 'Edit Address',
                      style: TextStyle(
                        color: _primaryTextColor(context),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: label,
                      dropdownColor: _surfaceColor(context),
                      style: TextStyle(color: _primaryTextColor(context)),
                      decoration: decoration(
                        'Address label',
                        Icons.bookmark_border_rounded,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Home', child: Text('Home')),
                        DropdownMenuItem(value: 'Work', child: Text('Work')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) => label = value ?? 'Home',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: recipientController,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(color: _primaryTextColor(context)),
                      decoration: decoration(
                        'Recipient full name',
                        Icons.person_outline_rounded,
                      ),
                      validator: (value) => value?.trim().isEmpty == true
                          ? 'Enter the recipient name.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                      style: TextStyle(color: _primaryTextColor(context)),
                      decoration: decoration(
                        'Mobile number',
                        Icons.phone_outlined,
                      ).copyWith(counterText: ''),
                      validator: (value) {
                        final phone = value?.trim() ?? '';
                        return RegExp(r'^09\d{9}$').hasMatch(phone)
                            ? null
                            : 'Use an 11-digit mobile number starting with 09.';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressController,
                      minLines: 3,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(color: _primaryTextColor(context)),
                      decoration:
                          decoration(
                            'Complete address',
                            Icons.location_on_outlined,
                          ).copyWith(
                            hintText:
                                'House number, street, barangay, city, province',
                          ),
                      validator: (value) => (value?.trim().length ?? 0) < 10
                          ? 'Enter a complete address.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeTrackColor: AppColors.primary,
                      value: setAsDefault,
                      title: Text(
                        'Set as default address',
                        style: TextStyle(
                          color: _primaryTextColor(context),
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      onChanged: (value) {
                        setSheetState(() => setAsDefault = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        if (formKey.currentState?.validate() != true) return;
                        Navigator.pop(sheetContext, {
                          'label': label,
                          'recipient_name': recipientController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'address': addressController.text.trim(),
                          'is_default': setAsDefault,
                        });
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text('Save Address'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    recipientController.dispose();
    phoneController.dispose();
    addressController.dispose();
    if (!mounted || result == null) return;

    final updated = List<Map<String, dynamic>>.from(_addresses);
    final resultIndex = index ?? updated.length;
    if (index == null) {
      updated.add(result);
    } else {
      updated[index] = result;
    }
    final nextDefault = result['is_default'] == true
        ? resultIndex
        : _defaultIndex.clamp(0, updated.length - 1);
    final saved = await _persistAddresses(updated, nextDefault);
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(index == null ? 'Address added' : 'Address updated'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailScaffold(
      title: 'Address Selection',
      child: Column(
        children: [
          Expanded(
            child: _addresses.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.location_off_outlined,
                              color: AppColors.primary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No saved addresses yet',
                            style: TextStyle(
                              color: _primaryTextColor(context),
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Add an address and set it as your default for faster bookings.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _secondaryTextColor(context),
                              height: 1.4,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                    itemCount: _addresses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final address = _addresses[index];
                      final selected = index == _defaultIndex;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _selectDefaultAddress(index),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _surfaceColor(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : _borderColor(context),
                                width: selected ? 1.4 : 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 9),
                                  child: Icon(
                                    selected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: selected
                                        ? AppColors.primary
                                        : _secondaryTextColor(context),
                                    size: 23,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              address['recipient_name']
                                                          ?.toString()
                                                          .trim()
                                                          .isNotEmpty ==
                                                      true
                                                  ? address['recipient_name']
                                                        .toString()
                                                  : address['label']
                                                            ?.toString() ??
                                                        'Saved Address',
                                              style: TextStyle(
                                                color: _primaryTextColor(
                                                  context,
                                                ),
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: _isSaving
                                                ? null
                                                : () => _openAddressEditor(
                                                    index: index,
                                                  ),
                                            child: const Text('Edit'),
                                          ),
                                        ],
                                      ),
                                      if ((address['phone']
                                                  ?.toString()
                                                  .trim() ??
                                              '')
                                          .isNotEmpty)
                                        Text(
                                          address['phone'].toString(),
                                          style: TextStyle(
                                            color: _secondaryTextColor(context),
                                            fontSize: 12,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      const SizedBox(height: 7),
                                      Text(
                                        address['address']?.toString() ?? '',
                                        style: TextStyle(
                                          color: _primaryTextColor(context),
                                          fontSize: 13,
                                          height: 1.35,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _AddressBadge(
                                            label:
                                                address['label']?.toString() ??
                                                'Address',
                                          ),
                                          if (selected)
                                            const _AddressBadge(
                                              label: 'Default',
                                              emphasized: true,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            decoration: BoxDecoration(
              color: _surfaceColor(context),
              border: Border(top: BorderSide(color: _borderColor(context))),
            ),
            child: SafeArea(
              top: false,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _openAddressEditor,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.3),
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
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.add_rounded),
                label: const Text('Add a New Address'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressBadge extends StatelessWidget {
  const _AddressBadge({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: emphasized ? AppColors.primary : _borderColor(context),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: emphasized ? AppColors.primary : _secondaryTextColor(context),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
        ),
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
