part of '../operator_web_screen.dart';

extension OperatorPriceRequestsTab on _OperatorWebScreenState {
  Widget _buildPriceRequestsContent(bool isDark) {
    // Filter and search price requests
    final filtered = _priceChangeRequests.where((req) {
      final data = req['data'] is Map
          ? Map<String, dynamic>.from(req['data'] as Map)
          : <String, dynamic>{};
      final status = (data['status'] ?? '').toString().toLowerCase();
      final isApproved = data['approved'] == true || status == 'approved';
      final isDeclined = data['declined'] == true || status == 'declined' || status == 'rejected';
      final isPending = !isApproved && !isDeclined;

      if (_priceRequestFilter == 'pending' && !isPending) return false;
      if (_priceRequestFilter == 'approved' && !isApproved) return false;
      if (_priceRequestFilter == 'declined' && !isDeclined) return false;

      if (_priceRequestSearchQuery.isNotEmpty) {
        final query = _priceRequestSearchQuery.toLowerCase();
        final title = (data['vehicle_title'] ?? req['title'] ?? '').toString().toLowerCase();
        final message = (req['message'] ?? '').toString().toLowerCase();
        final note = (data['note'] ?? '').toString().toLowerCase();
        final opNote = (data['operator_note'] ?? data['decline_reason'] ?? '').toString().toLowerCase();
        if (!title.contains(query) && !message.contains(query) && !note.contains(query) && !opNote.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Price Change Requests',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : _operatorInk,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (_pendingPriceRequestsCount > 0) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_pendingPriceRequestsCount New',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Direct requests from fleet partners to adjust daily and hourly rental rates. Review full vehicle details before approving.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _loadPriceChangeRequests(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E2A3A) : const Color(0xFFEAEFF5),
                  foregroundColor: isDark ? Colors.white : _operatorInk,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Search and Filters Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                // Search Input
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _priceRequestSearchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search by vehicle, note, or title...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFF7F8F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Filter Tabs
            _buildPriceFilterPill('all', 'All (${_priceChangeRequests.length})', isDark),
            const SizedBox(width: 8),
            _buildPriceFilterPill(
              'pending',
              'Pending ($_pendingPriceRequestsCount)',
              isDark,
              isHighlight: _pendingPriceRequestsCount > 0,
            ),
            const SizedBox(width: 8),
            _buildPriceFilterPill(
              'approved',
              'Approved (${_priceChangeRequests.where((r) {
                final d = r['data'] is Map ? r['data'] as Map : {};
                return d['approved'] == true || d['status'] == 'approved';
              }).length})',
              isDark,
            ),
            const SizedBox(width: 8),
            _buildPriceFilterPill(
              'declined',
              'Declined (${_priceChangeRequests.where((r) {
                final d = r['data'] is Map ? r['data'] as Map : {};
                return d['declined'] == true || d['status'] == 'declined' || d['status'] == 'rejected';
              }).length})',
              isDark,
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),

      // Request Cards List / Grid
      if (filtered.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 60),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.borderColor : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.price_change_outlined,
                size: 54,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(height: 14),
              Text(
                _priceRequestFilter == 'pending'
                    ? 'No pending price change requests'
                    : 'No price change requests found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'When partners submit a rate update, it will appear directly here.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
          ),
        )
      else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (ctx, idx) => _buildPriceRequestCard(filtered[idx], isDark),
        ),
      ],
    ),
  );
}

  Widget _buildPriceFilterPill(
    String key,
    String label,
    bool isDark, {
    bool isHighlight = false,
  }) {
    final isSelected = _priceRequestFilter == key;
    return InkWell(
      onTap: () => setState(() => _priceRequestFilter = key),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isHighlight ? Colors.red : _operatorGold)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F4F8)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? (isHighlight ? Colors.red : _operatorGold)
                : (isDark ? AppColors.borderColor : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? (isHighlight ? Colors.white : Colors.black)
                : (isDark ? Colors.white70 : _operatorInk),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRequestCard(Map<String, dynamic> req, bool isDark) {
    final data = req['data'] is Map
        ? Map<String, dynamic>.from(req['data'] as Map)
        : <String, dynamic>{};

    final status = (data['status'] ?? '').toString().toLowerCase();
    final isApproved = data['approved'] == true || status == 'approved';
    final isDeclined = data['declined'] == true || status == 'declined' || status == 'rejected';
    final isPending = !isApproved && !isDeclined;

    final vehicleTitle = (data['vehicle_title'] ?? req['title'] ?? 'Vehicle Price Request').toString();
    final currentDaily = (data['current_price_per_day'] as num?)?.toDouble() ?? 0.0;
    final reqDaily = (data['requested_price_per_day'] as num?)?.toDouble() ?? 0.0;
    final currentHourly = (data['current_price_per_hour'] as num?)?.toDouble() ?? 0.0;
    final reqHourly = (data['requested_price_per_hour'] as num?)?.toDouble() ?? 0.0;
    final note = (data['note'] ?? '').toString().trim();
    final operatorNote = (data['operator_note'] ?? data['decline_reason'] ?? '').toString().trim();
    final createdAt = req['created_at']?.toString() ?? '';
    final formattedDate = createdAt.isNotEmpty
        ? DateTime.tryParse(createdAt)?.toLocal().toString().split('.')[0] ?? createdAt
        : 'Recently';

    final dailyDiff = reqDaily - currentDaily;

    // Resolve vehicle image from all possible sources
    final directImg = (data['image_url'] ?? data['vehicle_image_url'] ?? data['photo_url'])?.toString().trim() ?? '';
    var carImageUrl = _normalizeVehicleImageUrl(directImg);
    if (carImageUrl.isEmpty) {
      final vid = (data['vehicle_id'] ?? data['partner_vehicle_id'] ?? data['application_id'])?.toString().trim() ?? '';
      if (vid.isNotEmpty) {
        for (final v in [..._vehicles, ..._partnerVehicles]) {
          final vId = v['id']?.toString() ?? '';
          final pId = (v['partner_vehicle_id'] ?? v['_partner_vehicle_id'] ?? v['application_id'])?.toString() ?? '';
          if (vId == vid || pId == vid) {
            carImageUrl = _primaryVehicleImageUrl(v);
            if (carImageUrl.isNotEmpty) break;
          }
        }
      }
    }
    if (carImageUrl.isEmpty) {
      final title = vehicleTitle.toLowerCase().trim();
      for (final v in [..._vehicles, ..._partnerVehicles]) {
        final b = (v['brand'] ?? '').toString().toLowerCase().trim();
        final m = (v['model'] ?? '').toString().toLowerCase().trim();
        final vName = (v['vehicle_name'] ?? '').toString().toLowerCase().trim();
        if ((title.contains(b) && title.contains(m) && b.isNotEmpty) ||
            (vName.isNotEmpty && title.contains(vName))) {
          carImageUrl = _primaryVehicleImageUrl(v);
          if (carImageUrl.isNotEmpty) break;
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending
              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
              : (isApproved
                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                  : (isDark ? AppColors.borderColor : Colors.grey.shade200)),
          width: isPending ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Car Photo (expandable on click), Title, status chip, date
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle Photo Thumbnail with Expand on Click Modal
              Tooltip(
                message: carImageUrl.isNotEmpty
                    ? 'Click to expand photo'
                    : 'Click to view vehicle',
                child: InkWell(
                  onTap: () async {
                    if (carImageUrl.isNotEmpty) {
                      _showOperatorImageAttachment(carImageUrl, vehicleTitle);
                    } else {
                      final v = await _findVehicleForPriceRequest(data);
                      if (v != null && mounted) {
                        final img = _primaryVehicleImageUrl(v);
                        if (img.isNotEmpty) {
                          _showOperatorImageAttachment(img, vehicleTitle);
                        } else {
                          _showEditVehicleDialog(v, isDark);
                        }
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF22304A) : const Color(0xFFEFF4FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? AppColors.borderColor
                                : Colors.grey.shade300,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: carImageUrl.isNotEmpty
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    OptimizedNetworkImage(
                                      imageUrl: carImageUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: Center(
                                        child: Icon(
                                          Icons.directions_car_filled_rounded,
                                          color: _operatorGold,
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                    // Subtle bottom gradient
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      height: 28,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withValues(alpha: 0.6),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Center(
                                  child: Icon(
                                    Icons.directions_car_filled_rounded,
                                    color: _operatorGold,
                                    size: 32,
                                  ),
                                ),
                        ),
                      ),
                      // Expand/Zoom icon badge in corner
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: const Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vehicleTitle,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : _operatorInk,
                            ),
                          ),
                        ),
                        // Status Badge
                        if (isPending)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFF59E0B)),
                            ),
                            child: const Text(
                              'Pending Review',
                              style: TextStyle(
                                color: Color(0xFFD97706),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else if (isApproved)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF10B981)),
                            ),
                            child: const Text(
                              'Approved',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red),
                            ),
                            child: const Text(
                              'Declined',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Requested on $formattedDate',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        if (carImageUrl.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400])),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _showOperatorImageAttachment(carImageUrl, vehicleTitle),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_in_rounded, size: 14, color: _operatorGold),
                                const SizedBox(width: 3),
                                Text(
                                  'View Photo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _operatorGold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Price Comparison Cards Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                // Current Prices
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT RATES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PHP ${_formatCurrency(currentDaily)} /day',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      Text(
                        'PHP ${_formatCurrency(currentHourly)} /hr',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                  size: 22,
                ),
                const SizedBox(width: 16),
                // Requested Prices
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REQUESTED RATES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _operatorGold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'PHP ${_formatCurrency(reqDaily)} /day',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : _operatorInk,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: dailyDiff >= 0
                                  ? const Color(0xFF10B981).withValues(alpha: 0.18)
                                  : Colors.orange.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${dailyDiff >= 0 ? '+' : ''}PHP ${_formatCurrency(dailyDiff, decimals: 0)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: dailyDiff >= 0 ? const Color(0xFF10B981) : Colors.orange[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'PHP ${_formatCurrency(reqHourly)} /hr',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Partner Note: "$note"',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
          ],

          if (operatorNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.speaker_notes_outlined, color: Colors.red, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Operator Note to Partner:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    operatorNote,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isApproved) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Price automatically applied: PHP ${_formatCurrency(reqDaily)}/day • PHP ${_formatCurrency(reqHourly)}/hr',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          // Action Buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isPending) ...[
                OutlinedButton.icon(
                  onPressed: () => _handleDeclinePriceRequest(req, isDark),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Decline'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _handleApprovePriceRequest(req, isDark),
                  icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                  label: const Text(
                    'Approve & Apply Price',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    final v = await _findVehicleForPriceRequest(data);
                    if (v != null && mounted) {
                      _showEditVehicleDialog(v, isDark);
                    }
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View Vehicle'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _operatorGold,
                    side: BorderSide(color: _operatorGold),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

