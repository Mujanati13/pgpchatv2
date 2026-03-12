import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/pin_service.dart';
import '../widgets/responsive_center.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final PinService _pinService = PinService();
  final List<String> _entered = [];
  final List<String> _confirm = [];
  bool _confirming = false;
  String? _error;

  void _onDigit(String digit) {
    final target = _confirming ? _confirm : _entered;
    if (target.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      target.add(digit);
    });

    if (target.length == 4) {
      if (!_confirming) {
        // Move to confirm step
        Future.delayed(const Duration(milliseconds: 200), () {
          setState(() => _confirming = true);
        });
      } else {
        _submitPin();
      }
    }
  }

  void _onDelete() {
    final target = _confirming ? _confirm : _entered;
    if (target.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      target.removeLast();
    });
  }

  Future<void> _submitPin() async {
    if (_entered.join() != _confirm.join()) {
      setState(() {
        _error = 'PINs do not match';
        _confirm.clear();
        _confirming = false;
        _entered.clear();
      });
      return;
    }

    await _pinService.setPin(_entered.join());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN enabled successfully')),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set PIN'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: ResponsiveScaffoldBody(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.pin_outlined,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _confirming ? 'Confirm PIN' : 'Create PIN',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMainDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _confirming
                        ? 'Enter the same PIN again'
                        : 'Choose a 4-digit PIN to protect the app',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSubDark,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // PIN dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final target = _confirming ? _confirm : _entered;
                      final filled = i < target.length;
                      return Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? AppColors.primary : Colors.transparent,
                          border: Border.all(
                            color: filled ? AppColors.primary : AppColors.borderDark,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: AppColors.error, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '5 wrong attempts will reset the app and wipe all data.',
                            style: TextStyle(
                              color: AppColors.textSubDark,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Numpad
                  _buildNumpad(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return SizedBox(
      width: 280,
      child: Column(
        children: [
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', 'del'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row.map((key) {
                  if (key.isEmpty) {
                    return const SizedBox(width: 72, height: 72);
                  }
                  if (key == 'del') {
                    return _NumpadKey(
                      onTap: _onDelete,
                      child: const Icon(Icons.backspace_outlined,
                          color: AppColors.textMainDark, size: 24),
                    );
                  }
                  return _NumpadKey(
                    onTap: () => _onDigit(key),
                    child: Text(
                      key,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMainDark,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _NumpadKey extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _NumpadKey({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderDark),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
