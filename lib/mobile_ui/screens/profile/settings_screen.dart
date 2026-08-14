import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/auth_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/image_optimization_service.dart';
import '../../../services/reservation_payment_service.dart';
import '../../../services/support_faq_service.dart';
import '../../../services/terms_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/leaflet_map.dart';
import '../../widgets/location_picker_modal.dart';
import 'legal_terms_privacy_screen.dart';
import 'ratings_reviews_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.onThemeToggle,
    this.isDarkMode = true,
    this.showHeader = true,
    this.showAppearance = false,
    this.showSignOut = false,
    this.operatorMode = false,
    this.adminMode = false,
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
  final bool operatorMode;
  final bool adminMode;
  final VoidCallback? onBack;
  final VoidCallback? onOpenSupport;
  final VoidCallback? onProfileUpdated;
  final VoidCallback? onSignOut;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic> _profile = const {};
  final Map<String, bool> _operatorPreferences = {};
  String _role = 'renter';
  bool _isLoading = true;
  String _operatorWorkingHours = '8:00 AM - 5:00 PM';
  String _operatorLanguage = 'English';
  Set<String> _operatorVehicleCategories = const {
    'Sedan',
    'SUV',
    'Van',
    'Pickup',
  };

  int _activeWebTab = 0;
  late final TextEditingController _webNameController = TextEditingController();
  late final TextEditingController _webPhoneController =
      TextEditingController();
  late final TextEditingController _webPositionController =
      TextEditingController();
  bool _isSavingWebProfile = false;

  // Admin System Controllers & State
  final TextEditingController _termsOfServiceController =
      TextEditingController();
  bool _isLoadingTermsOfService = false;
  bool _isSavingTermsOfService = false;

  final TextEditingController _rentalTermsController = TextEditingController();
  bool _isLoadingTerms = false;
  bool _isSavingTerms = false;

  final TextEditingController _privacyPolicyController =
      TextEditingController();
  bool _isLoadingPrivacy = false;
  bool _isSavingPrivacy = false;

  final TextEditingController _reservationAmountController =
      TextEditingController();
  final TextEditingController _reservationAccountNameController =
      TextEditingController();
  final TextEditingController _reservationQrUrlController =
      TextEditingController();
  final TextEditingController _reservationInstructionsController =
      TextEditingController();
  bool _isLoadingReservationPayment = false;
  bool _isSavingReservationPayment = false;
  bool _isUploadingReservationQr = false;
  bool _isDeletingReservationQr = false;

  String _supportFaqRole = 'renter';
  Map<String, List<SupportFaq>> _supportFaqsByRole = {};
  bool _isLoadingSupportFaqs = false;
  bool _isSavingSupportFaqs = false;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  @override
  void dispose() {
    _webNameController.dispose();
    _webPhoneController.dispose();
    _webPositionController.dispose();
    _termsOfServiceController.dispose();
    _rentalTermsController.dispose();
    _privacyPolicyController.dispose();
    _reservationAmountController.dispose();
    _reservationAccountNameController.dispose();
    _reservationQrUrlController.dispose();
    _reservationInstructionsController.dispose();
    super.dispose();
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
        _webNameController.text = _operatorFullName;
        _webPhoneController.text = _operatorPhone;
        _webPositionController.text = _operatorPosition;
      });
      if (widget.operatorMode || widget.adminMode)
        await _loadOperatorPreferences();
      if (widget.adminMode) {
        await Future.wait([
          _loadTermsOfService(),
          _loadRentalTerms(),
          _loadPrivacyPolicy(),
          _loadReservationPaymentSettings(),
          _loadSupportFaqSettings(),
        ]);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOperatorPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final entry in const <String, bool>{
        'operator_notify_new_booking': true,
        'operator_notify_cancellation': true,
        'operator_notify_payment': true,
        'operator_notify_driver_assignment': true,
        'operator_online_status': true,
        'operator_vacation_leave': false,
        'operator_auto_accept': false,
        'operator_manual_approval': true,
      }.entries) {
        _operatorPreferences[entry.key] =
            preferences.getBool(entry.key) ?? entry.value;
      }
      _operatorWorkingHours =
          preferences.getString('operator_working_hours') ??
          '8:00 AM - 5:00 PM';
      _operatorLanguage =
          preferences.getString('operator_language') ?? 'English';
      _operatorVehicleCategories =
          (preferences.getStringList('operator_vehicle_categories') ??
                  const ['Sedan', 'SUV', 'Van', 'Pickup'])
              .toSet();
    });
  }

  Future<void> _setOperatorPreference(String key, bool value) async {
    setState(() {
      _operatorPreferences[key] = value;
      if (key == 'operator_auto_accept' && value) {
        _operatorPreferences['operator_manual_approval'] = false;
      } else if (key == 'operator_manual_approval' && value) {
        _operatorPreferences['operator_auto_accept'] = false;
      }
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, value);
    if (key == 'operator_auto_accept' && value) {
      await preferences.setBool('operator_manual_approval', false);
    } else if (key == 'operator_manual_approval' && value) {
      await preferences.setBool('operator_auto_accept', false);
    }
  }

  // --- ADMIN SETTINGS API METHODS ---
  Future<void> _loadTermsOfService() async {
    setState(() => _isLoadingTermsOfService = true);
    try {
      final terms = await TermsService().getTermsOfService();
      if (!mounted) return;
      _termsOfServiceController.text = terms;
    } catch (e) {
      debugPrint('Error loading terms of service: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTermsOfService = false);
    }
  }

  Future<void> _saveTermsOfService() async {
    setState(() => _isSavingTermsOfService = true);
    try {
      await TermsService().updateTermsOfService(_termsOfServiceController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terms of Service updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update Terms of Service: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingTermsOfService = false);
    }
  }

  Future<void> _loadRentalTerms() async {
    setState(() => _isLoadingTerms = true);
    try {
      final terms = await TermsService().getRentalTerms();
      if (!mounted) return;
      _rentalTermsController.text = terms;
    } catch (e) {
      debugPrint('Error loading rental terms: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTerms = false);
    }
  }

  Future<void> _saveRentalTerms() async {
    setState(() => _isSavingTerms = true);
    try {
      await TermsService().updateRentalTerms(_rentalTermsController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rental terms updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update rental terms: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingTerms = false);
    }
  }

  Future<void> _loadPrivacyPolicy() async {
    setState(() => _isLoadingPrivacy = true);
    try {
      final privacy = await TermsService().getPrivacyPolicy();
      if (!mounted) return;
      _privacyPolicyController.text = privacy;
    } catch (e) {
      debugPrint('Error loading privacy policy: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPrivacy = false);
    }
  }

  Future<void> _savePrivacyPolicy() async {
    setState(() => _isSavingPrivacy = true);
    try {
      await TermsService().updatePrivacyPolicy(_privacyPolicyController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Privacy policy updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update privacy policy: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingPrivacy = false);
    }
  }

  Future<void> _loadReservationPaymentSettings() async {
    setState(() => _isLoadingReservationPayment = true);
    try {
      final settings = await ReservationPaymentService().getSettings();
      if (!mounted) return;
      _reservationAmountController.text = settings.amount.toStringAsFixed(0);
      _reservationQrUrlController.text = settings.qrUrl;
      _reservationAccountNameController.text = settings.accountName;
      _reservationInstructionsController.text = settings.instructions;
    } catch (e) {
      debugPrint('Error loading reservation payment settings: $e');
    } finally {
      if (mounted) setState(() => _isLoadingReservationPayment = false);
    }
  }

  Future<void> _saveReservationPaymentSettings() async {
    final amount =
        double.tryParse(_reservationAmountController.text.trim()) ?? 0;
    setState(() => _isSavingReservationPayment = true);
    try {
      await ReservationPaymentService().updateSettings(
        amount: amount,
        qrUrl: _reservationQrUrlController.text,
        accountName: _reservationAccountNameController.text,
        instructions: _reservationInstructionsController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reservation payment settings updated'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update reservation payment settings: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingReservationPayment = false);
    }
  }

  Future<void> _uploadReservationPaymentQr() async {
    setState(() => _isUploadingReservationQr = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (picked == null) return;

      final qrUrl = await ReservationPaymentService().uploadQrCode(
        file: picked,
      );
      if (!mounted) return;
      setState(() => _reservationQrUrlController.text = qrUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reservation QR uploaded. Save settings to publish it.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to upload reservation QR: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingReservationQr = false);
    }
  }

  Future<void> _deleteReservationPaymentQr() async {
    final currentQrUrl = _reservationQrUrlController.text.trim();
    if (currentQrUrl.isEmpty || _isDeletingReservationQr) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surfaceColor(context),
        title: Text(
          'Delete Payment QR?',
          style: TextStyle(color: _primaryTextColor(context)),
        ),
        content: Text(
          'This will remove the current QR from payment settings. Renters cannot submit reservation payment until a new QR is uploaded.',
          style: TextStyle(color: _secondaryTextColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    setState(() => _isDeletingReservationQr = true);
    try {
      final service = ReservationPaymentService();
      await service.deleteQrCode(currentQrUrl);
      await service.updateSettings(
        amount: double.tryParse(_reservationAmountController.text.trim()) ?? 0,
        qrUrl: '',
        accountName: _reservationAccountNameController.text,
        instructions: _reservationInstructionsController.text,
      );
      if (!mounted) return;
      setState(() => _reservationQrUrlController.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment QR code deleted'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete QR code: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeletingReservationQr = false);
    }
  }

  Future<void> _loadSupportFaqSettings() async {
    if (mounted) setState(() => _isLoadingSupportFaqs = true);
    try {
      final faqs = await SupportFaqService().getAllFaqs();
      if (!mounted) return;
      setState(() => _supportFaqsByRole = faqs);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load support FAQs: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingSupportFaqs = false);
    }
  }

  Future<void> _saveSupportFaqSettings() async {
    final faqs = _supportFaqsByRole[_supportFaqRole] ?? const <SupportFaq>[];
    if (faqs.isEmpty || _isSavingSupportFaqs) return;
    setState(() => _isSavingSupportFaqs = true);
    try {
      await SupportFaqService().updateFaqs(_supportFaqRole, faqs);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer support auto-replies updated.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save support FAQs: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingSupportFaqs = false);
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
    if (widget.operatorMode) {
      await _showOperatorSettingsModal(
        title: 'Account & Security',
        icon: Icons.security_rounded,
        child: const _AccountSecurityScreen(embedded: true),
      );
      return;
    }
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
    if (widget.operatorMode) {
      _showOperatorSettingsModal(
        title: 'Privacy Settings',
        icon: Icons.privacy_tip_outlined,
        child: const _PreferenceSettingsScreen(
          title: 'Privacy Settings',
          description: 'Control optional data and location preferences.',
          embedded: true,
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
      );
      return;
    }
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

  Future<T?> _showOperatorSettingsModal<T>({
    required String title,
    required IconData icon,
    required Widget child,
    double maxWidth = 760,
  }) {
    final size = MediaQuery.sizeOf(context);
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (dialogContext) => Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: size.width < 720 ? 14 : 40,
          vertical: size.height < 720 ? 12 : 28,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: size.height * 0.86,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Material(
              color: _surfaceColor(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(icon, color: AppColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: _primaryTextColor(context),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: Icon(
                            Icons.close_rounded,
                            color: _primaryTextColor(context),
                          ),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: _borderColor(context)),
                  Flexible(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openOperatorRatingsModal() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    _showOperatorSettingsModal(
      title: 'Operator Ratings & Reviews',
      icon: Icons.star_outline_rounded,
      maxWidth: 820,
      child: RatingsReviewsScreen(
        userId: userId,
        title: 'Operator Ratings & Reviews',
        embedded: true,
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

  void _openTerms() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalTermsPrivacyScreen(
          initialTab: 'terms',
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );
  }

  void _openPrivacyPolicy() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalTermsPrivacyScreen(
          initialTab: 'privacy',
          isDarkMode: widget.isDarkMode,
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

  String get _operatorFullName => _firstText([
    _profile['full_name'],
    _profile['name'],
    AuthService().currentUser?.userMetadata?['full_name'],
    AuthService().currentUser?.userMetadata?['name'],
  ]);

  String get _operatorPhone => _firstText([
    _profile['phone'],
    AuthService().currentUser?.userMetadata?['phone'],
  ]);

  String get _operatorEmail =>
      _firstText([AuthService().currentUser?.email, _profile['email']]);

  String get _operatorPosition => _firstText([
    AuthService().currentUser?.userMetadata?['position'],
    _profile['position'],
    'Operations Desk',
  ]);

  String get _operatorAvatarUrl => _firstText([
    _profile['avatar_url'],
    _profile['profile_picture_url'],
    AuthService().currentUser?.userMetadata?['avatar_url'],
    AuthService().currentUser?.userMetadata?['profile_picture_url'],
    AuthService().currentUser?.userMetadata?['picture'],
  ]);

  Future<void> _editOperatorProfile() async {
    final nameController = TextEditingController(text: _operatorFullName);
    final phoneController = TextEditingController(text: _operatorPhone);
    final positionController = TextEditingController(text: _operatorPosition);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Profile Settings'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'Enter the operator name.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Contact Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    helperText: 'Use an 11-digit Philippine mobile number.',
                  ),
                  validator: (value) {
                    final phone = value?.trim() ?? '';
                    if (phone.isEmpty) return 'Enter a contact number.';
                    if (phone.length != 11) {
                      return 'Contact number must be 11 digits.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: positionController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Position',
                    prefixIcon: Icon(Icons.work_outline_rounded),
                  ),
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'Enter the operator position.'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(dialogContext, {
                'full_name': nameController.text.trim(),
                'phone': phoneController.text.trim(),
                'position': positionController.text.trim(),
              });
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
    nameController.dispose();
    phoneController.dispose();
    positionController.dispose();
    if (result == null || !mounted) return;

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No signed-in operator found.');
      await supabase
          .from('users')
          .update({
            'name': result['full_name'],
            'full_name': result['full_name'],
            'phone': result['phone'],
          })
          .eq('id', user.id);
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            ...?user.userMetadata,
            'full_name': result['full_name'],
            'name': result['full_name'],
            'phone': result['phone'],
            'position': result['position'],
          },
        ),
      );
      await _loadAccount();
      widget.onProfileUpdated?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operator profile updated.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update profile: $error')),
      );
    }
  }

  Future<void> _changeOperatorEmail() async {
    final controller = TextEditingController(text: _operatorEmail);
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Email'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'New email address',
              prefixIcon: Icon(Icons.alternate_email_rounded),
              helperText: 'A confirmation link may be sent to the new address.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Enter a valid email address.')),
                );
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Update Email'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email == _operatorEmail || !mounted) return;
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: email),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Confirm the email change using the link sent to $email.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not change email: $error')));
    }
  }

  Future<void> _uploadOperatorProfilePicture() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.single;
    final rawBytes = file?.bytes;
    if (file == null || rawBytes == null || !mounted) return;
    if (rawBytes.lengthInBytes > 8 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose an image smaller than 8 MB.')),
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No signed-in operator found.');
      final extension = (file.extension ?? 'jpg').toLowerCase();
      final safeExtension =
          const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
          ? extension
          : 'jpg';
      final objectPath =
          'profile_pictures/${user.id}/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
      final bytes = await ImageOptimizationService.optimizeForUpload(
        rawBytes,
        fileName: file.name,
        preset: UploadImagePreset.profile,
      );
      await supabase.storage
          .from('id_images')
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '31536000',
              upsert: true,
              contentType: safeExtension == 'png'
                  ? 'image/png'
                  : safeExtension == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg',
            ),
          );
      final publicUrl = supabase.storage
          .from('id_images')
          .getPublicUrl(objectPath);
      await supabase
          .from('users')
          .update({'avatar_url': publicUrl, 'profile_picture_url': publicUrl})
          .eq('id', user.id);
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            ...?user.userMetadata,
            'avatar_url': publicUrl,
            'profile_picture_url': publicUrl,
          },
        ),
      );
      await _loadAccount();
      widget.onProfileUpdated?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload profile picture: $error')),
      );
    }
  }

  Future<void> _editOperatorWorkingHours() async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Select work start time',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 17, minute: 0),
      helpText: 'Select work end time',
    );
    if (end == null || !mounted) return;
    final hours =
        '${MaterialLocalizations.of(context).formatTimeOfDay(start)} - ${MaterialLocalizations.of(context).formatTimeOfDay(end)}';
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('operator_working_hours', hours);
    if (mounted) setState(() => _operatorWorkingHours = hours);
  }

  Future<void> _editOperatorCategories() async {
    final selected = <String>{..._operatorVehicleCategories};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Preferred Vehicle Categories'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final category in const [
                  'Sedan',
                  'SUV',
                  'Van',
                  'Pickup',
                  'Hatchback',
                  'Luxury',
                ])
                  FilterChip(
                    label: Text(category),
                    selected: selected.contains(category),
                    onSelected: (value) => setDialogState(() {
                      value
                          ? selected.add(category)
                          : selected.remove(category);
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, selected),
              child: const Text('Save Categories'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'operator_vehicle_categories',
      result.toList()..sort(),
    );
    if (mounted) setState(() => _operatorVehicleCategories = result);
  }

  Future<void> _changeOperatorLanguage() async {
    final language = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Language'),
        children: [
          for (final value in const ['English', 'Filipino'])
            ListTile(
              leading: Icon(
                value == _operatorLanguage
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: value == _operatorLanguage ? AppColors.primary : null,
              ),
              title: Text(value),
              onTap: () => Navigator.pop(dialogContext, value),
            ),
        ],
      ),
    );
    if (language == null || !mounted) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('operator_language', language);
    if (mounted) setState(() => _operatorLanguage = language);
  }

  void _showOperatorSecurityInfo(String title, String description) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _logoutAllOperatorDevices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout All Devices?'),
        content: const Text(
          'Every active operator session will be signed out. You will need to log in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout All'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await Supabase.instance.client.auth.signOut();
    widget.onSignOut?.call();
  }

  Widget _operatorToggle(String key, {bool defaultValue = false}) {
    return Switch(
      value: _operatorPreferences[key] ?? defaultValue,
      onChanged: (value) => _setOperatorPreference(key, value),
      activeThumbColor: AppColors.primary,
    );
  }

  Future<void> _saveInlineWebProfile() async {
    if (_isSavingWebProfile) return;
    setState(() => _isSavingWebProfile = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No signed-in operator found.');
      final newName = _webNameController.text.trim();
      final newPhone = _webPhoneController.text.trim();
      final newPos = _webPositionController.text.trim();

      if (newName.isEmpty) throw Exception('Name cannot be empty.');
      if (newPhone.length != 11)
        throw Exception('Contact number must be 11 digits.');

      await supabase
          .from('users')
          .update({'name': newName, 'full_name': newName, 'phone': newPhone})
          .eq('id', user.id);

      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            ...?user.userMetadata,
            'full_name': newName,
            'name': newName,
            'phone': newPhone,
            'position': newPos,
          },
        ),
      );
      await _loadAccount();
      widget.onProfileUpdated?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operator profile updated successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSavingWebProfile = false);
    }
  }

  Widget _buildOperatorSettings() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 840;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1360),
            child: Padding(
              padding: EdgeInsets.all(isWide ? 28.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWebHeaderCard(isDark),
                  const SizedBox(height: 20),
                  Expanded(
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 260,
                                child: _buildWebSidebarNav(isDark),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: _buildWebTabContent(isDark),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _buildWebHorizontalTabs(isDark),
                              const SizedBox(height: 16),
                              Expanded(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                    children: [
                                      _buildWebTabContent(isDark),
                                      const SizedBox(height: 20),
                                      _buildOperatorSignOutCard(),
                                    ],
                                  ),
                                ),
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
    );
  }

  Widget _buildWebHeaderCard(bool isDark) {
    final isOnline = _operatorPreferences['operator_online_status'] ?? true;
    final titleText = widget.adminMode ? 'Admin Settings' : 'Operator Settings';
    final badgeText = widget.adminMode ? 'Super Admin' : 'Console Admin';
    final subtitleText = widget.adminMode
        ? 'Manage administrator profile, system policies, reservation payment rules, FAQ auto-replies, notifications, and portal settings.'
        : 'Manage profile, workflow preferences, security, notifications, and support.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor(context)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              widget.adminMode
                  ? Icons.admin_panel_settings_rounded
                  : Icons.tune_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      titleText,
                      style: TextStyle(
                        color: _primaryTextColor(context),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_user_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            badgeText,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitleText,
                  style: TextStyle(
                    color: _secondaryTextColor(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Header Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isOnline
                  ? AppColors.success.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOnline
                    ? AppColors.success.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOnline ? AppColors.success : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: isOnline
                        ? AppColors.success
                        : _secondaryTextColor(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: isOnline,
                    onChanged: (val) =>
                        _setOperatorPreference('operator_online_status', val),
                    activeThumbColor: AppColors.success,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminAllSettingsPage(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWebAppearanceTabContent(isDark),
        const SizedBox(height: 24),
        _buildWebRentalTermsTabContent(isDark),
        const SizedBox(height: 24),
        _buildWebReservationPaymentTabContent(isDark),
        const SizedBox(height: 24),
        _buildWebFaqTabContent(isDark),
        const SizedBox(height: 24),
        _buildWebProfileTabContent(isDark),
        const SizedBox(height: 24),
        _buildWebWorkflowTabContent(isDark),
        const SizedBox(height: 24),
        _buildWebNotificationsTabContent(isDark),
        const SizedBox(height: 24),
        _buildWebSecurityTabContent(isDark),
        const SizedBox(height: 24),
        _buildWebSupportTabContent(isDark),
      ],
    );
  }

  Widget _buildWebSidebarNav(bool isDark) {
    final tabs = widget.adminMode
        ? [
            _WebCategoryItem(
              0,
              'All Admin Settings',
              Icons.space_dashboard_outlined,
              'Full view of all settings',
            ),
            _WebCategoryItem(
              1,
              'Appearance & Theme',
              Icons.palette_outlined,
              'Dark mode & portal theme',
            ),
            _WebCategoryItem(
              2,
              'Rental Agreement Policies',
              Icons.description_outlined,
              'Booking agreement text',
            ),
            _WebCategoryItem(
              3,
              'Reservation & Payments',
              Icons.payments_outlined,
              'Deposit fee & QR uploader',
            ),
            _WebCategoryItem(
              4,
              'FAQ Auto-Replies',
              Icons.question_answer_outlined,
              'Customer support bot replies',
            ),
            _WebCategoryItem(
              5,
              'Profile & Credentials',
              Icons.badge_outlined,
              'Admin details & position',
            ),
            _WebCategoryItem(
              6,
              'Workflow & System Rules',
              Icons.tune_rounded,
              'Auto-approval & operating mode',
            ),
            _WebCategoryItem(
              7,
              'Notifications & Alerts',
              Icons.notifications_none_rounded,
              'System & audit alerts',
            ),
            _WebCategoryItem(
              8,
              'Account & Security',
              Icons.shield_outlined,
              'Password & credentials',
            ),
            _WebCategoryItem(
              9,
              'Ratings & System Legal',
              Icons.help_outline_rounded,
              'Reviews, terms & help',
            ),
          ]
        : [
            _WebCategoryItem(
              0,
              'Profile & Identity',
              Icons.badge_outlined,
              'Avatar, details & role',
            ),
            _WebCategoryItem(
              1,
              'Workflow & Availability',
              Icons.tune_rounded,
              'Status, hours & vehicles',
            ),
            _WebCategoryItem(
              2,
              'Notifications',
              Icons.notifications_none_rounded,
              'Operational alerts',
            ),
            _WebCategoryItem(
              3,
              'Account & Security',
              Icons.shield_outlined,
              'Password & email',
            ),
            _WebCategoryItem(
              4,
              'Appearance & Theme',
              Icons.palette_outlined,
              'Dark mode & display',
            ),
            _WebCategoryItem(
              5,
              'Support & System',
              Icons.help_outline_rounded,
              'Help center & info',
            ),
          ];

    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              'SETTINGS',
              style: TextStyle(
                color: _secondaryTextColor(context),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                children: [
                  ...tabs.map((tab) {
                    final isSelected = _activeWebTab == tab.id;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      child: widget.adminMode
                          ? _buildAdminSettingsNavItem(tab, isDark, isSelected)
                          : Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _activeWebTab = tab.id),
                                borderRadius: BorderRadius.circular(12),
                                hoverColor: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withValues(
                                            alpha: 0.14,
                                          )
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? Border.all(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.3,
                                            ),
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      if (isSelected)
                                        Container(
                                          width: 3.5,
                                          height: 18,
                                          margin: const EdgeInsets.only(
                                            right: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      Icon(
                                        tab.icon,
                                        size: 20,
                                        color: isSelected
                                            ? AppColors.primary
                                            : _secondaryTextColor(context),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tab.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? (isDark
                                                          ? Colors.white
                                                          : Colors.black87)
                                                    : _primaryTextColor(
                                                        context,
                                                      ),
                                                fontSize: 13,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              tab.subtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: _secondaryTextColor(
                                                  context,
                                                ),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          widget.adminMode
              ? _buildAdminSignOutCard()
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onSignOut ?? () {},
                      borderRadius: BorderRadius.circular(12),
                      hoverColor: AppColors.error.withValues(alpha: 0.1),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 50),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              size: 18,
                              color: AppColors.error,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Sign Out Operator',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildAdminSignOutCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
      child: Semantics(
        button: true,
        label: 'Sign out of Admin portal',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: widget.onSignOut ?? () {},
              borderRadius: BorderRadius.circular(12),
              hoverColor: AppColors.error.withValues(alpha: 0.1),
              child: Container(
                constraints: const BoxConstraints(minHeight: 62),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sign Out Admin',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Leave the admin portal securely',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                      color: AppColors.error,
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

  Widget _buildDefaultSettingsNavItem(
    _WebCategoryItem tab,
    bool isDark,
    bool isSelected,
  ) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() => _activeWebTab = tab.id),
        borderRadius: BorderRadius.circular(12),
        hoverColor: AppColors.primary.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            children: [
              if (isSelected)
                Container(
                  width: 3.5,
                  height: 18,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Icon(
                tab.icon,
                size: 20,
                color: isSelected
                    ? AppColors.primary
                    : _secondaryTextColor(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tab.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black87)
                            : _primaryTextColor(context),
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    Text(
                      tab.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminSettingsNavItem(
    _WebCategoryItem tab,
    bool isDark,
    bool isSelected,
  ) {
    final isWorkflow = tab.id == 6;
    return Semantics(
      button: true,
      label: 'Open ${tab.title}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => setState(() => _activeWebTab = tab.id),
            mouseCursor: SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(12),
            hoverColor: AppColors.primary.withValues(alpha: 0.08),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  if (isSelected)
                    Container(
                      width: 3.5,
                      height: 18,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  Icon(
                    tab.icon,
                    size: 20,
                    color: isSelected || isWorkflow
                        ? AppColors.primary
                        : _secondaryTextColor(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tab.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? (isDark ? Colors.white : Colors.black87)
                                : isWorkflow
                                ? AppColors.primary
                                : _primaryTextColor(context),
                            fontSize: 13,
                            fontWeight: isSelected || isWorkflow
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        Text(
                          tab.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _secondaryTextColor(context),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: isSelected || isWorkflow
                        ? AppColors.primary
                        : _secondaryTextColor(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebHorizontalTabs(bool isDark) {
    final tabs = widget.adminMode
        ? [
            _WebCategoryItem(
              0,
              'All Settings',
              Icons.space_dashboard_outlined,
              '',
            ),
            _WebCategoryItem(1, 'Appearance', Icons.palette_outlined, ''),
            _WebCategoryItem(
              2,
              'Rental Agreement',
              Icons.description_outlined,
              '',
            ),
            _WebCategoryItem(3, 'Payments', Icons.payments_outlined, ''),
            _WebCategoryItem(
              4,
              'FAQ Auto-Replies',
              Icons.question_answer_outlined,
              '',
            ),
            _WebCategoryItem(5, 'Profile', Icons.badge_outlined, ''),
            _WebCategoryItem(6, 'Workflow', Icons.tune_rounded, ''),
            _WebCategoryItem(
              7,
              'Notifications',
              Icons.notifications_none_rounded,
              '',
            ),
            _WebCategoryItem(8, 'Security', Icons.shield_outlined, ''),
            _WebCategoryItem(
              9,
              'Support & Legal',
              Icons.help_outline_rounded,
              '',
            ),
          ]
        : [
            _WebCategoryItem(0, 'Profile', Icons.badge_outlined, ''),
            _WebCategoryItem(1, 'Workflow', Icons.tune_rounded, ''),
            _WebCategoryItem(
              2,
              'Notifications',
              Icons.notifications_none_rounded,
              '',
            ),
            _WebCategoryItem(3, 'Security', Icons.shield_outlined, ''),
            _WebCategoryItem(4, 'Appearance', Icons.palette_outlined, ''),
            _WebCategoryItem(5, 'Support', Icons.help_outline_rounded, ''),
          ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _activeWebTab == tab.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tab.icon,
                    size: 16,
                    color: isSelected
                        ? AppColors.primary
                        : _secondaryTextColor(context),
                  ),
                  const SizedBox(width: 6),
                  Text(tab.title),
                ],
              ),
              selectedColor: AppColors.primary.withValues(alpha: 0.16),
              backgroundColor: _surfaceColor(context),
              labelStyle: TextStyle(
                color: isSelected
                    ? AppColors.primary
                    : _primaryTextColor(context),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              onSelected: (_) => setState(() => _activeWebTab = tab.id),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWebTabContent(bool isDark) {
    if (widget.adminMode) {
      switch (_activeWebTab) {
        case 0:
          return _buildAdminAllSettingsPage(isDark);
        case 1:
          return _buildWebAppearanceTabContent(isDark);
        case 2:
          return _buildWebRentalTermsTabContent(isDark);
        case 3:
          return _buildWebReservationPaymentTabContent(isDark);
        case 4:
          return _buildWebFaqTabContent(isDark);
        case 5:
          return _buildWebProfileTabContent(isDark);
        case 6:
          return _buildWebWorkflowTabContent(isDark);
        case 7:
          return _buildWebNotificationsTabContent(isDark);
        case 8:
          return _buildWebSecurityTabContent(isDark);
        case 9:
          return _buildWebSupportTabContent(isDark);
        default:
          return _buildAdminAllSettingsPage(isDark);
      }
    }

    switch (_activeWebTab) {
      case 0:
        return _buildWebProfileTabContent(isDark);
      case 1:
        return _buildWebWorkflowTabContent(isDark);
      case 2:
        return _buildWebNotificationsTabContent(isDark);
      case 3:
        return _buildWebSecurityTabContent(isDark);
      case 4:
        return _buildWebAppearanceTabContent(isDark);
      case 5:
        return _buildWebSupportTabContent(isDark);
      default:
        return _buildWebProfileTabContent(isDark);
    }
  }

  Widget _buildOperatorSignOutCard() {
    return _SettingsSection(
      title: 'Account',
      children: [
        _SettingsMenuRow(
          icon: Icons.logout_rounded,
          title: 'Sign Out',
          subtitle: widget.adminMode
              ? 'Leave the admin portal securely'
              : 'Leave the operator portal securely',
          foregroundColor: AppColors.error,
          showChevron: false,
          onTap: widget.onSignOut ?? () {},
        ),
      ],
    );
  }

  // --- TAB 0: PROFILE & IDENTITY ---
  Widget _buildWebProfileTabContent(bool isDark) {
    final avatar = _operatorAvatarUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar Hero Banner Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: avatar.isEmpty
                        ? const Icon(
                            Icons.person_outline_rounded,
                            size: 40,
                            color: AppColors.primary,
                          )
                        : Image.network(
                            avatar,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.person_outline_rounded,
                              size: 40,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _surfaceColor(context),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _operatorFullName.isEmpty
                          ? 'Operator Desk'
                          : _operatorFullName,
                      style: TextStyle(
                        color: _primaryTextColor(context),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildBadgeChip(
                          Icons.work_outline_rounded,
                          _operatorPosition,
                        ),
                        _buildBadgeChip(
                          Icons.alternate_email_rounded,
                          _operatorEmail,
                        ),
                        _buildBadgeChip(
                          Icons.star_rounded,
                          '4.9 Operator Rating',
                          isGold: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: _uploadOperatorProfilePicture,
                    icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                    label: const Text('Upload Photo'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _editOperatorProfile,
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Edit Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryTextColor(context),
                      side: BorderSide(color: _borderColor(context)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Personal Details Web Form Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Personal Credentials',
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Update your display name, contact phone number, and position title.',
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, box) {
                  final isTwoCol = box.maxWidth > 550;
                  return Column(
                    children: [
                      if (isTwoCol)
                        Row(
                          children: [
                            Expanded(
                              child: _buildWebTextField(
                                'Full Name',
                                _webNameController,
                                Icons.person_outline_rounded,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildWebTextField(
                                'Position',
                                _webPositionController,
                                Icons.work_outline_rounded,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildWebTextField(
                          'Full Name',
                          _webNameController,
                          Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 14),
                        _buildWebTextField(
                          'Position',
                          _webPositionController,
                          Icons.work_outline_rounded,
                        ),
                      ],
                      const SizedBox(height: 14),
                      if (isTwoCol)
                        Row(
                          children: [
                            Expanded(
                              child: _buildWebTextField(
                                'Contact Number',
                                _webPhoneController,
                                Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildWebTextField(
                                'Email Address (Login)',
                                TextEditingController(text: _operatorEmail),
                                Icons.alternate_email_rounded,
                                readOnly: true,
                                suffixWidget: TextButton(
                                  onPressed: _changeOperatorEmail,
                                  child: const Text('Change'),
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildWebTextField(
                          'Contact Number',
                          _webPhoneController,
                          Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        _buildWebTextField(
                          'Email Address (Login)',
                          TextEditingController(text: _operatorEmail),
                          Icons.alternate_email_rounded,
                          readOnly: true,
                          suffixWidget: TextButton(
                            onPressed: _changeOperatorEmail,
                            child: const Text('Change'),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _isSavingWebProfile ? null : _saveInlineWebProfile,
                  icon: _isSavingWebProfile
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                  label: Text(
                    _isSavingWebProfile ? 'Saving...' : 'Save Profile Changes',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Ratings & Reviews Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                  size: 30,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trip Ratings & Renter Reviews',
                      style: TextStyle(
                        color: _primaryTextColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View performance feedback and completed trip ratings from renters.',
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _openOperatorRatingsModal,
                icon: const Icon(Icons.reviews_outlined, size: 16),
                label: const Text('View All Reviews'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryTextColor(context),
                  side: BorderSide(color: _borderColor(context)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 1 (ADMIN): RENTAL TERMS & POLICIES ---
  Widget _buildWebRentalTermsTabContent(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.gavel_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terms of Service',
                          style: TextStyle(
                            color: _primaryTextColor(context),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'General system-wide rules for every Mobilis user. Keep this separate from the Rental Agreement.',
                          style: TextStyle(
                            color: _secondaryTextColor(context),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _termsOfServiceController,
                minLines: 10,
                maxLines: 18,
                enabled: !_isLoadingTermsOfService && !_isSavingTermsOfService,
                style: TextStyle(
                  color: _primaryTextColor(context),
                  height: 1.45,
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Add headings, numbered sections, responsibilities, prohibited activities, and general platform rules...',
                  hintStyle: TextStyle(color: _secondaryTextColor(context)),
                  filled: true,
                  fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
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
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  if (_isLoadingTermsOfService)
                    Text(
                      'Loading Terms of Service...',
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 13,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed:
                        _isLoadingTermsOfService || _isSavingTermsOfService
                        ? null
                        : _loadTermsOfService,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reload'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryTextColor(context),
                      side: BorderSide(color: _borderColor(context)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed:
                        _isLoadingTermsOfService || _isSavingTermsOfService
                        ? null
                        : _saveTermsOfService,
                    icon: _isSavingTermsOfService
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _isSavingTermsOfService
                          ? 'Saving...'
                          : 'Save Terms of Service',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Rental Agreement Policies',
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'This separate agreement is shown to renters before booking requests are finalized. It is not the system-wide Terms of Service.',
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _rentalTermsController,
                minLines: 8,
                maxLines: 14,
                enabled: !_isLoadingTerms && !_isSavingTerms,
                style: TextStyle(
                  color: _primaryTextColor(context),
                  height: 1.4,
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter rental terms and policies...',
                  hintStyle: TextStyle(color: _secondaryTextColor(context)),
                  filled: true,
                  fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
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
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_isLoadingTerms)
                    Text(
                      'Loading current terms...',
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 13,
                      ),
                    ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _isLoadingTerms || _isSavingTerms
                        ? null
                        : _loadRentalTerms,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reload'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryTextColor(context),
                      side: BorderSide(color: _borderColor(context)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isLoadingTerms || _isSavingTerms
                        ? null
                        : _saveRentalTerms,
                    icon: _isSavingTerms
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_isSavingTerms ? 'Saving...' : 'Save Terms'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Privacy Policy Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkBgSecondary
                : AppColors.lightBgSecondary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.privacy_tip_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primaryTextColor(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'This text is displayed in the Privacy Policy section for users and renters detailing data usage, identity verification, location tracking, and security.',
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _privacyPolicyController,
                minLines: 8,
                maxLines: 14,
                enabled: !_isLoadingPrivacy && !_isSavingPrivacy,
                style: TextStyle(
                  color: _primaryTextColor(context),
                  height: 1.4,
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter privacy policy content...',
                  hintStyle: TextStyle(color: _secondaryTextColor(context)),
                  filled: true,
                  fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
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
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_isLoadingPrivacy)
                    Text(
                      'Loading privacy policy...',
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 13,
                      ),
                    ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _isLoadingPrivacy || _isSavingPrivacy
                        ? null
                        : _loadPrivacyPolicy,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reload'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryTextColor(context),
                      side: BorderSide(color: _borderColor(context)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isLoadingPrivacy || _isSavingPrivacy
                        ? null
                        : _savePrivacyPolicy,
                    icon: _isSavingPrivacy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _isSavingPrivacy ? 'Saving...' : 'Save Privacy Policy',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 2 (ADMIN): RESERVATION & PAYMENTS ---
  Widget _buildWebReservationPaymentTabContent(bool isDark) {
    final hasQr = _reservationQrUrlController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Refundable Reservation Payment Rules',
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Configure the refundable reservation deposit and payment instructions shown to renters during booking request creation.',
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, box) {
                  final isTwoCol = box.maxWidth > 550;
                  return Column(
                    children: [
                      if (isTwoCol)
                        Row(
                          children: [
                            Expanded(
                              child: _buildWebTextField(
                                'Reservation Fee Amount (₱)',
                                _reservationAmountController,
                                Icons.payments_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildWebTextField(
                                'Account / Payee Name',
                                _reservationAccountNameController,
                                Icons.account_balance_outlined,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildWebTextField(
                          'Reservation Fee Amount (₱)',
                          _reservationAmountController,
                          Icons.payments_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),
                        _buildWebTextField(
                          'Account / Payee Name',
                          _reservationAccountNameController,
                          Icons.account_balance_outlined,
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Payment QR Code Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _borderColor(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkBgSecondary
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _borderColor(context)),
                      ),
                      child: hasQr
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _reservationQrUrlController.text.trim(),
                                width: 90,
                                height: 90,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.error,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.qr_code_2_rounded,
                              color: AppColors.textTertiary,
                              size: 42,
                            ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment QR Code Image',
                            style: TextStyle(
                              color: _primaryTextColor(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasQr
                                ? 'QR Code uploaded. Renters can scan this to pay the reservation fee.'
                                : 'No Payment QR uploaded yet. Upload a QR code image to enable instant scan-to-pay.',
                            style: TextStyle(
                              color: _secondaryTextColor(context),
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    _isLoadingReservationPayment ||
                                        _isSavingReservationPayment ||
                                        _isUploadingReservationQr ||
                                        _isDeletingReservationQr
                                    ? null
                                    : _uploadReservationPaymentQr,
                                icon: _isUploadingReservationQr
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.upload_file_rounded,
                                        size: 16,
                                      ),
                                label: Text(
                                  _isUploadingReservationQr
                                      ? 'Uploading...'
                                      : hasQr
                                      ? 'Replace QR Image'
                                      : 'Upload QR Image',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _primaryTextColor(context),
                                  side: BorderSide(
                                    color: _borderColor(context),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              if (hasQr)
                                OutlinedButton.icon(
                                  onPressed:
                                      _isLoadingReservationPayment ||
                                          _isSavingReservationPayment ||
                                          _isUploadingReservationQr ||
                                          _isDeletingReservationQr
                                      ? null
                                      : _deleteReservationPaymentQr,
                                  icon: _isDeletingReservationQr
                                      ? const SizedBox(
                                          width: 15,
                                          height: 15,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 16,
                                        ),
                                  label: Text(
                                    _isDeletingReservationQr
                                        ? 'Deleting...'
                                        : 'Delete QR',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: BorderSide(
                                      color: AppColors.error.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Payment Instructions Textarea
              Text(
                'Payment Instructions Shown to Renters',
                style: TextStyle(
                  color: _primaryTextColor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reservationInstructionsController,
                minLines: 3,
                maxLines: 5,
                enabled:
                    !_isLoadingReservationPayment &&
                    !_isSavingReservationPayment,
                style: TextStyle(
                  color: _primaryTextColor(context),
                  height: 1.4,
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Enter payment steps and screenshot instructions...',
                  hintStyle: TextStyle(color: _secondaryTextColor(context)),
                  filled: true,
                  fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
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
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_isLoadingReservationPayment)
                    Text(
                      'Loading payment settings...',
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 13,
                      ),
                    ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed:
                        _isLoadingReservationPayment ||
                            _isSavingReservationPayment
                        ? null
                        : _loadReservationPaymentSettings,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reload'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryTextColor(context),
                      side: BorderSide(color: _borderColor(context)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed:
                        _isLoadingReservationPayment ||
                            _isSavingReservationPayment
                        ? null
                        : _saveReservationPaymentSettings,
                    icon: _isSavingReservationPayment
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _isSavingReservationPayment
                          ? 'Saving...'
                          : 'Save Payment Settings',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addNewFaqQuestion() {
    setState(() {
      final currentList = List<SupportFaq>.from(
        _supportFaqsByRole[_supportFaqRole] ?? [],
      );
      final newKey = 'custom_${DateTime.now().millisecondsSinceEpoch}';
      currentList.add(
        SupportFaq(
          key: newKey,
          question:
              'New Question for ${_supportFaqRole[0].toUpperCase()}${_supportFaqRole.substring(1)}s',
          answer: 'Enter automatic reply here...',
        ),
      );
      _supportFaqsByRole[_supportFaqRole] = currentList;
    });
  }

  void _removeFaqQuestion(int index) {
    setState(() {
      final currentList = List<SupportFaq>.from(
        _supportFaqsByRole[_supportFaqRole] ?? [],
      );
      if (index >= 0 && index < currentList.length) {
        currentList.removeAt(index);
        _supportFaqsByRole[_supportFaqRole] = currentList;
      }
    });
  }

  // --- TAB 3 (ADMIN): CUSTOMER SUPPORT FAQ AUTO-REPLIES ---
  Widget _buildWebFaqTabContent(bool isDark) {
    final faqs = _supportFaqsByRole[_supportFaqRole] ?? const <SupportFaq>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.question_answer_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Customer Support FAQ Auto-Replies',
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Configure automated responses, questions, and answers shown to Renters, Partners, and Drivers in Customer Support.',
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),

              // Role Tabs Selection Chips & Add Button
              Row(
                children: [
                  Wrap(
                    spacing: 10,
                    children: [
                      for (final roleOption in const [
                        {'key': 'renter', 'label': 'Renter Support'},
                        {'key': 'partner', 'label': 'Partner Support'},
                        {'key': 'driver', 'label': 'Driver Support'},
                      ])
                        ChoiceChip(
                          selected: _supportFaqRole == roleOption['key'],
                          label: Text(roleOption['label']!),
                          selectedColor: AppColors.primary.withValues(
                            alpha: 0.16,
                          ),
                          backgroundColor: isDark
                              ? AppColors.darkBg
                              : AppColors.lightBg,
                          labelStyle: TextStyle(
                            color: _supportFaqRole == roleOption['key']
                                ? AppColors.primary
                                : _primaryTextColor(context),
                            fontWeight: _supportFaqRole == roleOption['key']
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                          onSelected: (_) {
                            setState(
                              () => _supportFaqRole = roleOption['key']!,
                            );
                          },
                        ),
                    ],
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _isLoadingSupportFaqs || _isSavingSupportFaqs
                        ? null
                        : _addNewFaqQuestion,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add FAQ Question'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // FAQ Items List
              if (_isLoadingSupportFaqs)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (faqs.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _borderColor(context)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        size: 36,
                        color: _secondaryTextColor(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No FAQ questions configured for ${_supportFaqRole}s.',
                        style: TextStyle(
                          color: _primaryTextColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _addNewFaqQuestion,
                        icon: const Icon(Icons.add),
                        label: const Text('Add First FAQ'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...faqs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final faq = entry.value;
                  return Container(
                    key: ValueKey('${_supportFaqRole}_${faq.key}_$index'),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBg : AppColors.lightBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _borderColor(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'FAQ #${index + 1}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: _isSavingSupportFaqs
                                  ? null
                                  : () => _removeFaqQuestion(index),
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red.shade400,
                              tooltip: 'Delete FAQ',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          initialValue: faq.question,
                          enabled: !_isSavingSupportFaqs,
                          onChanged: (value) {
                            _supportFaqsByRole[_supportFaqRole]![index] = faq
                                .copyWith(question: value);
                          },
                          style: TextStyle(
                            color: _primaryTextColor(context),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Question',
                            hintText: 'Enter customer question...',
                            filled: true,
                            fillColor: _surfaceColor(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _borderColor(context),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _borderColor(context),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: faq.answer,
                          minLines: 2,
                          maxLines: 4,
                          enabled: !_isSavingSupportFaqs,
                          onChanged: (value) {
                            _supportFaqsByRole[_supportFaqRole]![index] = faq
                                .copyWith(answer: value);
                          },
                          style: TextStyle(
                            color: _primaryTextColor(context),
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Automated Answer Text',
                            hintText: 'Enter response shown to users...',
                            filled: true,
                            fillColor: _surfaceColor(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _borderColor(context),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _borderColor(context),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isLoadingSupportFaqs || _isSavingSupportFaqs
                        ? null
                        : _addNewFaqQuestion,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Another Question'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryTextColor(context),
                      side: BorderSide(color: _borderColor(context)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _isLoadingSupportFaqs || _isSavingSupportFaqs
                        ? null
                        : _loadSupportFaqSettings,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reload Defaults'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryTextColor(context),
                      side: BorderSide(color: _borderColor(context)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed:
                        _isLoadingSupportFaqs ||
                            _isSavingSupportFaqs ||
                            faqs.isEmpty
                        ? null
                        : _saveSupportFaqSettings,
                    icon: _isSavingSupportFaqs
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _isSavingSupportFaqs ? 'Saving...' : 'Save Auto-Replies',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 1: WORKFLOW & AVAILABILITY ---
  Widget _buildWebWorkflowTabContent(bool isDark) {
    final isOnline = _operatorPreferences['operator_online_status'] ?? true;
    final isVacation = _operatorPreferences['operator_vacation_leave'] ?? false;
    final isAutoAccept = _operatorPreferences['operator_auto_accept'] ?? false;
    final isManualApprove =
        _operatorPreferences['operator_manual_approval'] ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Availability Status Panel
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.wifi_tethering_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Operational Status & Availability',
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Control whether your operator desk accepts real-time vehicle booking requests.',
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),

              // Switch Item 1: Online Status
              _buildWebSwitchTile(
                icon: Icons.power_settings_new_rounded,
                title: 'Online / Operating Status',
                subtitle: isOnline
                    ? '🟢 Online — Live and accepting booking requests'
                    : '🔴 Offline — Paused from accepting new bookings',
                value: isOnline,
                onChanged: (val) =>
                    _setOperatorPreference('operator_online_status', val),
              ),
              const Divider(height: 24),

              // Switch Item 2: Vacation Leave
              _buildWebSwitchTile(
                icon: Icons.beach_access_outlined,
                title: 'Vacation / Leave Pause Mode',
                subtitle: isVacation
                    ? '🏖️ Vacation Mode ON — New incoming requests are paused'
                    : 'Regular operations active',
                value: isVacation,
                onChanged: (val) =>
                    _setOperatorPreference('operator_vacation_leave', val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Operating Hours & Automation Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Operating Hours & Dispatch Automation',
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Configure working hours and automated approval modes for incoming trips.',
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),

              // Working Hours Selector Row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _borderColor(context)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_filled_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Console Operating Hours',
                            style: TextStyle(
                              color: _primaryTextColor(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _operatorWorkingHours,
                            style: TextStyle(
                              color: _secondaryTextColor(context),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _editOperatorWorkingHours,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Change Hours'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Switch Item: Auto Accept
              _buildWebSwitchTile(
                icon: Icons.bolt_rounded,
                title: 'Auto-Accept Incoming Bookings',
                subtitle:
                    'Automatically approve booking requests without manual confirmation',
                value: isAutoAccept,
                onChanged: (val) =>
                    _setOperatorPreference('operator_auto_accept', val),
              ),
              const Divider(height: 24),

              // Switch Item: Manual Approval
              _buildWebSwitchTile(
                icon: Icons.fact_check_outlined,
                title: 'Manual Booking Approval Mode',
                subtitle:
                    'Require operator verification for each booking before confirmation',
                value: isManualApprove,
                onChanged: (val) =>
                    _setOperatorPreference('operator_manual_approval', val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Vehicle Categories Preference Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Supported Vehicle Categories',
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _editOperatorCategories,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Manage Categories'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Vehicle types currently managed by your operator console.',
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _operatorVehicleCategories.map((cat) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cat,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
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

  // --- TAB 2: NOTIFICATIONS ---
  Widget _buildWebNotificationsTabContent(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Operational Alerts & Push Notifications',
                style: TextStyle(
                  color: _primaryTextColor(context),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Select which dispatch events trigger live audio and banner notifications on your browser.',
            style: TextStyle(color: _secondaryTextColor(context), fontSize: 13),
          ),
          const SizedBox(height: 24),

          _buildWebSwitchTile(
            icon: Icons.event_available_outlined,
            title: 'New Booking Request Alerts',
            subtitle:
                'Get notified immediately when a renter submits a new vehicle reservation',
            value: _operatorPreferences['operator_notify_new_booking'] ?? true,
            onChanged: (val) =>
                _setOperatorPreference('operator_notify_new_booking', val),
          ),
          const Divider(height: 24),

          _buildWebSwitchTile(
            icon: Icons.event_busy_outlined,
            title: 'Booking Cancellation & Refund Alerts',
            subtitle:
                'Receive instant alerts if a renter cancels or requests a booking modification',
            value: _operatorPreferences['operator_notify_cancellation'] ?? true,
            onChanged: (val) =>
                _setOperatorPreference('operator_notify_cancellation', val),
          ),
          const Divider(height: 24),

          _buildWebSwitchTile(
            icon: Icons.payments_outlined,
            title: 'Payment Receipt Submissions',
            subtitle:
                'Notifications when GCash / Bank transfer receipts are uploaded for verification',
            value: _operatorPreferences['operator_notify_payment'] ?? true,
            onChanged: (val) =>
                _setOperatorPreference('operator_notify_payment', val),
          ),
          const Divider(height: 24),

          _buildWebSwitchTile(
            icon: Icons.assignment_ind_outlined,
            title: 'Driver Assignment Updates',
            subtitle:
                'Alerts when assigned drivers accept, reject, or start scheduled trips',
            value:
                _operatorPreferences['operator_notify_driver_assignment'] ??
                true,
            onChanged: (val) => _setOperatorPreference(
              'operator_notify_driver_assignment',
              val,
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: ACCOUNT & SECURITY ---
  Widget _buildWebSecurityTabContent(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Password & Authentication Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.password_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password & Account Credentials',
                      style: TextStyle(
                        color: _primaryTextColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Send a secure password reset link to your operator email address.',
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: _openAccountSecurity,
                icon: const Icon(Icons.lock_reset_rounded, size: 16),
                label: const Text('Change Password'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Email Credentials Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  color: Colors.blue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operator Console Login Email',
                      style: TextStyle(
                        color: _primaryTextColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _operatorEmail,
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _changeOperatorEmail,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Update Email'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryTextColor(context),
                  side: BorderSide(color: _borderColor(context)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Security Role & Session Badge Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Console Access Level & Security',
                style: TextStyle(
                  color: _primaryTextColor(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildSecurityBadge(
                    'Operator Level 1 Access',
                    Icons.verified_user_outlined,
                  ),
                  const SizedBox(width: 12),
                  _buildSecurityBadge(
                    'Supabase JWT Auth',
                    Icons.security_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 4: APPEARANCE & THEME ---
  Widget _buildWebAppearanceTabContent(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.palette_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Console Color Theme',
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Choose your preferred visual theme for the operator management portal.',
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),

              // Side-by-side Visual Theme Selectors
              Row(
                children: [
                  // Dark Mode Card
                  Expanded(
                    child: _buildThemePreviewCard(
                      title: 'Dark Mode',
                      subtitle:
                          'Sleek dark theme optimized for long operational shifts.',
                      icon: Icons.dark_mode_outlined,
                      isSelected: isDark,
                      previewColor: const Color(0xFF141721),
                      onTap: () {
                        if (!isDark) widget.onThemeToggle?.call(true);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Light Mode Card
                  Expanded(
                    child: _buildThemePreviewCard(
                      title: 'Light Mode',
                      subtitle:
                          'High contrast light theme for bright environments.',
                      icon: Icons.light_mode_outlined,
                      isSelected: !isDark,
                      previewColor: const Color(0xFFF4F6FB),
                      onTap: () {
                        if (isDark) widget.onThemeToggle?.call(false);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Language Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.language_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portal Language',
                      style: TextStyle(
                        color: _primaryTextColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current selection: $_operatorLanguage',
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _changeOperatorLanguage,
                icon: const Icon(Icons.translate_rounded, size: 16),
                label: const Text('Change Language'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryTextColor(context),
                  side: BorderSide(color: _borderColor(context)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 5: SUPPORT & SYSTEM ---
  Widget _buildWebSupportTabContent(bool isDark) {
    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: [
            _buildSupportCard(
              icon: Icons.menu_book_rounded,
              title: 'Operator Help Center',
              subtitle: 'Read guidelines, policies & FAQs',
              buttonText: 'Open FAQs',
              onTap: _openHelpCentre,
            ),
            _buildSupportCard(
              icon: Icons.support_agent_rounded,
              title: 'Dispatch Admin Support',
              subtitle: 'Connect with admin team via chat',
              buttonText: 'Open Chat',
              onTap: () => widget.onOpenSupport?.call(),
            ),
            _buildSupportCard(
              icon: Icons.bug_report_outlined,
              title: 'Report Technical Bug',
              subtitle: 'Send a report to system support',
              buttonText: 'Report Issue',
              onTap: () => widget.onOpenSupport?.call(),
            ),
            _buildSupportCard(
              icon: Icons.info_outline_rounded,
              title: 'System Information',
              subtitle: 'Mobilis v1.0.0 (Web Build)',
              buttonText: 'View Terms',
              onTap: _openTerms,
            ),
          ],
        ),
      ],
    );
  }

  // --- HELPER SUB-WIDGETS FOR WEB UI ---
  Widget _buildWebSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _primaryTextColor(context),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildWebTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool readOnly = false,
    TextInputType? keyboardType,
    Widget? suffixWidget,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _primaryTextColor(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          style: TextStyle(color: _primaryTextColor(context), fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              size: 18,
              color: _secondaryTextColor(context),
            ),
            suffixIcon: suffixWidget,
            filled: true,
            fillColor: readOnly
                ? _borderColor(context).withValues(alpha: 0.2)
                : _surfaceColor(context),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
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
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemePreviewCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color previewColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : _borderColor(context),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: isSelected
                        ? AppColors.primary
                        : _secondaryTextColor(context),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.black,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 48,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: previewColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borderColor(context)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: _secondaryTextColor(context),
              fontSize: 12.5,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeChip(IconData icon, String label, {bool isGold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isGold
            ? Colors.amber.withValues(alpha: 0.14)
            : _borderColor(context).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: isGold
            ? Border.all(color: Colors.amber.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isGold ? Colors.amber : _secondaryTextColor(context),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: isGold ? Colors.amber : _secondaryTextColor(context),
              fontSize: 12,
              fontWeight: isGold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityBadge(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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
                  : widget.operatorMode
                  ? _buildOperatorSettings()
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
            boxShadow: Theme.of(context).brightness == Brightness.dark
                ? const []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
  const _SettingsDetailScaffold({
    required this.title,
    required this.child,
    this.embedded = false,
  });

  final String title;
  final Widget child;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    if (embedded) return child;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _backgroundColor(context),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: _surfaceColor(context),
        foregroundColor: _primaryTextColor(context),
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2837) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade300,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : Colors.black87,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
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
  const _AccountSecurityScreen({this.embedded = false});

  final bool embedded;

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

  Future<void> _showChangeEmailDialog() async {
    final newEmailController = TextEditingController();
    final currentEmail = AuthService().currentUser?.email ?? '';
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.darkBgSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.borderColor),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.alternate_email_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Change Email',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current: $currentEmail',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'New Email Address',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: newEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Enter new email address',
                      hintStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: AppColors.darkBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.borderColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.borderColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newEmail = newEmailController.text.trim();
                          if (newEmail.isEmpty || !newEmail.contains('@')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter a valid email address.',
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            await Supabase.instance.client.auth.updateUser(
                              UserAttributes(email: newEmail),
                            );
                            final userId = AuthService().currentUser?.id;
                            if (userId != null) {
                              await Supabase.instance.client
                                  .from('users')
                                  .update({'email': newEmail})
                                  .eq('id', userId);
                            }
                            if (!mounted) return;
                            Navigator.pop(dialogContext);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Confirmation link sent to new email. Please check your inbox.',
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error updating email: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Update Email',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
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

  Future<void> _configureMpin({bool isRecovery = false}) async {
    final wasConfigured = _hasMpin;
    if (isRecovery) {
      final identifier = await showDialog<String>(
        context: context,
        builder: (_) => const _AccountIdentifierDialog(
          title: 'Reset MPIN',
          description:
              'Enter the email or mobile number linked to this account before creating a new MPIN.',
        ),
      );
      if (identifier == null || !mounted) return;

      setState(() => _isSavingMpin = true);
      try {
        final matches = await AuthService().matchesCurrentAccountIdentifier(
          identifier,
        );
        if (!matches) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'That email or mobile number does not match this account.',
              ),
            ),
          );
          return;
        }
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not verify this account: ${AuthService().getErrorMessage(error)}',
            ),
          ),
        );
        return;
      } finally {
        if (mounted) setState(() => _isSavingMpin = false);
      }
    }

    if (!mounted) return;
    final result = await showDialog<_MpinSetupResult>(
      context: context,
      builder: (_) =>
          _MpinSetupDialog(requiresCurrentMpin: wasConfigured && !isRecovery),
    );
    if (result == null || !mounted) return;
    if (wasConfigured &&
        !isRecovery &&
        !_matchesCurrentMpin(result.currentMpin ?? '')) {
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
            wasConfigured && !isRecovery
                ? 'MPIN changed successfully.'
                : 'MPIN created successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update MPIN: ${AuthService().getErrorMessage(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingMpin = false);
    }
  }

  Future<void> _removeMpin() async {
    if (!_hasMpin) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        title: const Text(
          'Remove MPIN',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will remove your 6-digit MPIN protection.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSavingMpin = true);
    try {
      final user = AuthService().currentUser;
      if (user == null) throw Exception('No signed-in user found');
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            ...?user.userMetadata,
            'mpin_enabled': false,
            'mpin_salt': '',
            'mpin_hash': '',
            'mpin_updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        ),
      );
      if (!mounted) return;
      setState(() {
        _mpinEnabled = false;
        _mpinSalt = '';
        _mpinHash = '';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('MPIN protection removed.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not remove MPIN: ${AuthService().getErrorMessage(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingMpin = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = AuthService().currentUser?.email;
    if (email == null || email.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await AuthService().resetPassword(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
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
      embedded: widget.embedded,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _DetailCard(
            icon: Icons.alternate_email_rounded,
            title: 'Account Email',
            subtitle: email,
            action: FilledButton(
              onPressed: _showChangeEmailDialog,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Change Email',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
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
                  : const Text(
                      'Reset Password',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
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
              alignment: WrapAlignment.start,
              children: [
                FilledButton(
                  onPressed: _isSavingMpin ? null : _configureMpin,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isSavingMpin
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          _hasMpin ? 'Change MPIN' : 'Set MPIN',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
                if (_hasMpin)
                  OutlinedButton(
                    onPressed: _isSavingMpin ? null : _removeMpin,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Remove'),
                  ),
                if (_hasMpin)
                  TextButton(
                    onPressed: _isSavingMpin
                        ? null
                        : () => _configureMpin(isRecovery: true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Forgot MPIN?'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountIdentifierDialog extends StatefulWidget {
  const _AccountIdentifierDialog({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  State<_AccountIdentifierDialog> createState() =>
      _AccountIdentifierDialogState();
}

class _AccountIdentifierDialogState extends State<_AccountIdentifierDialog> {
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
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.description),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.text,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.telephoneNumber,
              ],
              decoration: const InputDecoration(
                labelText: 'Email or Mobile Number',
                hintText: 'name@gmail.com or 09XXXXXXXXX',
                prefixIcon: Icon(Icons.contact_mail_outlined),
              ),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? 'Enter your email or mobile number.'
                  : null,
            ),
          ],
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
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: const Text('Continue'),
        ),
      ],
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

    double? latitude = existing?['latitude'] is num
        ? (existing!['latitude'] as num).toDouble()
        : double.tryParse(existing?['latitude']?.toString() ?? '');
    double? longitude = existing?['longitude'] is num
        ? (existing!['longitude'] as num).toDouble()
        : double.tryParse(existing?['longitude']?.toString() ?? '');

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
                    // Map Location Pin Picker Button & Status Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _backgroundColor(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: latitude != null && longitude != null
                              ? AppColors.primary
                              : _borderColor(context),
                          width: latitude != null && longitude != null
                              ? 1.5
                              : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.pin_drop_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  latitude != null && longitude != null
                                      ? 'Location Pinned'
                                      : 'Pin Location on Map',
                                  style: TextStyle(
                                    color: _primaryTextColor(context),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  latitude != null && longitude != null
                                      ? 'GPS: ${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}'
                                      : 'Tap to pick location on map & auto-fill address',
                                  style: TextStyle(
                                    color: _secondaryTextColor(context),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final mapResult =
                                  await MobilisLocationPickerModal.show(
                                    context,
                                    title: 'Pin Address Location',
                                    subtitle:
                                        'Search an address or use your current location to set the exact pin.',
                                    confirmLabel: 'Confirm Pinned Location',
                                    initialAddress: addressController.text
                                        .trim(),
                                    initialLatitude: latitude,
                                    initialLongitude: longitude,
                                  );
                              if (mapResult != null) {
                                setSheetState(() {
                                  latitude = mapResult.latitude;
                                  longitude = mapResult.longitude;
                                  addressController.text = mapResult.address;
                                });
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: const BorderSide(color: AppColors.primary),
                              foregroundColor: AppColors.primary,
                            ),
                            icon: Icon(
                              latitude != null && longitude != null
                                  ? Icons.edit_location_alt_rounded
                                  : Icons.map_rounded,
                              size: 16,
                            ),
                            label: Text(
                              latitude != null && longitude != null
                                  ? 'Re-pin'
                                  : 'Pick Pin',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                          'latitude': latitude,
                          'longitude': longitude,
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
    this.embedded = false,
  });

  final String title;
  final String description;
  final List<_PreferenceItem> items;
  final bool embedded;

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
      embedded: widget.embedded,
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
                  'Mobilis',
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackAction = action != null && constraints.maxWidth < 390;
        final header = Row(
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
            if (action != null && !stackAction) ...[
              const SizedBox(width: 10),
              Flexible(child: action!),
            ],
          ],
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor(context)),
          ),
          child: stackAction
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerLeft, child: action!),
                  ],
                )
              : header,
        );
      },
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

class _WebCategoryItem {
  const _WebCategoryItem(this.id, this.title, this.icon, this.subtitle);
  final int id;
  final String title;
  final IconData icon;
  final String subtitle;
}

class _AddressMapPickerSheet extends StatefulWidget {
  const _AddressMapPickerSheet({
    this.initialLatitude,
    this.initialLongitude,
    required this.isDark,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final bool isDark;

  @override
  State<_AddressMapPickerSheet> createState() => _AddressMapPickerSheetState();
}

class _AddressMapPickerSheetState extends State<_AddressMapPickerSheet> {
  late LatLng _pinnedPosition;
  late final MapController _mapController;
  final TextEditingController _searchController = TextEditingController();
  String _geocodedAddress = '';
  bool _isGeocoding = false;
  bool _isLocating = false;

  static const double _defaultLat = 15.9758;
  static const double _defaultLng = 120.5719;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pinnedPosition = LatLng(
      widget.initialLatitude ?? _defaultLat,
      widget.initialLongitude ?? _defaultLng,
    );
    _reverseGeocode(_pinnedPosition);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    if (!mounted) return;
    setState(() => _isGeocoding = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts =
            [
                  place.street,
                  place.subLocality,
                  place.locality,
                  place.subAdministrativeArea,
                  place.administrativeArea,
                ]
                .where(
                  (p) =>
                      p != null &&
                      p.trim().isNotEmpty &&
                      p.trim() != 'Unnamed Road',
                )
                .join(', ');

        if (mounted) {
          setState(() {
            _geocodedAddress = parts.isNotEmpty
                ? parts
                : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
            _isGeocoding = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('[MapPicker] Reverse geocode error: $e');
    }
    if (mounted) {
      setState(() {
        _geocodedAddress =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        _isGeocoding = false;
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable GPS location services.'),
            ),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')),
            );
          }
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final newPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _pinnedPosition = newPos;
      });
      _mapController.move(newPos, 16.5);
      await _reverseGeocode(newPos);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not fetch current location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final newPos = LatLng(loc.latitude, loc.longitude);
        setState(() {
          _pinnedPosition = newPos;
        });
        _mapController.move(newPos, 16.0);
        await _reverseGeocode(newPos);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location not found. Try a different search.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? AppColors.darkBgSecondary : Colors.white;
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 12, 10),
            child: Row(
              children: [
                const Icon(Icons.pin_drop_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pin Address Location',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _searchAddress(),
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Search city, barangay, or street...',
                hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.primary,
                  ),
                  onPressed: _searchAddress,
                ),
                filled: true,
                fillColor: widget.isDark ? Colors.white10 : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              children: [
                MobilisLeafletMap(
                  mapController: _mapController,
                  fallbackLatitude: _pinnedPosition.latitude,
                  fallbackLongitude: _pinnedPosition.longitude,
                  initialZoom: 16.0,
                  interactive: true,
                  markers: [
                    MobilisMapMarker(
                      latitude: _pinnedPosition.latitude,
                      longitude: _pinnedPosition.longitude,
                      icon: Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 48,
                    ),
                  ],
                  onTap: (lat, lng) {
                    final newPos = LatLng(lat, lng);
                    setState(() {
                      _pinnedPosition = newPos;
                    });
                    _reverseGeocode(newPos);
                  },
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: FloatingActionButton.small(
                    heroTag: 'map_gps_btn',
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    onPressed: _isLocating ? null : _useCurrentLocation,
                    child: _isLocating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.my_location_rounded),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            decoration: BoxDecoration(
              color: bgColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _isGeocoding
                          ? const Text(
                              'Locating address...',
                              style: TextStyle(fontStyle: FontStyle.italic),
                            )
                          : Text(
                              _geocodedAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'latitude': _pinnedPosition.latitude,
                      'longitude': _pinnedPosition.longitude,
                      'address': _geocodedAddress,
                    });
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Confirm Pinned Location',
                    style: TextStyle(fontWeight: FontWeight.w800),
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
