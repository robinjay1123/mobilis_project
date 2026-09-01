import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/favorite_vehicle_service.dart';
import '../../widgets/vehicle_image_carousel.dart';

class VehicleSearchScreen extends StatefulWidget {
  final String? initialCategory;
  final DateTime? initialAvailableFrom;
  final DateTime? initialAvailableTo;
  final bool initialOnlyPartners;

  const VehicleSearchScreen({
    super.key,
    this.initialCategory,
    this.initialAvailableFrom,
    this.initialAvailableTo,
    this.initialOnlyPartners = false,
  });

  @override
  State<VehicleSearchScreen> createState() => _VehicleSearchScreenState();
}

class _VehicleSearchScreenState extends State<VehicleSearchScreen> {
  final vehicleService = VehicleService();

  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  String? _selectedColor;
  String? _selectedFuelType;
  String? _selectedTransmission;
  int? _minSeats;
  DateTime? _availableFrom;
  DateTime? _availableTo;

  final List<Map<String, dynamic>> _results = [];
  Set<String> _favoriteVehicleIds = {};
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;
  bool _showFilters = false;

  final List<String> _colors = [
    'Black',
    'White',
    'Gray',
    'Silver',
    'Red',
    'Blue',
    'Green',
    'Yellow',
    'Orange',
    'Brown',
  ];

  final List<String> _fuelTypes = ['Gasoline', 'Diesel', 'Hybrid', 'Electric'];
  final List<int> _seatOptions = [2, 4, 5, 6, 7, 8, 9, 10];
  final List<String> _categories = [
    'All Cars',
    'Sedan',
    'SUV',
    'Van',
    'Hatchback',
    'Pickup',
  ];

  String _selectedCategory = 'All Cars';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCategory?.trim();
    if (initial != null && initial.isNotEmpty) {
      _selectedCategory = _categories.contains(initial) ? initial : 'All Cars';
    }
    _availableFrom = widget.initialAvailableFrom;
    _availableTo = widget.initialAvailableTo ?? widget.initialAvailableFrom;
    _loadFavoriteVehicleIds();
    _loadRecentVehicles();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  String? get _selectedCategoryForQuery =>
      _selectedCategory == 'All Cars' ? null : _selectedCategory;

  bool get _hasAvailabilityFilter =>
      _availableFrom != null || _availableTo != null;

  bool _isPartnerVehicle(Map<String, dynamic> vehicle) {
    final source = vehicle['source']?.toString().toLowerCase();
    final ownerRole = vehicle['owner_role']?.toString().toLowerCase();
    final owner = vehicle['owner'];
    final relatedOwnerRole = owner is Map
        ? owner['role']?.toString().toLowerCase()
        : null;
    return source == 'partner' ||
        ownerRole == 'partner' ||
        relatedOwnerRole == 'partner' ||
        vehicle['is_partner_vehicle'] == true ||
        vehicle['partner_vehicle_id'] != null;
  }

  Future<void> _loadRecentVehicles() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      var vehicles = await vehicleService.getAvailableVehicles(
        category: _selectedCategoryForQuery,
        availableFrom: _availableFrom,
        availableTo: _availableTo,
      );

      if (widget.initialOnlyPartners) {
        vehicles = vehicles.where(_isPartnerVehicle).toList();
      }

      if (!mounted) return;
      setState(() {
        _results
          ..clear()
          ..addAll(vehicles);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error loading vehicles: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFavoriteVehicleIds() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    final ids = await FavoriteVehicleService().getFavoriteVehicleIds(user.id);
    if (!mounted) return;
    setState(() => _favoriteVehicleIds = ids);
  }

  Future<void> _toggleFavoriteVehicle(Map<String, dynamic> vehicle) async {
    final user = AuthService().currentUser;
    final vehicleId = vehicle['id']?.toString() ?? '';
    if (user == null || vehicleId.isEmpty) return;

    final wasFavorite = _favoriteVehicleIds.contains(vehicleId);
    setState(() {
      if (wasFavorite) {
        _favoriteVehicleIds.remove(vehicleId);
      } else {
        _favoriteVehicleIds.add(vehicleId);
      }
    });

    try {
      final nowFavorite = await FavoriteVehicleService().toggleFavorite(
        userId: user.id,
        vehicleId: vehicleId,
      );
      if (!mounted) return;
      setState(() {
        if (nowFavorite) {
          _favoriteVehicleIds.add(vehicleId);
        } else {
          _favoriteVehicleIds.remove(vehicleId);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasFavorite) {
          _favoriteVehicleIds.add(vehicleId);
        } else {
          _favoriteVehicleIds.remove(vehicleId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update favorites: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _performSearch() async {
    try {
      setState(() {
        _isSearching = true;
        _errorMessage = null;
      });

      final minPrice = _minPriceController.text.isEmpty
          ? null
          : double.tryParse(_minPriceController.text);
      final maxPrice = _maxPriceController.text.isEmpty
          ? null
          : double.tryParse(_maxPriceController.text);

      final vehicles = await vehicleService.searchVehicles(
        brand: _brandController.text.isEmpty ? null : _brandController.text,
        model: _modelController.text.isEmpty ? null : _modelController.text,
        location: _locationController.text.isEmpty
            ? null
            : _locationController.text,
        color: _selectedColor,
        fuelType: _selectedFuelType,
        transmission: _selectedTransmission,
        category: _selectedCategoryForQuery,
        minPrice: minPrice,
        maxPrice: maxPrice,
        minSeats: _minSeats,
        availableFrom: _availableFrom,
        availableTo: _availableTo,
      );

      var filtered = vehicles;
      if (widget.initialOnlyPartners) {
        filtered = filtered.where(_isPartnerVehicle).toList();
      }
      if (_selectedTransmission != null && _selectedTransmission!.isNotEmpty) {
        filtered = filtered.where((v) {
          final trans = v['transmission']?.toString().toLowerCase() ?? '';
          return trans.contains(_selectedTransmission!.toLowerCase());
        }).toList();
      }

      if (!mounted) return;
      setState(() {
        _results
          ..clear()
          ..addAll(filtered);
        _isSearching = false;
      });

      if (filtered.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _hasAvailabilityFilter
                  ? 'No available cars for the selected date'
                  : 'No vehicles found matching criteria',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Search error: $e';
        _isSearching = false;
      });
    }
  }

  Future<void> _selectCategory(String category) async {
    if (_selectedCategory == category) return;
    setState(() => _selectedCategory = category);
    await _loadRecentVehicles();
  }

  Future<void> _viewAllVehicles() async {
    setState(() => _selectedCategory = 'All Cars');
    await _loadRecentVehicles();
  }

  void _clearFilters() {
    setState(() {
      _locationController.clear();
      _brandController.clear();
      _modelController.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
      _selectedColor = null;
      _selectedFuelType = null;
      _selectedTransmission = null;
      _minSeats = null;
      _availableFrom = null;
      _availableTo = null;
      _selectedCategory = 'All Cars';
    });
    _loadRecentVehicles();
  }

  Future<void> _selectDate(bool isFrom) async {
    final initial = isFrom
        ? (_availableFrom ?? DateTime.now())
        : (_availableTo ?? _availableFrom ?? DateTime.now());
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.black,
                    surface: AppColors.darkBgSecondary,
                    onSurface: AppColors.textPrimary,
                  )
                : const ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.black,
                    surface: Colors.white,
                    onSurface: AppColors.lightTextPrimary,
                  ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: isDark ? AppColors.darkBgSecondary : Colors.white,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: isDark ? AppColors.darkBg : AppColors.primary,
              headerForegroundColor: isDark ? AppColors.textPrimary : Colors.black,
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;
                }
                if (states.contains(WidgetState.selected)) return Colors.black;
                return isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return Colors.transparent;
              }),
              todayForegroundColor: WidgetStateProperty.all(AppColors.primary),
              todayBorder: const BorderSide(color: AppColors.primary),
              yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;
                }
                if (states.contains(WidgetState.selected)) return Colors.black;
                return isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
              }),
              yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return Colors.transparent;
              }),
            ),
            dialogBackgroundColor: isDark ? AppColors.darkBgSecondary : Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: isDark ? AppColors.primary : AppColors.primaryDark,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null && mounted) {
      setState(() {
        if (isFrom) {
          _availableFrom = selectedDate;
          if (_availableTo == null || _availableTo!.isBefore(selectedDate)) {
            _availableTo = selectedDate;
          }
        } else {
          _availableTo = selectedDate;
          if (_availableFrom == null || _availableFrom!.isAfter(selectedDate)) {
            _availableFrom = selectedDate;
          }
        }
      });
    }
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategory == category;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark ? AppColors.darkCard : Colors.white;
    final chipBorder = isDark ? AppColors.borderColor : AppColors.lightBorderColor;
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final iconColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: () => _selectCategory(category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppColors.primary, Color(0xFFFFD84D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : chipBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primary : chipBorder,
            width: 1.2,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ]
              : AppColors.cardShadowOf(context),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category == 'Van'
                  ? Icons.airport_shuttle
                  : category == 'Pickup'
                  ? Icons.local_shipping
                  : category == 'All Cars'
                  ? Icons.all_inclusive
                  : Icons.directions_car,
              size: 14,
              color: isSelected ? Colors.black : iconColor,
            ),
            const SizedBox(width: 8),
            Text(
              category,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.black : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    final brand = vehicle['brand'] as String? ?? 'Unknown';
    final model = vehicle['model'] as String? ?? 'Model';
    final year = vehicle['year'] as int? ?? 0;
    final pricePerDay = vehicle['price_per_day'] as num? ?? 0;
    final seats = vehicle['seats'] as int? ?? 0;
    final transmission = vehicle['transmission']?.toString() ?? 'Manual';
    final fuelType = vehicle['fuel_type']?.toString() ?? 'Gasoline';
    final vehicleId = vehicle['id']?.toString() ?? '';
    final isFavorite = _favoriteVehicleIds.contains(vehicleId);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          '/vehicle-detail',
          arguments: {
            'vehicleId': vehicle['id']?.toString() ?? '',
            'vehicleData': vehicle,
            'initialStartDate': _availableFrom,
            'initialEndDate': _availableTo,
          },
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                VehicleImageCarousel(
                  key: ValueKey('search-car-$vehicleId'),
                  vehicle: vehicle,
                  height: 140,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                  backgroundColor: Colors.grey.shade300,
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => _toggleFavoriteVehicle(vehicle),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.darkBgSecondary.withValues(
                          alpha: 0.92,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isFavorite
                              ? AppColors.error
                              : AppColors.borderColor,
                        ),
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite
                            ? AppColors.error
                            : AppColors.textSecondary,
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$brand $model',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Year: $year',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$seats seats',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            transmission,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.local_gas_station_outlined,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            fuelType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₱${pricePerDay.toStringAsFixed(0)}/day',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBg = isDark ? AppColors.darkCard : Colors.white;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final tertiaryText = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;
    final fieldBg = isDark ? AppColors.darkBgTertiary : const Color(0xFFF1F5F9);
    final chipUnselectedBg = isDark ? AppColors.darkBgTertiary : const Color(0xFFF1F5F9);

    final activeFiltersCount = [
      _selectedTransmission,
      _selectedFuelType,
      _selectedColor,
      _minSeats,
      _brandController.text.trim().isNotEmpty ? true : null,
      _modelController.text.trim().isNotEmpty ? true : null,
      _minPriceController.text.trim().isNotEmpty ? true : null,
      _maxPriceController.text.trim().isNotEmpty ? true : null,
      _availableFrom,
      _availableTo,
    ].where((item) => item != null).length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(top: 14, bottom: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.primary.withValues(alpha: 0.4) : AppColors.lightBorderColor,
          width: 1.5,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : AppColors.cardShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Vehicle Specifications',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: primaryText,
                    ),
                  ),
                  if (activeFiltersCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$activeFiltersCount Active',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (activeFiltersCount > 0)
                GestureDetector(
                  onTap: _clearFilters,
                  child: const Text(
                    'Reset All',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          Divider(height: 24, color: border),

          // ── TRANSMISSION ──
          Text(
            'Transmission',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['All', 'Automatic', 'Manual'].map((type) {
              final isSelected = (_selectedTransmission == null && type == 'All') ||
                  _selectedTransmission == type;
              return ChoiceChip(
                label: Text(type),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedTransmission = type == 'All' ? null : type;
                  });
                },
                selectedColor: AppColors.primary,
                backgroundColor: chipUnselectedBg,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : primaryText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // ── FUEL TYPE ──
          Text(
            'Fuel Type',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['All', 'Gasoline', 'Diesel', 'Hybrid', 'Electric'].map((fuel) {
              final isSelected = (_selectedFuelType == null && fuel == 'All') ||
                  _selectedFuelType == fuel;
              return ChoiceChip(
                label: Text(fuel),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFuelType = fuel == 'All' ? null : fuel;
                  });
                },
                selectedColor: AppColors.primary,
                backgroundColor: chipUnselectedBg,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : primaryText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // ── BRAND & MODEL ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Brand / Make',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _brandController,
                      style: TextStyle(color: primaryText, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Toyota',
                        hintStyle: TextStyle(color: tertiaryText, fontSize: 12),
                        filled: true,
                        fillColor: fieldBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: border, width: 1.2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: border, width: 1.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Model',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _modelController,
                      style: TextStyle(color: primaryText, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Vios',
                        hintStyle: TextStyle(color: tertiaryText, fontSize: 12),
                        filled: true,
                        fillColor: fieldBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: border, width: 1.2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: border, width: 1.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── COLOR ──
          Text(
            'Vehicle Color',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['All', ..._colors].map((color) {
                final isSelected = (_selectedColor == null && color == 'All') ||
                    _selectedColor == color;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(color),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedColor = color == 'All' ? null : color;
                      });
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: chipUnselectedBg,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : primaryText,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // ── SEATING CAPACITY ──
          Text(
            'Minimum Seats',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [null, 2, 4, 5, 6, 7, 8, 10].map((seats) {
              final label = seats == null ? 'Any' : '$seats+ Seats';
              final isSelected = _minSeats == seats;
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _minSeats = selected ? seats : null);
                },
                selectedColor: AppColors.primary,
                backgroundColor: chipUnselectedBg,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : primaryText,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // ── PRICE PER DAY RANGE ──
          Text(
            'Price / Day (PHP)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minPriceController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: primaryText, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Min ₱',
                    hintStyle: TextStyle(color: tertiaryText, fontSize: 12),
                    filled: true,
                    fillColor: fieldBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border, width: 1.2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border, width: 1.2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('–', style: TextStyle(color: secondaryText)),
              ),
              Expanded(
                child: TextField(
                  controller: _maxPriceController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: primaryText, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Max ₱',
                    hintStyle: TextStyle(color: tertiaryText, fontSize: 12),
                    filled: true,
                    fillColor: fieldBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border, width: 1.2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border, width: 1.2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── DATE RANGE AVAILABILITY ──
          Text(
            'Booking Date Availability',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: Text(
                    _availableFrom == null
                        ? 'Pickup Date'
                        : '${_availableFrom!.month}/${_availableFrom!.day}/${_availableFrom!.year}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryText,
                    side: BorderSide(color: border, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _selectDate(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event, size: 14),
                  label: Text(
                    _availableTo == null
                        ? 'Return Date'
                        : '${_availableTo!.month}/${_availableTo!.day}/${_availableTo!.year}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryText,
                    side: BorderSide(color: border, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _selectDate(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── APPLY BUTTON ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Apply Specification Filters', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _performSearch();
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final tertiaryText = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;
    final searchFill = isDark ? AppColors.darkBgTertiary : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(widget.initialOnlyPartners ? 'Partner Vehicles' : 'Find Vehicles', style: TextStyle(color: primaryText, fontWeight: FontWeight.w800)),
        elevation: 0,
        backgroundColor: cardBg,
        iconTheme: IconThemeData(color: primaryText),
        actions: [
          if (_results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  '${_results.length} found',
                  style: TextStyle(fontSize: 14, color: primaryText, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
      // ── KEY CHANGE: one CustomScrollView so everything scrolls together ──
      body: CustomScrollView(
        slivers: [
          // ── Search + category header (non-scrollable visually, part of scroll) ──
          SliverToBoxAdapter(
            child: Container(
              color: cardBg,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search field
                  TextField(
                    controller: _locationController,
                    style: TextStyle(color: primaryText),
                    decoration: InputDecoration(
                      hintText: 'Search location, brand, model...',
                      prefixIcon: Icon(Icons.search, color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border, width: 1.2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border, width: 1.2),
                      ),
                      filled: true,
                      fillColor: searchFill,
                      hintStyle: TextStyle(color: tertiaryText),
                      suffixIcon: _locationController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _locationController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _performSearch(),
                  ),
                  const SizedBox(height: 14),
                  // Filter toggle + Search button
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          icon: Icon(
                            _showFilters ? Icons.expand_less : Icons.tune,
                          ),
                          label: Text(
                            _showFilters ? 'Hide Filters' : 'Show Filters',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: _showFilters
                                  ? AppColors.primary
                                  : border,
                              width: 1.2,
                            ),
                            foregroundColor: _showFilters
                                ? (isDark ? AppColors.primary : AppColors.primaryDark)
                                : primaryText,
                            backgroundColor: cardBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () =>
                              setState(() => _showFilters = !_showFilters),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.search),
                          label: const Text('Search'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isSearching ? null : _performSearch,
                        ),
                      ),
                    ],
                  ),
                  if (_showFilters) _buildFilterPanel(),
                  const SizedBox(height: 12),

                  // View all button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isLoading ? null : _viewAllVehicles,
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? AppColors.primary : AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('View All Vehicles'),
                    ),
                  ),
                  // Categories
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border, width: 1.2),
                      boxShadow: isDark ? null : AppColors.cardShadowOf(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Categories',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: primaryText,
                              ),
                            ),
                            TextButton(
                              onPressed: _viewAllVehicles,
                              style: TextButton.styleFrom(
                                foregroundColor: isDark ? AppColors.primary : AppColors.primaryDark,
                              ),
                              child: const Text('All Cars'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 54,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            itemBuilder: (context, index) =>
                                _buildCategoryChip(_categories[index]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── "Available Cars" section header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.initialOnlyPartners ? 'Partner Cars' : 'Available Cars',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_results.isNotEmpty)
                    Text(
                      '${_results.length} cars',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Car grid / loading / empty / error states ──
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            SliverFillRemaining(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadRecentVehicles,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_results.isEmpty)
            SliverFillRemaining(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.directions_car_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _hasAvailabilityFilter
                        ? 'No available cars'
                        : 'No vehicles found',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _hasAvailabilityFilter
                        ? 'All cars are already booked for this date'
                        : 'Try adjusting your filters',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildVehicleCard(_results[index]),
                  childCount: _results.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.58,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
