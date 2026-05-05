import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../../services/vehicle_service.dart';

class VehicleSearchScreen extends StatefulWidget {
  final String? initialCategory;

  const VehicleSearchScreen({super.key, this.initialCategory});

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
  int? _minSeats;
  DateTime? _availableFrom;
  DateTime? _availableTo;

  final List<Map<String, dynamic>> _results = [];
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

  Future<void> _loadRecentVehicles() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final vehicles = await vehicleService.getAvailableVehicles(
        category: _selectedCategoryForQuery,
      );

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
        category: _selectedCategoryForQuery,
        minPrice: minPrice,
        maxPrice: maxPrice,
        minSeats: _minSeats,
        availableFrom: _availableFrom,
        availableTo: _availableTo,
      );

      if (!mounted) return;
      setState(() {
        _results
          ..clear()
          ..addAll(vehicles);
        _isSearching = false;
      });

      if (vehicles.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No vehicles found matching criteria')),
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

    setState(() {
      _selectedCategory = category;
    });
    await _loadRecentVehicles();
  }

  Future<void> _viewAllVehicles() async {
    setState(() {
      _selectedCategory = 'All Cars';
    });
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
      _minSeats = null;
      _availableFrom = null;
      _availableTo = null;
      _selectedCategory = 'All Cars';
    });
    _loadRecentVehicles();
  }

  Future<void> _selectDate(bool isFrom) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate != null && mounted) {
      setState(() {
        if (isFrom) {
          _availableFrom = selectedDate;
        } else {
          _availableTo = selectedDate;
        }
      });
    }
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategory == category;
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
          color: isSelected ? null : AppColors.darkBgSecondary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderColor,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category == 'Sedan'
                  ? Icons.directions_car
                  : category == 'SUV'
                  ? Icons.directions_car
                  : category == 'Van'
                  ? Icons.airport_shuttle
                  : category == 'Pickup'
                  ? Icons.local_shipping
                  : Icons.all_inclusive,
              size: 14,
              color: isSelected ? Colors.black : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              category,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.black : AppColors.textPrimary,
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
    final imageUrl = vehicle['image_url'] as String?;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          '/vehicle-detail',
          arguments: {
            'vehicleId': vehicle['id']?.toString() ?? '',
            'vehicleData': vehicle,
          },
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
                color: Colors.grey.shade300,
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.directions_car, size: 48),
                      ),
                    )
                  : const Center(child: Icon(Icons.directions_car, size: 48)),
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
                    const Spacer(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: const Text('Find Vehicles'),
        elevation: 0,
        backgroundColor: AppColors.darkBgSecondary,
        actions: [
          if (_results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  '${_results.length} found',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.darkBgSecondary,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    hintText: 'Search location, brand, model...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: AppColors.darkBgTertiary,
                    hintStyle: const TextStyle(color: AppColors.textTertiary),
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(
                          _showFilters ? Icons.expand_less : Icons.tune,
                        ),
                        label: Text(
                          _showFilters ? 'Hide Filters' : 'Show Filters',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.borderColor),
                          foregroundColor: AppColors.textPrimary,
                          backgroundColor: AppColors.darkBgSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => setState(() {
                          _showFilters = !_showFilters;
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.search),
                      label: const Text('Search'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isSearching ? null : _performSearch,
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _isLoading ? null : _viewAllVehicles,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: _viewAllVehicles,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
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
          if (_showFilters)
            Container(
              color: AppColors.darkBg,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _brandController,
                            decoration: InputDecoration(
                              labelText: 'Brand',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: AppColors.darkBgSecondary,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _modelController,
                            decoration: InputDecoration(
                              labelText: 'Model',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: AppColors.darkBgSecondary,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minPriceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Min Price',
                              prefixText: '₱ ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: AppColors.darkBgSecondary,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _maxPriceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Max Price',
                              prefixText: '₱ ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: AppColors.darkBgSecondary,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedColor,
                            decoration: InputDecoration(
                              labelText: 'Color',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: AppColors.darkBgSecondary,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: _colors
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _selectedColor = value),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedFuelType,
                            decoration: InputDecoration(
                              labelText: 'Fuel Type',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: AppColors.darkBgSecondary,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: _fuelTypes
                                .map(
                                  (f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(f),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _selectedFuelType = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _minSeats,
                      decoration: InputDecoration(
                        labelText: 'Minimum Seats',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: AppColors.darkBgSecondary,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: _seatOptions
                          .map(
                            (seatCount) => DropdownMenuItem(
                              value: seatCount,
                              child: Text('$seatCount+ seats'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _minSeats = value),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDate(true),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.borderColor,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: AppColors.darkBgSecondary,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _availableFrom != null
                                          ? 'From: ${_availableFrom!.toString().split(' ')[0]}'
                                          : 'Available From',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDate(false),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.borderColor,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: AppColors.darkBgSecondary,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _availableTo != null
                                          ? 'To: ${_availableTo!.toString().split(' ')[0]}'
                                          : 'Available To',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Cars',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Row(
                  children: [
                    if (_results.isNotEmpty)
                      Text(
                        '${_results.length} cars',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _viewAllVehicles,
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
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
                : _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.directions_car_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No vehicles found',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try adjusting your filters',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final vehicle = _results[index];
                      return _buildVehicleCard(vehicle);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
