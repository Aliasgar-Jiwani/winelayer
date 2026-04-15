import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../theme/app_colors.dart';
import '../providers/app_providers.dart';

/// Wine onboarding screen shown to Linux users when Wine is missing.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _isInstalling = false;
  String _statusMessage = '';
  bool _installSuccess = false;
  bool _checking = true;
  Map<String, dynamic> _sysStatus = {};

  @override
  void initState() {
    super.initState();
    _checkSystem();
  }

  Future<void> _checkSystem() async {
    try {
      // Ensure we connect to the daemon before trying to send requests!
      final client = ref.read(daemonClientProvider);
      if (!client.isConnected) {
        await ref.read(daemonStatusProvider.notifier).connect();
      }
      if (!client.isConnected) {
        throw StateError('Could not establish connection to daemon');
      }

      final status = await client.call('get_system_status');
      setState(() {
        _sysStatus = status as Map<String, dynamic>;
        _checking = false;
        // Wine already installed
        final wine = _sysStatus['wine'] as Map<String, dynamic>? ?? {};
        if (wine['installed'] == true) {
          _installSuccess = true;
          _statusMessage = 'Wine ${wine['version']} detected!';
        }
      });
    } catch (e) {
      setState(() {
        _checking = false;
        _statusMessage = 'Could not connect to daemon.';
      });
    }
  }

  Future<void> _installWine() async {
    setState(() {
      _isInstalling = true;
      _statusMessage = 'Requesting installer privileges...';
    });

    try {
      final result = await ref.read(daemonClientProvider).call('install_wine', {});
      final success = (result as Map<String, dynamic>)['success'] == true;
      setState(() {
        _isInstalling = false;
        _installSuccess = success;
        _statusMessage = success
            ? 'Wine installed successfully! You\'re ready to go.'
            : 'Installation failed. Please install Wine manually.';
      });
    } catch (e) {
      setState(() {
        _isInstalling = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wine = _sysStatus['wine'] as Map<String, dynamic>? ?? {};
    final wineInstalled = wine['installed'] == true;
    final canAutoInstall = _sysStatus['can_auto_install'] == true;
    final distro = _sysStatus['distro'] as String? ?? 'your system';

    return Scaffold(
      backgroundColor: AppColors.bgDarkest,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Image.asset('assets/logo.png', width: 56, height: 56),
              ),
              const SizedBox(height: 28),
              Text(
                'Welcome to WineLayer',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Run Windows apps on Linux — no terminal required.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 40),

              // Requirement check
              if (_checking)
                const CircularProgressIndicator()
              else
                _buildRequirementCard(
                  icon: wineInstalled ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  iconColor: wineInstalled ? AppColors.success : AppColors.warning,
                  title: 'Wine Runtime',
                  subtitle: wineInstalled
                      ? wine['version'] ?? 'Installed'
                      : 'Not detected on $distro',
                ),

              const SizedBox(height: 24),

              // Action button
              if (!_checking) ...[
                if (!wineInstalled && !_installSuccess) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isInstalling ? null : _installWine,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isInstalling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.download_rounded,
                              color: Colors.white),
                      label: Text(
                        _isInstalling ? 'Installing...' : 'Install Wine Automatically',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (!canAutoInstall)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Auto-install not available for your distro. Visit winehq.org',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textTertiary, fontSize: 13),
                      ),
                    ),
                ],
                if (_installSuccess)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Dismiss onboarding — navigate to main app
                        ref.read(onboardingCompleteProvider.notifier).state = true;
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.rocket_launch_rounded,
                          color: Colors.white),
                      label: const Text(
                        'Launch WineLayer',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],

              if (_statusMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _installSuccess
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.glassBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _installSuccess
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.glassBorder,
                    ),
                  ),
                  child: Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _installSuccess
                            ? AppColors.success
                            : AppColors.textSecondary,
                        fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: TextStyle(
                      color: AppColors.textTertiary, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Provider to track if onboarding is complete
final onboardingCompleteProvider = StateProvider<bool>((ref) => false);
