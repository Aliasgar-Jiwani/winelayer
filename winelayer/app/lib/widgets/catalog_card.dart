import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/catalog_model.dart';
import '../widgets/glass_container.dart';

/// Card widget for displaying a catalog app entry.
class CatalogCard extends StatefulWidget {
  final CatalogEntry entry;
  final VoidCallback onInstall;
  final VoidCallback? onViewDetails;

  const CatalogCard({
    super.key,
    required this.entry,
    required this.onInstall,
    this.onViewDetails,
  });

  @override
  State<CatalogCard> createState() => _CatalogCardState();
}

class _CatalogCardState extends State<CatalogCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final accentColor = _categoryColor(entry.category);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
        transformAlignment: Alignment.center,
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          backgroundColor: _isHovered
              ? accentColor.withValues(alpha: 0.05)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header Row ────────────────────────────────
              Row(
                children: [
                  // App Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.2),
                          accentColor.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _categoryIcon(entry.category),
                      color: accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + Category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.category.replaceAll('-', ' '),
                          style: TextStyle(
                            fontSize: 11,
                            color: accentColor.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  _buildStatusBadge(entry.status),
                ],
              ),

              const SizedBox(height: 10),

              // ─── Description ───────────────────────────────
              if (entry.description.isNotEmpty)
                Text(
                  entry.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              const Spacer(),

              // ─── Footer Row ────────────────────────────────
              Row(
                children: [
                  // Report count
                  Icon(
                    Icons.people_outline_rounded,
                    size: 13,
                    color: AppColors.textTertiary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.reportCount} reports',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary.withValues(alpha: 0.6),
                    ),
                  ),
                  if (entry.sizeEstimate.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Icon(
                      Icons.storage_rounded,
                      size: 13,
                      color: AppColors.textTertiary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entry.sizeEstimate,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Install button
                  if (entry.hasScript)
                    SizedBox(
                      height: 30,
                      child: ElevatedButton(
                        onPressed: widget.onInstall,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Install'),
                      ),
                    )
                  else
                    SizedBox(
                      height: 30,
                      child: OutlinedButton(
                        onPressed: widget.onInstall,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: BorderSide(
                            color: AppColors.glassBorder.withValues(alpha: 0.5),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: const Text('Manual'),
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

  Widget _buildStatusBadge(String status) {
    final (Color color, String label, IconData icon) = switch (status) {
      'working' => (AppColors.success, 'Working', Icons.check_circle_rounded),
      'partial' => (AppColors.warning, 'Partial', Icons.warning_rounded),
      'broken' => (AppColors.error, 'Broken', Icons.error_rounded),
      _ => (AppColors.textTertiary, 'Unknown', Icons.help_outline_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    return switch (category) {
      'text-editor' => AppColors.primary,
      'media' => const Color(0xFFE040FB),
      'utility' => AppColors.secondary,
      'productivity' => const Color(0xFF26C6DA),
      'graphics' => const Color(0xFFFFA726),
      _ => AppColors.primary,
    };
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'text-editor' => Icons.edit_note_rounded,
      'media' => Icons.play_circle_rounded,
      'utility' => Icons.build_circle_rounded,
      'productivity' => Icons.work_rounded,
      'graphics' => Icons.brush_rounded,
      _ => Icons.apps_rounded,
    };
  }
}
