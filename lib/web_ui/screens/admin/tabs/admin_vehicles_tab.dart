part of '../admin_web_screen.dart';

extension AdminVehiclesTab on _AdminWebScreenState {
  Widget _buildVehiclesContent(bool isDark) {
    // 1. Separate PSDC vs Partner vehicles based on source & database origin
    final psdcVehicles = _allVehicles.where((v) {
      final source = (v['source']?.toString() ?? 'company').toLowerCase();
      return source != 'partner' && v['is_partner_vehicle'] != true;
    }).toList();

    final partnerVehicles = _allVehicles.where((v) {
      final source = (v['source']?.toString() ?? '').toLowerCase();
      return source == 'partner' || v['is_partner_vehicle'] == true;
    }).toList();

    final totalCount = _allVehicles.length;
    final psdcCount = psdcVehicles.length;
    final partnerCount = partnerVehicles.length;

    // 2. Select target list by active tab
    List<Map<String, dynamic>> activeList;
    if (_vehicleTabFilter == 'psdc') {
      activeList = psdcVehicles;
    } else if (_vehicleTabFilter == 'partner') {
      activeList = partnerVehicles;
    } else {
      activeList = _allVehicles;
    }

    // 3. Search query filter
    final query = _vehicleSearchQuery.trim().toLowerCase();
    final filteredVehicles = activeList.where((v) {
      if (query.isEmpty) return true;
      final brand = (v['brand']?.toString() ?? '').toLowerCase();
      final model = (v['model']?.toString() ?? '').toLowerCase();
      final plate = (v['plate_number']?.toString() ?? '').toLowerCase();
      final year = (v['year']?.toString() ?? '').toLowerCase();
      final owner = v['owner'] as Map<String, dynamic>?;
      final ownerName = (owner?['full_name']?.toString() ?? '').toLowerCase();
      final partnerName = (v['partner_name']?.toString() ?? '').toLowerCase();

      return brand.contains(query) ||
          model.contains(query) ||
          plate.contains(query) ||
          year.contains(query) ||
          ownerName.contains(query) ||
          partnerName.contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Tabs & Search
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF021F35) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
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
                        Icons.directions_car_filled_rounded,
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
                            'Vehicles Fleet Management',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Manage company PSDC fleet vehicles and registered Partner vehicles on the platform.',
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

                // Search & Filter Bar
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      child: TextField(
                        onChanged: (val) =>
                            setState(() => _vehicleSearchQuery = val),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Search vehicles by Brand, Model, Plate, Year, or Partner Name...',
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
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // View Mode Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Grid View',
                            icon: const Icon(Icons.grid_view_rounded, size: 18),
                            color: _vehicleViewMode == 'cards'
                                ? AppColors.primary
                                : (isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600),
                            onPressed: () =>
                                setState(() => _vehicleViewMode = 'cards'),
                          ),
                          IconButton(
                            tooltip: 'Table View',
                            icon: const Icon(
                              Icons.table_rows_rounded,
                              size: 18,
                            ),
                            color: _vehicleViewMode == 'table'
                                ? AppColors.primary
                                : (isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600),
                            onPressed: () =>
                                setState(() => _vehicleViewMode = 'table'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Separated Fleet Tabs
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildVehicleTabChip(
                      'all',
                      'All Vehicles',
                      totalCount,
                      Icons.directions_car_rounded,
                      isDark,
                    ),
                    _buildVehicleTabChip(
                      'psdc',
                      'PSDC Vehicles',
                      psdcCount,
                      Icons.business_rounded,
                      isDark,
                      accentColor: const Color(0xFFF59E0B),
                    ),
                    _buildVehicleTabChip(
                      'partner',
                      'Partner Vehicles',
                      partnerCount,
                      Icons.handshake_rounded,
                      isDark,
                      accentColor: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Vehicle Grid View
          if (filteredVehicles.isEmpty)
            _buildCard(
              'Vehicles List (0)',
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 48,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No vehicles match your selected tab or search query.',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              isDark,
            )
          else
            _buildCard(
              _vehicleTabFilter == 'psdc'
                  ? 'PSDC Company Fleet (${filteredVehicles.length})'
                  : _vehicleTabFilter == 'partner'
                  ? 'Partner Fleet Vehicles (${filteredVehicles.length})'
                  : 'All Vehicles Fleet (${filteredVehicles.length})',
              _vehicleViewMode == 'cards'
                  ? _buildAdminVehiclesGrid(filteredVehicles, isDark)
                  : _buildAdminVehiclesTable(filteredVehicles, isDark),
              isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildAdminVehiclesGrid(
    List<Map<String, dynamic>> vehicles,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final columns = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final rows = <Widget>[];

        for (var start = 0; start < vehicles.length; start += columns) {
          final end = (start + columns).clamp(0, vehicles.length);
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = start; index < end; index++) ...[
                  if (index > start) const SizedBox(width: spacing),
                  Expanded(
                    child: _buildAdminVehicleCard(vehicles[index], isDark),
                  ),
                ],
              ],
            ),
          );
          if (end < vehicles.length) {
            rows.add(const SizedBox(height: spacing));
          }
        }

        return Column(children: rows);
      },
    );
  }

  Widget _buildAdminVehiclesTable(
    List<Map<String, dynamic>> vehicles,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 28,
              columns: [
                DataColumn(
                  label: Text(
                    'Vehicle',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Fleet',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Owner / Operator',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Specifications',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Daily Rate',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Availability',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Actions',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
              rows: vehicles.map((vehicle) {
                final owner = vehicle['owner'] as Map<String, dynamic>?;
                final source =
                    vehicle['source']?.toString().toLowerCase() ?? 'company';
                final isPartner =
                    source == 'partner' ||
                    vehicle['is_partner_vehicle'] == true;
                final ownerName =
                    owner?['full_name']?.toString().trim().isNotEmpty == true
                    ? owner!['full_name'].toString().trim()
                    : (vehicle['partner_name']?.toString().trim().isNotEmpty ==
                              true
                          ? vehicle['partner_name'].toString().trim()
                          : (isPartner
                                ? 'Mobilis Partner'
                                : 'Unknown Operator'));
                final brand =
                    vehicle['brand']?.toString().trim().isNotEmpty == true
                    ? vehicle['brand'].toString().trim()
                    : 'Unknown';
                final model =
                    vehicle['model']?.toString().trim().isNotEmpty == true
                    ? vehicle['model'].toString().trim()
                    : 'Model';
                final plate =
                    vehicle['plate_number']?.toString().trim().isNotEmpty ==
                        true
                    ? vehicle['plate_number'].toString().trim()
                    : 'No plate';
                final year = vehicle['year']?.toString() ?? 'N/A';
                final transmission =
                    vehicle['transmission']?.toString() ?? 'Manual';
                final seats = vehicle['seats']?.toString() ?? '5';
                final pricePerDay =
                    (vehicle['price_per_day'] as num?)?.toDouble() ?? 0;
                final posted = isPartner
                    ? vehicle['is_available'] == true
                    : vehicle['is_posted'] == true;

                return DataRow(
                  cells: [
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$brand $model',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            plate,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(_buildSourceBadge(isPartner ? 'PARTNER' : 'PSDC')),
                    DataCell(
                      Text(
                        ownerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '$year  •  $transmission  •  $seats seats',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        'PHP ${pricePerDay.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    DataCell(_buildPostedBadge(posted, isDark)),
                    DataCell(
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showAdminVehicleDetailsDialog(vehicle, isDark),
                        icon: const Icon(Icons.visibility_rounded, size: 16),
                        label: const Text('View'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleTabChip(
    String key,
    String label,
    int count,
    IconData icon,
    bool isDark, {
    Color? accentColor,
  }) {
    final isSelected = _vehicleTabFilter == key;
    final activeColor = accentColor ?? AppColors.primary;

    return Tooltip(
      message: 'Filter vehicles by $label ($count total)',
      child: InkWell(
        onTap: () => setState(() => _vehicleTabFilter = key),
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
              icon,
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
    ),
  );
}

  Widget _buildAdminVehicleCard(Map<String, dynamic> vehicle, bool isDark) {
    final owner = vehicle['owner'] as Map<String, dynamic>?;
    final source = vehicle['source']?.toString().toLowerCase() ?? 'company';
    final isPartner = source == 'partner';
    final ownerFullName = owner?['full_name']?.toString().trim() ?? '';
    final ownerName = ownerFullName.isNotEmpty
        ? ownerFullName
        : isPartner
        ? 'Mobilis Partner'
        : 'Unknown Operator';
    final ownerEmail = owner?['email']?.toString().trim() ?? '';
    final status = vehicle['status']?.toString() ?? 'pending';
    final imageUrl = _adminPrimaryVehicleImageUrl(vehicle);
    final pricePerDay = (vehicle['price_per_day'] as num?)?.toDouble() ?? 0;
    final pricePerHour = (vehicle['price_per_hour'] as num?)?.toDouble() ?? 0;
    final brand = vehicle['brand']?.toString().trim().isNotEmpty == true
        ? vehicle['brand'].toString()
        : 'Unknown';
    final model = vehicle['model']?.toString().trim().isNotEmpty == true
        ? vehicle['model'].toString()
        : 'Model';
    final year = vehicle['year']?.toString() ?? '';
    final plate = vehicle['plate_number']?.toString().trim() ?? '';
    final vehicleType =
        vehicle['vehicle_type']?.toString().trim().isNotEmpty == true
        ? vehicle['vehicle_type'].toString()
        : vehicle['category']?.toString() ?? 'Standard';
    final transmission = vehicle['transmission']?.toString() ?? 'Manual';
    final fuelType = vehicle['fuel_type']?.toString() ?? 'Gasoline';
    final seats = vehicle['seats']?.toString() ?? '5';
    final posted = isPartner
        ? vehicle['is_available'] == true
        : vehicle['is_posted'] == true;

    return InkWell(
      onTap: () => _showAdminVehicleDetailsDialog(vehicle, isDark),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF021F35) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.25)
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
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Container(
                height: 168,
                width: double.infinity,
                color: isDark ? AppColors.darkBgTertiary : Colors.grey.shade200,
                child: imageUrl.isEmpty
                    ? Icon(
                        Icons.directions_car,
                        size: 52,
                        color: isDark ? Colors.grey[600] : Colors.grey.shade500,
                      )
                    : OptimizedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorWidget: Icon(
                          Icons.directions_car,
                          size: 52,
                          color: isDark
                              ? Colors.grey[600]
                              : Colors.grey.shade500,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildSourceBadge(
                        isPartner ? 'PARTNER FLEET' : 'PSDC FLEET',
                      ),
                      const SizedBox(width: 8),
                      _buildPostedBadge(posted, isDark),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '$brand $model${year.isNotEmpty ? ' ($year)' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (plate.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Plate number  -  $plate',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildAdminVehicleInfoRow(
                    Icons.person_outline_rounded,
                    isPartner ? 'Applied by partner' : 'Added by operator',
                    ownerName,
                    isDark,
                  ),
                  if (ownerEmail.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 28, top: 2),
                      child: Text(
                        ownerEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey[500]
                              : Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = constraints.maxWidth < 330
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 10) / 2;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: _buildVehicleAttributeCard(
                              'Vehicle Type',
                              vehicleType,
                              Icons.category_outlined,
                              isDark,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildVehicleAttributeCard(
                              'Capacity',
                              '$seats seats',
                              Icons.event_seat_outlined,
                              isDark,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildVehicleAttributeCard(
                              'Transmission',
                              transmission,
                              Icons.settings_outlined,
                              isDark,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildVehicleAttributeCard(
                              'Fuel Type',
                              fuelType,
                              Icons.local_gas_station_outlined,
                              isDark,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildRateBox(
                          'Price/Day',
                          'PHP ${pricePerDay.toStringAsFixed(0)}',
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildRateBox(
                          'Price/Hour',
                          'PHP ${pricePerHour.toStringAsFixed(0)}',
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          _showAdminVehicleDetailsDialog(vehicle, isDark),
                      icon: const Icon(Icons.visibility_rounded, size: 16),
                      label: const Text('View details'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminVehicleDetailsDialog(
    Map<String, dynamic> vehicle,
    bool isDark,
  ) {
    final owner = vehicle['owner'] as Map<String, dynamic>?;
    final source = vehicle['source']?.toString().toLowerCase() ?? 'company';
    final isPartner =
        source == 'partner' || vehicle['is_partner_vehicle'] == true;
    final ownerFullName = owner?['full_name']?.toString().trim() ?? '';
    final ownerName = ownerFullName.isNotEmpty
        ? ownerFullName
        : (vehicle['partner_name']?.toString().trim() ??
              (isPartner ? 'Mobilis Partner' : 'PSDC Fleet Operator'));
    final ownerEmail =
        owner?['email']?.toString().trim() ??
        vehicle['partner_email']?.toString().trim() ??
        '';
    final ownerPhone =
        owner?['phone']?.toString().trim() ??
        vehicle['partner_phone']?.toString().trim() ??
        '';

    final imageUrl = _adminPrimaryVehicleImageUrl(vehicle);
    final rawImages = vehicle['vehicle_images'];
    final imageList = <String>[];
    if (imageUrl.isNotEmpty) imageList.add(imageUrl);
    if (rawImages is List) {
      for (final img in rawImages) {
        if (img is Map) {
          final url = img['image_url']?.toString().trim() ?? '';
          if (url.isNotEmpty && !imageList.contains(url)) {
            imageList.add(url);
          }
        }
      }
    }

    final pricePerDay = (vehicle['price_per_day'] as num?)?.toDouble() ?? 0;
    final pricePerHour = (vehicle['price_per_hour'] as num?)?.toDouble() ?? 0;
    final brand = vehicle['brand']?.toString().trim().isNotEmpty == true
        ? vehicle['brand'].toString()
        : 'Unknown';
    final model = vehicle['model']?.toString().trim().isNotEmpty == true
        ? vehicle['model'].toString()
        : 'Model';
    final year = vehicle['year']?.toString() ?? '';
    final plate = vehicle['plate_number']?.toString().trim() ?? 'N/A';
    final vehicleType =
        vehicle['vehicle_type']?.toString().trim().isNotEmpty == true
        ? vehicle['vehicle_type'].toString()
        : vehicle['category']?.toString() ?? 'Standard';
    final transmission = vehicle['transmission']?.toString() ?? 'Manual';
    final fuelType = vehicle['fuel_type']?.toString() ?? 'Gasoline';
    final seats = vehicle['seats']?.toString() ?? '5';
    final posted = isPartner
        ? vehicle['is_available'] == true
        : vehicle['is_posted'] == true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        String activeImage = imageList.isNotEmpty ? imageList.first : '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF021F35) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Container(
                width: 840,
                constraints: const BoxConstraints(maxHeight: 740),
                child: Column(
                  children: [
                    // Header Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.directions_car_filled_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '$brand $model ${year.isNotEmpty ? "($year)" : ""}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _buildSourceBadge(
                                      isPartner ? 'PARTNER' : 'PSDC',
                                    ),
                                    const SizedBox(width: 8),
                                    _buildPostedBadge(posted, isDark),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Plate Number: $plate • Category: $vehicleType',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),

                    // Scrollable Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Gallery Preview Box
                            Container(
                              height: 250,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkBgTertiary
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: activeImage.isEmpty
                                    ? Center(
                                        child: Icon(
                                          Icons.directions_car,
                                          size: 64,
                                          color: isDark
                                              ? Colors.white30
                                              : Colors.grey.shade400,
                                        ),
                                      )
                                    : OptimizedNetworkImage(
                                        imageUrl: activeImage,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 250,
                                      ),
                              ),
                            ),

                            if (imageList.length > 1) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 60,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: imageList.length,
                                  itemBuilder: (context, index) {
                                    final img = imageList[index];
                                    final isSelected = img == activeImage;
                                    return GestureDetector(
                                      onTap: () => setModalState(
                                        () => activeImage = img,
                                      ),
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          right: 10,
                                        ),
                                        width: 80,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.primary
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: OptimizedNetworkImage(
                                            imageUrl: img,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Specifications Grid (4 Columns)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 650;
                                final colWidth = isNarrow
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 24) / 2;

                                return Wrap(
                                  spacing: 24,
                                  runSpacing: 20,
                                  children: [
                                    // Section 1: Spec details
                                    SizedBox(
                                      width: colWidth,
                                      child: _buildVehicleSpecSectionCard(
                                        'VEHICLE SPECIFICATIONS',
                                        Icons.tune_rounded,
                                        isDark,
                                        [
                                          _buildModalDetailRow(
                                            'Brand & Model',
                                            '$brand $model',
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Model Year',
                                            year.isNotEmpty ? year : 'N/A',
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Plate Number',
                                            plate,
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Vehicle Category',
                                            vehicleType,
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Seating Capacity',
                                            '$seats Seats',
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Transmission',
                                            transmission,
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Fuel Type',
                                            fuelType,
                                            isDark,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Section 2: Pricing & Rates
                                    SizedBox(
                                      width: colWidth,
                                      child: _buildVehicleSpecSectionCard(
                                        'PRICING & RENTAL RATES',
                                        Icons.payments_rounded,
                                        isDark,
                                        [
                                          _buildModalDetailRow(
                                            'Price Per Day',
                                            'PHP ${pricePerDay.toStringAsFixed(0)}',
                                            isDark,
                                            highlight: true,
                                          ),
                                          _buildModalDetailRow(
                                            'Price Per Hour',
                                            'PHP ${pricePerHour.toStringAsFixed(0)}',
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Delivery Fee',
                                            '₱75 / km delivery rate',
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Posting Status',
                                            posted
                                                ? 'Available for Rent'
                                                : 'Unposted / Maintenance',
                                            isDark,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Section 3: Owner & Fleet Operator
                                    SizedBox(
                                      width: colWidth,
                                      child: _buildVehicleSpecSectionCard(
                                        'OWNERSHIP & OPERATOR',
                                        Icons.person_pin_rounded,
                                        isDark,
                                        [
                                          _buildModalDetailRow(
                                            'Owner / Partner',
                                            ownerName,
                                            isDark,
                                          ),
                                          if (ownerEmail.isNotEmpty)
                                            _buildModalDetailRow(
                                              'Contact Email',
                                              ownerEmail,
                                              isDark,
                                            ),
                                          if (ownerPhone.isNotEmpty)
                                            _buildModalDetailRow(
                                              'Contact Phone',
                                              ownerPhone,
                                              isDark,
                                            ),
                                          _buildModalDetailRow(
                                            'Fleet Type',
                                            isPartner
                                                ? 'Mobilis Partner Fleet'
                                                : 'PSDC Company Fleet',
                                            isDark,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Section 4: Vehicle Features & Amenities
                                    SizedBox(
                                      width: colWidth,
                                      child: _buildVehicleSpecSectionCard(
                                        'FEATURES & AMENITIES',
                                        Icons.auto_awesome_rounded,
                                        isDark,
                                        [
                                          _buildModalDetailRow(
                                            'Air Conditioning',
                                            'Equipped',
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'GPS & Map Tracking',
                                            'Live GPS Active',
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Bluetooth Audio',
                                            'Supported',
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Sanitization',
                                            'Verified Clean',
                                            isDark,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Footer Action Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton.icon(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                            ),
                            label: const Text('Close Overview'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildVehicleSpecSectionCard(
    String title,
    IconData icon,
    bool isDark,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModalDetailRow(
    String label,
    String value,
    bool isDark, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: highlight ? FontWeight.w900 : FontWeight.bold,
                color: highlight
                    ? Colors.green
                    : (isDark ? Colors.white : Colors.black87),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge(String label) {
    final isPartner = label.trim().toUpperCase() == 'PARTNER';
    final tooltip = isPartner
        ? 'Vehicle supplied and managed by a verified Partner'
        : 'In-House PSDC Company-owned Fleet';

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildPostedBadge(bool posted, bool isDark) {
    final tooltip = posted
        ? 'Vehicle is published and visible in the public rental catalog'
        : 'Vehicle is currently unpublished / hidden from public catalog';

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: posted
              ? Colors.green.withOpacity(0.15)
              : Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          posted ? 'POSTED' : 'NOT POSTED',
          style: TextStyle(
            color: posted
                ? Colors.green
                : (isDark ? Colors.white70 : Colors.grey.shade700),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildForwardStatusBadge(bool forwarded) {
    final color = forwarded ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            forwarded
                ? Icons.check_circle_outline_rounded
                : Icons.pending_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            forwarded ? 'FORWARDED' : 'PENDING',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminVehicleInfoRow(
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey.shade600,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniVehicleChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSecondary : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.grey[300] : Colors.grey.shade800,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildVehicleAttributeCard(
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSecondary : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey.shade600,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateBox(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSecondary : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey.shade600,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.green,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _adminPrimaryVehicleImageUrl(Map<String, dynamic>? vehicle, [Map<String, dynamic>? booking]) {
    if (vehicle != null) {
      final direct = (vehicle['image_url'] ??
              vehicle['imageUrl'] ??
              vehicle['photo_url'] ??
              vehicle['vehicle_image_url'] ??
              vehicle['thumbnail_url'])
          ?.toString()
          .trim() ?? '';
      if (direct.isNotEmpty) return direct;
      final rawImages = vehicle['vehicle_images'] ?? vehicle['images'] ?? vehicle['photos'];
      if (rawImages is List) {
        for (final image in rawImages) {
          if (image is! Map) continue;
          final url = (image['image_url'] ?? image['url'] ?? image['image'])?.toString().trim() ?? '';
          if (url.isNotEmpty) return url;
        }
      }
    }
    if (booking != null) {
      final bDirect = (booking['vehicle_image_url'] ??
              booking['image_url'] ??
              booking['photo_url'])
          ?.toString()
          .trim() ?? '';
      if (bDirect.isNotEmpty) return bDirect;
      final pv = booking['partner_vehicles'] ?? booking['partner_vehicle'];
      if (pv is Map<String, dynamic>) {
        final pvUrl = _adminPrimaryVehicleImageUrl(pv);
        if (pvUrl.isNotEmpty) return pvUrl;
      }
      final bv = booking['vehicles'];
      if (bv is Map<String, dynamic> && bv != vehicle) {
        final bvUrl = _adminPrimaryVehicleImageUrl(bv);
        if (bvUrl.isNotEmpty) return bvUrl;
      }
    }
    return '';
  }

  String _resolveVehicleImage(Map<String, dynamic>? vehicle, [Map<String, dynamic>? booking]) {
    var img = _adminPrimaryVehicleImageUrl(vehicle, booking);
    if (img.isNotEmpty) return img;
    final vid = (vehicle?['id'] ?? booking?['vehicle_id'] ?? booking?['partner_vehicle_id'])?.toString().trim() ?? '';
    if (vid.isNotEmpty && _allVehicles.isNotEmpty) {
      final found = _allVehicles.firstWhere(
        (v) => v['id']?.toString() == vid,
        orElse: () => {},
      );
      if (found.isNotEmpty) {
        img = _adminPrimaryVehicleImageUrl(found);
      }
    }
    return img;
  }
}
