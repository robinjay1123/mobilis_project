part of '../admin_web_screen.dart';

extension AdminSettingsTab on _AdminWebScreenState {
  Widget _buildSettingsContent(bool isDark) {
    return SettingsScreen(
      isDarkMode: isDark,
      showHeader: false,
      showAppearance: true,
      showSignOut: true,
      operatorMode: true,
      adminMode: true,
      onThemeToggle: widget.onThemeToggle,
      onBack: () {},
      onOpenSupport: () => setState(() => _selectedIndex = 7),
      onSignOut: _handleLogout,
      onProfileUpdated: () {
        _loadDashboardData();
      },
    );
  }

  Future<void> _showAddOperatorDialog(bool isDark) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    var obscurePassword = true;
    var obscureConfirmation = true;
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final inputColor = isDark ? Colors.white : Colors.black87;

          InputDecoration fieldDecoration(
            String label,
            IconData icon, {
            Widget? suffixIcon,
          }) {
            return InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            insetPadding: const EdgeInsets.all(24),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
            title: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Operator',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Create a new operator login account',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        enabled: !isSubmitting,
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(color: inputColor),
                        decoration: fieldDecoration(
                          'Full name',
                          Icons.badge_outlined,
                        ),
                        validator: (value) => validatePersonName(
                          value,
                          fieldName: 'Operator full name',
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: emailController,
                        enabled: !isSubmitting,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: inputColor),
                        decoration: fieldDecoration(
                          'Email address',
                          Icons.email_outlined,
                        ),
                        validator: (value) {
                          return validateEmailAddress(value);
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: phoneController,
                        enabled: !isSubmitting,
                        keyboardType: TextInputType.phone,
                        inputFormatters: philippineMobileInputFormatters,
                        style: TextStyle(color: inputColor),
                        decoration: fieldDecoration(
                          'Phone number (optional)',
                          Icons.phone_outlined,
                        ),
                        validator: (value) {
                          return validatePhilippineMobile(
                            value,
                            required: false,
                          );
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: passwordController,
                        enabled: !isSubmitting,
                        obscureText: obscurePassword,
                        style: TextStyle(color: inputColor),
                        decoration: fieldDecoration(
                          'Temporary password',
                          Icons.lock_outline,
                          suffixIcon: IconButton(
                            onPressed: () => setDialogState(
                              () => obscurePassword = !obscurePassword,
                            ),
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: _operatorPasswordError,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Minimum 8 characters with uppercase, lowercase, number, and special character.',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: confirmPasswordController,
                        enabled: !isSubmitting,
                        obscureText: obscureConfirmation,
                        style: TextStyle(color: inputColor),
                        decoration: fieldDecoration(
                          'Confirm password',
                          Icons.lock_reset_outlined,
                          suffixIcon: IconButton(
                            onPressed: () => setDialogState(
                              () => obscureConfirmation = !obscureConfirmation,
                            ),
                            icon: Icon(
                              obscureConfirmation
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => value != passwordController.text
                            ? 'Passwords do not match'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        try {
                          await _createOperatorAccount(
                            fullName: nameController.text.trim(),
                            email: emailController.text.trim(),
                            phone: phoneController.text.trim(),
                            password: passwordController.text,
                          );
                          if (!mounted || !dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Operator account created'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          await _loadDashboardData();
                        } catch (error) {
                          if (!mounted || !dialogContext.mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(_operatorCreationError(error)),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          setDialogState(() => isSubmitting = false);
                        }
                      },
                icon: isSubmitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.person_add_alt_1_outlined),
                label: Text(isSubmitting ? 'Creating...' : 'Create Operator'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
  }

  String? _operatorPasswordError(String? value) {
    final password = value ?? '';
    if (password.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Add at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Add at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Add at least one number';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Add at least one special character';
    }
    return null;
  }

  Future<void> _createOperatorAccount({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _supabase.functions.invoke(
      'create-operator',
      body: {
        'full_name': toTitleCaseName(fullName),
        'email': email.toLowerCase(),
        'phone': phone.isEmpty ? null : normalizePhilippineMobile(phone),
        'password': password,
      },
    );
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
  }

  String _operatorCreationError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('already') || message.contains('registered')) {
      return 'An account already exists for this email address.';
    }
    if (message.contains('create-operator') && message.contains('404')) {
      return 'The create-operator function is not deployed yet.';
    }
    return 'Could not create operator: $message';
  }

  Future<void> _generateAndExportReport(bool isDark) async {
    try {
      final currentAdminId = _supabase.auth.currentUser?.id ?? '';
      final adminEmail = _supabase.auth.currentUser?.email ?? 'admin@mobilis.ph';
      final adminMatch = _allUsers.firstWhere(
        (u) => u['id'] == currentAdminId,
        orElse: () => <String, dynamic>{},
      );
      final adminFullName = (adminMatch['full_name']?.toString().trim().isNotEmpty == true)
          ? adminMatch['full_name'].toString().trim()
          : adminEmail;

      final calculatedFin = _calculatePlatformFinancials();

      final reportData = AdminReportData.fromDashboard(
        allBookings: _allBookings,
        allVehicles: _allVehicles,
        allUsers: _allUsers,
        verificationRecords: _verificationRecords,
        trackingLocations: _trackingLocations,
        totalRevenue: _totalRevenue,
        calculatedFinancials: calculatedFin,
        adminName: adminFullName,
        adminEmail: adminEmail,
        adminId: currentAdminId,
        actionLogsCount: _actionLogs.length,
        userReportsCount: _userReports.length,
      );
      if (mounted) {
        await AdminReportDialog.show(context, reportData: reportData);
      }
      try {
        await AuditService().logAdminAction(
          action: 'audit_report_generated',
          category: 'EXECUTIVE AUDIT',
          adminId: currentAdminId,
          actorName: adminFullName,
          notes: '$adminFullName generated Executive Audit Report (${reportData.auditCycle} - Ref: ${reportData.referenceCode})',
          metadata: {
            'doc_serial': reportData.docSerial,
            'reference_code': reportData.referenceCode,
            'audit_cycle': reportData.auditCycle,
            'total_bookings': _allBookings.length,
            'sha256_hash': reportData.sha256Hash,
          },
        );
      } catch (auditErr) {
        debugPrint('Warning logging report audit: $auditErr');
      }
    } catch (e) {
      debugPrint('Error generating report preview: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
