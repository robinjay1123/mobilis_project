part of '../operator_web_screen.dart';

extension _OperatorSettingsTab on _OperatorWebScreenState {
  Widget _buildSettingsContent(bool isDark) {
    return SettingsScreen(
      isDarkMode: isDark,
      showHeader: false,
      showAppearance: true,
      showSignOut: true,
      operatorMode: true,
      onThemeToggle: widget.onThemeToggle,
      onBack: () {},
      onOpenSupport: () => setState(() => _selectedIndex = 2),
      onSignOut: _handleLogout,
      onProfileUpdated: () {
        _loadDashboardData();
      },
    );
  }
}

