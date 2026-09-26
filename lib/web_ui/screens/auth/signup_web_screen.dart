import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../mobile_ui/theme/app_colors.dart';
import '../../../mobile_ui/widgets/location_picker_modal.dart';
import '../../../services/auth_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/preferences_service.dart';
import '../../../utils/input_validation.dart';

class SignupWebScreen extends StatefulWidget {
  const SignupWebScreen({super.key});

  @override
  State<SignupWebScreen> createState() => _SignupWebScreenState();
}

class _SignupWebScreenState extends State<SignupWebScreen> {
  bool _nameTouched = false;
  bool _emailTouched = false;
  bool _phoneTouched = false;
  bool _locationTouched = false;
  bool _addressTouched = false;

  late TextEditingController fullNameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController locationController;
  late TextEditingController addressController;
  late TextEditingController passwordController;
  late TextEditingController confirmPasswordController;

  bool agreeToTerms = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;
  bool _isSubmitting = false;
  DateTime? _lastSubmitTime;
  String? selectedRole; // 'renter', 'partner', or 'driver'
  MobilisLocationSelection? _selectedLocation;

  @override
  void initState() {
    super.initState();
    fullNameController = TextEditingController();
    emailController = TextEditingController();
    phoneController = TextEditingController();
    locationController = TextEditingController();
    addressController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();
    _loadSavedFormData();
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    locationController.dispose();
    addressController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedFormData() async {
    try {
      final prefsService = PreferencesService();
      await prefsService.init();
      final formData = prefsService.getAllSignupFormData();

      if (mounted && formData.isNotEmpty) {
        setState(() {
          fullNameController.text = formData['fullName'] ?? '';
          emailController.text = formData['email'] ?? '';
          phoneController.text = formData['phone'] ?? '';
          locationController.text = formData['location'] ?? '';
          addressController.text = formData['address'] ?? '';
          selectedRole = formData['role'];
        });
      }
    } catch (e) {
      debugPrint('Error loading saved form data: $e');
    }
  }

  Future<void> _saveFormData() async {
    try {
      final prefsService = PreferencesService();
      await prefsService.init();
      await prefsService.saveAllSignupFormData({
        'fullName': fullNameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'location': locationController.text.trim(),
        'address': addressController.text.trim(),
        'role': selectedRole ?? '',
      });
    } catch (e) {
      debugPrint('Error saving form data: $e');
    }
  }

  String? get _nameError =>
      _nameTouched ? validatePersonName(fullNameController.text) : null;

  String? get _emailError =>
      _emailTouched ? validateEmailAddress(emailController.text) : null;

  String? get _phoneError =>
      _phoneTouched ? validatePhilippineMobile(phoneController.text) : null;

  String? get _locationError => _locationTouched
      ? validateRequiredText(
          locationController.text,
          fieldName: 'Location',
          minLength: 2,
        )
      : null;

  String? get _addressError => _addressTouched
      ? validateRequiredText(
          addressController.text,
          fieldName: 'Home address',
          minLength: 5,
        )
      : null;

  bool _passwordMeetsRequirements(String password) =>
      password.length >= 8 &&
      RegExp(r'[A-Z]').hasMatch(password) &&
      RegExp(r'[a-z]').hasMatch(password) &&
      RegExp(r'\d').hasMatch(password) &&
      RegExp(r'[^A-Za-z0-9]').hasMatch(password);

  Widget _buildLocationSection() {
    return _buildTextField(
      controller: locationController,
      hintText: 'Tap to choose your city or address',
      prefixIcon: Icons.location_on_outlined,
      readOnly: true,
      errorText: _locationError,
      onTap: _openLocationPicker,
      suffixIcon: IconButton(
        tooltip: 'Open map',
        icon: const Icon(Icons.map_outlined, color: AppColors.primary),
        onPressed: _openLocationPicker,
      ),
    );
  }

  Future<void> _openLocationPicker() async {
    setState(() => _locationTouched = true);
    final selection = await MobilisLocationPickerModal.show(
      context,
      title: 'Set your location',
      subtitle: 'Search an address or pin your location on the map.',
      confirmLabel: 'Use this location',
      initialAddress: locationController.text.trim().isNotEmpty
          ? locationController.text.trim()
          : addressController.text.trim(),
      initialLatitude: _selectedLocation?.latitude,
      initialLongitude: _selectedLocation?.longitude,
    );
    if (!mounted || selection == null) return;
    setState(() {
      _selectedLocation = selection;
      locationController.text = selection.address;
      if (addressController.text.trim().isEmpty) {
        addressController.text = selection.address;
        _addressTouched = true;
      }
    });
  }

  void _handleSignup() async {
    final now = DateTime.now();
    // Anti-spam guard: prevent rapid duplicate submissions
    if (isLoading || _isSubmitting) return;
    if (_lastSubmitTime != null &&
        now.difference(_lastSubmitTime!) < const Duration(milliseconds: 1500)) {
      return;
    }
    _lastSubmitTime = now;

    unawaited(_saveFormData());

    final connectivityService = ConnectivityService();
    if (!connectivityService.isOnline) {
      _showErrorSnackBar(
        'No internet connection. Please check your WiFi or mobile data.',
      );
      return;
    }

    if (selectedRole == null) {
      _showErrorSnackBar('Please select what you want to do with Mobilis');
      return;
    }

    setState(() {
      _nameTouched = true;
      _emailTouched = true;
      _phoneTouched = true;
      _locationTouched = true;
      _addressTouched = true;
    });

    if (_nameError != null ||
        _emailError != null ||
        _phoneError != null ||
        _locationError != null ||
        _addressError != null) {
      _showErrorSnackBar(
        _nameError ??
            _emailError ??
            _phoneError ??
            _locationError ??
            _addressError ??
            'Please fill in all required fields correctly',
      );
      return;
    }

    if (!_passwordMeetsRequirements(passwordController.text)) {
      _showErrorSnackBar('Password does not fulfill all requirements');
      setState(() {});
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      _showErrorSnackBar('Passwords do not match');
      setState(() {});
      return;
    }

    if (!agreeToTerms) {
      _showErrorSnackBar('Please agree to Terms of Service and Privacy Policy');
      return;
    }

    setState(() {
      isLoading = true;
      _isSubmitting = true;
    });

    try {
      final authService = AuthService();
      final fullName = toTitleCaseName(fullNameController.text);
      final normalizedPhone = normalizePhilippineMobile(phoneController.text);

      final response = await authService.signup(
        email: emailController.text.trim(),
        password: passwordController.text,
        userMetadata: {
          'full_name': fullName,
          'phone': normalizedPhone,
          'location': locationController.text.trim(),
          'address': addressController.text.trim(),
          'role': selectedRole,
        },
      );

      if (mounted && response.user != null) {
        final signupEmail = emailController.text.trim();
        fullNameController.clear();
        emailController.clear();
        phoneController.clear();
        locationController.clear();
        addressController.clear();
        passwordController.clear();
        confirmPasswordController.clear();

        // Clear saved form data asynchronously (non-blocking)
        PreferencesService().clearSignupFormData().catchError((e) {
          debugPrint('Error clearing saved form data: $e');
          return false;
        });

        // Navigate based on whether an active session was created
        if (response.session != null) {
          Navigator.of(context).pushReplacementNamed('/verification-options');
        } else {
          Navigator.of(context).pushReplacementNamed(
            '/email-confirmation',
            arguments: {'email': signupEmail},
          );
        }
      } else {
        _showErrorSnackBar('Account creation failed. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        final authService = AuthService();
        _showErrorSnackBar(authService.getErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          _isSubmitting = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildPasswordRequirement(String label, bool isMet) {
    final color = isMet ? AppColors.success : AppColors.textTertiary;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        prefixIcon: Icon(prefixIcon, color: AppColors.textTertiary),
        suffixIcon: suffixIcon,
        errorText: errorText,
        filled: true,
        fillColor: AppColors.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildAppNoticeBanner({required bool isCompact}) {
    if (isCompact) {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F2B5C), Color(0xFF081938)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x44FFD740)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.android_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Renters, Drivers & Partners',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Download the official Mobilis Android app for live GPS maps, vehicle rentals, and daily payouts.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(
                    'https://github.com/robinjay1123/mobilis_project/releases/download/APK/mobilis-app.apk',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.download, size: 16),
                label: const Text(
                  'Download Android APK',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: const Color(0xFF030A18),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2B5C), Color(0xFF081938)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x44FFD740)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.android_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Renters, Drivers & Partners use our Mobile App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Download the official Mobilis Android app for live GPS maps, vehicle rentals, and daily payouts.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () async {
              final uri = Uri.parse(
                'https://github.com/robinjay1123/mobilis_project/releases/download/APK/mobilis-app.apk',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: const Color(0xFF030A18),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Download APK',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required Widget icon,
    required String title,
    bool isCompact = false,
  }) {
    final isSelected = selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => selectedRole = role),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            vertical: isCompact ? 14 : 16,
            horizontal: isCompact ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.darkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderColor,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: isCompact ? 13 : 15,
                  color: isSelected ? Colors.black : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignupForm({required bool isCompact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Create Your Account',
          style: TextStyle(
            fontSize: isCompact ? 28 : 38,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Get started with Mobilis today. Join thousands of satisfied customers.',
          style: TextStyle(
            fontSize: isCompact ? 14 : 16,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        SizedBox(height: isCompact ? 22 : 32),

        // App Notice Banner
        _buildAppNoticeBanner(isCompact: isCompact),

        // Role Selection
        _buildLabel('What will you do on Mobilis?'),
        const SizedBox(height: 12),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildRoleCard(
                    role: 'renter',
                    icon: FaIcon(
                      FontAwesomeIcons.car,
                      color: selectedRole == 'renter'
                          ? Colors.black
                          : AppColors.textSecondary,
                      size: isCompact ? 26 : 30,
                    ),
                    title: 'Rent a Car',
                    isCompact: isCompact,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildRoleCard(
                    role: 'partner',
                    icon: FaIcon(
                      FontAwesomeIcons.building,
                      color: selectedRole == 'partner'
                          ? Colors.black
                          : AppColors.textSecondary,
                      size: isCompact ? 26 : 30,
                    ),
                    title: 'List a Car',
                    isCompact: isCompact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => selectedRole = 'driver'),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    vertical: isCompact ? 14 : 16,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: selectedRole == 'driver'
                        ? AppColors.primary
                        : AppColors.darkCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selectedRole == 'driver'
                          ? AppColors.primary
                          : AppColors.borderColor,
                      width: 2,
                    ),
                    boxShadow: selectedRole == 'driver'
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.userTie,
                        color: selectedRole == 'driver'
                            ? Colors.black
                            : AppColors.textSecondary,
                        size: isCompact ? 24 : 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Become a Driver',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isCompact ? 14 : 15,
                          color: selectedRole == 'driver'
                              ? Colors.black
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Full Name
        _buildLabel('Full Name'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: fullNameController,
          hintText: 'Enter your full name',
          prefixIcon: Icons.person_outline,
          errorText: _nameError,
          onChanged: (_) => setState(() => _nameTouched = true),
        ),
        const SizedBox(height: 20),

        // Email
        _buildLabel('Email Address'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: emailController,
          hintText: 'name@example.com',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          onChanged: (_) => setState(() => _emailTouched = true),
        ),
        const SizedBox(height: 20),

        // Phone
        _buildLabel('Phone Number'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: phoneController,
          hintText: '09XX XXX XXXX',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: philippineMobileInputFormatters,
          errorText: _phoneError,
          onChanged: (_) => setState(() => _phoneTouched = true),
        ),
        const SizedBox(height: 20),

        // Location
        _buildLabel('Location'),
        const SizedBox(height: 8),
        _buildLocationSection(),
        const SizedBox(height: 20),

        // Address
        _buildLabel('Home Address'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: addressController,
          hintText: 'Street address',
          prefixIcon: Icons.home_outlined,
          errorText: _addressError,
          onChanged: (_) => setState(() => _addressTouched = true),
        ),
        const SizedBox(height: 20),

        // Password
        _buildLabel('Password'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: passwordController,
          hintText: '••••••••',
          prefixIcon: Icons.lock_outline,
          obscureText: obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textTertiary,
            ),
            onPressed: () {
              setState(() {
                obscurePassword = !obscurePassword;
              });
            },
          ),
          onChanged: (_) => setState(() {}),
        ),
        _buildPasswordRequirement(
          'At least 8 characters',
          passwordController.text.length >= 8,
        ),
        _buildPasswordRequirement(
          'At least 1 uppercase letter',
          RegExp(r'[A-Z]').hasMatch(passwordController.text),
        ),
        _buildPasswordRequirement(
          'At least 1 lowercase letter',
          RegExp(r'[a-z]').hasMatch(passwordController.text),
        ),
        _buildPasswordRequirement(
          'At least 1 number',
          RegExp(r'\d').hasMatch(passwordController.text),
        ),
        _buildPasswordRequirement(
          'At least 1 special character',
          RegExp(r'[^A-Za-z0-9]').hasMatch(passwordController.text),
        ),
        const SizedBox(height: 20),

        // Confirm Password
        _buildLabel('Confirm Password'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: confirmPasswordController,
          hintText: '••••••••',
          prefixIcon: Icons.lock_outline,
          obscureText: obscureConfirmPassword,
          suffixIcon: IconButton(
            icon: Icon(
              obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textTertiary,
            ),
            onPressed: () {
              setState(() {
                obscureConfirmPassword = !obscureConfirmPassword;
              });
            },
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (confirmPasswordController.text.isNotEmpty)
          _buildPasswordRequirement(
            'Passwords match',
            passwordController.text == confirmPasswordController.text,
          ),
        const SizedBox(height: 20),

        // Terms agreement
        Row(
          children: [
            Checkbox(
              value: agreeToTerms,
              onChanged: (value) {
                setState(() {
                  agreeToTerms = value ?? false;
                });
              },
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return Colors.transparent;
              }),
              side: const BorderSide(color: AppColors.borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'I agree to the ',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextSpan(
                      text: 'Terms of Service',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.of(context).pushNamed(
                            '/terms-and-privacy',
                            arguments: const <String, dynamic>{'tab': 'terms'},
                          );
                        },
                    ),
                    const TextSpan(
                      text: ' and ',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.of(context).pushNamed(
                            '/terms-and-privacy',
                            arguments: const <String, dynamic>{
                              'tab': 'privacy',
                            },
                          );
                        },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Sign up button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (isLoading || _isSubmitting) ? null : _handleSignup,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
            child: (isLoading || _isSubmitting)
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.black),
                          strokeWidth: 2.5,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Creating Account...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),

        // Divider
        Row(
          children: [
            Expanded(
              child: Container(height: 1, color: AppColors.borderColor),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'or',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Container(height: 1, color: AppColors.borderColor),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Login link
        Center(
          child: RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: 'Already have an account? ',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: 'Sign In',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BoxConstraints constraints) {
    return Row(
      children: [
        // Left side - Branding panel
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.darkBg,
                ],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    GestureDetector(
                      onTap: () => Navigator.of(
                        context,
                      ).pushReplacementNamed('/welcome'),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/icon/logo-black.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Mobilis',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your trusted car rental platform',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 60),
                    _buildFeatureItem(
                      Icons.verified_user,
                      'Verified Partners',
                      'All partners undergo strict verification',
                    ),
                    const SizedBox(height: 32),
                    _buildFeatureItem(
                      Icons.security,
                      'Secure & Trusted',
                      'Your data is encrypted and protected',
                    ),
                    const SizedBox(height: 32),
                    _buildFeatureItem(
                      Icons.support_agent,
                      '24/7 Support',
                      'Always here when you need us',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Right side - Signup form
        Expanded(
          flex: 1,
          child: Container(
            color: AppColors.darkBg,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _buildSignupForm(isCompact: false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(BoxConstraints constraints, bool isTablet) {
    final isMobile = !isTablet;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.darkBg,
            AppColors.darkBg,
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 18 : 36,
              vertical: isMobile ? 24 : 40,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Compact Branding Header
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(
                            context,
                          ).pushReplacementNamed('/welcome'),
                          child: Container(
                            width: isMobile ? 56 : 68,
                            height: isMobile ? 56 : 68,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 20,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/icon/logo-black.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Mobilis',
                          style: TextStyle(
                            fontSize: isMobile ? 28 : 34,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your trusted car rental platform',
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (isTablet) ...[
                          const SizedBox(height: 20),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _buildFeatureChip(
                                Icons.verified_user,
                                'Verified Partners',
                              ),
                              _buildFeatureChip(
                                Icons.security,
                                'Secure & Trusted',
                              ),
                              _buildFeatureChip(
                                Icons.support_agent,
                                '24/7 Support',
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 20 : 32),

                  // Form Container (card wrapper on tablet, clean flat on mobile)
                  if (isTablet)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.darkCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.borderColor,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: _buildSignupForm(isCompact: true),
                    )
                  else
                    _buildSignupForm(isCompact: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 960;
          final isTablet =
              constraints.maxWidth >= 600 && constraints.maxWidth < 960;

          if (isDesktop) {
            return _buildDesktopLayout(constraints);
          } else {
            return _buildCompactLayout(constraints, isTablet);
          }
        },
      ),
    );
  }
}
