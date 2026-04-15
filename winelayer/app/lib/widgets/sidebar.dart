import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../providers/app_providers.dart';
import '../models/app_model.dart';
import 'status_indicator.dart';

/// Navigation sidebar with glass effect, icons, and daemon status.
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final daemonStatus = ref.watch(daemonStatusProvider);

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        gradient: AppColors.sidebarGradient,
        border: Border(
          right: BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // ─── Logo / Brand ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 22,
                    height: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WineLayer',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                    ),
                    Text(
                      'v0.1.0',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Divider(color: AppColors.glassBorder.withValues(alpha: 0.5), height: 1),
          const SizedBox(height: 16),

          // ─── Navigation Items ─────────────────────────────────
          _NavItem(
            icon: Icons.grid_view_rounded,
            label: 'Library',
            index: 0,
            selectedIndex: selectedIndex,
            onTap: () => ref.read(selectedNavIndexProvider.notifier).state = 0,
          ),
          _NavItem(
            icon: Icons.add_circle_outline_rounded,
            label: 'Add App',
            index: 1,
            selectedIndex: selectedIndex,
            onTap: () => ref.read(selectedNavIndexProvider.notifier).state = 1,
          ),
          _NavItem(
            icon: Icons.store_rounded,
            label: 'Catalog',
            index: 2,
            selectedIndex: selectedIndex,
            onTap: () => ref.read(selectedNavIndexProvider.notifier).state = 2,
          ),
          _NavItem(
            icon: Icons.settings_rounded,
            label: 'Settings',
            index: 3,
            selectedIndex: selectedIndex,
            onTap: () => ref.read(selectedNavIndexProvider.notifier).state = 3,
          ),

          const Spacer(),

          // ─── Daemon Status ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.glassBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  StatusIndicator(
                    status: daemonStatus == DaemonStatus.connected
                        ? 'installed'
                        : daemonStatus == DaemonStatus.connecting
                            ? 'installing'
                            : 'error',
                    size: 8,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daemon',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                        ),
                        Text(
                          _statusText(daemonStatus),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: daemonStatus == DaemonStatus.connected
                                    ? AppColors.success
                                    : AppColors.textTertiary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (daemonStatus != DaemonStatus.connected)
                    IconButton(
                      onPressed: () {
                        ref.read(daemonStatusProvider.notifier).connect();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: AppColors.textTertiary,
                      tooltip: 'Reconnect',
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(DaemonStatus status) {
    switch (status) {
      case DaemonStatus.connected:
        return 'Connected';
      case DaemonStatus.connecting:
        return 'Connecting...';
      case DaemonStatus.error:
        return 'Connection Failed';
      case DaemonStatus.disconnected:
        return 'Disconnected';
    }
  }
}

/// Individual navigation item with hover and selection animations.
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final int index;
  final int selectedIndex;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  bool get _isSelected => widget.index == widget.selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : _isHovered
                      ? AppColors.glassBg
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: _isSelected
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: _isSelected
                      ? AppColors.primary
                      : _isHovered
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: _isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: _isSelected
                        ? AppColors.textPrimary
                        : _isHovered
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
}
