import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Full-screen progress overlay with animated stages.
class ProgressOverlay extends StatelessWidget {
  final String title;
  final String message;
  final String stage;
  final bool isVisible;
  final VoidCallback? onCancel;

  const ProgressOverlay({
    super.key,
    required this.title,
    required this.message,
    required this.stage,
    this.isVisible = true,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.bgDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated spinner
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

                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // Stage label
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    stage,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                if (onCancel != null) ...[
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
