part of '../operator_web_screen.dart';

extension OperatorVehiclesTab on _OperatorWebScreenState {
  Widget _buildVehiclesContent(bool isDark) {
    final source = _vehicleView == 'partner' ? _partnerVehicles : _vehicles;
    final query = _vehicleSearchQuery.toLowerCase();
    final visible = source.where((vehicle) {
      if (query.isEmpty) return true;
      final haystack = [
        vehicle['brand'],
        vehicle['model'],
        vehicle['vehicle_name'],
        vehicle['plate_number'],
        vehicle['partner_name'],
        vehicle['owner_name'],
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
    final allVehicles = [..._vehicles, ..._partnerVehicles];
    final available = allVehicles.where(_operatorVehicleIsAvailable).length;
    final posted = allVehicles
        .where((vehicle) => vehicle['is_posted'] == true)
        .length;
    final unavailable = allVehicles.length - available;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle Management',
                      style: TextStyle(
                        color: isDark ? Colors.white : _operatorInk,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Manage PSDC vehicles and review partner vehicle inventory.',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (_vehicleView != 'partner') ...[
                OutlinedButton.icon(
                  onPressed: () => _showOperatorTurnaroundBufferDialog(isDark),
                  icon: Icon(
                    Icons.cleaning_services_rounded,
                    size: 16,
                    color: _operatorGold,
                  ),
                  label: const Text('Turnaround Buffer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : _operatorInk,
                    side: BorderSide(
                      color: isDark
                          ? _operatorGold.withValues(alpha: 0.4)
                          : _operatorNavy.withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _showAddVehicleDialog(isDark),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _operatorNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add New Vehicle'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1040
                  ? 4
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 16)) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: width,
                    child: _buildVehicleMetricCard(
                      'Total Vehicles',
                      allVehicles.length,
                      Icons.directions_car_outlined,
                      const Color(0xFF0284C7),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildVehicleMetricCard(
                      'Available',
                      available,
                      Icons.route_outlined,
                      const Color(0xFF10B981),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildVehicleMetricCard(
                      'Unavailable',
                      unavailable,
                      Icons.build_outlined,
                      const Color(0xFFEF4444),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildVehicleMetricCard(
                      'Posted',
                      posted,
                      Icons.verified_outlined,
                      const Color(0xFFF59E0B),
                      isDark,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 720;
                      final tabs = Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : const Color(0xFFF1F3F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildVehicleViewTab(
                              'company',
                              'Managed Vehicles',
                              isDark,
                            ),
                            _buildVehicleViewTab(
                              'partner',
                              'Partner Vehicles',
                              isDark,
                            ),
                          ],
                        ),
                      );
                      final search = SizedBox(
                        width: compact ? constraints.maxWidth : 340,
                        child: TextField(
                          controller: _vehicleSearchController,
                          onChanged: (value) => setState(
                            () => _vehicleSearchQuery = value.trim(),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search vehicle, plate, or owner',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withOpacity(0.05)
                                : const Color(0xFFF4F5F7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      );
                      final styleToggle = Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : const Color(0xFFF1F3F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.table_rows_rounded, size: 18),
                              tooltip: 'Table / List view',
                              color: _vehicleViewMode == 'table'
                                  ? _operatorGold
                                  : (isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  setState(() => _vehicleViewMode = 'table'),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.grid_view_rounded, size: 18),
                              tooltip: 'Grid / Cards view',
                              color: _vehicleViewMode == 'grid'
                                  ? _operatorGold
                                  : (isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  setState(() => _vehicleViewMode = 'grid'),
                            ),
                          ],
                        ),
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: tabs,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                styleToggle,
                              ],
                            ),
                            const SizedBox(height: 12),
                            search,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          tabs,
                          const SizedBox(width: 10),
                          styleToggle,
                          const Spacer(),
                          search,
                        ],
                      );
                    },
                  ),
                ),
                _buildOperatorVehicleInventory(visible, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _operatorVehicleIsAvailable(Map<String, dynamic> vehicle) {
    // Check if vehicle is in an active cleaning turnaround buffer
    final cleaningUntilRaw =
        vehicle['cleaning_until'] ?? vehicle['auto_relist_at'];
    if (cleaningUntilRaw != null) {
      final cleaningUntil = DateTime.tryParse(cleaningUntilRaw.toString());
      if (cleaningUntil != null && DateTime.now().isBefore(cleaningUntil)) {
        return false;
      }
    }

    final status =
        vehicle['status']?.toString().trim().toLowerCase() ?? '';
    if (status == 'cleaning') {
      return false;
    }

    if (vehicle['is_posted'] == true) {
      return true;
    }

    if (vehicle['is_available'] is bool) {
      return vehicle['is_available'] == true;
    }

    return status == 'active' || status == 'available' || status == 'approved';
  }

  Widget _buildVehicleMetricCard(
    String label,
    int value,
    IconData icon,
    Color accent,
    bool isDark,
  ) {
    final effectiveAccent = isDark &&
            (accent == _operatorNavy || accent.computeLuminance() < 0.22)
        ? const Color(0xFF38BDF8)
        : accent;

    final cardWidget = Container(
      constraints: const BoxConstraints(minHeight: 125),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? effectiveAccent.withOpacity(0.25)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: effectiveAccent.withOpacity(isDark ? 0.22 : 0.1),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: effectiveAccent.withOpacity(isDark ? 0.45 : 0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, color: effectiveAccent, size: 22),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: TextStyle(
                    color: isDark ? Colors.white : _operatorInk,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : Colors.grey.shade600,
                    fontSize: 9,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Tooltip(
      message: 'View $label statistics',
      waitDuration: const Duration(milliseconds: 400),
      child: cardWidget,
    );
  }

  Widget _buildVehicleViewTab(String value, String label, bool isDark) {
    final selected = _vehicleView == value;
    return InkWell(
      onTap: () => setState(() => _vehicleView = value),
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? _operatorGold : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected && !isDark
              ? const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? _operatorNavyDeep
                : (isDark ? Colors.grey[300] : Colors.grey.shade700),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorVehicleInventory(
    List<Map<String, dynamic>> vehicles,
    bool isDark,
  ) {
    if (vehicles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        child: Column(
          children: [
            Icon(
              Icons.directions_car_outlined,
              color: isDark ? Colors.grey[600] : Colors.grey.shade300,
              size: 54,
            ),
            const SizedBox(height: 12),
            Text(
              'No matching vehicles',
              style: TextStyle(
                color: isDark ? Colors.white : _operatorInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }
    if (_vehicleViewMode == 'grid') {
      return _buildOperatorVehicleGrid(vehicles, isDark);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: vehicles
                  .map(
                    (vehicle) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildOperatorVehicleRowCard(vehicle, isDark),
                    ),
                  )
                  .toList(),
            ),
          );
        }
        final isPartnerTab = _vehicleView == 'partner';
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
              color: isDark
                  ? Colors.white.withOpacity(0.04)
                  : const Color(0xFFF7F8FA),
              child: Row(
                children: [
                  _vehicleHeaderLabel('Vehicle', 4, isDark),
                  _vehicleHeaderLabel('Owner', 3, isDark),
                  _vehicleHeaderLabel('Status', 2, isDark),
                  _vehicleHeaderLabel('Pricing', 3, isDark),
                  _vehicleHeaderLabel('Listing', 2, isDark),
                  _vehicleHeaderLabel(
                    'Actions',
                    2,
                    isDark,
                    alignment: Alignment.center,
                  ),
                ],
              ),
            ),
            ...vehicles.map(
              (vehicle) => _buildOperatorVehicleTableRow(vehicle, isDark),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              color: isDark
                  ? Colors.white.withOpacity(0.02)
                  : const Color(0xFFFAFBFC),
              child: Text(
                'Showing ${vehicles.length} ${_vehicleView == 'partner' ? 'partner' : 'managed'} vehicles',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOperatorVehicleGrid(
    List<Map<String, dynamic>> vehicles,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 720
                ? 2
                : 1;
        const spacing = 16.0;
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
                    child: _buildOperatorVehicleCard(vehicles[index], isDark),
                  ),
                ],
                for (var pad = 0; pad < (columns - (end - start)); pad++) ...[
                  const SizedBox(width: spacing),
                  const Expanded(child: SizedBox()),
                ],
              ],
            ),
          );
          if (end < vehicles.length) {
            rows.add(const SizedBox(height: spacing));
          }
        }

        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: rows),
        );
      },
    );
  }

  Widget _buildOperatorVehicleCard(
    Map<String, dynamic> vehicle,
    bool isDark,
  ) {
    final foreground = isDark ? Colors.white : _operatorInk;
    final isPartner =
        vehicle['_source'] == 'partner' || _vehicleView == 'partner';
    final owner = isPartner
        ? vehicle['partner_name']?.toString() ?? 'Mobilis Partner'
        : 'PSDC Fleet';
    final posted = vehicle['is_posted'] == true;
    final imageUrl = _primaryVehicleImageUrl(vehicle);
    final pricePerDay =
        ((vehicle['price_per_day'] as num?)?.toDouble() ?? 0).toStringAsFixed(0);
    final pricePerHour =
        ((vehicle['price_per_hour'] as num?)?.toDouble() ?? 0).toStringAsFixed(0);
    final plateNumber = vehicle['plate_number']?.toString() ?? 'No plate';
    final vehicleType =
        vehicle['category'] ?? vehicle['vehicle_type'] ?? 'Sedan';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 160,
                width: double.infinity,
                color: isDark ? Colors.white10 : Colors.grey.shade200,
                child: imageUrl.isEmpty
                    ? Icon(
                        Icons.directions_car_outlined,
                        size: 48,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      )
                    : OptimizedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget:
                            const Icon(Icons.directions_car_outlined),
                      ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPartner
                        ? const Color(0xFF0284C7)
                        : _operatorNavyDeep,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPartner ? 'PARTNER' : 'PSDC',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    plateNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _vehicleTitle(vehicle),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$owner • $vehicleType',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildOperatorVehicleMenu(vehicle, isDark),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.04)
                        : const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₱$pricePerDay/day',
                        style: TextStyle(
                          color: _operatorGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '₱$pricePerHour/hr',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildOperatorVehicleStatus(vehicle, isDark),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Transform.scale(
                            scale: 0.72,
                            child: Switch(
                              value: posted,
                              onChanged: (value) =>
                                  _togglePostingStatus(vehicle, value),
                              activeTrackColor: _operatorGold,
                              activeThumbColor: _operatorNavyDeep,
                            ),
                          ),
                          Text(
                            posted ? 'POSTED' : 'HIDDEN',
                            style: TextStyle(
                              color: foreground,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
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

  Widget _vehicleHeaderLabel(
    String label,
    int flex,
    bool isDark, {
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey.shade600,
            fontSize: 9,
            letterSpacing: 0.7,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorVehicleTableRow(
    Map<String, dynamic> vehicle,
    bool isDark,
  ) {
    final foreground = isDark ? Colors.white : _operatorInk;
    final isPartner =
        vehicle['_source'] == 'partner' || _vehicleView == 'partner';
    final owner = isPartner
        ? vehicle['partner_name']?.toString() ?? 'Mobilis Partner'
        : 'PSDC';
    final posted = vehicle['is_posted'] == true;
    Widget cell(Widget child, int flex) => Expanded(flex: flex, child: child);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          cell(
            _buildOperatorVehicleIdentity(vehicle, isDark),
            4,
          ),
          cell(
            Text(
              owner,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            3,
          ),
          cell(_buildOperatorVehicleStatus(vehicle, isDark), 2),
          cell(
            Text(
              'PHP ${((vehicle['price_per_day'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}/day\nPHP ${((vehicle['price_per_hour'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}/hour',
              style: TextStyle(color: foreground, fontSize: 10, height: 1.45),
            ),
            3,
          ),
          cell(
            Row(
                children: [
                  Transform.scale(
                    scale: 0.72,
                    child: Switch(
                      value: posted,
                      onChanged: (value) =>
                          _togglePostingStatus(vehicle, value),
                      activeTrackColor: _operatorGold,
                      activeThumbColor: _operatorNavyDeep,
                    ),
                  ),
                  Text(
                    posted ? 'POSTED' : 'HIDDEN',
                    style: TextStyle(
                      color: foreground,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              2,
            ),
          cell(_buildOperatorVehicleMenu(vehicle, isDark), 2),
        ],
      ),
    );
  }

  Widget _buildOperatorVehicleIdentity(
    Map<String, dynamic> vehicle,
    bool isDark,
  ) {
    final imageUrl = _primaryVehicleImageUrl(vehicle);
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 62,
            height: 46,
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            child: imageUrl.isEmpty
                ? const Icon(Icons.directions_car_outlined)
                : OptimizedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: const Icon(Icons.directions_car_outlined),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _vehicleTitle(vehicle),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : _operatorInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                vehicle['plate_number']?.toString() ?? 'No plate number',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorVehicleStatus(
    Map<String, dynamic> vehicle,
    bool isDark,
  ) {
    final cleaningUntilRaw =
        vehicle['cleaning_until'] ?? vehicle['auto_relist_at'];
    DateTime? cleaningUntil;
    if (cleaningUntilRaw != null) {
      cleaningUntil = DateTime.tryParse(cleaningUntilRaw.toString());
    }
    final isCleaning = (vehicle['status'] == 'cleaning' || cleaningUntil != null) &&
        cleaningUntil != null &&
        DateTime.now().isBefore(cleaningUntil);

    if (isCleaning) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cleaning_services_rounded,
            size: 12,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Tooltip(
              message:
                  'Cleaning turnaround until ${DateFormat('h:mm a, MMM d').format(cleaningUntil)}',
              child: Text(
                'Cleaning (${DateFormat('h:mm a').format(cleaningUntil)})',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      );
    }

    final posted = vehicle['is_posted'] == true;
    final available = _operatorVehicleIsAvailable(vehicle);

    if (posted && available) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
          const SizedBox(width: 6),
          Text(
            'Available',
            style: TextStyle(
              color: isDark ? Colors.white : _operatorInk,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    if (!posted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Colors.grey.shade400),
          const SizedBox(width: 6),
          Text(
            'Unlisted',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey.shade600,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.circle, size: 8, color: Color(0xFFEF4444)),
        const SizedBox(width: 6),
        Text(
          'Unavailable',
          style: TextStyle(
            color: isDark ? Colors.white : _operatorInk,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Future<void> _showOperatorVehicleDetailsDialog(
    Map<String, dynamic> vehicle,
    bool isDark,
  ) async {
    final isPartner = vehicle['_source'] == 'partner' ||
        vehicle['is_partner_vehicle'] == true ||
        vehicle['partner_vehicle_id'] != null;
    final owner = isPartner
        ? vehicle['partner_name']?.toString() ?? 'Mobilis Partner'
        : 'PSDC';
    final available = _operatorVehicleIsAvailable(vehicle);
    final posted = vehicle['is_posted'] == true;
    final vehicleId = vehicle['id']?.toString() ?? '';
    final partnerVehicleId = vehicle['partner_vehicle_id']?.toString() ??
        vehicle['_partner_vehicle_id']?.toString();

    // Query active GPS tracker & telemetry
    Map<String, dynamic>? trackerInfo;
    Map<String, dynamic>? latestLocation;

    try {
      if (vehicleId.isNotEmpty) {
        final tRows = await _supabase
            .from('vehicle_trackers')
            .select()
            .eq('vehicle_id', vehicleId)
            .neq('connection_status', 'disconnected')
            .limit(1);
        final list = List<Map<String, dynamic>>.from(tRows);
        if (list.isNotEmpty) trackerInfo = list.first;
      }
      if (trackerInfo == null && partnerVehicleId != null && partnerVehicleId.isNotEmpty) {
        final ptRows = await _supabase
            .from('vehicle_trackers')
            .select()
            .eq('partner_vehicle_id', partnerVehicleId)
            .neq('connection_status', 'disconnected')
            .limit(1);
        final list = List<Map<String, dynamic>>.from(ptRows);
        if (list.isNotEmpty) trackerInfo = list.first;
      }
    } catch (e) {
      debugPrint('Tracker lookup note: $e');
    }

    try {
      if (vehicleId.isNotEmpty) {
        final locRows = await _supabase
            .from('tracking_locations')
            .select('latitude, longitude, speed_mps, heading_degrees, recorded_at, source')
            .eq('vehicle_id', vehicleId)
            .order('recorded_at', ascending: false)
            .limit(1);
        final list = List<Map<String, dynamic>>.from(locRows);
        if (list.isNotEmpty) latestLocation = list.first;
      }
    } catch (e) {
      debugPrint('Tracking location lookup note: $e');
    }

    final hasGpsTracker = trackerInfo != null || latestLocation != null;

    final imageUrls = <String>{};
    final primaryImageUrl = _primaryVehicleImageUrl(vehicle);
    if (primaryImageUrl.isNotEmpty) imageUrls.add(primaryImageUrl);
    for (final image in vehicle['vehicle_images'] as List? ?? const []) {
      if (image is! Map) continue;
      final value = image['image_url']?.toString().trim() ?? '';
      if (value.isNotEmpty) imageUrls.add(_normalizeVehicleImageUrl(value));
    }
    final images = imageUrls.toList();
    var selectedImage = 0;

    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final surface = isDark ? const Color(0xFF172235) : Colors.white;
          final mutedSurface = isDark
              ? const Color(0xFF101B2D)
              : const Color(0xFFF5F6F7);
          final foreground = isDark ? Colors.white : _operatorInk;
          final secondary = isDark
              ? Colors.grey.shade400
              : Colors.grey.shade600;

          Widget imagePanel() => Container(
            height: 300,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: mutedSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (images.isEmpty)
                  Center(
                    child: Icon(
                      Icons.directions_car_outlined,
                      size: 72,
                      color: secondary,
                    ),
                  )
                else
                  OptimizedNetworkImage(
                    imageUrl: images[selectedImage],
                    fit: BoxFit.cover,
                    errorWidget: Icon(
                      Icons.directions_car_outlined,
                      size: 72,
                      color: secondary,
                    ),
                  ),
                if (images.length > 1) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _operatorGalleryButton(
                      Icons.chevron_left_rounded,
                      () => setDialogState(
                        () => selectedImage =
                            (selectedImage - 1 + images.length) % images.length,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _operatorGalleryButton(
                      Icons.chevron_right_rounded,
                      () => setDialogState(
                        () =>
                            selectedImage = (selectedImage + 1) % images.length,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: index == selectedImage ? 22 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: index == selectedImage
                                ? _operatorGold
                                : Colors.white70,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );

          Widget specs() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _operatorDetailSectionTitle(
                'Technical & Financial Specifications',
                secondary,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = constraints.maxWidth < 430
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: tileWidth,
                        child: _operatorVehicleSpecTile(
                          'Daily Rental Rate',
                          'PHP ${((vehicle['price_per_day'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} / day',
                          Icons.payments_outlined,
                          isDark,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _operatorVehicleSpecTile(
                          'Hourly Rental Rate',
                          'PHP ${((vehicle['price_per_hour'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} / hour',
                          Icons.schedule_outlined,
                          isDark,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _operatorVehicleSpecTile(
                          'Transmission',
                          vehicle['transmission']?.toString() ?? 'Not provided',
                          Icons.settings_outlined,
                          isDark,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _operatorVehicleSpecTile(
                          'Fuel Type',
                          vehicle['fuel_type']?.toString() ?? 'Not provided',
                          Icons.local_gas_station_outlined,
                          isDark,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _operatorVehicleSpecTile(
                          'Vehicle Type / Category',
                          (vehicle['vehicle_type'] ??
                                  vehicle['category'] ??
                                  'Not provided')
                              .toString(),
                          Icons.category_outlined,
                          isDark,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _operatorVehicleSpecTile(
                          'Seats / Color',
                          '${vehicle['seats'] ?? 'N/A'} seats • ${vehicle['color'] ?? 'Not provided'}',
                          Icons.event_seat_outlined,
                          isDark,
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (vehicle['description']?.toString().trim().isNotEmpty ==
                  true) ...[
                const SizedBox(height: 20),
                _operatorDetailSectionTitle(
                  'Vehicle Description & Remarks',
                  secondary,
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : const Color(0xFFF5F6F7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    vehicle['description'].toString(),
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          );

          Widget statusAndOwner() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _operatorDetailSectionTitle(
                'Asset Status & Live Telemetry',
                secondary,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: mutedSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    _operatorVehicleHealthRow(
                      'Availability',
                      available ? 'Available' : 'Unavailable',
                      Icons.route_outlined,
                      available ? const Color(0xFF2EAD78) : Colors.redAccent,
                      foreground,
                    ),
                    const SizedBox(height: 15),
                    _operatorVehicleHealthRow(
                      'Listing Status',
                      posted ? 'Posted' : 'Hidden',
                      Icons.campaign_outlined,
                      posted ? _operatorGold : secondary,
                      foreground,
                    ),
                    const SizedBox(height: 15),
                    _operatorVehicleHealthRow(
                      'Base Location',
                      vehicle['location']?.toString().trim().isNotEmpty == true
                          ? vehicle['location'].toString()
                          : 'Not provided',
                      Icons.location_on_outlined,
                      _operatorGold,
                      foreground,
                    ),
                    const SizedBox(height: 15),
                    _operatorVehicleHealthRow(
                      'Daily Price',
                      'PHP ${((vehicle['price_per_day'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                      Icons.account_balance_wallet_outlined,
                      _operatorGold,
                      foreground,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _operatorDetailSectionTitle(
                'Live GPS Tracking Status',
                secondary,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF132035) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: hasGpsTracker
                        ? const Color(0xFF0284C7).withValues(alpha: 0.5)
                        : (isDark ? Colors.white10 : Colors.grey.shade300),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (hasGpsTracker ? const Color(0xFF0284C7) : Colors.grey)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            hasGpsTracker ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                            size: 20,
                            color: hasGpsTracker ? const Color(0xFF0284C7) : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasGpsTracker
                                    ? 'GPS Tracker Connected'
                                    : 'No Active GPS Tracker Device',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: hasGpsTracker ? const Color(0xFF38BDF8) : foreground,
                                ),
                              ),
                              if (trackerInfo != null)
                                Text(
                                  'Provider: ${(trackerInfo['provider'] ?? 'Aika168').toString().toUpperCase()} • Device: ${trackerInfo['device_identifier'] ?? 'N/A'}',
                                  style: TextStyle(fontSize: 11, color: secondary),
                                )
                              else if (latestLocation != null)
                                Text(
                                  'Source: ${latestLocation['source'] ?? 'Driver Telemetry'}',
                                  style: TextStyle(fontSize: 11, color: secondary),
                                )
                              else
                                Text(
                                  'Manual updates via booking inspection logs',
                                  style: TextStyle(fontSize: 11, color: secondary),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (latestLocation != null) ...[
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Latest Coordinates', style: TextStyle(fontSize: 12, color: secondary)),
                          Text(
                            '${(latestLocation['latitude'] as num?)?.toStringAsFixed(4) ?? 'N/A'}, ${(latestLocation['longitude'] as num?)?.toStringAsFixed(4) ?? 'N/A'}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Last Recorded Ping', style: TextStyle(fontSize: 12, color: secondary)),
                          Text(
                            latestLocation['recorded_at'] != null
                                ? DateFormat('MMM d, h:mm a').format(
                                    DateTime.tryParse(latestLocation['recorded_at'].toString())?.toLocal() ?? DateTime.now(),
                                  )
                                : 'Recent',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _selectNavigationIndex(6);
                            setState(() {
                              _focusedTrackingBookingId = vehicleId;
                            });
                            _loadTrackingLocations();
                          },
                          icon: const Icon(Icons.map_rounded, size: 16),
                          label: const Text(
                            'Open in Live Map',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFF0284C7)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _operatorDetailSectionTitle(
                isPartner ? 'Partnership Information' : 'Ownership Information',
                secondary,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _operatorNavy,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE29A),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            isPartner
                                ? Icons.workspace_premium_outlined
                                : Icons.business_outlined,
                            color: _operatorNavy,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                owner,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                isPartner
                                    ? 'PSDC CERTIFIED PARTNER'
                                    : 'PSDC DIRECT VEHICLE',
                                style: TextStyle(
                                  color: _operatorGold,
                                  fontSize: 9,
                                  letterSpacing: 0.7,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28, color: Colors.white24),
                    _operatorPartnerContactRow(
                      Icons.email_outlined,
                      vehicle['partner_email']?.toString() ??
                          (isPartner
                              ? 'Email not provided'
                              : 'PSDC Operations'),
                    ),
                    const SizedBox(height: 10),
                    _operatorPartnerContactRow(
                      Icons.phone_outlined,
                      vehicle['partner_phone']?.toString() ??
                          (isPartner
                              ? 'Phone not provided'
                              : 'Operations Desk'),
                    ),
                    if (vehicle['partner_address']
                            ?.toString()
                            .trim()
                            .isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 10),
                      _operatorPartnerContactRow(
                        Icons.location_on_outlined,
                        vehicle['partner_address'].toString(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050, maxHeight: 790),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 22, 16, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _operatorVehicleBadge(
                                      vehicle['plate_number']?.toString() ??
                                          'NO PLATE',
                                      _operatorNavy,
                                      _operatorGold,
                                    ),
                                    const SizedBox(width: 9),
                                    _operatorVehicleBadge(
                                      available
                                          ? 'Active & Ready'
                                          : 'Unavailable',
                                      available
                                          ? const Color(0xFFFFF4D0)
                                          : const Color(0xFFFFE1E1),
                                      available
                                          ? const Color(0xFF755B00)
                                          : const Color(0xFFC62828),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  _vehicleTitle(vehicle),
                                  style: TextStyle(
                                    color: foreground,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(Icons.close_rounded, color: foreground),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 760;
                            final left = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                imagePanel(),
                                const SizedBox(height: 24),
                                specs(),
                              ],
                            );
                            if (compact) {
                              return Column(
                                children: [
                                  left,
                                  const SizedBox(height: 28),
                                  statusAndOwner(),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: left),
                                const SizedBox(width: 28),
                                Expanded(flex: 4, child: statusAndOwner()),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 18,
                      ),
                      color: mutedSurface,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compactFooter = constraints.maxWidth < 620;
                          final details = Row(
                            children: [
                              Expanded(
                                child: _operatorFooterValue(
                                  'PLATE NUMBER',
                                  vehicle['plate_number']?.toString() ??
                                      'Not set',
                                  foreground,
                                  secondary,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 38,
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _operatorFooterValue(
                                  'CATEGORY',
                                  vehicle['category']?.toString() ?? 'Not set',
                                  foreground,
                                  secondary,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 38,
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _operatorFooterValue(
                                  'DAILY RATE',
                                  'PHP ${((vehicle['price_per_day'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                                  foreground,
                                  secondary,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 38,
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _operatorFooterValue(
                                  'HOURLY RATE',
                                  'PHP ${((vehicle['price_per_hour'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                                  foreground,
                                  secondary,
                                ),
                              ),
                            ],
                          );
                          Widget? manageButton;
                          if (!isPartner) {
                            manageButton = ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _showEditVehicleDialog(vehicle, isDark);
                              },
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(
                                  compactFooter ? double.infinity : 0,
                                  50,
                                ),
                                backgroundColor: _operatorNavy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: const Text('Manage Vehicle'),
                            );
                          }
                          if (compactFooter) {
                            return Column(
                              children: [
                                details,
                                if (manageButton != null) ...[
                                  const SizedBox(height: 16),
                                  manageButton,
                                ],
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: details),
                              if (manageButton != null) ...[
                                const SizedBox(width: 30),
                                manageButton,
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _operatorGalleryButton(IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xCC021F35),
          foregroundColor: Colors.white,
        ),
        icon: Icon(icon),
      ),
    );
  }

  Widget _operatorVehicleBadge(String label, Color background, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _operatorDetailSectionTitle(String title, Color color) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 9,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _operatorVehicleSpecTile(
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF5F6F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: _operatorNavy, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : _operatorInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _operatorVehicleHealthRow(
    String label,
    String value,
    IconData icon,
    Color accent,
    Color foreground,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: accent),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _operatorPartnerContactRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _operatorFooterValue(
    String label,
    String value,
    Color foreground,
    Color secondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: secondary,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: foreground,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorVehicleMenu(Map<String, dynamic> vehicle, bool isDark) {
    final posted = vehicle['is_posted'] == true;
    final isPartner =
        vehicle['_source'] == 'partner' || _vehicleView == 'partner';

    // For Partner Vehicles: Only display direct "View Details" button without 3-dots menu
    if (isPartner) {
      return Align(
        alignment: Alignment.center,
        child: OutlinedButton.icon(
          onPressed: () => _showOperatorVehicleDetailsDialog(vehicle, isDark),
          icon: const Icon(Icons.visibility_outlined, size: 14),
          label: const Text(
            'View Details',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0284C7),
            side: BorderSide(
              color: const Color(0xFF0284C7).withValues(alpha: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    final cleaningUntilRaw =
        vehicle['cleaning_until'] ?? vehicle['auto_relist_at'];
    DateTime? cleaningUntil;
    if (cleaningUntilRaw != null) {
      cleaningUntil = DateTime.tryParse(cleaningUntilRaw.toString());
    }
    final isCleaning = (vehicle['status'] == 'cleaning' || cleaningUntil != null) &&
        cleaningUntil != null &&
        DateTime.now().isBefore(cleaningUntil);

    return Align(
      alignment: Alignment.center,
      child: PopupMenuButton<String>(
        tooltip: 'Vehicle actions',
        onSelected: (action) async {
          if (action == 'view') {
            _showOperatorVehicleDetailsDialog(vehicle, isDark);
          } else if (action == 'edit') {
            _showEditVehicleDialog(vehicle, isDark);
          } else if (action == 'toggle') {
            _togglePostingStatus(vehicle, !posted);
          } else if (action == 'turnaround') {
            _showVehicleTurnaroundDialog(vehicle, isDark);
          } else if (action == 'relist') {
            _togglePostingStatus(vehicle, true);
          } else if (action == 'delete') {
            _deleteVehicle(vehicle['id']);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'view',
            child: Row(
              children: [
                Icon(Icons.visibility_outlined, size: 18),
                SizedBox(width: 9),
                Text('View Details'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 9),
                Text('Edit Vehicle'),
              ],
            ),
          ),
          if (isCleaning)
            PopupMenuItem(
              value: 'relist',
              child: Row(
                children: [
                  Icon(Icons.flash_on_rounded, size: 18, color: _operatorGold),
                  const SizedBox(width: 9),
                  Text(
                    'Relist Immediately (Cleaned)',
                    style: TextStyle(
                      color: _operatorGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          const PopupMenuItem(
            value: 'turnaround',
            child: Row(
              children: [
                Icon(Icons.cleaning_services_rounded, size: 18),
                SizedBox(width: 9),
                Text('Turnaround Buffer'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'toggle',
            child: Row(
              children: [
                Icon(
                  posted
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                ),
                SizedBox(width: 9),
                Text(posted ? 'Hide Listing' : 'Post Vehicle'),
              ],
            ),
          ),
          if (!isPartner)
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  SizedBox(width: 9),
                  Text('Delete Vehicle', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
        ],
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : const Color(0xFFF2F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.more_vert_rounded, size: 19),
        ),
      ),
    );
  }

  Widget _buildOperatorVehicleRowCard(
    Map<String, dynamic> vehicle,
    bool isDark,
  ) {
    final isPartner =
        vehicle['_source'] == 'partner' || _vehicleView == 'partner';
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.035)
            : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildOperatorVehicleIdentity(vehicle, isDark)),
              _buildOperatorVehicleMenu(vehicle, isDark),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildOperatorVehicleStatus(vehicle, isDark)),
              if (!isPartner)
                Text(
                  vehicle['is_posted'] == true ? 'POSTED' : 'HIDDEN',
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : _operatorInk,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Partner Vehicle',
                    style: TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyVehiclesContent(bool isDark) {
    final ownVehicles = _vehicles;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Vehicles (${_vehicles.length})',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddVehicleDialog(isDark),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Add Vehicle',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Company Vehicles (${ownVehicles.length})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          if (ownVehicles.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: isDark ? Colors.black12 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 60,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No company vehicles added yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const crossAxisCount = 5;
                const spacing = 16.0;
                final cardWidth =
                    (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                    crossAxisCount;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: ownVehicles
                      .map(
                        (vehicle) => SizedBox(
                          width: cardWidth,
                          child: _buildVehicleCard(vehicle, isDark),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          const SizedBox(height: 32),
          Text(
            'Partner Vehicles (${_partnerVehicles.length})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          if (_partnerVehicles.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: isDark ? Colors.black12 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.business_center_outlined,
                      size: 60,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No partner vehicles',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const crossAxisCount = 5;
                const spacing = 16.0;
                final cardWidth =
                    (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                    crossAxisCount;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _partnerVehicles
                      .map(
                        (vehicle) => SizedBox(
                          width: cardWidth,
                          child: _buildVehicleCard(vehicle, isDark),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle, bool isDark) {
    final isPartnerVehicle =
        vehicle['_source'] == 'partner' ||
        vehicle['source'] == 'partner' ||
        vehicle['is_partner_vehicle'] == true;

    return _VehicleCard(
      brand: vehicle['brand'] ?? 'Unknown',
      model: vehicle['model'] ?? 'Model',
      vehicleName: vehicle['vehicle_name'] ?? '',
      category: vehicle['category'] ?? '',
      vehicleType: vehicle['vehicle_type'] ?? '',
      description: vehicle['description'] ?? '',
      color: vehicle['color'] ?? '',
      location: vehicle['location'] ?? '',
      latitude: vehicle['latitude'],
      longitude: vehicle['longitude'],
      year: (vehicle['year'] ?? '').toString(),
      pricePerDay: vehicle['price_per_day'] ?? 0,
      pricePerHour: vehicle['price_per_hour'] ?? 0,
      isPosted: vehicle['is_posted'] ?? vehicle['is_available'] ?? false,
      images: (vehicle['vehicle_images'] as List?) ?? [],
      isDark: isDark,
      transmission: vehicle['transmission'] ?? '',
      isPartnerVehicle: isPartnerVehicle,
      onEdit: () => _showEditVehicleDialog(vehicle, isDark),
      onDelete: () => _deleteVehicle(vehicle['id']),
      onTogglePost: (value) => _togglePostingStatus(vehicle, value),
    );
  }

  InputDecoration _fieldDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
        fontSize: 14,
      ),
      filled: true,
      fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  TextStyle _fieldTextStyle(bool isDark) {
    return TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15);
  }

  InputDecoration _registerVehicleDecoration(
    String hint,
    bool isDark, {
    Widget? suffixIcon,
  }) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : const Color(0xFFD9E0E6);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.white38 : Colors.blueGrey.shade400,
        fontSize: 13,
      ),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.045)
          : const Color(0xFFF7F9FA),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _operatorGold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
      ),
    );
  }

  Widget _registerVehicleField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool isDark,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.blueGrey.shade600,
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          obscureText: obscureText,
          cursorColor: _operatorGold,
          style: TextStyle(
            color: isDark ? Colors.white : _operatorInk,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: _registerVehicleDecoration(
            hint,
            isDark,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }

  Widget _registerVehicleDropdown({
    required String label,
    required String value,
    required List<String> options,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.blueGrey.shade600,
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? Colors.white54 : Colors.blueGrey,
          ),
          dropdownColor: isDark ? const Color(0xFF102C43) : Colors.white,
          style: TextStyle(
            color: isDark ? Colors.white : _operatorInk,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: _registerVehicleDecoration('Select $label', isDark),
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _resetNewVehicleForm() {
    _brandController.clear();
    _modelController.clear();
    _categoryController.clear();
    _vehicleTypeController.clear();
    _vehicleNameController.clear();
    _descriptionController.clear();
    _colorController.clear();
    _transmissionController.clear();
    _yearController.clear();
    _plateController.clear();
    _priceController.clear();
    _pricePerHourController.clear();
    _seatsController.text = '5';
    _locationController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    _gpsDeviceIdController.clear();
    _gpsPasswordController.clear();
    _isTestingGps = false;
    _isGpsVerified = null;
    _gpsTestMessage = null;
    _selectedImages = [];
    _selectedStatus = 'active';
  }

  String? _requiredVehicleField(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required';
    return null;
  }

  String? _positiveNumberVehicleField(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || number <= 0) return 'Enter a value greater than 0';
    return null;
  }

  Future<bool> _showVehicleProcessingModal({
    required BuildContext parentContext,
    required String title,
    required String message,
    required String successTitle,
    required String successMessage,
    required Future<void> Function(void Function(String) updateStatus) operation,
    required bool isDark,
  }) async {
    String currentStatus = message;
    bool isSuccess = false;
    String? errorMessage;
    StateSetter? modalSetState;

    showDialog<void>(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          modalSetState = setDialogState;
          final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
          final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
          final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: Container(
                width: 420,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.25),
                      blurRadius: 36,
                      offset: const Offset(0, 18),
                    ),
                  ],
                  border: Border.all(
                    color: isSuccess
                        ? const Color(0xFF10B981)
                        : (errorMessage != null
                            ? Colors.red
                            : (isDark ? Colors.white12 : Colors.black12)),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: isSuccess
                          ? Container(
                              key: const ValueKey('success_icon'),
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF10B981),
                                size: 60,
                              ),
                            )
                          : (errorMessage != null
                              ? Container(
                                  key: const ValueKey('error_icon'),
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.red,
                                    size: 60,
                                  ),
                                )
                              : Container(
                                  key: const ValueKey('loading_spinner'),
                                  width: 80,
                                  height: 80,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: (isDark ? _operatorNavy : const Color(0xFFF59E0B))
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isDark ? _operatorGold : const Color(0xFFD97706),
                                    ),
                                  ),
                                )),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isSuccess
                          ? successTitle
                          : (errorMessage != null ? 'Action Failed' : title),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isSuccess
                          ? successMessage
                          : (errorMessage ?? currentStatus),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    try {
      await operation((newStatus) {
        if (modalSetState != null) {
          modalSetState!(() => currentStatus = newStatus);
        }
      });

      if (modalSetState != null) {
        modalSetState!(() => isSuccess = true);
      }

      await Future.delayed(const Duration(milliseconds: 1300));
      if (parentContext.mounted) {
        Navigator.of(parentContext, rootNavigator: true).pop();
      }
      return true;
    } catch (e) {
      if (modalSetState != null) {
        modalSetState!(() => errorMessage = e.toString());
      }
      return false;
    }
  }

  Future<bool> _saveOperatorVehicle({
    required BuildContext parentContext,
    required String category,
    required String vehicleType,
    required String fuelType,
    required String transmission,
    required String status,
    required bool isDark,
    required void Function(VoidCallback callback) setDialogState,
  }) async {
    setDialogState(() => _isSubmittingVehicle = true);
    final normalizedPlate = _plateController.text.trim().toUpperCase();
    final vName = _vehicleNameController.text.trim();

    try {
      final success = await _showVehicleProcessingModal(
        parentContext: parentContext,
        title: 'Adding Vehicle',
        message: 'Registering $vName ($normalizedPlate) into fleet...',
        successTitle: 'Vehicle Added Successfully!',
        successMessage: '$vName ($normalizedPlate) is now registered in PSDC inventory.',
        isDark: isDark,
        operation: (updateStatus) async {
          final currentUserId = _supabase.auth.currentUser?.id;
          if (currentUserId == null) {
            throw 'Operator account is required to add vehicles';
          }

          updateStatus('Verifying vehicle plate & records...');
          final existing = await _supabase
              .from('vehicles')
              .select('id')
              .eq('plate_number', normalizedPlate)
              .limit(1);
          if ((existing as List).isNotEmpty) {
            throw 'A vehicle with plate number $normalizedPlate already exists';
          }

          updateStatus('Saving vehicle specifications...');
          final vehicleResponse = await _supabase
              .from('vehicles')
              .insert({
                'brand': _brandController.text.trim(),
                'model': _modelController.text.trim(),
                'category': category,
                'vehicle_type': vehicleType,
                'vehicle_name': _vehicleNameController.text.trim(),
                'description': _descriptionController.text.trim(),
                'color': _colorController.text.trim(),
                'fuel_type': fuelType,
                'transmission': transmission,
                'plate_number': normalizedPlate,
                'year': int.parse(_yearController.text.trim()),
                'seats': int.parse(_seatsController.text.trim()),
                'price_per_day': double.parse(_priceController.text.trim()),
                'price_per_hour': double.parse(_pricePerHourController.text.trim()),
                'location': _locationController.text.trim(),
                'latitude': double.tryParse(_latitudeController.text.trim()),
                'longitude': double.tryParse(_longitudeController.text.trim()),
                'status': status,
                'is_available': status == 'active',
                'is_posted': false,
                'owner_id': currentUserId,
                'rating': 0.0,
                'rating_count': 0,
              })
              .select('id')
              .single();
          final vehicleId = vehicleResponse['id'].toString();

          if (_gpsDeviceIdController.text.trim().isNotEmpty) {
            updateStatus('Pairing GPS tracker (${_gpsDeviceIdController.text.trim()})...');
            try {
              await GpsService().verifyAndConnectTracker(
                vehicleId: vehicleId,
                provider: 'aika168',
                deviceIdentifier: _gpsDeviceIdController.text.trim(),
                password: _gpsPasswordController.text.trim(),
              );
            } catch (trackerErr) {
              debugPrint(
                'GPS Tracker pairing note during operator vehicle creation: $trackerErr',
              );
            }
          }

          if (_selectedImages.isNotEmpty) {
            for (var index = 0; index < _selectedImages.length; index++) {
              updateStatus('Optimizing & uploading photo ${index + 1} of ${_selectedImages.length}...');
              final fileName =
                  'vehicle_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
              final filePath = 'vehicles/$currentUserId/$fileName';
              try {
                final originalBytes = await _selectedImages[index].readAsBytes();
                final imageBytes = await ImageOptimizationService.optimizeForUpload(
                  originalBytes,
                  fileName: fileName,
                );
                await _supabase.storage
                    .from(_vehicleImagesBucket)
                    .uploadBinary(
                      filePath,
                      imageBytes,
                      fileOptions: const FileOptions(
                        cacheControl: '31536000',
                        upsert: false,
                      ),
                    );
                final imageUrl = _supabase.storage
                    .from(_vehicleImagesBucket)
                    .getPublicUrl(filePath);
                await _supabase.from('vehicle_images').insert({
                  'vehicle_id': vehicleId,
                  'image_url': imageUrl,
                  'display_order': index,
                });
              } catch (error) {
                debugPrint('Error uploading vehicle image $index: $error');
              }
            }
          }

          updateStatus('Finalizing vehicle inventory...');
        },
      );

      if (success) {
        _resetNewVehicleForm();
        await _loadVehicles();
        await _loadTrackingLocations();
        _loadDashboardData(showLoading: false);
        return true;
      }
      return false;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to add vehicle: $error'),
            backgroundColor: const Color(0xFFC93C47),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setDialogState(() => _isSubmittingVehicle = false);
      }
    }
  }

  void _showAddVehicleDialog(bool isDark) {
    _resetNewVehicleForm();
    final formKey = GlobalKey<FormState>();
    var category = 'Sedan';
    var vehicleType = 'Sedan';
    var fuelType = 'Unleaded';
    var transmission = 'Automatic';
    var status = 'active';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final foreground = isDark ? Colors.white : _operatorInk;
          final panelColor = isDark ? _operatorNavyDeep : Colors.white;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 820),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 36,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(38, 28, 24, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Register New Vehicle',
                                  style: TextStyle(
                                    color: foreground,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Configure vehicle details, pricing, and deployment status.',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.blueGrey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: _isSubmittingVehicle
                                ? null
                                : () => Navigator.pop(dialogContext),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.all(12),
                            ),
                            icon: Icon(Icons.close_rounded, color: foreground),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 850;
                          final imagePanel = _buildRegisterVehicleImagePanel(
                            isDark: isDark,
                            setDialogState: setDialogState,
                          );
                          final formPanel = Form(
                            key: formKey,
                            child: _buildRegisterVehicleFields(
                              isDark: isDark,
                              category: category,
                              vehicleType: vehicleType,
                              fuelType: fuelType,
                              transmission: transmission,
                              status: status,
                              onCategoryChanged: (value) => setDialogState(
                                () => category = value ?? category,
                              ),
                              onVehicleTypeChanged: (value) => setDialogState(
                                () => vehicleType = value ?? vehicleType,
                              ),
                              onFuelTypeChanged: (value) => setDialogState(
                                () => fuelType = value ?? fuelType,
                              ),
                              onTransmissionChanged: (value) => setDialogState(
                                () => transmission = value ?? transmission,
                              ),
                              onStatusChanged: (value) => setDialogState(
                                () => status = value ?? status,
                              ),
                              setDialogState: setDialogState,
                            ),
                          );
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(38),
                            child: compact
                                ? Column(
                                    children: [
                                      imagePanel,
                                      const SizedBox(height: 28),
                                      formPanel,
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(width: 285, child: imagePanel),
                                      const SizedBox(width: 38),
                                      Expanded(child: formPanel),
                                    ],
                                  ),
                          );
                        },
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 18, 30, 22),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isSubmittingVehicle
                                ? null
                                : () => Navigator.pop(dialogContext),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark
                                  ? Colors.white70
                                  : Colors.blueGrey.shade700,
                              minimumSize: const Size(110, 52),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _isSubmittingVehicle
                                ? null
                                : () async {
                                    if (!(formKey.currentState?.validate() ??
                                        false)) {
                                      return;
                                    }
                                    final saved = await _saveOperatorVehicle(
                                      parentContext: dialogContext,
                                      category: category,
                                      vehicleType: vehicleType,
                                      fuelType: fuelType,
                                      transmission: transmission,
                                      status: status,
                                      isDark: isDark,
                                      setDialogState: setDialogState,
                                    );
                                    if (saved && dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _operatorGold,
                              foregroundColor: _operatorNavyDeep,
                              elevation: 0,
                              minimumSize: const Size(190, 54),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 17,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _isSubmittingVehicle
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _operatorNavyDeep,
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_circle_outline_rounded,
                                    size: 20,
                                  ),
                            label: Text(
                              _isSubmittingVehicle
                                  ? 'Adding Vehicle...'
                                  : 'Add Vehicle',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
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
      ),
    );
  }

  Widget _buildRegisterVehicleImagePanel({
    required bool isDark,
    required void Function(VoidCallback callback) setDialogState,
  }) {
    final borderColor = isDark ? Colors.white24 : Colors.blueGrey.shade200;
    Future<void> pickImages() async {
      final images = await _imagePicker.pickMultiImage(imageQuality: 88);
      if (images.isEmpty) return;
      setDialogState(() {
        final remaining = 5 - _selectedImages.length;
        if (remaining > 0) _selectedImages.addAll(images.take(remaining));
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VEHICLE IMAGES',
          style: TextStyle(
            color: _operatorGold,
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: pickImages,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 220,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.025)
                  : const Color(0xFFF7F9FA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: _selectedImages.isNotEmpty
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImageWidget(
                        _selectedImages.first,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _operatorNavyDeep.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_selectedImages.length}/5 images',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: _operatorNavy.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.cloud_upload_outlined,
                          color: _operatorGold,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Upload vehicle images',
                        style: TextStyle(
                          color: isDark ? Colors.white : _operatorInk,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'JPG or PNG - up to 5 images',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.blueGrey,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 13),
                      Text(
                        'Browse files',
                        style: TextStyle(
                          color: _operatorGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => Stack(
                children: [
                  SizedBox(
                    width: 70,
                    child: _buildImageWidget(
                      _selectedImages[index],
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  Positioned(
                    top: 3,
                    right: 3,
                    child: InkWell(
                      onTap: () =>
                          setDialogState(() => _selectedImages.removeAt(index)),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _selectedImages.length >= 5 ? null : pickImages,
            style: OutlinedButton.styleFrom(
              foregroundColor: _operatorGold,
              side: BorderSide(color: borderColor),
              minimumSize: const Size(double.infinity, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 19),
            label: const Text(
              'Add More Images',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRegisterVehicleFields({
    required bool isDark,
    required String category,
    required String vehicleType,
    required String fuelType,
    required String transmission,
    required String status,
    required ValueChanged<String?> onCategoryChanged,
    required ValueChanged<String?> onVehicleTypeChanged,
    required ValueChanged<String?> onFuelTypeChanged,
    required ValueChanged<String?> onTransmissionChanged,
    required ValueChanged<String?> onStatusChanged,
    required void Function(VoidCallback callback) setDialogState,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 3 : 1;
        const gap = 18.0;
        final fieldWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap * (columns - 1)) / columns;
        Widget field(Widget child, {bool fullWidth = false}) => SizedBox(
          width: fullWidth ? constraints.maxWidth : fieldWidth,
          child: child,
        );
        final currentYear = DateTime.now().year;

        return Wrap(
          spacing: gap,
          runSpacing: 18,
          children: [
            field(
              _registerVehicleField(
                label: 'Brand',
                hint: 'e.g. Toyota',
                controller: _brandController,
                isDark: isDark,
                validator: _requiredVehicleField,
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Model',
                hint: 'e.g. Innova',
                controller: _modelController,
                isDark: isDark,
                validator: _requiredVehicleField,
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Year',
                hint: '$currentYear',
                controller: _yearController,
                isDark: isDark,
                keyboardType: TextInputType.number,
                validator: (value) {
                  final year = int.tryParse(value?.trim() ?? '');
                  if (year == null || year < 1900 || year > currentYear + 1) {
                    return 'Enter a valid vehicle year';
                  }
                  return null;
                },
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Plate Number',
                hint: 'ABC 1234',
                controller: _plateController,
                isDark: isDark,
                validator: _requiredVehicleField,
              ),
            ),
            field(
              _registerVehicleDropdown(
                label: 'Transmission',
                value: transmission,
                options: const ['Automatic', 'Manual', 'CVT'],
                isDark: isDark,
                onChanged: onTransmissionChanged,
              ),
            ),
            field(
              _registerVehicleDropdown(
                label: 'Category',
                value: category,
                options: const ['Sedan', 'SUV', 'Van', 'Pickup', 'Hatchback'],
                isDark: isDark,
                onChanged: onCategoryChanged,
              ),
            ),
            field(
              _registerVehicleDropdown(
                label: 'Vehicle Type',
                value: vehicleType,
                options: const ['Sedan', 'SUV', 'Van', 'Pickup', 'Hatchback'],
                isDark: isDark,
                onChanged: onVehicleTypeChanged,
              ),
            ),
            field(
              _registerVehicleDropdown(
                label: 'Fuel Type',
                value: fuelType,
                options: const [
                  'Diesel',
                  'Premium',
                  'Unleaded',
                  'Gasoline',
                  'Electric',
                  'Hybrid',
                ],
                isDark: isDark,
                onChanged: onFuelTypeChanged,
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Color',
                hint: 'e.g. Pearl White',
                controller: _colorController,
                isDark: isDark,
                validator: _requiredVehicleField,
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Vehicle Name',
                hint: 'Display name',
                controller: _vehicleNameController,
                isDark: isDark,
                validator: _requiredVehicleField,
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Seats',
                hint: '5',
                controller: _seatsController,
                isDark: isDark,
                keyboardType: TextInputType.number,
                validator: _positiveNumberVehicleField,
              ),
            ),
            field(
              _registerVehicleDropdown(
                label: 'Active Status',
                value: status,
                options: const ['active', 'inactive', 'maintenance'],
                isDark: isDark,
                onChanged: onStatusChanged,
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Price / Day (PHP)',
                hint: '0.00',
                controller: _priceController,
                isDark: isDark,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _positiveNumberVehicleField,
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Price / Hour (PHP)',
                hint: '0.00',
                controller: _pricePerHourController,
                isDark: isDark,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _positiveNumberVehicleField,
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Location',
                hint: 'Vehicle location',
                controller: _locationController,
                isDark: isDark,
                validator: _requiredVehicleField,
                suffixIcon: IconButton(
                  tooltip: 'Use current location',
                  onPressed: () => _getCurrentVehicleLocation(
                    onLocationFound: (location, latitude, longitude) {
                      setDialogState(() {
                        _locationController.text = location;
                        _latitudeController.text = latitude;
                        _longitudeController.text = longitude;
                      });
                    },
                  ),
                  icon: Icon(
                    Icons.my_location_rounded,
                    color: _operatorGold,
                    size: 20,
                  ),
                ),
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Vehicle Description',
                hint: 'Add features, condition, and other important details...',
                controller: _descriptionController,
                isDark: isDark,
                maxLines: 3,
                validator: _requiredVehicleField,
              ),
              fullWidth: true,
            ),
            field(
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  'GPS TRACKER SETUP (OPTIONAL - AIKA168)',
                  style: TextStyle(
                    color: _operatorGold,
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              fullWidth: true,
            ),
            field(
              _registerVehicleField(
                label: 'Tracker Device IMEI / ID',
                hint: 'e.g. 868123456789012',
                controller: _gpsDeviceIdController,
                isDark: isDark,
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Tracker Password',
                hint: 'Default: 123456',
                controller: _gpsPasswordController,
                obscureText: true,
                isDark: isDark,
              ),
            ),
            field(
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'AIKA168 Real-Time Sync',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _operatorGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _operatorGold.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 12,
                          color: _operatorGold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'v2.4.0 (Live Proxy)',
                          style: TextStyle(
                            color: _operatorGold,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              fullWidth: true,
            ),
            field(
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  height: 46,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isTestingGps
                        ? null
                        : () => _testGpsConnection(setDialogState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isGpsVerified == true
                          ? Colors.green.shade700
                          : _operatorNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _isTestingGps
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _isGpsVerified == true
                                ? Icons.check_circle_rounded
                                : Icons.sensors_rounded,
                            size: 18,
                          ),
                    label: Text(
                      _isTestingGps
                          ? 'Testing AIKA168...'
                          : (_isGpsVerified == true
                                ? 'Tracker Verified'
                                : 'Test & Connect Tracker'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
              fullWidth: true,
            ),
            if (_gpsTestMessage != null) ...[
              field(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _isGpsVerified == true
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isGpsVerified == true
                          ? Colors.green.shade400
                          : Colors.red.shade400,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isGpsVerified == true
                            ? Icons.check_circle_outline_rounded
                            : Icons.error_outline_rounded,
                        color: _isGpsVerified == true
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _gpsTestMessage!,
                          style: TextStyle(
                            color: _isGpsVerified == true
                                ? (isDark
                                      ? Colors.green.shade300
                                      : Colors.green.shade900)
                                : (isDark
                                      ? Colors.red.shade300
                                      : Colors.red.shade900),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                fullWidth: true,
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _testGpsConnection(
    void Function(VoidCallback callback) setDialogState,
  ) async {
    final deviceId = _gpsDeviceIdController.text.trim();
    final password = _gpsPasswordController.text.trim();

    if (deviceId.isEmpty) {
      setDialogState(() {
        _isGpsVerified = false;
        _gpsTestMessage = 'Please enter a Tracker Device IMEI / ID first.';
      });
      return;
    }

    setDialogState(() {
      _isTestingGps = true;
      _gpsTestMessage = null;
      _isGpsVerified = null;
    });

    try {
      final isValid = await GpsService().verifyCredentials(
        provider: 'aika168',
        deviceIdentifier: deviceId,
        password: password,
      );

      setDialogState(() {
        _isTestingGps = false;
        _isGpsVerified = isValid;
        _gpsTestMessage = isValid
            ? '● Tracker Verified! AIKA168 Device Connection Successful.'
            : 'Connection Failed: Invalid Device ID or Password on AIKA168.';
      });
    } catch (e) {
      setDialogState(() {
        _isTestingGps = false;
        _isGpsVerified = false;
        _gpsTestMessage = 'Error connecting to tracker: $e';
      });
    }
  }

  void _showLegacyAddVehicleDialog(bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 1000),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add New Vehicle',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: _isSubmittingVehicle
                            ? null
                            : () => Navigator.pop(context),
                        child: Icon(
                          Icons.close,
                          color: _isSubmittingVehicle
                              ? Colors.grey
                              : (isDark
                                    ? Colors.grey[400]
                                    : Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Main image preview
                        Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey.shade300,
                            ),
                            color: isDark
                                ? Colors.black26
                                : Colors.grey.shade50,
                          ),
                          child: _selectedImages.isNotEmpty
                              ? _buildImageWidget(
                                  _selectedImages.first,
                                  fit: BoxFit.cover,
                                  borderRadius: BorderRadius.circular(8),
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image_outlined,
                                        size: 50,
                                        color: isDark
                                            ? Colors.grey[600]
                                            : Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No images selected',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[600]
                                              : Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        // Thumbnails
                        if (_selectedImages.isNotEmpty)
                          SizedBox(
                            height: 90,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _selectedImages.length,
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: index == 0
                                              ? AppColors.primary
                                              : (isDark
                                                    ? Colors.grey[700]!
                                                    : Colors.grey.shade300),
                                          width: index == 0 ? 3 : 1,
                                        ),
                                      ),
                                      child: _buildImageWidget(
                                        _selectedImages[index],
                                        fit: BoxFit.cover,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    Positioned(
                                      top: -6,
                                      right: -6,
                                      child: GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            _selectedImages.removeAt(index);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        // Image picker buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final pickedFile = await _imagePicker
                                      .pickImage(source: ImageSource.gallery);
                                  if (pickedFile != null) {
                                    setDialogState(() {
                                      _selectedImages.add(pickedFile);
                                    });
                                  }
                                },
                                icon: const Icon(Icons.add_photo_alternate),
                                label: const Text('Add Image'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            if (_selectedImages.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setDialogState(() {
                                      _selectedImages.clear();
                                    });
                                  },
                                  icon: const Icon(Icons.clear, size: 18),
                                  label: const Text('Clear All'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _brandController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration('Brand', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _modelController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration('Model', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _plateController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration('Plate Number', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _categoryController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration('Category', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _vehicleTypeController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration('Vehicle Type', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _vehicleNameController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration('Vehicle Name', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _colorController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration('Color', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _transmissionController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration(
                            'Transmission (Manual/Automatic)',
                            isDark,
                          ),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _descriptionController,
                          cursorColor: AppColors.primary,
                          maxLines: 4,
                          decoration: _fieldDecoration('Description', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _yearController,
                          cursorColor: AppColors.primary,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration('Year', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _priceController,
                          cursorColor: AppColors.primary,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration(
                            'Price per Day (PHP)',
                            isDark,
                          ),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _pricePerHourController,
                          cursorColor: AppColors.primary,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration(
                            'Price per Hour (PHP)',
                            isDark,
                          ),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Location',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _getCurrentVehicleLocation(
                                    onLocationFound:
                                        (location, latitude, longitude) {
                                          setDialogState(() {
                                            _locationController.text = location;
                                            _latitudeController.text = latitude;
                                            _longitudeController.text =
                                                longitude;
                                          });
                                        },
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.my_location,
                                          size: 18,
                                          color: Colors.black,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Use Current Location',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
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
                        const SizedBox(height: 8),
                        TextField(
                          controller: _locationController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration('Location', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _latitudeController,
                                readOnly: true,
                                cursorColor: AppColors.primary,
                                keyboardType: TextInputType.number,
                                decoration: _fieldDecoration(
                                  'Latitude',
                                  isDark,
                                ),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _longitudeController,
                                readOnly: true,
                                cursorColor: AppColors.primary,
                                keyboardType: TextInputType.number,
                                decoration: _fieldDecoration(
                                  'Longitude',
                                  isDark,
                                ),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          items: const [
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Active'),
                            ),
                            DropdownMenuItem(
                              value: 'inactive',
                              child: Text('Inactive'),
                            ),
                            DropdownMenuItem(
                              value: 'maintenance',
                              child: Text('Maintenance'),
                            ),
                          ],
                          onChanged: (value) => setDialogState(
                            () => _selectedStatus = value ?? 'active',
                          ),
                          decoration: _fieldDecoration('Status', isDark),
                          dropdownColor: isDark
                              ? AppColors.darkCard
                              : Colors.white,
                          style: _fieldTextStyle(isDark),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Footer actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmittingVehicle
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: _isSubmittingVehicle
                                ? Colors.grey
                                : (isDark
                                      ? Colors.grey[400]
                                      : Colors.grey.shade700),
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSubmittingVehicle
                            ? null
                            : () async {
                                if (_brandController.text.isEmpty ||
                                    _modelController.text.isEmpty ||
                                    _plateController.text.isEmpty ||
                                    _categoryController.text.isEmpty ||
                                    _vehicleTypeController.text.isEmpty ||
                                    _vehicleNameController.text.isEmpty ||
                                    _descriptionController.text.isEmpty ||
                                    _colorController.text.isEmpty ||
                                    _yearController.text.isEmpty ||
                                    _priceController.text.isEmpty ||
                                    _pricePerHourController.text.isEmpty ||
                                    _locationController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please fill all fields'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                setDialogState(
                                  () => _isSubmittingVehicle = true,
                                );

                                try {
                                  final currentUserId =
                                      _supabase.auth.currentUser?.id;
                                  if (currentUserId == null) {
                                    throw 'Operator account is required to add vehicles';
                                  }

                                  final opProfile = await _supabase
                                      .from('profiles')
                                      .select('full_name')
                                      .eq('id', currentUserId)
                                      .maybeSingle();
                                  final rawName = opProfile?['full_name']?.toString().trim() ?? '';
                                  final opOwnerName = rawName.isNotEmpty
                                      ? (rawName.toLowerCase().startsWith('operator')
                                          ? rawName
                                          : 'Operator $rawName')
                                      : 'PSDC Operator';

                                  final existing = await _supabase
                                      .from('vehicles')
                                      .select('id')
                                      .eq('plate_number', _plateController.text)
                                      .limit(1);

                                  String vehicleId;
                                  if (existing != null &&
                                      (existing as List).isNotEmpty) {
                                    vehicleId = existing[0]['id'];
                                  } else {
                                    final vehicleResponse = await _supabase
                                        .from('vehicles')
                                        .insert({
                                          'brand': _brandController.text,
                                          'model': _modelController.text,
                                          'category': _categoryController.text,
                                          'vehicle_type':
                                              _vehicleTypeController.text,
                                          'vehicle_name':
                                              _vehicleNameController.text,
                                          'description':
                                              _descriptionController.text,
                                          'color': _colorController.text,
                                          'transmission':
                                              _transmissionController
                                                  .text
                                                  .isEmpty
                                              ? 'Manual'
                                              : _transmissionController.text,
                                          'plate_number': _plateController.text,
                                          'year':
                                              int.tryParse(
                                                _yearController.text,
                                              ) ??
                                              0,
                                          'price_per_day':
                                              double.tryParse(
                                                _priceController.text,
                                              ) ??
                                              0.0,
                                          'price_per_hour':
                                              double.tryParse(
                                                _pricePerHourController.text,
                                              ) ??
                                              0.0,
                                          'location': _locationController.text,
                                          'latitude':
                                              double.tryParse(
                                                _latitudeController.text,
                                              ) ??
                                              0.0,
                                          'longitude':
                                              double.tryParse(
                                                _longitudeController.text,
                                              ) ??
                                              0.0,
                                          'status': _selectedStatus,
                                          'is_available': true,
                                          'is_posted': true,
                                          'owner_id': currentUserId,
                                          'owner_role': 'operator',
                                          'owner_name': opOwnerName,
                                        })
                                        .select()
                                        .single();
                                    vehicleId = vehicleResponse['id'];
                                  }

                                  for (
                                    int i = 0;
                                    i < _selectedImages.length;
                                    i++
                                  ) {
                                    final fileName =
                                        'vehicle_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
                                    final filePath =
                                        'vehicles/$currentUserId/$fileName';
                                    try {
                                      final originalImageBytes =
                                          await _selectedImages[i]
                                              .readAsBytes();
                                      final imageBytes =
                                          await ImageOptimizationService.optimizeForUpload(
                                            originalImageBytes,
                                            fileName: fileName,
                                          );
                                      await _supabase.storage
                                          .from(_vehicleImagesBucket)
                                          .uploadBinary(
                                            filePath,
                                            imageBytes,
                                            fileOptions: const FileOptions(
                                              cacheControl: '31536000',
                                              upsert: false,
                                            ),
                                          );
                                      final imageUrl = _supabase.storage
                                          .from(_vehicleImagesBucket)
                                          .getPublicUrl(filePath);
                                      await _supabase
                                          .from('vehicle_images')
                                          .insert({
                                            'vehicle_id': vehicleId,
                                            'image_url': imageUrl,
                                            'display_order': i,
                                          });
                                    } catch (e) {
                                      debugPrint(
                                        'Error uploading image $i: $e',
                                      );
                                    }
                                  }

                                  final imageCount = _selectedImages.length;
                                  _brandController.clear();
                                  _modelController.clear();
                                  _categoryController.clear();
                                  _vehicleTypeController.clear();
                                  _vehicleNameController.clear();
                                  _descriptionController.clear();
                                  _colorController.clear();
                                  _transmissionController.clear();
                                  _yearController.clear();
                                  _plateController.clear();
                                  _priceController.clear();
                                  _pricePerHourController.clear();
                                  _selectedImages = [];
                                  _selectedStatus = 'active';
                                  _locationController.clear();
                                  _latitudeController.clear();
                                  _longitudeController.clear();

                                  if (mounted) Navigator.pop(context);
                                  _loadVehicles();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Vehicle added successfully with $imageCount images!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                } finally {
                                  if (mounted) {
                                    setDialogState(
                                      () => _isSubmittingVehicle = false,
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: _isSubmittingVehicle
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Add Vehicle',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
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
      ),
    );
  }

  Future<void> _showEditVehicleDialog(
    Map<String, dynamic> vehicle,
    bool isDark, {
    double? prefilledPricePerDay,
    double? prefilledPricePerHour,
    String? priceChangeRequestId,
    String? partnerIdForNotification,
    String? vehicleTitleForNotification,
  }) async {
    if (_isOpeningEditVehicleDialog) return;
    _isOpeningEditVehicleDialog = true;

    final brand = vehicle['brand']?.toString().trim() ?? '';
    final model = vehicle['model']?.toString().trim() ?? '';
    final rawName = vehicle['vehicle_name']?.toString().trim() ?? '';
    final plate = vehicle['plate_number']?.toString().trim().toUpperCase() ?? '';
    final displayName = rawName.isNotEmpty ? rawName : (brand.isNotEmpty ? '$brand $model' : 'Vehicle');

    BuildContext? loadingDialogContext;

    // Show immediate processing modal to block spam clicks
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.5 : 0.25),
      builder: (ctx) {
        loadingDialogContext = ctx;
        final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: Container(
              width: 400,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 34),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.25),
                    blurRadius: 36,
                    offset: const Offset(0, 18),
                  ),
                ],
                border: Border.all(
                  color: _operatorGold.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (isDark ? _operatorNavy : const Color(0xFFF59E0B))
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? _operatorGold : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Loading Vehicle Details',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plate.isNotEmpty
                        ? 'Preparing editor for $displayName ($plate)...'
                        : 'Preparing editor for $displayName...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final formKey = GlobalKey<FormState>();
      final isPartnerVehicle =
          vehicle['_source'] == 'partner' ||
          vehicle['source'] == 'partner' ||
          vehicle['is_partner_vehicle'] == true;
      final partnerVehicleId =
          vehicle['partner_vehicle_id'] ??
          vehicle['_partner_vehicle_id'] ??
          vehicle['id'];

      _brandController.text = vehicle['brand']?.toString() ?? '';
      _modelController.text = vehicle['model']?.toString() ?? '';
      _plateController.text = vehicle['plate_number']?.toString() ?? '';
      _yearController.text = (vehicle['year'] ?? '').toString();
      _colorController.text = vehicle['color']?.toString() ?? '';
      _vehicleNameController.text = vehicle['vehicle_name']?.toString() ?? '';
      _seatsController.text = (vehicle['seats'] ?? '5').toString();
      if (prefilledPricePerDay != null) {
        _priceController.text = prefilledPricePerDay.toStringAsFixed(0);
      } else {
        _priceController.text = (vehicle['price_per_day'] ?? '').toString();
      }
      if (prefilledPricePerHour != null) {
        _pricePerHourController.text =
            prefilledPricePerHour.toStringAsFixed(0);
      } else {
        _pricePerHourController.text =
            (vehicle['price_per_hour'] ?? '').toString();
      }
      _locationController.text = vehicle['location']?.toString() ?? '';
      _latitudeController.text = vehicle['latitude'] != null
          ? vehicle['latitude'].toString()
          : '';
      _longitudeController.text = vehicle['longitude'] != null
          ? vehicle['longitude'].toString()
          : '';
      _descriptionController.text = vehicle['description']?.toString() ?? '';

      // Reset and preload GPS Tracker info for this vehicle
      _gpsDeviceIdController.clear();
      _gpsPasswordController.clear();
      _isGpsVerified = null;
      _gpsTestMessage = null;

      final targetVehicleId =
          (vehicle['id'] ?? vehicle['partner_vehicle_id'])?.toString() ?? '';
      if (targetVehicleId.isNotEmpty) {
        try {
          final existingTracker =
              await GpsService().getTrackerForVehicle(targetVehicleId);
          if (existingTracker != null) {
            final rawPass = GpsService.decryptSecret(
              existingTracker.encryptedPassword ?? '',
            );
            _gpsDeviceIdController.text = existingTracker.deviceIdentifier;
            _gpsPasswordController.text = rawPass.isNotEmpty
                ? rawPass
                : (existingTracker.encryptedPassword ?? '');
            _isGpsVerified = existingTracker.connectionStatus !=
                GpsConnectionStatus.disconnected;
            if (_isGpsVerified == true) {
              _gpsTestMessage =
                  '● Connected: AIKA168 tracker active (${existingTracker.deviceIdentifier})';
            }
          }
        } catch (e) {
          debugPrint('Error loading vehicle tracker: $e');
        }
      }

      // Small delay to ensure smooth transition
      await Future.delayed(const Duration(milliseconds: 250));

      if (loadingDialogContext != null && loadingDialogContext!.mounted) {
        Navigator.of(loadingDialogContext!).pop();
        loadingDialogContext = null;
      } else if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) return;

      var category = (vehicle['category']?.toString().trim().isNotEmpty == true)
          ? vehicle['category'].toString().trim()
          : 'Sedan';
      var vehicleType =
          (vehicle['vehicle_type']?.toString().trim().isNotEmpty == true)
          ? vehicle['vehicle_type'].toString().trim()
          : 'Sedan';
      var fuelType = (vehicle['fuel_type']?.toString().trim().isNotEmpty == true)
          ? vehicle['fuel_type'].toString().trim()
          : 'Unleaded';
      var transmission =
          (vehicle['transmission']?.toString().trim().isNotEmpty == true)
          ? vehicle['transmission'].toString().trim()
          : 'Automatic';
      var status = (vehicle['status']?.toString().trim().isNotEmpty == true)
          ? vehicle['status'].toString().trim()
          : 'active';

      final List<Map<String, dynamic>> existingImages =
          List<Map<String, dynamic>>.from(
            (vehicle['vehicle_images'] as List?) ?? [],
          );
      final List<XFile> newImages = [];
      bool isUpdating = false;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final foreground = isDark ? Colors.white : _operatorInk;
          final panelColor = isDark ? _operatorNavyDeep : Colors.white;
          final borderColor = isDark
              ? Colors.white24
              : Colors.blueGrey.shade200;

          Future<void> pickNewImages() async {
            if (isPartnerVehicle) return;
            try {
              final picked = await _imagePicker.pickMultiImage(
                imageQuality: 88,
              );
              if (picked.isNotEmpty) {
                setDialogState(() {
                  final remaining =
                      5 - (existingImages.length + newImages.length);
                  if (remaining > 0) newImages.addAll(picked.take(remaining));
                });
              }
            } catch (e) {
              debugPrint('Error picking new images: $e');
            }
          }

          Future<void> removeExistingImage(int index) async {
            if (isPartnerVehicle) return;
            final id = existingImages[index]['id'];
            try {
              await _supabase.from('vehicle_images').delete().eq('id', id);
              setDialogState(() => existingImages.removeAt(index));
            } catch (e) {
              debugPrint('Error deleting image: $e');
            }
          }

          final totalImagesCount = existingImages.length + newImages.length;

          Widget imagePanel() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VEHICLE IMAGES',
                style: TextStyle(
                  color: _operatorGold,
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: isPartnerVehicle ? null : pickNewImages,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 220,
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.025)
                        : const Color(0xFFF7F9FA),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor, width: 1.2),
                  ),
                  child: totalImagesCount > 0
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            if (newImages.isNotEmpty)
                              _buildImageWidget(
                                newImages.first,
                                fit: BoxFit.cover,
                                borderRadius: BorderRadius.circular(17),
                              )
                            else
                              OptimizedNetworkImage(
                                imageUrl:
                                    existingImages.first['image_url'] ?? '',
                                fit: BoxFit.cover,
                                errorWidget: Center(
                                  child: Icon(
                                    Icons.directions_car_outlined,
                                    size: 58,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: _operatorNavyDeep.withValues(
                                    alpha: 0.88,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$totalImagesCount/5 images',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: _operatorNavy.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.cloud_upload_outlined,
                                color: _operatorGold,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Upload vehicle images',
                              style: TextStyle(
                                color: isDark ? Colors.white : _operatorInk,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'JPG or PNG - up to 5 images',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white38
                                    : Colors.blueGrey,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 13),
                            Text(
                              'Browse files',
                              style: TextStyle(
                                color: _operatorGold,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              if (totalImagesCount > 0) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 62,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: totalImagesCount,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isExisting = index < existingImages.length;
                      return Stack(
                        children: [
                          SizedBox(
                            width: 70,
                            child: isExisting
                                ? OptimizedNetworkImage(
                                    imageUrl:
                                        existingImages[index]['image_url'] ??
                                        '',
                                    fit: BoxFit.cover,
                                    borderRadius: BorderRadius.circular(11),
                                  )
                                : _buildImageWidget(
                                    newImages[index - existingImages.length],
                                    fit: BoxFit.cover,
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                          ),
                          if (!isPartnerVehicle)
                            Positioned(
                              top: 3,
                              right: 3,
                              child: InkWell(
                                onTap: () {
                                  if (isExisting) {
                                    removeExistingImage(index);
                                  } else {
                                    setDialogState(
                                      () => newImages.removeAt(
                                        index - existingImages.length,
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.72),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                if (!isPartnerVehicle) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: totalImagesCount >= 5 ? null : pickNewImages,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _operatorGold,
                      side: BorderSide(color: borderColor),
                      minimumSize: const Size(double.infinity, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 19,
                    ),
                    label: const Text(
                      'Add More Images',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ],
          );

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 820),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 36,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(38, 28, 24, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isPartnerVehicle
                                      ? 'Vehicle Details (Partner)'
                                      : 'Edit Vehicle',
                                  style: TextStyle(
                                    color: foreground,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  isPartnerVehicle
                                      ? 'View partner vehicle specifications, pricing, and assigned tracker.'
                                      : 'Update vehicle details, pricing, and deployment status.',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.blueGrey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: isUpdating
                                ? null
                                : () => Navigator.pop(dialogContext),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.all(12),
                            ),
                            icon: Icon(Icons.close_rounded, color: foreground),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 850;
                          final imgPanel = imagePanel();
                          final formPanel = IgnorePointer(
                            ignoring: isPartnerVehicle,
                            child: Form(
                              key: formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isPartnerVehicle) ...[
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 20),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.purple.withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.handshake_outlined,
                                            color: Colors.purpleAccent,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Partner Vehicle (View Only) — Owned and managed directly by the Partner. Operators cannot modify specifications, rates, or listings.',
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.purple[200]
                                                    : Colors.purple[800],
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  _buildRegisterVehicleFields(
                                    isDark: isDark,
                                    category: category,
                                    vehicleType: vehicleType,
                                    fuelType: fuelType,
                                    transmission: transmission,
                                    status: status,
                                    onCategoryChanged: (value) => setDialogState(
                                      () => category = value ?? category,
                                    ),
                                    onVehicleTypeChanged: (value) => setDialogState(
                                      () => vehicleType = value ?? vehicleType,
                                    ),
                                    onFuelTypeChanged: (value) => setDialogState(
                                      () => fuelType = value ?? fuelType,
                                    ),
                                    onTransmissionChanged: (value) => setDialogState(
                                      () => transmission = value ?? transmission,
                                    ),
                                    onStatusChanged: (value) => setDialogState(
                                      () => status = value ?? status,
                                    ),
                                    setDialogState: setDialogState,
                                  ),
                                ],
                              ),
                            ),
                          );
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(38),
                            child: compact
                                ? Column(
                                    children: [
                                      imgPanel,
                                      const SizedBox(height: 28),
                                      formPanel,
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(width: 285, child: imgPanel),
                                      const SizedBox(width: 38),
                                      Expanded(child: formPanel),
                                    ],
                                  ),
                          );
                        },
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 18, 30, 22),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isUpdating
                                ? null
                                : () => Navigator.pop(dialogContext),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark
                                  ? Colors.white70
                                  : Colors.blueGrey.shade700,
                              minimumSize: const Size(110, 52),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                            child: Text(
                              isPartnerVehicle ? 'Close' : 'Cancel',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!isPartnerVehicle) ...[
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: isUpdating
                                  ? null
                                  : () async {
                                      if (!(formKey.currentState?.validate() ??
                                          false)) {
                                        return;
                                      }
                                      final normalizedPlate = _plateController
                                          .text
                                          .trim()
                                          .toUpperCase();
                                      final vName = _vehicleNameController.text.trim();
                                      setDialogState(() => isUpdating = true);

                                      try {
                                        final success = await _showVehicleProcessingModal(
                                          parentContext: dialogContext,
                                          title: 'Updating Vehicle',
                                          message: 'Saving vehicle modifications for $vName ($normalizedPlate)...',
                                          successTitle: 'Vehicle Updated Successfully!',
                                          successMessage: '$vName ($normalizedPlate) details and rates have been saved.',
                                          isDark: isDark,
                                          operation: (updateStatus) async {
                                            if (isPartnerVehicle) {
                                              updateStatus('Updating partner vehicle rates...');
                                              await _supabase
                                                  .from('partner_vehicles')
                                                  .update({
                                                    'price_per_day':
                                                        double.tryParse(
                                                          _priceController.text
                                                              .trim(),
                                                        ) ??
                                                        0.0,
                                                    'price_per_hour':
                                                        double.tryParse(
                                                          _pricePerHourController
                                                              .text
                                                              .trim(),
                                                        ) ??
                                                        0.0,
                                                    'updated_at': DateTime.now()
                                                        .toIso8601String(),
                                                  })
                                                  .eq('id', partnerVehicleId);

                                              await _supabase
                                                  .from(
                                                    'partner_vehicle_applications',
                                                  )
                                                  .update({
                                                    'price_per_day':
                                                        double.tryParse(
                                                          _priceController.text
                                                              .trim(),
                                                        ) ??
                                                        0.0,
                                                    'price_per_hour':
                                                        double.tryParse(
                                                          _pricePerHourController
                                                              .text
                                                              .trim(),
                                                        ) ??
                                                        0.0,
                                                  })
                                                  .eq(
                                                    'partner_vehicle_id',
                                                    partnerVehicleId,
                                                  );
                                            } else {
                                              updateStatus('Saving vehicle specifications...');
                                              await _supabase
                                                  .from('vehicles')
                                                  .update({
                                                    'brand': _brandController.text
                                                        .trim(),
                                                    'model': _modelController.text
                                                        .trim(),
                                                    'plate_number': normalizedPlate,
                                                    'category': category,
                                                    'vehicle_type': vehicleType,
                                                    'vehicle_name':
                                                        _vehicleNameController.text
                                                            .trim(),
                                                    'description':
                                                        _descriptionController.text
                                                            .trim(),
                                                    'color': _colorController.text
                                                        .trim(),
                                                    'fuel_type': fuelType,
                                                    'transmission': transmission,
                                                    'year':
                                                        int.tryParse(
                                                          _yearController.text
                                                              .trim(),
                                                        ) ??
                                                        0,
                                                    'seats':
                                                        int.tryParse(
                                                          _seatsController.text
                                                              .trim(),
                                                        ) ??
                                                        5,
                                                    'price_per_day':
                                                        double.tryParse(
                                                          _priceController.text
                                                              .trim(),
                                                        ) ??
                                                        0.0,
                                                    'price_per_hour':
                                                        double.tryParse(
                                                          _pricePerHourController
                                                              .text
                                                              .trim(),
                                                        ) ??
                                                        0.0,
                                                    'location': _locationController
                                                        .text
                                                        .trim(),
                                                    'latitude': double.tryParse(
                                                      _latitudeController.text
                                                          .trim(),
                                                    ),
                                                    'longitude': double.tryParse(
                                                      _longitudeController.text
                                                          .trim(),
                                                    ),
                                                    'status': status,
                                                    'is_available':
                                                        status == 'active',
                                                  })
                                                  .eq('id', vehicle['id']);

                                              if (newImages.isNotEmpty) {
                                                for (
                                                  int i = 0;
                                                  i < newImages.length;
                                                  i++
                                                ) {
                                                  updateStatus('Uploading photo ${i + 1} of ${newImages.length}...');
                                                  final fileName =
                                                      'vehicle_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
                                                  final ownerId =
                                                      vehicle['owner_id'] ??
                                                      _supabase.auth.currentUser?.id;
                                                  final filePath =
                                                      'vehicles/${ownerId ?? 'unknown'}/$fileName';
                                                  try {
                                                    final originalImageBytes =
                                                        await newImages[i]
                                                            .readAsBytes();
                                                    final imageBytes =
                                                        await ImageOptimizationService.optimizeForUpload(
                                                          originalImageBytes,
                                                          fileName: fileName,
                                                        );
                                                    await _supabase.storage
                                                        .from(_vehicleImagesBucket)
                                                        .uploadBinary(
                                                          filePath,
                                                          imageBytes,
                                                          fileOptions:
                                                              const FileOptions(
                                                                cacheControl:
                                                                    '31536000',
                                                                upsert: false,
                                                              ),
                                                        );
                                                    final imageUrl = _supabase.storage
                                                        .from(_vehicleImagesBucket)
                                                        .getPublicUrl(filePath);
                                                    await _supabase
                                                        .from('vehicle_images')
                                                        .insert({
                                                          'vehicle_id': vehicle['id'],
                                                          'image_url': imageUrl,
                                                          'display_order':
                                                              existingImages.length +
                                                              i,
                                                        });
                                                  } catch (e) {
                                                    debugPrint(
                                                      'Error uploading image $i: $e',
                                                    );
                                                  }
                                                }
                                              }
                                            }

                                            // Connect or update GPS Tracker credentials
                                            final trimmedDeviceId =
                                                _gpsDeviceIdController.text.trim();
                                            final trimmedPassword =
                                                _gpsPasswordController.text.trim();
                                            final targetVehicleId =
                                                (vehicle['id'] ?? partnerVehicleId)
                                                    ?.toString() ??
                                                '';

                                            if (targetVehicleId.isNotEmpty) {
                                              if (trimmedDeviceId.isNotEmpty) {
                                                updateStatus('Verifying GPS tracker ($trimmedDeviceId)...');
                                                try {
                                                  await GpsService()
                                                      .verifyAndConnectTracker(
                                                    vehicleId: isPartnerVehicle
                                                        ? null
                                                        : targetVehicleId,
                                                    partnerVehicleId:
                                                        isPartnerVehicle
                                                            ? targetVehicleId
                                                            : null,
                                                    provider: 'aika168',
                                                    deviceIdentifier:
                                                        trimmedDeviceId,
                                                    password:
                                                        trimmedPassword.isEmpty
                                                            ? '123456'
                                                            : trimmedPassword,
                                                  );
                                                } catch (trackerErr) {
                                                  debugPrint(
                                                    'GPS Tracker pairing note during vehicle edit: $trackerErr',
                                                  );
                                                }
                                              } else {
                                                // User cleared the GPS field -> disconnect tracker
                                                try {
                                                  await GpsService()
                                                      .disconnectTracker(
                                                    targetVehicleId,
                                                  );
                                                } catch (e) {
                                                  debugPrint(
                                                    'GPS Tracker disconnect note: $e',
                                                  );
                                                }
                                              }
                                            }

                                            if (priceChangeRequestId != null &&
                                                priceChangeRequestId.isNotEmpty) {
                                              updateStatus('Approving price change request...');
                                              try {
                                                final reqRow = _priceChangeRequests
                                                    .firstWhere(
                                                      (r) =>
                                                          r['id']?.toString() ==
                                                          priceChangeRequestId,
                                                      orElse: () =>
                                                          <String, dynamic>{},
                                                    );
                                                final rawData = reqRow['data'] is Map
                                                    ? Map<String, dynamic>.from(
                                                        reqRow['data'],
                                                      )
                                                    : <String, dynamic>{};
                                                await _supabase
                                                    .from('notifications')
                                                    .update({
                                                      'is_read': true,
                                                      'data': {
                                                        ...rawData,
                                                        'status': 'approved',
                                                        'approved': true,
                                                        'approved_at':
                                                            DateTime.now()
                                                                .toIso8601String(),
                                                        'updated_daily_price':
                                                            double.tryParse(
                                                              _priceController.text
                                                                  .trim(),
                                                            ),
                                                        'updated_hourly_price':
                                                            double.tryParse(
                                                              _pricePerHourController
                                                                  .text
                                                                  .trim(),
                                                            ),
                                                      },
                                                    })
                                                    .eq('id', priceChangeRequestId);

                                                final pId =
                                                    partnerIdForNotification ??
                                                    rawData['partner_id']?.toString() ??
                                                    vehicle['partner_id']?.toString() ??
                                                    '';
                                                final vTitle =
                                                    vehicleTitleForNotification ??
                                                    rawData['vehicle_title']?.toString() ??
                                                    '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim();
                                                if (pId.isNotEmpty) {
                                                  await NotificationService()
                                                      .createNotification(
                                                        userId: pId,
                                                        title:
                                                            'Price Change Approved',
                                                        message:
                                                            'Your price change request for $vTitle (PHP ${_priceController.text.trim()}/day) has been approved and updated by the operator.',
                                                        type:
                                                            'partner_price_change_approved',
                                                        data: {
                                                          'vehicle_id':
                                                              vehicle['id'],
                                                          'price_per_day':
                                                              double.tryParse(
                                                                _priceController
                                                                    .text
                                                                    .trim(),
                                                              ),
                                                          'price_per_hour':
                                                              double.tryParse(
                                                                _pricePerHourController
                                                                    .text
                                                                    .trim(),
                                                              ),
                                                        },
                                                      );
                                                }
                                                await _loadPriceChangeRequests();
                                              } catch (e) {
                                                debugPrint(
                                                  'Error updating price change request: $e',
                                                );
                                              }
                                            }

                                            updateStatus('Finalizing update...');
                                          },
                                        );

                                        if (success) {
                                          if (dialogContext.mounted) {
                                            Navigator.pop(dialogContext);
                                          }
                                          _loadRecentBookings();
                                          _loadDashboardData(showLoading: false);
                                          await _loadVehicles();
                                          await _loadTrackingLocations();
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Unable to update vehicle: $e',
                                              ),
                                              backgroundColor: const Color(
                                                0xFFC93C47,
                                              ),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setDialogState(() => isUpdating = false);
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _operatorGold,
                                foregroundColor: _operatorNavyDeep,
                                elevation: 0,
                                minimumSize: const Size(190, 54),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 17,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: isUpdating
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _operatorNavyDeep,
                                      ),
                                    )
                                  : const Icon(Icons.edit_rounded, size: 20),
                              label: Text(
                                isUpdating
                                    ? 'Updating Vehicle...'
                                    : 'Update Vehicle',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
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
    );
    } finally {
      if (loadingDialogContext != null && loadingDialogContext!.mounted) {
        Navigator.of(loadingDialogContext!).pop();
      }
      _isOpeningEditVehicleDialog = false;
    }
  }

  Future<void> _deleteVehicle(dynamic vehicleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: const Text('Are you sure you want to delete this vehicle?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final isPartner = _partnerVehicles.any(
          (vehicle) =>
              vehicle['id']?.toString() == vehicleId?.toString() ||
              vehicle['partner_vehicle_id']?.toString() ==
                  vehicleId?.toString(),
        );
        if (isPartner) {
          throw Exception('Operators cannot delete partner vehicles.');
        }
        await _supabase
            .from('vehicles')
            .delete()
            .eq('id', vehicleId);
        _loadVehicles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehicle deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _togglePostingStatus(
    Map<String, dynamic> vehicle,
    bool isPosted,
  ) async {
    final vehicleTitle = _vehicleTitle(vehicle);
    final plate = vehicle['plate_number']?.toString().toUpperCase() ?? '';
    final label = plate.isNotEmpty ? '$vehicleTitle ($plate)' : vehicleTitle;
    final isDark = Theme.of(context).brightness == Brightness.dark || widget.isDarkMode;

    final actionTitle = isPosted ? 'Listing Vehicle' : 'Unlisting Vehicle';
    final actionMessage = isPosted
        ? 'Activating $label and making it available for bookings...'
        : 'Unlisting $label and removing from public search...';
    final successTitle = isPosted ? 'Vehicle Listed!' : 'Vehicle Unlisted!';
    final successMessage = isPosted
        ? '$label is now active and listed for bookings.'
        : '$label has been unlisted and hidden from bookings.';

    await _showVehicleProcessingModal(
      parentContext: context,
      title: actionTitle,
      message: actionMessage,
      successTitle: successTitle,
      successMessage: successMessage,
      isDark: isDark,
      operation: (updateStatus) async {
        final vehicleId = vehicle['id']?.toString() ?? '';
        final partnerVehicleId = vehicle['partner_vehicle_id']?.toString() ??
            vehicle['_partner_vehicle_id']?.toString();
        final isPartnerVehicle =
            vehicle['_source'] == 'partner' ||
            vehicle['source'] == 'partner' ||
            vehicle['is_partner_vehicle'] == true;

        if (isPosted) {
          updateStatus('Clearing turnaround cleaning buffers...');
          try {
            await VehicleTurnaroundService().relistVehicleImmediately(
              vehicleId: vehicleId,
              partnerVehicleId: partnerVehicleId,
            );
          } catch (turnaroundErr) {
            debugPrint('Note on turnaround buffer clear: $turnaroundErr');
          }
        }

        final targetStatus = isPosted ? 'available' : 'hidden';

        if (isPartnerVehicle) {
          updateStatus('Updating partner vehicle record...');
          final targetId = (partnerVehicleId != null && partnerVehicleId.isNotEmpty)
              ? partnerVehicleId
              : vehicleId;

          try {
            await _supabase
                .from('partner_vehicles')
                .update({
                  'is_posted': isPosted,
                  'is_available': isPosted,
                  'status': targetStatus,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', targetId);
          } catch (e) {
            await _supabase
                .from('partner_vehicles')
                .update({
                  'is_posted': isPosted,
                  'is_available': isPosted,
                  'status': targetStatus,
                })
                .eq('id', targetId);
          }

          // Also synchronize in canonical vehicles table if linked
          final canonicalId = vehicle['vehicle_id']?.toString() ??
              (targetId != vehicleId ? vehicleId : null);
          if (canonicalId != null && canonicalId.isNotEmpty) {
            try {
              await _supabase
                  .from('vehicles')
                  .update({
                    'is_posted': isPosted,
                    'is_available': isPosted,
                    'status': targetStatus,
                  })
                  .eq('id', canonicalId);
            } catch (_) {}
          }
        } else {
          updateStatus('Updating PSDC fleet vehicle record...');
          try {
            await _supabase
                .from('vehicles')
                .update({
                  'is_posted': isPosted,
                  'is_available': isPosted,
                  'status': targetStatus,
                })
                .eq('id', vehicleId);
          } catch (e) {
            try {
              await _supabase
                  .from('vehicles')
                  .update({
                    'is_available': isPosted,
                    'status': targetStatus,
                  })
                  .eq('id', vehicleId);
            } catch (_) {
              await _supabase
                  .from('vehicles')
                  .update({
                    'is_available': isPosted,
                  })
                  .eq('id', vehicleId);
            }
          }
        }

        vehicle['is_posted'] = isPosted;
        vehicle['is_available'] = isPosted;
        vehicle['status'] = targetStatus;
        if (isPosted) {
          vehicle['cleaning_until'] = null;
          vehicle['auto_relist_at'] = null;
        }

        updateStatus('Refreshing fleet inventory...');
        await _loadVehicles();
      },
    );
  }

  void _showOperatorTurnaroundBufferDialog(bool isDark) async {
    final currentBuffer =
        await VehicleTurnaroundService().getGlobalTurnaroundMinutes();
    if (!mounted) return;

    int selectedBuffer = currentBuffer;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: _operatorGold.withOpacity(0.3),
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _operatorGold.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cleaning_services_rounded,
                  color: _operatorGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Post-Trip Turnaround Buffer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  'Set the default automatic unlist duration when a vehicle is returned. The car will be unlisted for turnaround cleaning and inspection for this duration before automatically relisting for bookings.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade300,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: VehicleTurnaroundService.turnaroundOptions
                              .contains(selectedBuffer)
                          ? selectedBuffer
                          : 60,
                      isExpanded: true,
                      dropdownColor:
                          isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: VehicleTurnaroundService.turnaroundOptions
                          .map((minutes) {
                        return DropdownMenuItem<int>(
                          value: minutes,
                          child: Row(
                            children: [
                              Icon(
                                minutes == 0
                                    ? Icons.flash_on_rounded
                                    : Icons.timer_outlined,
                                size: 16,
                                color: minutes == 0
                                    ? _operatorGold
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                VehicleTurnaroundService.getLabelForMinutes(
                                  minutes,
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: minutes == selectedBuffer
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedBuffer = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Note: When turnaround cleaning finishes early, you can click "Relist Immediately" anytime or turn the POSTED switch on to make the car available right away.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await VehicleTurnaroundService()
                    .setGlobalTurnaroundMinutes(selectedBuffer);
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Turnaround buffer set to ${VehicleTurnaroundService.getLabelForMinutes(selectedBuffer)}',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: _operatorGold,
                foregroundColor: _operatorNavyDeep,
              ),
              child: const Text(
                'Save Settings',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVehicleTurnaroundDialog(
    Map<String, dynamic> vehicle,
    bool isDark,
  ) async {
    final vehicleId = vehicle['id']?.toString() ?? '';
    final partnerVehicleId = vehicle['partner_vehicle_id']?.toString() ??
        vehicle['_partner_vehicle_id']?.toString();
    final currentMinutes =
        await VehicleTurnaroundService().getVehicleTurnaroundMinutes(vehicleId);
    final activeTurnaround =
        await VehicleTurnaroundService().getActiveTurnaround(vehicleId);
    if (!mounted) return;

    int selectedBuffer = currentMinutes;
    bool isRelisting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: _operatorGold.withOpacity(0.3),
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _operatorGold.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cleaning_services_rounded,
                  color: _operatorGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Turnaround Buffer Settings',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _vehicleTitle(vehicle),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
                if (activeTurnaround != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.cleaning_services_rounded,
                              color: Colors.amber,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Currently In Cleaning Turnaround',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeTurnaround['auto_relist_at'] != null
                              ? 'Auto-relists at: ${DateFormat('h:mm a, MMM d').format(DateTime.tryParse(activeTurnaround['auto_relist_at'].toString()) ?? DateTime.now())}'
                              : 'Turnaround buffer active',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: isRelisting
                                ? null
                                : () async {
                                    setModalState(() => isRelisting = true);
                                    await VehicleTurnaroundService()
                                        .relistVehicleImmediately(
                                          vehicleId: vehicleId,
                                          partnerVehicleId: partnerVehicleId,
                                        );
                                    vehicle['is_available'] = true;
                                    vehicle['is_posted'] = true;
                                    vehicle['status'] = 'active';
                                    vehicle['cleaning_until'] = null;
                                    vehicle['auto_relist_at'] = null;
                                    await _loadVehicles();
                                    if (dialogCtx.mounted) {
                                      Navigator.pop(dialogCtx);
                                    }
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Vehicle relisted & marked available!'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.flash_on_rounded, size: 14),
                            label: Text(
                              isRelisting
                                  ? 'Relisting...'
                                  : 'Relist Immediately (Cleaned)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _operatorGold,
                              foregroundColor: _operatorNavyDeep,
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Text(
                  'Configure how long this vehicle should be unlisted for turnaround cleaning after each return:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade300,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: VehicleTurnaroundService.turnaroundOptions
                              .contains(selectedBuffer)
                          ? selectedBuffer
                          : 60,
                      isExpanded: true,
                      dropdownColor:
                          isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: VehicleTurnaroundService.turnaroundOptions
                          .map((minutes) {
                        return DropdownMenuItem<int>(
                          value: minutes,
                          child: Row(
                            children: [
                              Icon(
                                minutes == 0
                                    ? Icons.flash_on_rounded
                                    : Icons.timer_outlined,
                                size: 16,
                                color: minutes == 0
                                    ? _operatorGold
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                VehicleTurnaroundService.getLabelForMinutes(
                                  minutes,
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: minutes == selectedBuffer
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedBuffer = val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await VehicleTurnaroundService().setVehicleTurnaroundMinutes(
                  vehicleId: vehicleId,
                  minutes: selectedBuffer,
                  partnerVehicleId: partnerVehicleId,
                );
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Turnaround buffer for ${_vehicleTitle(vehicle)} set to ${VehicleTurnaroundService.getLabelForMinutes(selectedBuffer)}',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: _operatorGold,
                foregroundColor: _operatorNavyDeep,
              ),
              child: const Text(
                'Save Buffer',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

