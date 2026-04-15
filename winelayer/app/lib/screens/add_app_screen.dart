import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_colors.dart';
import '../providers/app_providers.dart';
import '../widgets/glass_container.dart';

/// Add App screen — pick an .exe, configure, and install.
class AddAppScreen extends ConsumerStatefulWidget {
  const AddAppScreen({super.key});

  @override
  ConsumerState<AddAppScreen> createState() => _AddAppScreenState();
}

class _AddAppScreenState extends ConsumerState<AddAppScreen> {
  final _nameController = TextEditingController();
  String? _selectedExePath;
  String _architecture = 'win64';
  bool _isInstalling = false;
  String _installStage = '';
  String _installMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ──────────────────────────────────────
              Text(
                'Add Application',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Install a Windows .exe into an isolated environment',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),

              const SizedBox(height: 32),

              // ─── Form ────────────────────────────────────────
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Step 1: Select .exe
                        _buildStepLabel(context, '1', 'Select Executable'),
                        const SizedBox(height: 12),
                        _buildFilePicker(context),

                        const SizedBox(height: 28),

                        // Step 2: App Name
                        _buildStepLabel(context, '2', 'Application Name'),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            hintText: 'e.g., Notepad++',
                            prefixIcon: Icon(Icons.label_outline_rounded),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Step 3: Architecture
                        _buildStepLabel(context, '3', 'Architecture'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildArchOption('win64', '64-bit', Icons.memory_rounded),
                            const SizedBox(width: 12),
                            _buildArchOption('win32', '32-bit', Icons.memory_rounded),
                          ],
                        ),

                        const SizedBox(height: 36),

                        // Install button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _canInstall ? _startInstall : null,
                            icon: const Icon(Icons.download_rounded, size: 20),
                            label: const Text('Install Application'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ─── Info Cards ──────────────────────────────────
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      _buildInfoCard(
                        context,
                        Icons.shield_outlined,
                        'Isolated Environment',
                        'Each app gets its own Wine prefix — no conflicts between apps.',
                        AppColors.success,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        context,
                        Icons.auto_fix_high_rounded,
                        'Auto-Configuration',
                        'WineLayer automatically sets up the right Windows version and dependencies.',
                        AppColors.secondary,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        context,
                        Icons.speed_rounded,
                        'Zero Terminal Required',
                        'Everything happens through this interface — no command line needed.',
                        AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ─── Install Progress Overlay ──────────────────────────
        if (_isInstalling)
          Container(
            color: Colors.black.withValues(alpha: 0.6),
            child: Center(
              child: GlassContainer(
                padding: const EdgeInsets.all(40),
                backgroundColor: AppColors.bgDark.withValues(alpha: 0.95),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                        backgroundColor: AppColors.glassBorder,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Installing ${_nameController.text}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _installStage,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _installMessage,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStepLabel(BuildContext context, String number, String label) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildFilePicker(BuildContext context) {
    return GestureDetector(
      onTap: _pickExe,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bgMedium,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _selectedExePath != null
                  ? AppColors.success.withValues(alpha: 0.4)
                  : AppColors.glassBorder,
              style: _selectedExePath != null
                  ? BorderStyle.solid
                  : BorderStyle.solid,
            ),
          ),
          child: _selectedExePath != null
              ? Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedExePath!.split('\\').last.split('/').last,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _selectedExePath!,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                    Icon(
                      Icons.upload_file_rounded,
                      size: 40,
                      color: AppColors.primary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Click to select a .exe file',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Supports Windows installer (.exe) and portable apps',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildArchOption(String value, String label, IconData icon) {
    final isSelected = _architecture == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _architecture = value),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.bgMedium,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.glassBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? AppColors.primary : AppColors.textTertiary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color accentColor,
  ) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _canInstall =>
      _selectedExePath != null &&
      _nameController.text.trim().isNotEmpty &&
      !_isInstalling;

  void _pickExe() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['exe'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedExePath = result.files.first.path;

        // Auto-fill name from filename if empty
        if (_nameController.text.isEmpty) {
          final filename = result.files.first.name;
          final name = filename.replaceAll('.exe', '').replaceAll('_', ' ');
          // Title case
          _nameController.text = name
              .split(' ')
              .map((w) => w.isNotEmpty
                  ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
                  : '')
              .join(' ');
        }
      });
    }
  }

  void _startInstall() async {
    if (!_canInstall) return;

    setState(() {
      _isInstalling = true;
      _installStage = 'starting';
      _installMessage = 'Preparing installation...';
    });

    // Listen for progress notifications
    final subscription = ref.read(daemonClientProvider).notifications.listen((notif) {
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
      await ref.read(appListProvider.notifier).installApp(
            displayName: _nameController.text.trim(),
            exePath: _selectedExePath!,
            architecture: _architecture,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_nameController.text} installed successfully!'),
            backgroundColor: AppColors.success.withValues(alpha: 0.9),
          ),
        );

        // Navigate to library
        ref.read(selectedNavIndexProvider.notifier).state = 0;

        // Reset form
        _nameController.clear();
        setState(() {
          _selectedExePath = null;
          _architecture = 'win64';
        });
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
        setState(() {
          _isInstalling = false;
        });
      }
    }
  }
}
