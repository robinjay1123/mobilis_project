part of '../operator_web_screen.dart';

extension _OperatorInspectionsTab on _OperatorWebScreenState {
  Widget _buildInspectionsContent(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    final bookingsNeedingRelease = _recentBookings.where((b) {
      final status = (b['status'] ?? '').toString().toLowerCase();
      return status == 'confirmed' ||
          status == 'approved' ||
          status == 'pending_release';
    }).toList();

    final bookingsNeedingReturn = _recentBookings.where((b) {
      final status = (b['status'] ?? '').toString().toLowerCase();
      return status == 'active' ||
          status == 'in_progress' ||
          status == 'pending_return';
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF032A46), const Color(0xFF021F35)]
                    : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _operatorGold.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _operatorGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vehicle Release & Return Inspection Hub',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Capture odometer readings and exterior photos during vehicle release & return handover.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 1: Ready for Release / Handover
          Row(
            children: [
              Icon(Icons.no_crash_rounded, color: _operatorGold, size: 20),
              const SizedBox(width: 8),
              Text(
                'Ready for Release & Handover (${bookingsNeedingRelease.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (bookingsNeedingRelease.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 40,
                    color: textSecondary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No bookings pending release inspection right now.',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bookingsNeedingRelease.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final b = bookingsNeedingRelease[index];
                return _buildInspectionBookingCard(
                  b,
                  isRelease: true,
                  isDark: isDark,
                );
              },
            ),

          const SizedBox(height: 28),

          // Section 2: Active / Awaiting Return Inspection
          Row(
            children: [
              Icon(
                Icons.assignment_turned_in_rounded,
                color: AppColors.success,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Active Trips Awaiting Return Inspection (${bookingsNeedingReturn.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (bookingsNeedingReturn.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.thumb_up_alt_outlined,
                    size: 40,
                    color: textSecondary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No active trips pending return inspection.',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bookingsNeedingReturn.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final b = bookingsNeedingReturn[index];
                return _buildInspectionBookingCard(
                  b,
                  isRelease: false,
                  isDark: isDark,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInspectionBookingCard(
    Map<String, dynamic> booking, {
    required bool isRelease,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renter = booking['renter'] as Map<String, dynamic>? ?? {};
    final vehicleTitle = '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'
        .trim();
    final plate = vehicle['plate_number']?.toString() ?? 'N/A';
    final renterName = renter['full_name']?.toString() ?? 'Renter';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (isRelease ? _operatorGold : AppColors.success)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isRelease ? 'READY FOR RELEASE' : 'ACTIVE TRIP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isRelease ? _operatorGold : AppColors.success,
                  ),
                ),
              ),
              if (_isPartnerVehicleBooking(booking)) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.purple.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.handshake_outlined,
                        size: 12,
                        color: Colors.purpleAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Partner',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.purple[200]
                              : Colors.purple[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Text(
                'BOOKING #${booking['id'].toString().substring(0, booking['id'].toString().length > 8 ? 8 : booking['id'].toString().length)}',
                style: TextStyle(
                  fontSize: 11,
                  color: textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            vehicleTitle.isNotEmpty ? vehicleTitle : 'Vehicle',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Plate: $plate • Renter: $renterName',
            style: TextStyle(fontSize: 13, color: textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openReleaseInspectionDialog(
                booking,
                inspectionType: isRelease ? 'release' : 'return',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isRelease ? _operatorGold : AppColors.primary,
                foregroundColor: isRelease ? _operatorNavyDeep : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.camera_alt_rounded, size: 20),
              label: Text(
                isRelease
                    ? 'Start Release Inspection & Photo Capture'
                    : 'Start Return Inspection & Photo Capture',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openReleaseInspectionDialog(
    Map<String, dynamic> booking, {
    String inspectionType = 'release',
  }) {
    _inspectionOdometerController.clear();
    _inspectionNotesController.clear();
    String currentFuel = '100% Full';

    XFile? odometerPhoto;
    XFile? frontPhoto;
    XFile? rearPhoto;
    XFile? leftPhoto;
    XFile? rightPhoto;
    List<XFile> damagePhotos = [];
    bool isSubmitting = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renter = booking['renter'] as Map<String, dynamic>? ?? {};
    final vehicleTitle = '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'
        .trim();
    final plateNumber = vehicle['plate_number']?.toString() ?? 'N/A';
    final renterName = renter['full_name']?.toString() ?? 'Renter';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> pickPhotoSlot(
            void Function(XFile? file) onPicked, {
            bool isMulti = false,
          }) async {
            final source = await showModalBottomSheet<ImageSource>(
              context: context,
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (ctx) => Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Capture / Select Photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(
                        Icons.camera_alt_rounded,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        'Take Photo with Camera',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      onTap: () => Navigator.pop(ctx, ImageSource.camera),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.photo_library_rounded,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        'Choose from Gallery',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                    ),
                  ],
                ),
              ),
            );

            if (source != null) {
              if (isMulti && source == ImageSource.gallery) {
                final files = await _imagePicker.pickMultiImage(
                  imageQuality: 85,
                );
                if (files.isNotEmpty) {
                  setSheetState(() => damagePhotos.addAll(files));
                }
              } else {
                final file = await _imagePicker.pickImage(
                  source: source,
                  imageQuality: 85,
                );
                if (file != null) {
                  setSheetState(() => onPicked(file));
                }
              }
            }
          }

          Widget photoTile({
            required String title,
            required IconData icon,
            required XFile? file,
            required VoidCallback onTap,
            required VoidCallback onDelete,
          }) {
            return Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: file != null
                      ? AppColors.primary
                      : (isDark ? Colors.white12 : Colors.grey.shade300),
                  width: file != null ? 2 : 1,
                ),
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (file != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FutureBuilder<Uint8List>(
                            future: file.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(
                                  snapshot.data!,
                                  height: 60,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                );
                              }
                              return const SizedBox(
                                height: 60,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.redAccent,
                              ),
                              onPressed: onDelete,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ] else ...[
                        Icon(
                          icon,
                          size: 28,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.camera_alt,
                              size: 12,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Tap to Capture',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Modal Handle Bar
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _operatorGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          inspectionType == 'release'
                              ? Icons.no_crash_rounded
                              : Icons.assignment_turned_in_rounded,
                          color: _operatorGold,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inspectionType == 'release'
                                  ? 'Vehicle Release Inspection'
                                  : 'Vehicle Return Inspection',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              '$vehicleTitle ($plateNumber) • Renter: $renterName',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        onPressed: () => Navigator.pop(bottomSheetContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Odometer Input
                        Text(
                          '1. Current Odometer Reading (km)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _inspectionOdometerController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter current odometer (e.g. 45210)',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey[500]
                                  : Colors.grey[400],
                            ),
                            suffixText: 'km',
                            prefixIcon: const Icon(
                              Icons.speed_rounded,
                              color: AppColors.primary,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Fuel Level Selector
                        Text(
                          '2. Vehicle Fuel Level',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              [
                                '100% Full',
                                '3/4 Full',
                                '1/2 Full',
                                '1/4 Full',
                                'Low / Reserve',
                              ].map((fuel) {
                                final selected = currentFuel == fuel;
                                return ChoiceChip(
                                  label: Text(fuel),
                                  selected: selected,
                                  onSelected: (_) =>
                                      setSheetState(() => currentFuel = fuel),
                                  selectedColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.grey[300]
                                              : Colors.black87),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 22),

                        // Required Photo Grid
                        Row(
                          children: [
                            Text(
                              '3. Inspection Photos (Camera / Gallery)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              'Camera Supported',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.3,
                          children: [
                            photoTile(
                              title: 'Odometer',
                              icon: Icons.speed_rounded,
                              file: odometerPhoto,
                              onTap: () =>
                                  pickPhotoSlot((f) => odometerPhoto = f),
                              onDelete: () =>
                                  setSheetState(() => odometerPhoto = null),
                            ),
                            photoTile(
                              title: 'Front Exterior',
                              icon: Icons.directions_car_rounded,
                              file: frontPhoto,
                              onTap: () => pickPhotoSlot((f) => frontPhoto = f),
                              onDelete: () =>
                                  setSheetState(() => frontPhoto = null),
                            ),
                            photoTile(
                              title: 'Rear Exterior',
                              icon: Icons.time_to_leave_rounded,
                              file: rearPhoto,
                              onTap: () => pickPhotoSlot((f) => rearPhoto = f),
                              onDelete: () =>
                                  setSheetState(() => rearPhoto = null),
                            ),
                            photoTile(
                              title: 'Left Exterior',
                              icon: Icons.unfold_more_rounded,
                              file: leftPhoto,
                              onTap: () => pickPhotoSlot((f) => leftPhoto = f),
                              onDelete: () =>
                                  setSheetState(() => leftPhoto = null),
                            ),
                            photoTile(
                              title: 'Right Exterior',
                              icon: Icons.unfold_more_rounded,
                              file: rightPhoto,
                              onTap: () => pickPhotoSlot((f) => rightPhoto = f),
                              onDelete: () =>
                                  setSheetState(() => rightPhoto = null),
                            ),
                            photoTile(
                              title: 'Damage / Scratch',
                              icon: Icons.warning_amber_rounded,
                              file: damagePhotos.isNotEmpty
                                  ? damagePhotos.first
                                  : null,
                              onTap: () => pickPhotoSlot((f) {}, isMulti: true),
                              onDelete: () =>
                                  setSheetState(() => damagePhotos.clear()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Remarks / Notes
                        Text(
                          '4. Inspection Remarks & Observations',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _inspectionNotesController,
                          maxLines: 3,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Notes on vehicle condition, scratches, or special tools provided...',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey[500]
                                  : Colors.grey[400],
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Footer Submit Button with correct padding!
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final odoText = _inspectionOdometerController.text
                                  .trim();
                              if (odoText.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter current odometer reading',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              setSheetState(() => isSubmitting = true);
                              try {
                                final List<String> uploadedUrls = [];
                                final photosToUpload = [
                                  odometerPhoto,
                                  frontPhoto,
                                  rearPhoto,
                                  leftPhoto,
                                  rightPhoto,
                                  ...damagePhotos,
                                ].whereType<XFile>().toList();

                                for (
                                  int i = 0;
                                  i < photosToUpload.length;
                                  i++
                                ) {
                                  final file = photosToUpload[i];
                                  final fileName =
                                      'inspection_${booking['id']}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
                                  final path =
                                      'inspections/${booking['id']}/$fileName';
                                  final bytes = await file.readAsBytes();
                                  final optBytes =
                                      await ImageOptimizationService.optimizeForUpload(
                                        bytes,
                                        fileName: fileName,
                                      );
                                  await _supabase.storage
                                      .from(_vehicleImagesBucket)
                                      .uploadBinary(
                                        path,
                                        optBytes,
                                        fileOptions: const FileOptions(
                                          cacheControl: '31536000',
                                          upsert: false,
                                        ),
                                      );
                                  final publicUrl = _supabase.storage
                                      .from(_vehicleImagesBucket)
                                      .getPublicUrl(path);
                                  uploadedUrls.add(publicUrl);
                                }

                                final isRelease = inspectionType == 'release';
                                final newStatus = isRelease
                                    ? 'active'
                                    : 'completed';

                                final inspectionPayload = {
                                  'type': inspectionType,
                                  'odometer': double.tryParse(odoText) ?? 0,
                                  'fuel_level': currentFuel,
                                  'notes': _inspectionNotesController.text
                                      .trim(),
                                  'photos': uploadedUrls,
                                  'inspected_at': DateTime.now()
                                      .toIso8601String(),
                                  'inspected_by': _operatorDisplayName(),
                                };

                                await BookingService.safeUpdateBooking(booking['id'], {
                                  'status': newStatus,
                                  if (isRelease)
                                    'operator_release_inspection':
                                        inspectionPayload,
                                  if (!isRelease)
                                    'operator_return_inspection':
                                        inspectionPayload,
                                  if (isRelease)
                                    'operator_released_at': DateTime.now()
                                        .toIso8601String(),
                                  if (!isRelease)
                                    'operator_returned_at': DateTime.now()
                                        .toIso8601String(),
                                });

                                if (bottomSheetContext.mounted) {
                                  Navigator.pop(bottomSheetContext);
                                }
                                await _loadDashboardData();

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isRelease
                                            ? 'Release Inspection completed! Vehicle handed over to renter.'
                                            : 'Return Inspection completed! Vehicle return finalized.',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error saving inspection: $e',
                                      ),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setSheetState(() => isSubmitting = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _operatorGold,
                        foregroundColor: _operatorNavyDeep,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Icon(
                              inspectionType == 'release'
                                  ? Icons.check_circle_rounded
                                  : Icons.task_alt_rounded,
                              size: 22,
                            ),
                      label: Text(
                        isSubmitting
                            ? 'Saving Inspection...'
                            : (inspectionType == 'release'
                                  ? 'Complete Release Inspection & Handover'
                                  : 'Complete Return Inspection'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>?> _findVehicleForPriceRequest(
    Map<String, dynamic> data,
  ) async {
    final vehicleId = data['vehicle_id']?.toString() ?? '';
    final partnerVehicleId = data['partner_vehicle_id']?.toString() ?? '';
    final vehicleTitle = (data['vehicle_title'] ?? '').toString().toLowerCase().trim();

    // 1. Search in cached _vehicles
    for (final v in _vehicles) {
      final vId = v['id']?.toString() ?? '';
      final pId = (v['partner_vehicle_id'] ?? v['_partner_vehicle_id'])?.toString() ?? '';
      if ((vehicleId.isNotEmpty && vId == vehicleId) ||
          (partnerVehicleId.isNotEmpty && (pId == partnerVehicleId || vId == partnerVehicleId))) {
        return Map<String, dynamic>.from(v);
      }
    }

    if (vehicleTitle.isNotEmpty) {
      for (final v in _vehicles) {
        final title = '${v['brand'] ?? ''} ${v['model'] ?? ''}'.toLowerCase().trim();
        final name = (v['vehicle_name'] ?? '').toString().toLowerCase().trim();
        if (title == vehicleTitle || name == vehicleTitle) {
          return Map<String, dynamic>.from(v);
        }
      }
    }

    // 2. Fetch directly from vehicles table in Supabase
    if (vehicleId.isNotEmpty) {
      try {
        final res = await _supabase
            .from('vehicles')
            .select('*')
            .eq('id', vehicleId)
            .maybeSingle();
        if (res != null) return Map<String, dynamic>.from(res);
      } catch (_) {}
    }

    // 3. Fetch from partner_vehicles table in Supabase
    if (partnerVehicleId.isNotEmpty) {
      try {
        final res = await _supabase
            .from('partner_vehicles')
            .select('*')
            .eq('id', partnerVehicleId)
            .maybeSingle();
        if (res != null) {
          final mapped = Map<String, dynamic>.from(res);
          mapped['_source'] = 'partner';
          mapped['is_partner_vehicle'] = true;
          return mapped;
        }
      } catch (_) {}
    }

    // 4. Fetch from partner_vehicle_applications table in Supabase
    final applicationId = data['application_id']?.toString() ?? '';
    if (applicationId.isNotEmpty) {
      try {
        final res = await _supabase
            .from('partner_vehicle_applications')
            .select('*')
            .eq('id', applicationId)
            .maybeSingle();
        if (res != null) {
          final mapped = Map<String, dynamic>.from(res);
          mapped['_source'] = 'partner_application';
          mapped['is_partner_vehicle'] = true;
          return mapped;
        }
      } catch (_) {}
    }

    // 5. Fallback object from payload data
    return <String, dynamic>{
      'id': vehicleId.isNotEmpty ? vehicleId : (partnerVehicleId.isNotEmpty ? partnerVehicleId : applicationId),
      'partner_vehicle_id': partnerVehicleId,
      'application_id': applicationId,
      'image_url': data['image_url'] ?? data['vehicle_image_url'] ?? data['photo_url'],
      'brand': vehicleTitle.split(' ').first,
      'model': vehicleTitle.split(' ').skip(1).join(' '),
      'price_per_day': data['current_price_per_day'] ?? 0,
      'price_per_hour': data['current_price_per_hour'] ?? 0,
      '_source': 'partner',
      'is_partner_vehicle': true,
      'partner_id': data['partner_id'],
    };
  }

    Future<void> _handleApprovePriceRequest(
    Map<String, dynamic> req,
    bool isDark,
  ) async {
    final data = req['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(req['data'])
        : (req['data'] is Map
            ? Map<String, dynamic>.from(req['data'] as Map)
            : <String, dynamic>{});

    final vehicleTitle = (data['vehicle_title'] ?? req['title'] ?? 'Vehicle').toString();
    final reqDaily = (data['requested_price_per_day'] as num?)?.toDouble() ??
        double.tryParse(data['requested_price_per_day']?.toString() ?? '') ?? 0.0;
    final reqHourly = (data['requested_price_per_hour'] as num?)?.toDouble() ??
        double.tryParse(data['requested_price_per_hour']?.toString() ?? '') ?? 0.0;
    final currentDaily = (data['current_price_per_day'] as num?)?.toDouble() ?? 0.0;
    final currentHourly = (data['current_price_per_hour'] as num?)?.toDouble() ?? 0.0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 10),
            Text(
              'Approve Price Change',
              style: TextStyle(
                color: isDark ? Colors.white : _operatorInk,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Approve and automatically update the rental rates for $vehicleTitle?',
                style: TextStyle(
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Current Rates:', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
                        Text('PHP ${_formatCurrency(currentDaily)}/day • PHP ${_formatCurrency(currentHourly)}/hr', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('New Daily Rate:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text('PHP ${_formatCurrency(reqDaily)} /day', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF10B981))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('New Hourly Rate:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text('PHP ${_formatCurrency(reqHourly)} /hr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF10B981))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The vehicle price will be updated automatically in the database and catalog. The partner will be notified immediately.',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Approve & Apply Price', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 10),
            Text(
              'Confirm Price Update',
              style: TextStyle(
                color: isDark ? Colors.white : _operatorInk,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to approve and apply these new rates for $vehicleTitle?',
                style: TextStyle(
                  color: isDark ? Colors.grey[200] : Colors.grey[900],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• New Daily Rate: PHP ${_formatCurrency(reqDaily)} /day',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• New Hourly Rate: PHP ${_formatCurrency(reqHourly)} /hr',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Once confirmed, the vehicle prices will update automatically across the platform without opening the edit vehicle window.',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmCtx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(confirmCtx, true),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Yes, Apply Price', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (doubleConfirmed != true) return;

    try {
      final reqId = req['id']?.toString() ?? '';
      final vehicleId = (data['vehicle_id'] ?? data['created_vehicle_id'] ?? '').toString();
      final partnerVehicleId = (data['partner_vehicle_id'] ?? '').toString();
      final applicationId = (data['application_id'] ?? '').toString();
      final partnerId = (data['partner_id'] ?? '').toString();

      // 1. Automatically update vehicles table
      if (vehicleId.isNotEmpty) {
        try {
          await _supabase.from('vehicles').update({
            'price_per_day': reqDaily,
            'price_per_hour': reqHourly,
            'daily_rate': reqDaily,
            'hourly_rate': reqHourly,
          }).eq('id', vehicleId);
        } catch (_) {
          try {
            await _supabase.from('vehicles').update({
              'price_per_day': reqDaily,
              'price_per_hour': reqHourly,
            }).eq('id', vehicleId);
          } catch (err) {
            debugPrint('Error updating vehicles table: $err');
          }
        }
      }

      // 2. Automatically update partner_vehicles table
      if (partnerVehicleId.isNotEmpty) {
        try {
          await _supabase.from('partner_vehicles').update({
            'price_per_day': reqDaily,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', partnerVehicleId);
        } catch (err) {
          debugPrint('Error updating partner_vehicles table: $err');
        }
      } else if (applicationId.isNotEmpty) {
        try {
          final appRes = await _supabase
              .from('partner_vehicle_applications')
              .select('partner_vehicle_id')
              .eq('id', applicationId)
              .maybeSingle();
          final resolvedPvId = appRes?['partner_vehicle_id']?.toString();
          if (resolvedPvId != null && resolvedPvId.isNotEmpty) {
            await _supabase.from('partner_vehicles').update({
              'price_per_day': reqDaily,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', resolvedPvId);
          }
        } catch (err) {
          debugPrint('Error resolving partner_vehicles from application: $err');
        }
      }

      // 3. Automatically update partner_vehicle_applications table
      if (applicationId.isNotEmpty) {
        try {
          await _supabase.from('partner_vehicle_applications').update({
            'price_per_day': reqDaily,
            'price_per_hour': reqHourly,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', applicationId);
        } catch (err) {
          debugPrint('Error updating partner_vehicle_applications table: $err');
        }
      } else if (partnerVehicleId.isNotEmpty) {
        try {
          await _supabase.from('partner_vehicle_applications').update({
            'price_per_day': reqDaily,
            'price_per_hour': reqHourly,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('partner_vehicle_id', partnerVehicleId);
        } catch (err) {
          debugPrint('Error updating partner_vehicle_applications table: $err');
        }
      }

      // If vehicle record is only matched by title or partner id, find and update
      if (vehicleId.isEmpty && partnerVehicleId.isEmpty) {
        final vehicle = await _findVehicleForPriceRequest(data);
        if (vehicle != null && vehicle['id'] != null) {
          try {
            await _supabase.from('vehicles').update({
              'price_per_day': reqDaily,
              'price_per_hour': reqHourly,
            }).eq('id', vehicle['id'].toString());
          } catch (_) {}
        }
      }

      // 4. Update the price request notification record
      if (reqId.isNotEmpty) {
        await _supabase.from('notifications').update({
          'is_read': true,
          'data': {
            ...data,
            'status': 'approved',
            'approved': true,
            'approved_at': DateTime.now().toIso8601String(),
            'approved_price_per_day': reqDaily,
            'approved_price_per_hour': reqHourly,
          },
        }).eq('id', reqId);
      }

      // 5. Send confirmation notification to partner
      if (partnerId.isNotEmpty) {
        await NotificationService().createNotification(
          userId: partnerId,
          title: 'Price Change Approved',
          message: 'Your price change request for $vehicleTitle was approved! New rates: PHP ${_formatCurrency(reqDaily)}/day (PHP ${_formatCurrency(reqHourly)}/hr). Rates have been automatically updated in the system.',
          type: 'partner_price_change_approved',
          data: {
            'vehicle_id': vehicleId,
            'partner_vehicle_id': partnerVehicleId,
            'application_id': applicationId,
            'price_per_day': reqDaily,
            'price_per_hour': reqHourly,
            'status': 'approved',
          },
        );
      }

      // 6. Reload data in operator view
      await Future.wait([
        _loadVehicles(),
        _loadPriceChangeRequests(),
      ]);

      if (mounted) {
        _showOperatorCheckModal(
          title: 'Price Approved!',
          message:
              'Rates for $vehicleTitle have been automatically updated to PHP ${_formatCurrency(reqDaily)}/day (PHP ${_formatCurrency(reqHourly)}/hr).',
          accentColor: const Color(0xFF10B981),
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving price change: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDeclinePriceRequest(
    Map<String, dynamic> req,
    bool isDark,
  ) async {
    final reasonController = TextEditingController(
      text: 'Proposed price exceeds current market standards for this vehicle category. Please consider adjusting the rate.',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: Colors.red),
            const SizedBox(width: 10),
            Text(
              'Decline Price Request',
              style: TextStyle(
                color: isDark ? Colors.white : _operatorInk,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Operator Note / Message for Partner:',
                style: TextStyle(
                  color: isDark ? Colors.white : _operatorInk,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'This message will be directly visible to the fleet partner explaining why the request was declined.',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 4,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: 'Enter explanation or recommendation for partner...',
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF7F8F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Decline & Send Note', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final reqId = req['id']?.toString() ?? '';
      final data = req['data'] is Map
          ? Map<String, dynamic>.from(req['data'] as Map)
          : <String, dynamic>{};
      final reason = reasonController.text.trim();

      await _supabase.from('notifications').update({
        'is_read': true,
        'data': {
          ...data,
          'status': 'declined',
          'declined': true,
          'declined_at': DateTime.now().toIso8601String(),
          'decline_reason': reason,
          'operator_note': reason,
        },
      }).eq('id', reqId);

      final partnerId = data['partner_id']?.toString() ?? '';
      final vehicleTitle = data['vehicle_title']?.toString() ?? 'your vehicle';
      if (partnerId.isNotEmpty) {
        await NotificationService().createNotification(
          userId: partnerId,
          title: 'Price Change Declined',
          message: 'Your price change request for $vehicleTitle was declined.\nOperator Note: $reason',
          type: 'partner_price_change_declined',
          data: {
            'vehicle_id': data['vehicle_id'],
            'partner_vehicle_id': data['partner_vehicle_id'],
            'reason': reason,
            'operator_note': reason,
            'decline_reason': reason,
          },
        );
      }

      await _loadPriceChangeRequests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Price change request declined. Note sent to partner.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

