import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../../services/auth_service.dart';

/// Desktop-only access screen shown when admin/operator tries to access
/// web dashboards on mobile/tablet platforms.
class WebOnlyAccessScreen extends StatelessWidget {
  final String role;

  const WebOnlyAccessScreen({super.key, this.role = 'Admin'});

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      await AuthService().signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      debugPrint('Logout error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Desktop Icon in Red Rounded Square
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.red, Colors.deepOrange],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.desktop_mac,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),

              // Title
              Text(
                'Desktop Only',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                'The $role dashboard is optimized for desktop and web platforms only.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Info Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.info,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Role',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            role,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Additional Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.laptop,
                          color: Colors.blue.shade300,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Access the dashboard from your desktop or laptop',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.language,
                          color: Colors.blue.shade300,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Visit the web version at your application URL',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _handleSignOut(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    shadowColor: Colors.red.withOpacity(0.4),
                  ),
                  icon: const Icon(Icons.logout, size: 20),
                  label: Text(
                    'Sign Out',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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
