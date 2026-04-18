import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/vehicle_service.dart';

class VehicleSearchScreen extends StatefulWidget {
  const VehicleSearchScreen({Key? key}) : super(key: key);

  @override
  State<VehicleSearchScreen> createState() => _VehicleSearchScreenState();
}

class _VehicleSearchScreenState extends State<VehicleSearchScreen> {
  final supabase = Supabase.instance.client;
  final vehicleService = VehicleService();

  // Filter variables
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

  List<Map<String, dynamic>> _searchResults = [];
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

  @override
  void initState() {
    super.initState();
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

  Future<void> _loadRecentVehicles() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load recent vehicles without filters
      final vehicles = await vehicleService.searchVehicles();

      setState(() {
        _searchResults = vehicles;
        _isLoading = false;
      });
    } catch (e) {
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
        minPrice: minPrice,
        maxPrice: maxPrice,
        minSeats: _minSeats,
        availableFrom: _availableFrom,
        availableTo: _availableTo,
      );

      setState(() {
        _searchResults = vehicles;
        _isSearching = false;
      });

      if (vehicles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No vehicles found matching criteria')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Search error: $e';
        _isSearching = false;
      });
    }
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

    if (selectedDate != null) {
      setState(() {
        if (isFrom) {
          _availableFrom = selectedDate;
        } else {
          _availableTo = selectedDate;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Vehicles'),
        elevation: 0,
        actions: [
          if (_searchResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '${_searchResults.length} found',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Quick search
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    hintText: 'Search location, brand, model...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                  onChanged: (value) => setState(() {}),
                  onSubmitted: (_) => _performSearch(),
                ),
                const SizedBox(height: 12),
                // Advanced filters toggle
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(
                          _showFilters ? Icons.expand_less : Icons.expand_more,
                        ),
                        label: Text(
                          _showFilters ? 'Hide Filters' : 'Show Filters',
                        ),
                        onPressed: () =>
                            setState(() => _showFilters = !_showFilters),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.search),
                      label: const Text('Search'),
                      onPressed: _isSearching ? null : _performSearch,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Advanced filters
          if (_showFilters)
            Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand and Model
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _brandController,
                            decoration: InputDecoration(
                              labelText: 'Brand',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
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
                                borderRadius: BorderRadius.circular(4),
                              ),
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

                    // Price range
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
                                borderRadius: BorderRadius.circular(4),
                              ),
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
                                borderRadius: BorderRadius.circular(4),
                              ),
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

                    // Color and Fuel Type
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedColor,
                            decoration: InputDecoration(
                              labelText: 'Color',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
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
                                borderRadius: BorderRadius.circular(4),
                              ),
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

                    // Seats
                    DropdownButtonFormField<int>(
                      value: _minSeats,
                      decoration: InputDecoration(
                        labelText: 'Minimum Seats',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: _seatOptions
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text('$s+ seats'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _minSeats = value),
                    ),
                    const SizedBox(height: 12),

                    // Date range
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDate(true),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                    color: Colors.blue,
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
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                    color: Colors.blue,
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

                    // Clear filters button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear All Filters'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Search results
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
                : _searchResults.isEmpty
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
                        ElevatedButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear Filters'),
                        ),
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
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final vehicle = _searchResults[index];
                      return _buildVehicleCard(vehicle);
                    },
                  ),
          ),
        ],
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
        // Navigate to vehicle detail screen
        // Navigator.push(context, MaterialPageRoute(
        //   builder: (_) => VehicleDetailScreen(vehicleId: vehicle['id']),
        // ));
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle image
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                color: Colors.grey.shade300,
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.directions_car, size: 48);
                      },
                    )
                  : const Center(child: Icon(Icons.directions_car, size: 48)),
            ),
            // Vehicle info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand and model
                    Text(
                      '$brand $model',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Year
                    Text(
                      'Year: $year',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Specs
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
                    // Price
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
}
