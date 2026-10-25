part of '../admin_web_screen.dart';

extension AdminApplicationsTab on _AdminWebScreenState {
  Widget _buildApplicationsContent(bool isDark) {
    final records = _pendingPartnerVehicleApplications;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: _buildCard(
        'Partner Vehicle Applications (${records.length})',
        records.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No pending vehicle applications.',
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              )
            : Column(
                children: records.map((record) {
                  final partner = record['partner'] as Map<String, dynamic>?;
                  final title =
                      '${record['brand'] ?? 'Unknown'} ${record['model'] ?? ''}'
                          .trim();
                  final pricePerDay =
                      (record['price_per_day'] as num?)?.toDouble() ?? 0;
                  final pricePerHour =
                      (record['price_per_hour'] as num?)?.toDouble() ?? 0;
                  final submittedAt = record['created_at']?.toString() ?? '';
                  final orUrl = record['or_document_url']?.toString() ?? '';
                  final crUrl = record['cr_document_url']?.toString() ?? '';
                  final vehiclePhotoUrl =
                      record['vehicle_photo_url']?.toString() ?? '';
                  final subtitle = [
                    if (record['year'] != null) record['year'].toString(),
                    if ((record['plate_number'] ?? '').toString().isNotEmpty)
                      'Plate: ${record['plate_number']}',
                  ].join('  •  ');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Partner: ${partner?['full_name'] ?? 'Unknown'} (${partner?['email'] ?? ''})',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Specs Collage Grid
                        _buildSpecsCollageGrid([
                          AdminSpecItem(
                            label: 'Price Per Day',
                            value: 'PHP ${pricePerDay.toStringAsFixed(0)}',
                            icon: Icons.payments_outlined,
                            highlightColor: Colors.green,
                          ),
                          AdminSpecItem(
                            label: 'Price Per Hour',
                            value: 'PHP ${pricePerHour.toStringAsFixed(0)}',
                            icon: Icons.access_time_rounded,
                            highlightColor: Colors.teal,
                          ),
                          AdminSpecItem(
                            label: 'Submitted',
                            value: _formatDate(submittedAt),
                            icon: Icons.calendar_today_rounded,
                          ),
                        ], isDark, maxColumns: 3),

                        // Documents & Media Collage
                        _buildDocumentAndMediaCollage(
                          context: context,
                          cardId: 'vehicle_verif_${record['id']}',
                          title: 'Vehicle Documents & Photo Inspection',
                          items: [
                            AdminCollageItem(
                              title: 'OR Document',
                              url: orUrl,
                              subtitle: 'Official Receipt',
                              placeholderIcon: Icons.description_outlined,
                            ),
                            AdminCollageItem(
                              title: 'CR Document',
                              url: crUrl,
                              subtitle: 'Certificate of Registration',
                              placeholderIcon: Icons.badge_outlined,
                            ),
                            AdminCollageItem(
                              title: 'Vehicle Photo',
                              url: vehiclePhotoUrl,
                              subtitle: 'Listing Photo Proof',
                              placeholderIcon: Icons.directions_car_outlined,
                            ),
                          ],
                          isDark: isDark,
                          isGlobalRevealed: _revealAllVerificationDocuments,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: () =>
                                  _approvePartnerVehicleApplication(record),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Approve'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _rejectPartnerVehicleApplication(record),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Reject'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
        isDark,
      ),
    );
  }

  Widget _buildApplicationsContentEnhanced(bool isDark) {
    var vehicleRecords = _pendingPartnerVehicleApplications;
    var driverRecords = _pendingDriverApplications;

    if (_applicationSearchQuery.trim().isNotEmpty) {
      final q = _applicationSearchQuery.toLowerCase().trim();
      vehicleRecords = vehicleRecords.where((v) {
        final brand = (v['brand']?.toString() ?? '').toLowerCase();
        final model = (v['model']?.toString() ?? '').toLowerCase();
        final plate = (v['plate_number']?.toString() ?? '').toLowerCase();
        final partner =
            (v['partner_name']?.toString() ??
                    v['partner_email']?.toString() ??
                    '')
                .toLowerCase();
        return brand.contains(q) ||
            model.contains(q) ||
            plate.contains(q) ||
            partner.contains(q);
      }).toList();

      driverRecords = driverRecords.where((d) {
        final user = d['users'] as Map<String, dynamic>?;
        final name =
            (user?['full_name']?.toString() ?? d['full_name']?.toString() ?? '')
                .toLowerCase();
        final email =
            (user?['email']?.toString() ?? d['email']?.toString() ?? '')
                .toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }

    final showVehicles =
        _applicationTypeFilter == 'all' || _applicationTypeFilter == 'vehicle';
    final showDrivers =
        _applicationTypeFilter == 'all' || _applicationTypeFilter == 'driver';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Search & Sub-Tabs
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF021F35) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
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
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.assignment_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vehicle & Driver Applications',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Review and manage incoming Partner vehicle listings and Driver onboarding applications.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  height: 1,
                ),
                const SizedBox(height: 16),

                // Search Bar
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) =>
                            setState(() => _applicationSearchQuery = val),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Search applications by Partner, Brand, Model, Plate, Year, or Driver Name...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade500,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.black26
                              : Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
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
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _revealAllApplicationDocuments =
                              !_revealAllApplicationDocuments;
                        });
                      },
                      icon: Icon(
                        _revealAllApplicationDocuments
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 16,
                        color: _revealAllApplicationDocuments
                            ? Colors.amber
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      label: Text(
                        _revealAllApplicationDocuments
                            ? 'Hide All Documents'
                            : 'Reveal All Documents',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _revealAllApplicationDocuments
                              ? Colors.amber
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: _revealAllApplicationDocuments
                              ? Colors.amber.withValues(alpha: 0.6)
                              : (isDark ? Colors.white24 : Colors.grey.shade300),
                        ),
                        backgroundColor: _revealAllApplicationDocuments
                            ? Colors.amber.withValues(alpha: 0.12)
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Application Sub-Tab Chips (Matching Image 2)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildApplicationTypeTab(
                      'all',
                      'All Applications',
                      vehicleRecords.length + driverRecords.length,
                      isDark,
                      icon: Icons.assignment_rounded,
                    ),
                    _buildApplicationTypeTab(
                      'vehicle',
                      'Partner Vehicle Listings',
                      vehicleRecords.length,
                      isDark,
                      icon: Icons.directions_car_rounded,
                      color: AppColors.primary,
                    ),
                    _buildApplicationTypeTab(
                      'driver',
                      'Driver Onboarding',
                      driverRecords.length,
                      isDark,
                      icon: Icons.badge_rounded,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Partner Vehicle Applications Section
          if (showVehicles) ...[
            _buildPartnerVehicleApplicationsSection(vehicleRecords, isDark),
            if (showDrivers && driverRecords.isNotEmpty)
              const SizedBox(height: 24),
          ],

          // Driver Applications Section
          if (showDrivers) ...[
            _buildDriverApplicationsSection(driverRecords, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildApplicationTypeTab(
    String key,
    String label,
    int count,
    bool isDark, {
    IconData? icon,
    Color? color,
  }) {
    final isSelected = _applicationTypeFilter == key;
    final activeColor = color ?? AppColors.primary;
    final displayIcon = icon ?? Icons.assignment_rounded;

    return InkWell(
      onTap: () => setState(() => _applicationTypeFilter = key),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : (isDark ? Colors.black26 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              displayIcon,
              size: 17,
              color: isSelected
                  ? activeColor
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white10 : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.black
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverApplicationsSection(
    List<Map<String, dynamic>> driverRecords,
    bool isDark,
  ) {
    return _buildCard(
      'Driver Onboarding Applications (${driverRecords.length})',
      driverRecords.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No pending driver applications.',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            )
          : Column(
              children: driverRecords
                  .map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildDriverApplicationCard(record, isDark),
                    ),
                  )
                  .toList(),
            ),
      isDark,
    );
  }

  Widget _buildDriverApplicationCard(Map<String, dynamic> record, bool isDark) {
    final user = record['users'] as Map<String, dynamic>?;
    final submittedName = (record['full_name'] as String?)?.trim();
    final profileName = (user?['full_name'] as String?)?.trim();
    final displayName = submittedName?.isNotEmpty == true
        ? submittedName!
        : (profileName?.isNotEmpty == true ? profileName! : 'Driver Applicant');

    final userEmail = user?['email']?.toString().trim() ?? (record['email']?.toString().trim() ?? '');
    final userPhone = (record['phone'] as String?)?.trim().isNotEmpty == true
        ? record['phone'].toString().trim()
        : (user?['phone']?.toString().trim() ?? '');
    final userLocation = (record['location'] as String?)?.trim().isNotEmpty == true
        ? record['location'].toString().trim()
        : (user?['location']?.toString().trim() ?? '');
    final avatarUrl = user?['avatar_url']?.toString().trim() ?? record['avatar_url']?.toString().trim();
    final joinedAt = user?['created_at']?.toString() ?? record['created_at']?.toString();

    final idParts = (record['id_document_url'] as String? ?? '').split('|');
    final legacyIdUrls = idParts
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part.trim())
        .toList();
    final idFrontUrl = record['id_front_url']?.toString().trim().isNotEmpty == true
        ? record['id_front_url'].toString().trim()
        : (legacyIdUrls.isNotEmpty ? legacyIdUrls.first : '');
    final idBackUrl = record['id_back_url']?.toString().trim().isNotEmpty == true
        ? record['id_back_url'].toString().trim()
        : (legacyIdUrls.length > 1 ? legacyIdUrls[1] : '');
    final faceSelfieUrl = record['face_selfie_url']?.toString().trim() ?? '';
    final selfieWithIdUrl = record['selfie_with_id_url']?.toString().trim() ?? '';
    final driverSignatureUrl = record['driver_signature_url']?.toString().trim() ?? '';
    final driverNbiUrl = record['driver_nbi_url']?.toString().trim() ?? '';
    final driverYearsExperience = record['driver_years_experience']?.toString().trim() ?? '';
    final driverPreviousCompanies = record['driver_previous_companies']?.toString().trim() ?? '';
    final driverLicenseExpiry = record['driver_license_expiry']?.toString().trim() ?? '';
    final rejectionReason = record['rejection_reason']?.toString().trim() ?? '';

    // Strictly check application_status for Driver Applications
    final appStatus = (record['application_status'] as String? ??
            user?['application_status']?.toString() ??
            'pending')
        .toLowerCase();

    final isPending = appStatus == 'pending' ||
        appStatus == 'submitted' ||
        appStatus == 'under_review';

    Color statusBadgeColor;
    IconData statusIcon;
    String statusDisplay;
    switch (appStatus) {
      case 'approved':
        statusBadgeColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        statusDisplay = 'APPLICATION APPROVED';
        break;
      case 'rejected':
        statusBadgeColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        statusDisplay = 'APPLICATION REJECTED';
        break;
      default:
        statusBadgeColor = Colors.orange;
        statusIcon = Icons.hourglass_top_rounded;
        statusDisplay = 'APPLICATION PENDING';
    }

    final roleBg = Colors.blue.withValues(alpha: 0.15);
    final roleText = Colors.blue;
    final roleIcon = Icons.badge_rounded;
    const roleTag = 'DRIVER ONBOARDING';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF021F35) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: roleText.withValues(alpha: 0.2),
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'D',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: roleText,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
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
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: roleBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: roleText.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(roleIcon, size: 13, color: roleText),
                                const SizedBox(width: 4),
                                Text(
                                  roleTag,
                                  style: TextStyle(
                                    color: roleText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusBadgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: statusBadgeColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  statusIcon,
                                  size: 13,
                                  color: statusBadgeColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusDisplay,
                                  style: TextStyle(
                                    color: statusBadgeColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (userEmail.isNotEmpty) ...[
                            Icon(
                              Icons.email_outlined,
                              size: 13,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              userEmail,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (userPhone.isNotEmpty) ...[
                            Icon(
                              Icons.phone_outlined,
                              size: 13,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              userPhone,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (joinedAt != null) ...[
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Submitted ${_formatDate(joinedAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Action Buttons strictly for Application Approval / Rejection
                if (isPending) ...[
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () => _approveDriverApplication(record),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Approve Driver'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _rejectDriverApplication(record),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                  ),
                ],
              ],
            ),
          ),

          // Rejection Reason Notice Banner (if rejected)
          if (appStatus == 'rejected' && rejectionReason.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.red.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Rejection Reason: $rejectionReason',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 2. User Essential Data Fields Grid
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DRIVER ONBOARDING DATA & EVALUATION METRICS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 700;
                    final itemWidth = isNarrow
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 36) / 4;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Full Legal Name',
                            displayName,
                            isDark,
                            icon: Icons.person_outline,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Target Role',
                            'PSDC Fleet Driver',
                            isDark,
                            icon: Icons.badge_outlined,
                            highlightColor: Colors.blue,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Address / Location',
                            userLocation.isNotEmpty
                                ? userLocation
                                : 'Not specified',
                            isDark,
                            icon: Icons.location_on_outlined,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Driving Experience',
                            driverYearsExperience.isNotEmpty
                                ? '$driverYearsExperience years'
                                : 'Not specified',
                            isDark,
                            icon: Icons.history_edu_outlined,
                          ),
                        ),
                        if (driverPreviousCompanies.isNotEmpty)
                          SizedBox(
                            width: itemWidth,
                            child: _buildDetailCard(
                              'Previous Employer',
                              driverPreviousCompanies,
                              isDark,
                              icon: Icons.business_outlined,
                            ),
                          ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Digital Signature Status',
                            driverSignatureUrl.isNotEmpty
                                ? 'Submitted & Signed'
                                : 'Not submitted',
                            isDark,
                            icon: Icons.draw_rounded,
                            highlightColor: driverSignatureUrl.isNotEmpty
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'NBI Clearance Status',
                            driverNbiUrl.isNotEmpty
                                ? 'Submitted Document'
                                : 'Not submitted',
                            isDark,
                            icon: Icons.verified_outlined,
                            highlightColor: driverNbiUrl.isNotEmpty
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                // 3. Document Proof Inspection Collage
                _buildDocumentAndMediaCollage(
                  context: context,
                  cardId: 'driver_app_${record['id']}',
                  title: 'Driver Documents & Identification Gallery',
                  items: [
                    AdminCollageItem(
                      title: 'Driver License (Front)',
                      url: idFrontUrl,
                      subtitle: 'Official Driver License',
                      placeholderIcon: Icons.badge_outlined,
                    ),
                    AdminCollageItem(
                      title: 'Driver License (Back)',
                      url: idBackUrl,
                      subtitle: 'License Restrictions & Serial',
                      placeholderIcon: Icons.badge_outlined,
                    ),
                    AdminCollageItem(
                      title: 'Face Selfie (Liveness)',
                      url: faceSelfieUrl,
                      subtitle: 'Facial Verification',
                      placeholderIcon: Icons.face_rounded,
                    ),
                    AdminCollageItem(
                      title: 'Selfie Holding License',
                      url: selfieWithIdUrl,
                      subtitle: 'Identity Verification Proof',
                      placeholderIcon: Icons.portrait_rounded,
                    ),
                    if (driverSignatureUrl.isNotEmpty)
                      AdminCollageItem(
                        title: 'Digital Signature',
                        url: driverSignatureUrl,
                        subtitle: 'Driver Signature',
                        placeholderIcon: Icons.draw_rounded,
                      ),
                    if (driverNbiUrl.isNotEmpty)
                      AdminCollageItem(
                        title: 'NBI Clearance Proof',
                        url: driverNbiUrl,
                        subtitle: 'Background Check Clearance',
                        placeholderIcon: Icons.verified_outlined,
                      ),
                  ],
                  isDark: isDark,
                  isGlobalRevealed: _revealAllApplicationDocuments,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerVehicleApplicationsSection(
    List<Map<String, dynamic>> records,
    bool isDark,
  ) {
    return _buildCard(
      'Partner Vehicle Applications (${records.length})',
      records.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No pending vehicle applications.',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            )
          : Column(
              children: records.map((record) {
                final partner = record['partner'] as Map<String, dynamic>?;
                final title =
                    '${record['brand'] ?? 'Unknown'} ${record['model'] ?? ''}'
                        .trim();
                final subtitle = [
                  if (record['year'] != null) record['year'].toString(),
                  if ((record['plate_number'] ?? '').toString().isNotEmpty)
                    'Plate: ${record['plate_number']}',
                ].join('  •  ');
                final photoUrls = List<String>.from(
                  (record['photo_urls'] as List?) ?? const <String>[],
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderColor
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'Partner: ${partner?['full_name'] ?? 'Unknown'} (${partner?['email'] ?? ''})',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 1. Details & Specs Collage Grid
                      _buildSpecsCollageGrid([
                        AdminSpecItem(
                          label: 'Price Per Day',
                          value:
                              'PHP ${((record['price_per_day'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                          icon: Icons.payments_outlined,
                          highlightColor: Colors.green,
                        ),
                        AdminSpecItem(
                          label: 'Price Per Hour',
                          value:
                              'PHP ${((record['price_per_hour'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                          icon: Icons.access_time_rounded,
                          highlightColor: Colors.teal,
                        ),
                        AdminSpecItem(
                          label: 'Seats',
                          value: record['seats']?.toString() ?? 'N/A',
                          icon: Icons.airline_seat_recline_normal_rounded,
                        ),
                        AdminSpecItem(
                          label: 'Fuel Type',
                          value: record['fuel_type']?.toString() ?? 'N/A',
                          icon: Icons.local_gas_station_rounded,
                        ),
                        AdminSpecItem(
                          label: 'Transmission',
                          value: record['transmission']?.toString() ?? 'N/A',
                          icon: Icons.settings_rounded,
                        ),
                        AdminSpecItem(
                          label: 'Driver Setup',
                          value: record['owner_is_driver'] == true
                              ? 'Owner will drive'
                              : 'Vehicle only',
                          icon: Icons.person_pin_rounded,
                        ),
                        AdminSpecItem(
                          label: 'Submitted',
                          value: _formatDate(record['created_at']?.toString() ?? ''),
                          icon: Icons.calendar_today_rounded,
                        ),
                        AdminSpecItem(
                          label: 'Application Status',
                          value: record['application_status']?.toString() ?? 'pending',
                          icon: Icons.info_outline_rounded,
                          highlightColor: record['application_status'] == 'approved'
                              ? Colors.green
                              : (record['application_status'] == 'rejected'
                                  ? Colors.red
                                  : Colors.orange),
                        ),
                      ], isDark, maxColumns: 4),

                      // 2. Documents & Media Collage
                      _buildDocumentAndMediaCollage(
                        context: context,
                        cardId: 'vehicle_app_${record['id']}',
                        title: 'Vehicle Documents & Gallery',
                        items: [
                          AdminCollageItem(
                            title: 'OR Document',
                            url: record['or_document_url']?.toString(),
                            subtitle: 'Official Receipt',
                            placeholderIcon: Icons.description_outlined,
                          ),
                          AdminCollageItem(
                            title: 'CR Document',
                            url: record['cr_document_url']?.toString(),
                            subtitle: 'Certificate of Registration',
                            placeholderIcon: Icons.badge_outlined,
                          ),
                          ...List.generate(
                            photoUrls.length,
                            (i) => AdminCollageItem(
                              title: 'Vehicle Photo ${i + 1}',
                              url: photoUrls[i],
                              subtitle: i == 0 ? 'Featured Photo' : 'Gallery Image',
                              placeholderIcon: Icons.directions_car_outlined,
                            ),
                          ),
                        ],
                        isDark: isDark,
                        isGlobalRevealed: _revealAllApplicationDocuments,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () =>
                                _approvePartnerVehicleApplication(record),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Approve'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _rejectPartnerVehicleApplication(record),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Reject'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
      isDark,
    );
  }

  Widget _buildVerificationSection({
    required String title,
    required List<Map<String, dynamic>> records,
    required bool isDark,
  }) {
    return _buildCard(
      '$title (${records.length})',
      records.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No ${title.toLowerCase()}.',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            )
          : Column(
              children: records
                  .map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildVerificationCard(record, isDark),
                    ),
                  )
                  .toList(),
            ),
      isDark,
    );
  }

  Widget _buildVerificationCard(Map<String, dynamic> record, bool isDark) {
    final user = record['users'] as Map<String, dynamic>?;
    final role =
        (user?['role']?.toString() ?? record['role']?.toString() ?? 'renter')
            .trim()
            .toLowerCase();
    final submittedName = (record['full_name'] as String?)?.trim();
    final profileName = (user?['full_name'] as String?)?.trim();
    final displayName = submittedName?.isNotEmpty == true
        ? submittedName!
        : (profileName?.isNotEmpty == true ? profileName! : 'Unknown User');

    final userEmail = user?['email']?.toString().trim() ?? '';
    final userPhone = (record['phone'] as String?)?.trim().isNotEmpty == true
        ? record['phone'].toString().trim()
        : (user?['phone']?.toString().trim() ?? '');
    final userLocation =
        (record['location'] as String?)?.trim().isNotEmpty == true
        ? record['location'].toString().trim()
        : '';
    final avatarUrl = user?['avatar_url']?.toString().trim();
    final joinedAt =
        user?['created_at']?.toString() ?? record['created_at']?.toString();

    final idParts = (record['id_document_url'] as String? ?? '').split('|');
    final legacyIdUrls = idParts
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part.trim())
        .toList();
    final idFrontUrl =
        record['id_front_url']?.toString().trim().isNotEmpty == true
        ? record['id_front_url'].toString().trim()
        : legacyIdUrls.isNotEmpty
        ? legacyIdUrls.first
        : '';
    final idBackUrl =
        record['id_back_url']?.toString().trim().isNotEmpty == true
        ? record['id_back_url'].toString().trim()
        : legacyIdUrls.length > 1
        ? legacyIdUrls[1]
        : '';
    final idType = record['id_type']?.toString().trim() ?? '';
    final faceSelfieUrl = record['face_selfie_url']?.toString().trim() ?? '';
    final selfieWithIdUrl =
        record['selfie_with_id_url']?.toString().trim() ?? '';
    final driverSignatureUrl =
        record['driver_signature_url']?.toString().trim() ?? '';
    final driverNbiUrl = record['driver_nbi_url']?.toString().trim() ?? '';
    final driverYearsExperience =
        record['driver_years_experience']?.toString().trim() ?? '';
    final driverPreviousCompanies =
        record['driver_previous_companies']?.toString().trim() ?? '';
    final driverLicenseExpiry =
        record['driver_license_expiry']?.toString().trim() ?? '';
    final rejectionReason = record['rejection_reason']?.toString().trim() ?? '';

    final status = (record['verification_status'] as String? ??
            user?['verification_status']?.toString() ??
            'pending')
        .toLowerCase();

    final isPending = status == 'pending' ||
        status == 'submitted' ||
        status == 'under_review';

    Color statusBadgeColor;
    IconData statusIcon;
    String statusDisplay;
    switch (status) {
      case 'verified':
      case 'approved':
        statusBadgeColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        statusDisplay = 'VERIFIED';
        break;
      case 'rejected':
        statusBadgeColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        statusDisplay = 'REJECTED';
        break;
      default:
        statusBadgeColor = Colors.orange;
        statusIcon = Icons.hourglass_top_rounded;
        statusDisplay = 'PENDING VERIFICATION';
    }

    Color roleBg = Colors.purple.withValues(alpha: 0.15);
    Color roleText = Colors.purple;
    IconData roleIcon = Icons.directions_car_rounded;
    String roleTag = 'RENTER';

    if (role == 'driver') {
      roleTag = 'DRIVER';
      roleBg = Colors.blue.withValues(alpha: 0.15);
      roleText = Colors.blue;
      roleIcon = Icons.badge_rounded;
    } else if (role == 'partner') {
      roleTag = 'PARTNER';
      roleBg = Colors.amber.withValues(alpha: 0.15);
      roleText = Colors.amber;
      roleIcon = Icons.handshake_rounded;
    } else if (role == 'admin' || role == 'superadmin') {
      roleTag = 'ADMIN';
      roleBg = Colors.teal.withValues(alpha: 0.15);
      roleText = Colors.teal;
      roleIcon = Icons.admin_panel_settings_rounded;
    } else if (role == 'operator') {
      roleTag = 'OPERATOR';
      roleBg = Colors.indigo.withValues(alpha: 0.15);
      roleText = Colors.indigo;
      roleIcon = Icons.headset_mic_rounded;
    }

    // License expiry validity check
    bool isLicenseExpired = false;
    if (driverLicenseExpiry.isNotEmpty) {
      final exp = DateTime.tryParse(driverLicenseExpiry);
      if (exp != null && exp.isBefore(DateTime.now())) {
        isLicenseExpired = true;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF021F35) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. User Header Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 26,
                  backgroundColor: roleText.withValues(alpha: 0.2),
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: roleText,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
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
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: roleBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: roleText.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(roleIcon, size: 13, color: roleText),
                                const SizedBox(width: 4),
                                Text(
                                  roleTag,
                                  style: TextStyle(
                                    color: roleText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusBadgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: statusBadgeColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  statusIcon,
                                  size: 13,
                                  color: statusBadgeColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusDisplay,
                                  style: TextStyle(
                                    color: statusBadgeColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (userEmail.isNotEmpty) ...[
                            Icon(
                              Icons.email_outlined,
                              size: 13,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              userEmail,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (userPhone.isNotEmpty) ...[
                            Icon(
                              Icons.phone_outlined,
                              size: 13,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              userPhone,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (joinedAt != null) ...[
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Joined ${_formatDate(joinedAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Action Buttons strictly for Identity Verification
                if (isPending) ...[
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          backgroundColor: isDark
                              ? AppColors.darkBgSecondary
                              : Colors.white,
                          title: Text(
                            'Approve Verification?',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          content: Text(
                            'This will verify $displayName\'s identity documents and notify them immediately.',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Approve Verification'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;

                      final dismissLoading = _showActionLoadingModal(
                        'Approving verification for $displayName...',
                        'Validating credentials and notifying user...',
                      );

                      final userId = record['user_id']?.toString() ??
                          (record['users'] as Map<String, dynamic>?)?['id']
                              ?.toString() ??
                          '';

                      // Immediate action: optimistically update UI state
                      if (mounted) {
                        setState(() {
                          record['verification_status'] = 'approved';
                          record['id_verified'] = true;
                          _pendingVerifications = _verificationRecords
                              .where((v) =>
                                  (v['verification_status'] ?? '')
                                      .toString()
                                      .toLowerCase() ==
                                  'pending')
                              .length;

                          for (final u in _allUsers) {
                            if (u['id']?.toString() == userId) {
                              u['id_verified'] = true;
                              u['verification_status'] = 'approved';
                              u['display_verification_status'] = 'Approved';
                            }
                          }
                        });
                      }

                      try {
                        final adminId = _supabase.auth.currentUser?.id ?? '';
                        final result =
                            await VerificationService.approveVerification(
                              verificationId: record['id'].toString(),
                              adminId: adminId,
                            );
                        if (!mounted) return;
                        dismissLoading();
                        if (result['success'] == true) {
                          _showActionSuccessModal(
                            title: 'Verification Approved',
                            message:
                                'Identity verification for $displayName has been approved successfully.',
                            icon: Icons.verified_rounded,
                            iconColor: Colors.green,
                          );
                          _refreshVerificationsAndApplicationsSilently();
                          _loadAllUsers();
                        } else {
                          _refreshVerificationsAndApplicationsSilently();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result['message']?.toString() ??
                                    'Approval failed',
                              ),
                            ),
                          );
                        }
                      } finally {
                        dismissLoading();
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Approve Verification'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final reason = await _showRejectionReasonDialog(
                        context,
                        displayName,
                        isDark,
                      );
                      if (reason == null || reason.trim().isEmpty) return;

                      final dismissLoading = _showActionLoadingModal(
                        'Rejecting verification for $displayName...',
                        'Updating verification status and sending feedback...',
                      );

                      // Immediate action: optimistically update UI state
                      if (mounted) {
                        setState(() {
                          record['verification_status'] = 'rejected';
                          record['rejection_reason'] = reason;
                          _pendingVerifications = _verificationRecords
                              .where((v) =>
                                  (v['verification_status'] ?? '')
                                      .toString()
                                      .toLowerCase() ==
                                  'pending')
                              .length;
                        });
                      }

                      try {
                        final adminId = _supabase.auth.currentUser?.id ?? '';
                        final result =
                            await VerificationService.rejectVerification(
                              verificationId: record['id'].toString(),
                              rejectionReason: reason,
                              adminId: adminId,
                            );
                        if (!mounted) return;
                        dismissLoading();
                        if (result['success'] == true) {
                          _showActionSuccessModal(
                            title: 'Verification Rejected',
                            message:
                                'Identity verification for $displayName has been rejected with feedback sent.',
                            icon: Icons.cancel_rounded,
                            iconColor: Colors.redAccent,
                          );
                          _refreshVerificationsAndApplicationsSilently();
                        } else {
                          _refreshVerificationsAndApplicationsSilently();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result['message']?.toString() ??
                                    'Rejection failed',
                              ),
                            ),
                          );
                        }
                      } finally {
                        dismissLoading();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject Verification'),
                  ),
                ],
              ],
            ),
          ),

          // Rejection Reason Notice Banner (if rejected)
          if (status == 'rejected' && rejectionReason.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.red.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Rejection Reason: $rejectionReason',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 2. User Essential Data Fields Grid
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'USER ESSENTIAL DATA & EVALUATION METRICS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 800;
                    final itemWidth = isNarrow
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 36) / 4;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Full Legal Name',
                            displayName,
                            isDark,
                            icon: Icons.person_outline_rounded,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Email Address',
                            userEmail.isNotEmpty ? userEmail : 'Not provided',
                            isDark,
                            icon: Icons.email_outlined,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Contact Phone',
                            userPhone.isNotEmpty ? userPhone : 'Not provided',
                            isDark,
                            icon: Icons.phone_outlined,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Registered Address / City',
                            userLocation.isNotEmpty
                                ? userLocation
                                : 'Not provided',
                            isDark,
                            icon: Icons.location_on_outlined,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Government ID Type',
                            (record['id_type'] as String?)?.isNotEmpty == true
                                ? record['id_type']
                                : 'Not provided',
                            isDark,
                            icon: Icons.badge_outlined,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'ID Card Number',
                            (record['id_number'] as String?)?.isNotEmpty == true
                                ? record['id_number']
                                : 'Not provided',
                            isDark,
                            icon: Icons.numbers_rounded,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Submitted Date & Time',
                            _formatDate(record['created_at']),
                            isDark,
                            icon: Icons.schedule_rounded,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Account Joined Date',
                            _formatDate(joinedAt),
                            isDark,
                            icon: Icons.how_to_reg_rounded,
                          ),
                        ),

                        // Driver credentials cards
                        if (role == 'driver') ...[
                          SizedBox(
                            width: itemWidth,
                            child: _buildDetailCard(
                              'License Expiry Date',
                              driverLicenseExpiry.isNotEmpty
                                  ? '${_formatDate(driverLicenseExpiry)} ${isLicenseExpired ? "(EXPIRED)" : "(VALID)"}'
                                  : 'Not provided',
                              isDark,
                              icon: Icons.event_available_rounded,
                              highlightColor: isLicenseExpired
                                  ? Colors.red
                                  : null,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildDetailCard(
                              'Driving Experience',
                              driverYearsExperience.isNotEmpty
                                  ? '$driverYearsExperience year${driverYearsExperience == '1' ? '' : 's'}'
                                  : 'Not specified',
                              isDark,
                              icon: Icons.time_to_leave_rounded,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildDetailCard(
                              'Previous Companies',
                              driverPreviousCompanies.isNotEmpty
                                  ? driverPreviousCompanies
                                  : 'None listed',
                              isDark,
                              icon: Icons.business_outlined,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildDetailCard(
                              'Digital Signature Status',
                              driverSignatureUrl.isNotEmpty
                                  ? 'Submitted & Signed'
                                  : 'Not submitted',
                              isDark,
                              icon: Icons.draw_rounded,
                              highlightColor: driverSignatureUrl.isNotEmpty
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildDetailCard(
                              'NBI Clearance Status',
                              driverNbiUrl.isNotEmpty
                                  ? 'Submitted Document'
                                  : 'Not submitted',
                              isDark,
                              icon: Icons.verified_outlined,
                              highlightColor: driverNbiUrl.isNotEmpty
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                // 3. Document Proof Inspection Collage
                _buildDocumentAndMediaCollage(
                  context: context,
                  cardId: 'verif_${record['id']}',
                  title: 'Identity Verification & Proof Documents',
                  items: [
                    AdminCollageItem(
                      title: 'ID Card (Front)',
                      url: idFrontUrl,
                      subtitle: idType.isNotEmpty ? idType : 'Front Photo',
                      placeholderIcon: Icons.badge_outlined,
                    ),
                    AdminCollageItem(
                      title: 'ID Card (Back)',
                      url: idBackUrl,
                      subtitle: 'Back Photo',
                      placeholderIcon: Icons.badge_outlined,
                    ),
                    AdminCollageItem(
                      title: 'Face Selfie (Liveness)',
                      url: faceSelfieUrl,
                      subtitle: 'Facial Verification',
                      placeholderIcon: Icons.face_rounded,
                    ),
                    AdminCollageItem(
                      title: 'Selfie Holding ID',
                      url: selfieWithIdUrl,
                      subtitle: 'Proof of Possession',
                      placeholderIcon: Icons.portrait_rounded,
                    ),
                    if (driverSignatureUrl.isNotEmpty)
                      AdminCollageItem(
                        title: 'Digital Signature',
                        url: driverSignatureUrl,
                        subtitle: 'Signature Record',
                        placeholderIcon: Icons.draw_rounded,
                      ),
                    if (driverNbiUrl.isNotEmpty)
                      AdminCollageItem(
                        title: 'NBI Clearance',
                        url: driverNbiUrl,
                        subtitle: 'Official Clearance',
                        placeholderIcon: Icons.verified_outlined,
                      ),
                  ],
                  isDark: isDark,
                  isGlobalRevealed: _revealAllVerificationDocuments,
                ),

                const SizedBox(height: 20),

                // 4. Admin Evaluation Checklist
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.fact_check_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Admin Verification Evaluation Checklist',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '✓ Ensure Full Name matches Government ID   •   ✓ Verify Face Selfie against ID photo   •   ✓ Confirm ID / Driver License is valid and unexpired.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecsCollageGrid(
    List<AdminSpecItem> specs,
    bool isDark, {
    int minColumns = 2,
    int maxColumns = 4,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = maxColumns;
        if (width < 600) {
          columns = 1;
        } else if (width < 900) {
          columns = minColumns.clamp(1, 2);
        } else if (width < 1200) {
          columns = 3.clamp(minColumns, maxColumns);
        } else {
          columns = maxColumns;
        }

        const spacing = 10.0;
        final totalSpacing = spacing * (columns - 1);
        final itemWidth = (width - totalSpacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: specs.map((spec) {
            return SizedBox(
              width: itemWidth,
              child: _buildDetailCard(
                spec.label,
                spec.value,
                isDark,
                icon: spec.icon,
                highlightColor: spec.highlightColor,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDocumentAndMediaCollage({
    required BuildContext context,
    required String cardId,
    required String title,
    required List<AdminCollageItem> items,
    required bool isDark,
    required bool isGlobalRevealed,
  }) {
    final validItems = items.where((e) => e.hasUrl).toList();
    final isCardRevealed = isGlobalRevealed || _revealedCardIds.contains(cardId);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1B2A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Collage Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.collections_bookmark_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${validItems.length} of ${items.length} submitted',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Local Reveal / Hide toggle
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (_revealedCardIds.contains(cardId)) {
                        _revealedCardIds.remove(cardId);
                      } else {
                        _revealedCardIds.add(cardId);
                      }
                    });
                  },
                  icon: Icon(
                    isCardRevealed
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 15,
                    color: isCardRevealed
                        ? Colors.amber
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  label: Text(
                    isCardRevealed ? 'Hide All' : 'Reveal All',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCardRevealed
                          ? Colors.amber
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                if (validItems.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => _showCollageGalleryLightbox(
                      context,
                      validItems,
                      0,
                      isDark,
                    ),
                    icon: const Icon(Icons.fullscreen_rounded, size: 16),
                    label: const Text(
                      'Full Gallery',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Collage Grid
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                int columns = 3;
                if (width < 600) {
                  columns = 1;
                } else if (width < 960) {
                  columns = 2;
                } else {
                  columns = 3;
                }

                const spacing = 12.0;
                final totalSpacing = spacing * (columns - 1);
                final tileWidth = (width - totalSpacing) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: items.map((item) {
                    return SizedBox(
                      width: tileWidth,
                      child: _buildCollageTile(
                        context: context,
                        item: item,
                        allValidItems: validItems,
                        itemIndexInValid: validItems.indexOf(item),
                        isRevealed: isCardRevealed,
                        isDark: isDark,
                        cardId: cardId,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollageTile({
    required BuildContext context,
    required AdminCollageItem item,
    required List<AdminCollageItem> allValidItems,
    required int itemIndexInValid,
    required bool isRevealed,
    required bool isDark,
    required String cardId,
  }) {
    final hasUrl = item.hasUrl;
    final localKey = '${cardId}_${item.title}';
    final isLocallyRevealed =
        isRevealed || _revealedCardIds.contains(localKey);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tile Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.3,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle!,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasUrl) ...[
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    tooltip: 'Open in new tab',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                    color: isDark ? Colors.white60 : Colors.grey.shade700,
                    onPressed: () => _openUrl(item.url!),
                  ),
                ],
              ],
            ),
          ),

          // Media Area
          AspectRatio(
            aspectRatio: 16 / 10,
            child: !hasUrl
                ? Container(
                    color: isDark ? Colors.black38 : Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.placeholderIcon,
                          size: 28,
                          color:
                              isDark ? Colors.white24 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Not submitted',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : isLocallyRevealed
                    ? InkWell(
                        onTap: () {
                          final idx =
                              itemIndexInValid >= 0 ? itemIndexInValid : 0;
                          _showCollageGalleryLightbox(
                            context,
                            allValidItems,
                            idx,
                            isDark,
                          );
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            OptimizedNetworkImage(
                              imageUrl: item.url!,
                              fit: BoxFit.cover,
                              isThumbnail: false,
                              errorWidget: Container(
                                color: isDark
                                    ? Colors.black45
                                    : Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.zoom_in_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Material(
                        color: isDark ? Colors.black38 : Colors.grey.shade100,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _revealedCardIds.add(localKey);
                            });
                          },
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.visibility_rounded,
                                      size: 20,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Tap to inspect',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'or click Reveal All',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
          ),

          // Indicator Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  hasUrl ? Icons.check_circle_rounded : Icons.cancel_outlined,
                  size: 13,
                  color: hasUrl ? Colors.green : Colors.grey.shade500,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasUrl ? 'Document uploaded' : 'Missing document',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: hasUrl
                          ? (isDark
                              ? Colors.green.shade300
                              : Colors.green.shade700)
                          : (isDark ? Colors.white38 : Colors.grey.shade600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCollageGalleryLightbox(
    BuildContext context,
    List<AdminCollageItem> items,
    int initialIndex,
    bool isDark,
  ) {
    if (items.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        int currentIndex = initialIndex.clamp(0, items.length - 1);

        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentItem = items[currentIndex];
            final screenHeight = MediaQuery.of(context).size.height;
            final screenWidth = MediaQuery.of(context).size.width;
            final maxDialogWidth = (screenWidth * 0.85).clamp(400.0, 1000.0);
            final maxDialogHeight = (screenHeight * 0.88).clamp(450.0, 850.0);

            return Dialog(
              backgroundColor:
                  isDark ? const Color(0xFF021F35) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Container(
                width: maxDialogWidth,
                height: maxDialogHeight,
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    // Lightbox Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      currentItem.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 17,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
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
                                      color: AppColors.primary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${currentIndex + 1} of ${items.length}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (currentItem.subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  currentItem.subtitle!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            if (currentItem.hasUrl)
                              IconButton(
                                icon: const Icon(Icons.open_in_new_rounded),
                                tooltip: 'Open in browser',
                                onPressed: () => _openUrl(currentItem.url!),
                              ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Close',
                              onPressed: () => Navigator.of(dialogContext).pop(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Image Viewer with InteractiveViewer + Left/Right arrows
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black38
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.borderColor
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: InteractiveViewer(
                              panEnabled: true,
                              minScale: 0.5,
                              maxScale: 4.0,
                              child: Center(
                                child: OptimizedNetworkImage(
                                  imageUrl: currentItem.url ?? '',
                                  fit: BoxFit.contain,
                                  isThumbnail: false,
                                  errorWidget: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.broken_image_outlined,
                                          size: 48,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Unable to display image',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Left navigation button
                          if (currentIndex > 0)
                            Positioned(
                              left: 12,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.chevron_left_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        currentIndex--;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          // Right navigation button
                          if (currentIndex < items.length - 1)
                            Positioned(
                              right: 12,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        currentIndex++;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Bottom Thumbnail Strip
                    if (items.length > 1) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 56,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final isSelected = idx == currentIndex;
                            final itm = items[idx];
                            return InkWell(
                              onTap: () {
                                setModalState(() {
                                  currentIndex = idx;
                                });
                              },
                              child: Container(
                                width: 56,
                                height: 56,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark
                                            ? Colors.white24
                                            : Colors.grey.shade300),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: OptimizedNetworkImage(
                                  imageUrl: itm.url ?? '',
                                  fit: BoxFit.cover,
                                  isThumbnail: true,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailCard(
    String label,
    String value,
    bool isDark, {
    IconData? icon,
    Color? highlightColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              highlightColor?.withValues(alpha: 0.4) ??
              (isDark ? AppColors.borderColor : Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color:
                      highlightColor ??
                      (isDark ? Colors.white54 : Colors.grey.shade600),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.4,
                    color:
                        highlightColor ??
                        (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: highlightColor ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreview({
    required String title,
    required String url,
    required bool isDark,
    BuildContext? context,
  }) {
    final hasUrl = url.trim().isNotEmpty;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade800,
                    ),
                  ),
                ),
                if (hasUrl) ...[
                  InkWell(
                    onTap: () => _openUrl(url),
                    child: Icon(
                      Icons.open_in_new_rounded,
                      size: 14,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: hasUrl
                ? InkWell(
                    onTap: () {
                      if (context != null) {
                        _showImageLightbox(context, title, url, isDark);
                      } else {
                        _openUrl(url);
                      }
                    },
                    child: OnDemandNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      label: 'Tap to inspect document',
                    ),
                  )
                : Container(
                    color: isDark ? Colors.black26 : Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.insert_drive_file_outlined,
                          size: 28,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Not submitted',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: DialogStatusIndicator(
              compact: true,
              isComplete: hasUrl,
              completeLabel: 'Document submitted',
              incompleteLabel: 'Document missing',
              completeDetail: 'Available for admin review.',
              incompleteDetail: 'Required document has not been submitted.',
            ),
          ),
        ],
      ),
    );
  }

  void _showImageLightbox(
    BuildContext context,
    String title,
    String url,
    bool isDark,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxDialogWidth = (screenWidth * 0.75).clamp(360.0, 750.0);
    final maxDialogHeight = (screenHeight * 0.80).clamp(400.0, 720.0);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: isDark ? const Color(0xFF021F35) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Container(
          width: maxDialogWidth,
          height: maxDialogHeight,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.badge_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Open in new tab',
                        icon: const Icon(Icons.open_in_new_rounded, size: 20),
                        onPressed: () => _openUrl(url),
                      ),
                      IconButton(
                        tooltip: 'Close modal',
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade300,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Center(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                                color: AppColors.primary,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                padding: const EdgeInsets.all(40),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.broken_image_rounded,
                                      size: 48,
                                      color: Colors.white54,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Unable to load document image',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.zoom_in_rounded,
                    size: 14,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Scroll or pinch to zoom • Drag to pan document',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showRejectionReasonDialog(
    BuildContext context,
    String userName,
    bool isDark,
  ) async {
    String selectedReason = 'Unclear or blurry ID document photo';
    final customReasonController = TextEditingController();
    final reasons = [
      'Unclear or blurry ID document photo',
      'Full name or ID number mismatch',
      'Expired Driver\'s License or ID document',
      'Face Selfie does not match ID photo',
      'Missing NBI clearance or required digital signature',
      'Other reason (Specify below)',
    ];

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark
                  ? AppColors.darkBgSecondary
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: Colors.red,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reject Verification: $userName',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Please select a clear rejection reason to inform the applicant:',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...reasons.map(
                      (reason) => RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          reason,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        value: reason,
                        groupValue: selectedReason,
                        activeColor: Colors.red,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedReason = val);
                          }
                        },
                      ),
                    ),
                    if (selectedReason.startsWith('Other')) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customReasonController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter specific rejection feedback...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.black26
                              : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final finalReason = selectedReason.startsWith('Other')
                        ? (customReasonController.text.trim().isNotEmpty
                              ? customReasonController.text.trim()
                              : 'Rejected by admin')
                        : selectedReason;
                    Navigator.pop(dialogContext, finalReason);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Confirm Rejection'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openUrl(String url) {
    if (!kIsWeb) return;
    final anchor = html.AnchorElement(href: url)..target = '_blank';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Unknown';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }
}
