import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/pin_service.dart';
import '../widgets/responsive_center.dart';
import 'pin_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _api = ApiService();
  final _pinService = PinService();
  bool _pinEnabled = false;

  @override
  void initState() {
    super.initState();
    _pinEnabled = _pinService.isEnabled;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _togglePin(bool enable) async {
    if (enable) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      );
      if (result == true && mounted) {
        setState(() => _pinEnabled = true);
      }
    } else {
      await _pinService.removePin();
      if (mounted) setState(() => _pinEnabled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ResponsiveScaffoldBody(
        child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Security section
          const Text(
            'SECURITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSubDark,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock_outline, size: 20, color: AppColors.primary),
                        SizedBox(width: 12),
                        Text(
                          'PIN Lock',
                          style: TextStyle(
                            color: AppColors.textMainDark,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _pinEnabled,
                      activeColor: AppColors.primary,
                      onChanged: _togglePin,
                    ),
                  ],
                ),
                if (_pinEnabled) ...[
                  const Divider(color: AppColors.borderDark, height: 24),
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
                      );
                      if (result == true && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PIN changed')),
                        );
                      }
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Change PIN',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.slate400, size: 20),
                      ],
                    ),
                  ),
                ],
                const Divider(color: AppColors.borderDark, height: 24),
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '5 wrong attempts will wipe all data',
                        style: TextStyle(
                          color: AppColors.textSubDark,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // About section
          const Text(
            'ABOUT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSubDark,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: const Column(
              children: [
                _InfoRow(label: 'App Name', value: 'PGP Chat'),
                Divider(color: AppColors.borderDark, height: 24),
                _InfoRow(label: 'Version', value: '1.0.0'),
                Divider(color: AppColors.borderDark, height: 24),
                _InfoRow(label: 'Encryption', value: 'OpenPGP'),
                Divider(color: AppColors.borderDark, height: 24),
                _InfoRow(label: 'Architecture', value: 'Zero-Knowledge'),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSubDark,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textMainDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
