import 'package:flutter/material.dart';

import '../../../models/gps_tracker_model.dart';
import '../../../services/gps_service.dart';
import '../../theme/app_colors.dart';

class ConnectGpsTrackerScreen extends StatefulWidget {
  final String? vehicleId;
  final String? partnerVehicleId;
  final String? vehicleApplicationId;
  final VehicleTracker? existingTracker;

  const ConnectGpsTrackerScreen({
    super.key,
    this.vehicleId,
    this.partnerVehicleId,
    this.vehicleApplicationId,
    this.existingTracker,
  });

  @override
  State<ConnectGpsTrackerScreen> createState() =>
      _ConnectGpsTrackerScreenState();
}

class _ConnectGpsTrackerScreenState extends State<ConnectGpsTrackerScreen> {
  final _formKey = GlobalKey<FormState>();
  final GpsService _gpsService = GpsService();

  late TextEditingController _deviceIdController;
  late TextEditingController _passwordController;

  String _selectedProvider = 'aika168';
  bool _obscurePassword = true;
  bool _isConnecting = false;
  String? _errorMessage;

  final List<Map<String, String>> _providerOptions = [
    {'id': 'aika168', 'name': 'AIKA168 (Recommended)'},
    {'id': 'traccar', 'name': 'Traccar GPS'},
  ];

  @override
  void initState() {
    super.initState();
    _deviceIdController = TextEditingController(
      text: widget.existingTracker?.deviceIdentifier ?? '',
    );
    _passwordController = TextEditingController();
    if (widget.existingTracker != null) {
      _selectedProvider = widget.existingTracker!.provider;
    }
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleConnectTracker() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final tracker = await _gpsService.verifyAndConnectTracker(
        vehicleId: widget.vehicleId,
        partnerVehicleId: widget.partnerVehicleId,
        vehicleApplicationId: widget.vehicleApplicationId,
        provider: _selectedProvider,
        deviceIdentifier: _deviceIdController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('✅ GPS Tracker connected and verified successfully!'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(tracker);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _errorMessage = msg;
        _isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text(
          'Connect GPS Tracker',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: isDark ? AppColors.darkBgSecondary : Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.gps_fixed_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AIKA168 GPS Integration',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Enter the Device ID/IMEI and password associated with your AIKA-compatible GPS tracker.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // GPS Provider Selector
              const Text(
                'GPS Provider',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedProvider,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppColors.darkBgSecondary : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: _providerOptions
                    .map((p) => DropdownMenuItem(
                          value: p['id'],
                          child: Text(p['name']!),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedProvider = val);
                },
              ),
              const SizedBox(height: 20),

              // Device ID / IMEI
              const Text(
                'Device ID / IMEI',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _deviceIdController,
                keyboardType: TextInputType.number,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'e.g. 868123456789012',
                  filled: true,
                  fillColor: isDark ? AppColors.darkBgSecondary : Colors.grey.shade100,
                  prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the Device ID or IMEI';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // AIKA Password
              const Text(
                'AIKA Password',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'Enter your AIKA login password',
                  filled: true,
                  fillColor: isDark ? AppColors.darkBgSecondary : Colors.grey.shade100,
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your tracker password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isConnecting ? null : _handleConnectTracker,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  icon: _isConnecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _isConnecting ? 'Verifying Tracker...' : 'Test & Connect Tracker',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
