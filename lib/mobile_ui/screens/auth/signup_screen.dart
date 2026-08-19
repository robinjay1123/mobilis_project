import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../../services/auth_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/preferences_service.dart';
import '../../../utils/input_validation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/location_picker_modal.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _phoneTouched = false;
  bool _nameTouched = false;
  bool _emailTouched = false;
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
  String? selectedRole; // 'renter' or 'partner'
  bool _didApplyInitialRouteArgs = false;
  bool _isPartnerRegistration = false;
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
    // Don't load saved form data - sign-up should always start fresh
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didApplyInitialRouteArgs) return;
    _didApplyInitialRouteArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['initialRole'] is String) {
      final role = (args['initialRole'] as String).trim().toLowerCase();
      if (['renter', 'partner', 'driver'].contains(role)) {
        selectedRole = role;
        _isPartnerRegistration = role == 'partner';
      }
    }
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

  void _handleSignup() async {
    // Check internet connection first
    final connectivityService = ConnectivityService();
    if (!connectivityService.isOnline) {
      _showErrorSnackBar(
        'No internet connection. Please check your WiFi or mobile data.',
      );
      return;
    }

    // Validate role selection first (required)
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
      return;
    }

    if (!_passwordMeetsRequirements(passwordController.text)) {
      setState(() {});
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      setState(() {});
      return;
    }

    if (!agreeToTerms) {
      _showErrorSnackBar('Please agree to Terms of Service and Privacy Policy');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final authService = AuthService();

      // Ensure fullName is not empty (database constraint)
      final fullName = toTitleCaseName(fullNameController.text);
      if (fullName.isEmpty) {
        _showErrorSnackBar('Full name is required');
        setState(() => isLoading = false);
        return;
      }

      // Create user account with metadata
      final response = await authService.signup(
        email: emailController.text.trim(),
        password: passwordController.text,
        userMetadata: {
          'full_name': fullName,
          'phone': normalizePhilippineMobile(phoneController.text),
          'location': locationController.text.trim(),
          'address': addressController.text.trim(),
          'role': selectedRole,
        },
      );

      if (mounted) {
        // Check if account was created successfully
        if (response.user != null) {
          // Clear controllers and saved form data on successful signup
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

          // Navigate immediately to verification options
          Navigator.of(context).pushReplacementNamed('/verification-options');
        } else {
          _showErrorSnackBar('Account creation failed. Please try again.');
        }
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

  bool _passwordMeetsRequirements(String password) =>
      password.length >= 8 &&
      RegExp(r'[A-Z]').hasMatch(password) &&
      RegExp(r'[a-z]').hasMatch(password) &&
      RegExp(r'\d').hasMatch(password) &&
      RegExp(r'[^A-Za-z0-9]').hasMatch(password);

  Widget _buildPasswordRequirement(String text, bool isMet) {
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
          Text(text, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  String? get _phoneError {
    if (!_phoneTouched) return null;
    return validatePhilippineMobile(phoneController.text);
  }

  String? get _nameError =>
      _nameTouched ? validatePersonName(fullNameController.text) : null;

  String? get _emailError =>
      _emailTouched ? validateEmailAddress(emailController.text) : null;

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

  Widget _buildLocationSection() {
    return CustomTextField(
      label: 'Location *',
      hintText: 'Tap to choose your city or address',
      controller: locationController,
      readOnly: true,
      onTap: _openLocationPicker,
      errorText: _locationError,
      onChanged: (_) => setState(() => _locationTouched = true),
      prefixIcon: const Icon(
        Icons.location_on_outlined,
        color: AppColors.textTertiary,
      ),
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
      initialAddress: locationController.text.trim(),
      initialLatitude: _selectedLocation?.latitude,
      initialLongitude: _selectedLocation?.longitude,
    );
    if (!mounted || selection == null) return;
    setState(() {
      _selectedLocation = selection;
      locationController.text = selection.address;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Create Account',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Join Mobilis',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'SECURE REGISTRATION VERIFIED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_isPartnerRegistration) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.business, color: AppColors.primary, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Partner Registration',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'You are applying as a Partner to list your vehicle.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.lock_outline, color: AppColors.primary),
                    ],
                  ),
                ),
              ] else ...[
                // Role Selection Section (Required)
                const Text(
                  'I want to...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose your role (required)',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 12),

                // Role options as radio cards (scrollable row for 3 options)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Renter option
                      SizedBox(
                        width: 140,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedRole = 'renter';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedRole == 'renter'
                                  ? AppColors.primary.withOpacity(0.15)
                                  : AppColors.darkBgSecondary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedRole == 'renter'
                                    ? AppColors.primary
                                    : AppColors.borderColor,
                                width: selectedRole == 'renter' ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: selectedRole == 'renter'
                                        ? AppColors.primary.withOpacity(0.2)
                                        : AppColors.darkBgTertiary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Image.asset(
                                    'assets/icon/logo1.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Rent a Car',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: selectedRole == 'renter'
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Find & book',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                // Radio indicator
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selectedRole == 'renter'
                                          ? AppColors.primary
                                          : AppColors.textTertiary,
                                      width: 2,
                                    ),
                                  ),
                                  child: selectedRole == 'renter'
                                      ? Center(
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Partner option
                      SizedBox(
                        width: 140,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedRole = 'partner';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedRole == 'partner'
                                  ? AppColors.primary.withOpacity(0.15)
                                  : AppColors.darkBgSecondary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedRole == 'partner'
                                    ? AppColors.primary
                                    : AppColors.borderColor,
                                width: selectedRole == 'partner' ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: selectedRole == 'partner'
                                        ? AppColors.primary.withOpacity(0.2)
                                        : AppColors.darkBgTertiary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Image.asset(
                                    'assets/icon/logo1.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'List My Car',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: selectedRole == 'partner'
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Earn money',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                // Radio indicator
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selectedRole == 'partner'
                                          ? AppColors.primary
                                          : AppColors.textTertiary,
                                      width: 2,
                                    ),
                                  ),
                                  child: selectedRole == 'partner'
                                      ? Center(
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Driver option
                      SizedBox(
                        width: 140,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedRole = 'driver';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedRole == 'driver'
                                  ? AppColors.primary.withOpacity(0.15)
                                  : AppColors.darkBgSecondary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedRole == 'driver'
                                    ? AppColors.primary
                                    : AppColors.borderColor,
                                width: selectedRole == 'driver' ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: selectedRole == 'driver'
                                        ? AppColors.primary.withOpacity(0.2)
                                        : AppColors.darkBgTertiary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Image.asset(
                                    'assets/icon/logo1.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Be a Driver',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: selectedRole == 'driver'
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Drive & earn',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                // Radio indicator
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selectedRole == 'driver'
                                          ? AppColors.primary
                                          : AppColors.textTertiary,
                                      width: 2,
                                    ),
                                  ),
                                  child: selectedRole == 'driver'
                                      ? Center(
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Personal Details Section
              const Text(
                'Personal Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Full Name
              CustomTextField(
                label: 'Full Name *',
                hintText: 'John Doe',
                controller: fullNameController,
                textCapitalization: TextCapitalization.words,
                errorText: _nameError,
                onChanged: (_) => setState(() => _nameTouched = true),
                prefixIcon: const Icon(
                  Icons.person_outline,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 16),

              // Email
              CustomTextField(
                label: 'Email Address *',
                hintText: 'name@gmail.com',
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
                onChanged: (_) => setState(() => _emailTouched = true),
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 16),

              // Phone
              CustomTextField(
                label: 'Phone Number *',
                hintText: '09171234567',
                controller: phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: philippineMobileInputFormatters,
                errorText: _phoneError,
                onChanged: (_) => setState(() => _phoneTouched = true),
                prefixIcon: const Icon(
                  Icons.phone_outlined,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 16),

              // Location
              _buildLocationSection(),
              const SizedBox(height: 16),

              // Home Address
              CustomTextField(
                label: 'Home Address *',
                hintText: 'House No., Street, Barangay, City, Country',
                controller: addressController,
                maxLines: 2,
                errorText: _addressError,
                onChanged: (_) => setState(() => _addressTouched = true),
                prefixIcon: const Icon(
                  Icons.home_outlined,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 24),

              // Security Section
              const Text(
                'Security',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Password
              CustomTextField(
                label: 'Password *',
                hintText: '••••••••',
                controller: passwordController,
                obscureText: obscurePassword,
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: AppColors.textTertiary,
                ),
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
                'At least 1 special character',
                RegExp(r'[^A-Za-z0-9]').hasMatch(passwordController.text),
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
              const SizedBox(height: 16),

              // Confirm Password
              CustomTextField(
                label: 'Confirm Password *',
                hintText: '••••••••',
                controller: confirmPasswordController,
                obscureText: obscureConfirmPassword,
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: AppColors.textTertiary,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
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

              // Terms checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: RichText(
                        text: TextSpan(
                          text: 'I agree to the ',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          children: [
                            TextSpan(
                              text: 'Terms of Service',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.of(context).pushNamed(
                                    '/terms-and-privacy',
                                    arguments: const <String, dynamic>{
                                      'tab': 'terms',
                                    },
                                  );
                                },
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: const TextStyle(
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
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Anti-scam protection
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkBgSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Anti-Scam Protection',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'All members undergo identity verification to ensure a safe rental community.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Next button
              CustomButton(
                label: 'Next',
                onPressed: _handleSignup,
                isLoading: isLoading,
              ),
              const SizedBox(height: 16),

              // Login link
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  child: RichText(
                    text: const TextSpan(
                      text: 'Already have an account? ',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        TextSpan(
                          text: 'Log In',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
