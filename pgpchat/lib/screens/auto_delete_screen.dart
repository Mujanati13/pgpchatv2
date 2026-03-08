import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_center.dart';
import '../providers/settings_provider.dart';

class AutoDeleteScreen extends StatefulWidget {
  const AutoDeleteScreen({super.key});

  @override
  State<AutoDeleteScreen> createState() => _AutoDeleteScreenState();
}

class _AutoDeleteScreenState extends State<AutoDeleteScreen> {
  bool _autoDeleteEnabled = true;
  double _sliderValue = 2; // index: 0=1hr, 1=12hr, 2=24hr, 3=1wk, 4=1mo
  bool _showConfirmDialog = false;

  final List<String> _labels = ['1 hr', '12 hr', '24 hr', '1 wk', '1 mo'];
  final List<int> _hours = [1, 12, 24, 168, 720];

  String get _currentLabel => _labels[_sliderValue.round()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      setState(() {
        _autoDeleteEnabled = settings.autoDeleteEnabled;
        final idx = _hours.indexOf(settings.autoDeleteHours);
        _sliderValue = idx >= 0 ? idx.toDouble() : 2;
      });
    });
  }

  void _onToggleChanged(bool val) {
    setState(() {
      _autoDeleteEnabled = val;
      if (val) _showConfirmDialog = true;
    });
    context.read<SettingsProvider>().setAutoDelete(val);
  }

  void _onSliderChanged(double val) {
    setState(() => _sliderValue = val);
    context.read<SettingsProvider>().setAutoDeleteHours(_hours[val.round()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: ResponsiveScaffoldBody(
        child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon:
                            const Icon(Icons.arrow_back_ios_new, size: 24),
                        color: AppColors.primary,
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: 40),
                          child: Text(
                            'Auto-delete',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: AppColors.textMainDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      children: [
                        // Info Text
                        const Padding(
                          padding:
                              EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text(
                            'Automatically wipe out message history for maximum privacy. Settings apply to all new messages.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.slate400,
                              height: 1.5,
                            ),
                          ),
                        ),
                        // Configuration Card
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A2530),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.slate800
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Column(
                              children: [
                                // Toggle Row
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.history_toggle_off,
                                          size: 24,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Auto-delete Messages',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    AppColors.textMainDark,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Self-destruct timer',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.slate400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: _autoDeleteEnabled,
                                        onChanged: _onToggleChanged,
                                        activeColor: Colors.white,
                                        activeTrackColor: AppColors.primary,
                                        inactiveThumbColor: Colors.white,
                                        inactiveTrackColor:
                                            const Color(0xFF2A3A4A),
                                      ),
                                    ],
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: AppColors.slate700
                                      .withValues(alpha: 0.5),
                                ),
                                // Slider Section
                                if (_autoDeleteEnabled)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 20, 16, 24),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment
                                                  .spaceBetween,
                                          children: [
                                            const Text(
                                              'Time limit',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    AppColors.textMainDark,
                                              ),
                                            ),
                                            Text(
                                              _getTimeDisplay(),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        SliderTheme(
                                          data: SliderThemeData(
                                            activeTrackColor:
                                                AppColors.primary,
                                            inactiveTrackColor:
                                                const Color(0xFF2A3A4A),
                                            thumbColor: Colors.white,
                                            overlayColor: AppColors.primary
                                                .withValues(alpha: 0.1),
                                            trackHeight: 6,
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                                    enabledThumbRadius: 14),
                                          ),
                                          child: Slider(
                                            value: _sliderValue,
                                            min: 0,
                                            max: 4,
                                            divisions: 4,
                                            onChanged: _onSliderChanged,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment
                                                  .spaceBetween,
                                          children: _labels.map((label) {
                                            final isSelected =
                                                label == _currentLabel;
                                            return Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: isSelected
                                                    ? AppColors.slate200
                                                    : AppColors.slate500,
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Footer text
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Text(
                            'Messages are securely wiped using military-grade deletion algorithms upon timer expiration.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.slate400,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Confirmation Dialog Overlay
            if (_showConfirmDialog)
              GestureDetector(
                onTap: () => setState(() => _showConfirmDialog = false),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Center(
                    child: Container(
                      width: 290,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2733),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.warning,
                                  size: 36,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Are you sure?',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: AppColors.textMainDark,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This will immediately delete messages older than ${_getTimeDisplay()}. This action cannot be undone.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.slate300,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            height: 1,
                            color:
                                AppColors.slate700.withValues(alpha: 0.7),
                          ),
                          InkWell(
                            onTap: () async {
                              setState(() => _showConfirmDialog = false);
                              await context.read<SettingsProvider>().autoDeleteNow();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Messages deleted')),
                                );
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppColors.slate700
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Yes, delete immediately',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _showConfirmDialog = false;
                                _autoDeleteEnabled = false;
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              child: const Text(
                                'No, cancel',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  color: AppColors.primary,
                                  letterSpacing: -0.3,
                                ),
                              ),
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
      ),
      ),
    );
  }

  String _getTimeDisplay() {
    switch (_sliderValue.round()) {
      case 0:
        return '1 hour';
      case 1:
        return '12 hours';
      case 2:
        return '24 hours';
      case 3:
        return '1 week';
      case 4:
        return '1 month';
      default:
        return '24 hours';
    }
  }
}
