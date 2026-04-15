import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../models/catalog_model.dart';
import '../providers/app_providers.dart';
import '../widgets/glass_container.dart';

/// Collapsible panel showing active background installation jobs.
class JobQueuePanel extends ConsumerWidget {
  const JobQueuePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobQueueProvider);

    return jobsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (jobs) {
        // Only show if there are active jobs
        final activeJobs =
            jobs.where((j) => j.isRunning || j.isQueued).toList();
        if (activeJobs.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${activeJobs.length} active ${activeJobs.length == 1 ? 'job' : 'jobs'}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(jobQueueProvider),
                      child: const Text('Refresh',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Job list
                ...activeJobs.map((job) => _buildJobItem(context, job)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildJobItem(BuildContext context, JobInfo job) {
    final isRunning = job.isRunning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Status icon
          Icon(
            isRunning
                ? Icons.download_rounded
                : Icons.hourglass_empty_rounded,
            size: 16,
            color: isRunning ? AppColors.primary : AppColors.textTertiary,
          ),
          const SizedBox(width: 10),

          // App name and progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.appId,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (job.progressMessage.isNotEmpty)
                  Text(
                    job.progressMessage,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Stage badge
          if (job.progressStage.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                job.progressStage,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
