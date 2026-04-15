import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_colors.dart';
import '../models/catalog_model.dart';
import '../providers/app_providers.dart';
import '../widgets/glass_container.dart';

/// Install wizard — multi-step guided install for catalog apps.
class InstallWizardScreen extends ConsumerStatefulWidget {
  const InstallWizardScreen({super.key});

  @override
  ConsumerState<InstallWizardScreen> createState() =>
      _InstallWizardScreenState();
}

class _InstallWizardScreenState extends ConsumerState<InstallWizardScreen> {
  int _currentStep = 0;
  String? _selectedExePath;
  InstallPlan? _plan;
  bool _isInstalling = false;
  String _installStage = '';
  String _installMessage = '';
  bool _loadingPlan = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInstallPlan();
    });
  }

  Future<void> _loadInstallPlan() async {
    final appId = ref.read(wizardAppIdProvider);
    if (appId == null || appId.isEmpty) {
      setState(() => _loadingPlan = false);
      return;
    }

    try {
      final client = ref.read(daemonClientProvider);
      final planJson = await client.call('get_install_plan', {'app_id': appId});
      setState(() {
        _plan = InstallPlan.fromJson(planJson as Map<String, dynamic>);
        _loadingPlan = false;
      });
    } catch (e) {
      setState(() => _loadingPlan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPlan) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_plan == null) {
      return _buildNoPlan(context);
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ──────────────────────────────────
              Text(
                'Install Wizard',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Guided installation for ${_plan!.displayName}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),

              const SizedBox(height: 24),

              // ─── Stepper ─────────────────────────────────
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    children: [
                      // Step indicator
                      _buildStepIndicator(),
                      const SizedBox(height: 24),

                      // Step content
                      _buildStepContent(),

                      const SizedBox(height: 24),

                      // Navigation buttons
                      if (!_isInstalling) _buildNavButtons(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ─── Install Progress ─────────────────────────
        if (_isInstalling) _buildProgressOverlay(),
      ],
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Summary', 'Select .exe', 'Configure', 'Install'];

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          // Connector line
          final stepIdx = index ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              color: stepIdx < _currentStep
                  ? AppColors.primary
                  : AppColors.glassBorder,
            ),
          );
        }

        final stepIdx = index ~/ 2;
        final isActive = stepIdx == _currentStep;
        final isComplete = stepIdx < _currentStep;

        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isActive || isComplete
                    ? AppColors.primaryGradient
                    : null,
                color: !isActive && !isComplete ? AppColors.bgMedium : null,
                border: Border.all(
                  color: isActive || isComplete
                      ? Colors.transparent
                      : AppColors.glassBorder,
                ),
              ),
              child: Center(
                child: isComplete
                    ? const Icon(Icons.check_rounded,
                        size: 18, color: Colors.white)
                    : Text(
                        '${stepIdx + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.white
                              : AppColors.textTertiary,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              steps[stepIdx],
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStepContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (_currentStep) {
        0 => _buildSummaryStep(),
        1 => _buildExeStep(),
        2 => _buildConfigStep(),
        3 => _buildInstallStep(),
        _ => const SizedBox.shrink(),
      },
    );
  }

  // ─── Step 1: Summary ─────────────────────────────────────────

  Widget _buildSummaryStep() {
    final plan = _plan!;
    return GlassContainer(
      key: const ValueKey('summary'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App name
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.apps_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.displayName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text('${plan.architecture} · Wine ${plan.wineVersion} · ${plan.windowsVersion}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textTertiary)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Dependencies
          if (plan.dependencies.isNotEmpty) ...[
            _buildSectionLabel('Dependencies (${plan.dependencies.length})'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: plan.dependencies.map((dep) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.2)),
                  ),
                  child: Text(dep,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.secondary,
                          fontWeight: FontWeight.w500)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Features
          Row(
            children: [
              _buildFeatureChip('DXVK', plan.dxvk),
              const SizedBox(width: 8),
              _buildFeatureChip('Esync', plan.esync),
              const SizedBox(width: 8),
              _buildFeatureChip('Registry', plan.registryCount > 0),
            ],
          ),

          // Known issues
          if (plan.knownIssues.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionLabel('Known Issues'),
            const SizedBox(height: 8),
            ...plan.knownIssues.map((issue) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      issue.severity == 'major' || issue.severity == 'critical'
                          ? Icons.warning_rounded
                          : Icons.info_outline_rounded,
                      size: 16,
                      color: issue.severity == 'major' ||
                              issue.severity == 'critical'
                          ? AppColors.warning
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(issue.description,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ─── Step 2: Select .exe ─────────────────────────────────────

  Widget _buildExeStep() {
    return GlassContainer(
      key: const ValueKey('exe'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Select the Installer'),
          const SizedBox(height: 8),
          const Text(
            'Choose the .exe file you downloaded for this application.',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickExe,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.bgMedium,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedExePath != null
                        ? AppColors.success.withValues(alpha: 0.4)
                        : AppColors.glassBorder,
                  ),
                ),
                child: _selectedExePath != null
                    ? Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedExePath!.split('\\').last.split('/').last,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary),
                                ),
                                Text(_selectedExePath!,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textTertiary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _pickExe,
                            child: const Text('Change'),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Icon(Icons.upload_file_rounded,
                              size: 44,
                              color: AppColors.primary.withValues(alpha: 0.6)),
                          const SizedBox(height: 12),
                          const Text('Click to browse for .exe',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 3: Configure ──────────────────────────────────────

  Widget _buildConfigStep() {
    final plan = _plan!;
    return GlassContainer(
      key: const ValueKey('config'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Configuration'),
          const SizedBox(height: 8),
          const Text(
            'These settings are pre-configured from the install script. Modify only if needed.',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 20),

          // Config items (read-only, from script)
          _buildConfigRow('Architecture', plan.architecture),
          _buildConfigRow('Wine Version', plan.wineVersion),
          _buildConfigRow('Windows Version', plan.windowsVersion),
          _buildConfigRow('Dependencies', '${plan.dependencies.length} packages'),
          _buildConfigRow('Registry Entries', '${plan.registryCount} entries'),
          if (plan.dxvk) _buildConfigRow('DXVK', 'Enabled'),
          if (plan.esync) _buildConfigRow('Esync', 'Enabled'),
        ],
      ),
    );
  }

  // ─── Step 4: Install ────────────────────────────────────────

  Widget _buildInstallStep() {
    return GlassContainer(
      key: const ValueKey('install'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.rocket_launch_rounded,
              size: 56, color: AppColors.primary),
          const SizedBox(height: 16),
          Text('Ready to install ${_plan!.displayName}',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'WineLayer will create an isolated environment, install dependencies,\napply registry tweaks, and run the installer automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppColors.textTertiary, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _selectedExePath != null ? _startInstall : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Start Installation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Progress Overlay ──────────────────────────────────────

  Widget _buildProgressOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: GlassContainer(
          padding: const EdgeInsets.all(40),
          backgroundColor: AppColors.bgDark.withValues(alpha: 0.95),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(height: 24),
              Text('Installing ${_plan!.displayName}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_installStage,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 8),
              Text(_installMessage,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────

  Widget _buildNoPlan(BuildContext context) {
    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 48, color: AppColors.warning),
            const SizedBox(height: 16),
            const Text('No app selected',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Browse the catalog to select an app to install.',
                style: TextStyle(color: AppColors.textTertiary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(selectedNavIndexProvider.notifier).state = 2;
              },
              child: const Text('Go to Catalog'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          OutlinedButton.icon(
            onPressed: () => setState(() => _currentStep--),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Back'),
          )
        else
          OutlinedButton(
            onPressed: () {
              ref.read(selectedNavIndexProvider.notifier).state = 2;
            },
            child: const Text('Back to Catalog'),
          ),
        if (_currentStep < 3)
          ElevatedButton.icon(
            onPressed: _canAdvance ? () => setState(() => _currentStep++) : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Next'),
          ),
      ],
    );
  }

  bool get _canAdvance {
    if (_currentStep == 1) return _selectedExePath != null;
    return true;
  }

  Widget _buildSectionLabel(String label) {
    return Text(label,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary));
  }

  Widget _buildFeatureChip(String label, bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.bgMedium,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: enabled
              ? AppColors.success.withValues(alpha: 0.2)
              : AppColors.glassBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_rounded : Icons.close_rounded,
            size: 13,
            color: enabled ? AppColors.success : AppColors.textTertiary,
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: enabled
                      ? AppColors.success
                      : AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textTertiary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _pickExe() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['exe'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedExePath = result.files.first.path;
      });
    }
  }

  void _startInstall() async {
    if (_selectedExePath == null || _plan == null) return;

    setState(() {
      _isInstalling = true;
      _installStage = 'starting';
      _installMessage = 'Preparing installation...';
    });

    final subscription =
        ref.read(daemonClientProvider).notifications.listen((notif) {
      if (notif['method'] == 'progress') {
        final params = notif['params'] as Map<String, dynamic>?;
        if (params != null && mounted) {
          setState(() {
            _installStage = params['stage'] as String? ?? '';
            _installMessage = params['message'] as String? ?? '';
          });
        }
      }
    });

    try {
      final client = ref.read(daemonClientProvider);
      await client.call('install_from_catalog', {
        'app_id': _plan!.appId,
        'exe_path': _selectedExePath!,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_plan!.displayName} installed successfully!'),
            backgroundColor: AppColors.success.withValues(alpha: 0.9),
          ),
        );
        ref.read(appListProvider.notifier).refresh();
        ref.read(selectedNavIndexProvider.notifier).state = 0;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Installation failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      subscription.cancel();
      if (mounted) {
        setState(() => _isInstalling = false);
      }
    }
  }
}
