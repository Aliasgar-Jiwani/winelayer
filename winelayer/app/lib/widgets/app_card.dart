import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/app_model.dart';
import '../providers/app_providers.dart';
import 'status_indicator.dart';
import 'glass_container.dart';
import '../screens/diagnostics_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Premium app card with glassmorphism, hover effects, and status display.
class AppCard extends ConsumerStatefulWidget {
  final WineApp app;
  final VoidCallback? onLaunch;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.app,
    this.onLaunch,
    this.onDelete,
    this.onTap,
  });

  @override
  ConsumerState<AppCard> createState() => _AppCardState();
}

class _AppCardState extends ConsumerState<AppCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _hoverController;
  late Animation<double> _elevationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _elevationAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  /// Get icon for app based on name
  IconData _getAppIcon() {
    final name = widget.app.displayName.toLowerCase();
    if (name.contains('notepad')) return Icons.edit_note_rounded;
    if (name.contains('photo') || name.contains('image')) return Icons.photo_rounded;
    if (name.contains('video') || name.contains('vlc')) return Icons.play_circle_rounded;
    if (name.contains('music') || name.contains('audio')) return Icons.music_note_rounded;
    if (name.contains('office') || name.contains('word')) return Icons.description_rounded;
    if (name.contains('zip') || name.contains('7')) return Icons.folder_zip_rounded;
    if (name.contains('browser') || name.contains('chrome')) return Icons.language_rounded;
    if (name.contains('game')) return Icons.games_rounded;
    return Icons.window_rounded;
  }

  /// Get a unique accent color per app
  Color _getAccentColor() {
    final hash = widget.app.appId.hashCode;
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.info,
      const Color(0xFFEC4899),  // Pink
      const Color(0xFFF97316),  // Orange
    ];
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final accent = _getAccentColor();

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _hoverController.reverse();
      },
      cursor: SystemMouseCursors.click,
      child: AnimatedBuilder(
        animation: _hoverController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: _elevationAnimation.value * 0.02),
                    blurRadius: _elevationAnimation.value * 2,
                    spreadRadius: _elevationAnimation.value * 0.5,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: GlassContainer(
          borderRadius: 18,
          backgroundColor: _isHovered
              ? AppColors.bgMedium.withValues(alpha: 0.8)
              : AppColors.bgDark.withValues(alpha: 0.6),
          borderColor: _isHovered
              ? accent.withValues(alpha: 0.3)
              : AppColors.glassBorder,
          onTap: widget.onTap,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Icon + Status Row ──────────────────────────
              Row(
                children: [
                  // App Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.2),
                          accent.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      _getAppIcon(),
                      color: accent,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  StatusIndicator(status: widget.app.status, size: 8),
                  const SizedBox(width: 6),
                  Text(
                    widget.app.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.app.executionEngine == 'microvm') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        'SANDBOX',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // ─── App Name ───────────────────────────────────
              Text(
                widget.app.displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // ─── Architecture + Wine Version ────────────────
              Text(
                '${widget.app.architecture} · Wine ${widget.app.wineVersion}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),

              const SizedBox(height: 4),

              // ─── Last Launched ──────────────────────────────
              if (widget.app.lastLaunched != null)
                Text(
                  'Last run: ${_formatDate(widget.app.lastLaunched!)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),

              const Spacer(),

              // ─── Action Buttons ─────────────────────────────
              Row(
                children: [
                  // Launch button
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        onPressed: widget.app.isLaunchable ? widget.onLaunch : null,
                        icon: Icon(
                          widget.app.status == 'running'
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          size: 18,
                        ),
                        label: Text(
                          widget.app.status == 'running' ? 'Running' : 'Launch',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Edit/Settings button
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      onPressed: _showEditDialog,
                      icon: const Icon(Icons.settings_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.glassBg,
                        foregroundColor: AppColors.textTertiary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: AppColors.glassBorder),
                        ),
                      ),
                      tooltip: 'Edit Config',
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Diagnostics button
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => DiagnosticsScreen(app: widget.app),
                        );
                      },
                      icon: const Icon(Icons.bug_report_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.glassBg,
                        foregroundColor: AppColors.textTertiary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: AppColors.glassBorder),
                        ),
                      ),
                      tooltip: 'Diagnostics',
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete button
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.glassBg,
                        foregroundColor: AppColors.textTertiary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: AppColors.glassBorder),
                        ),
                      ),
                      tooltip: 'Uninstall',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showEditDialog() {
    final exeController = TextEditingController(text: widget.app.exePath);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.bgDarkest,
          title: const Text('Edit Executable Target', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Change this if the application installed its own true executable (e.g. inside Program Files).',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: exeController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Executable Path',
                  labelStyle: TextStyle(color: AppColors.textTertiary),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newPath = exeController.text.trim();
                if (newPath.isNotEmpty && newPath != widget.app.exePath) {
                  try {
                    await ref.read(daemonClientProvider).updateApp(widget.app.appId, {
                      'exe_path': newPath,
                    });
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Executable path updated!'), backgroundColor: AppColors.success),
                      );
                      // Tell the library to reload apps
                      ref.read(appListProvider.notifier).refresh();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppColors.error),
                      );
                    }
                  }
                } else {
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
