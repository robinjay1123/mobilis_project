import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;

  // Stream to listen to connectivity changes
  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  bool get isOnline => _isOnline;

  // Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = result != ConnectivityResult.none;
      debugPrint('Connectivity check: $_isOnline, result: $result');
      return _isOnline;
    } catch (e) {
      debugPrint('Connectivity check error: $e');
      return true; // Assume online on error
    }
  }

  // Listen to connectivity changes
  void listenConnectivity(Function(bool) onConnectivityChanged) {
    connectivityStream.listen((result) {
      final isOnline =
          result.isNotEmpty && !result.contains(ConnectivityResult.none);
      _isOnline = isOnline;
      debugPrint('Connectivity changed: $isOnline');
      onConnectivityChanged(isOnline);
    });
  }

  // Get detailed connection type
  Future<String> getConnectionType() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (result.isEmpty || result.contains(ConnectivityResult.none)) {
        return 'No Connection';
      } else if (result.contains(ConnectivityResult.wifi)) {
        return 'WiFi';
      } else if (result.contains(ConnectivityResult.mobile)) {
        return 'Mobile Data';
      } else if (result.contains(ConnectivityResult.ethernet)) {
        return 'Ethernet';
      } else if (result.contains(ConnectivityResult.vpn)) {
        return 'VPN';
      }
      return 'Connected';
    } catch (e) {
      return 'Unknown';
    }
  }
}
