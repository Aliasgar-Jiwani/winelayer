import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../models/app_model.dart';
import '../providers/app_providers.dart';
import '../widgets/glass_container.dart';
import '../widgets/status_indicator.dart';

/// Settings screen — daemon status, Wine info, storage paths, about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daemonStatus = ref.watch(daemonStatusProvider);
    final wineInfoAsync = ref.watch(wineInfoProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ──────────────────────────────────────────
          Text(
            'Settings',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Configure WineLayer and view system information',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),

          const SizedBox(height: 32),

          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                children: [
                  // ─── Daemon Status Section ─────────────────────
                  _buildSectionTitle(context, 'Daemon Connection'),
                  const SizedBox(height: 12),
                  GlassContainer(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: (daemonStatus == DaemonStatus.connected
                                        ? AppColors.success
                                        : AppColors.error)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                daemonStatus == DaemonStatus.connected
                                    ? Icons.cloud_done_rounded
                                    : Icons.cloud_off_rounded,
                                color: daemonStatus == DaemonStatus.connected
                                    ? AppColors.success
                                    : AppColors.error,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'WineLayer Daemon',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(width: 10),
                                      StatusIndicator(
                                        status: daemonStatus ==
                                                DaemonStatus.connected
                                            ? 'installed'
                                            : daemonStatus ==
                                                    DaemonStatus.connecting
                                                ? 'installing'
                                                : 'error',
                                        size: 8,
                                        showLabel: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'localhost:9274 · JSON-RPC 2.0',
                                    style: TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (daemonStatus != DaemonStatus.connected)
                              ElevatedButton.icon(
                                onPressed: () {
                                  ref
                                      .read(daemonStatusProvider.notifier)
                                      .connect();
                                },
                                icon: const Icon(Icons.refresh_rounded,
                                    size: 18),
                                label: const Text('Reconnect'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── Wine Info Section ─────────────────────────
                  _buildSectionTitle(context, 'Wine Runtime'),
                  const SizedBox(height: 12),
                  GlassContainer(
                    padding: const EdgeInsets.all(20),
                    child: wineInfoAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                      error: (e, _) => _buildInfoRow(
                        context,
                        Icons.warning_amber_rounded,
                        'Wine Status',
                        'Unable to detect: $e',
                        AppColors.warning,
                      ),
                      data: (info) {
                        if (info == null) {
                          return _buildInfoRow(
                            context,
                            Icons.warning_amber_rounded,
                            'Wine Status',
                            'Not connected to daemon',
                            AppColors.warning,
                          );
                        }
                        return Column(
                          children: [
                            _buildInfoRow(
                              context,
                              Icons.new_releases_rounded,
                              'Version',
                              info.version,
                              AppColors.primary,
                            ),
                            const Divider(height: 20),
                            _buildInfoRow(
                              context,
                              Icons.folder_rounded,
                              'Binary Path',
                              info.path ?? 'System default',
                              AppColors.secondary,
                            ),
                            const Divider(height: 20),
                            _buildInfoRow(
                              context,
                              Icons.memory_rounded,
                              'Architecture',
                              info.arch ?? 'Unknown',
                              AppColors.info,
                            ),
                            if (info.isStaging) ...[
                              const Divider(height: 20),
                              _buildInfoRow(
                                context,
                                Icons.science_rounded,
                                'Build Type',
                                'Wine Staging',
                                AppColors.warning,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 28),
                  
                  // ─── VM Sandbox Engine ──────────────────────────
                  _buildSectionTitle(context, 'Micro-VM Sandbox Engine (Phase 4)'),
                  const SizedBox(height: 12),
                  GlassContainer(
                    padding: const EdgeInsets.all(20),
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: ref.read(daemonClientProvider).getVmStatus(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Text('Error loading VM status: ${snapshot.error}');
                        }
                        
                        final status = snapshot.data ?? {};
                        final isRunning = status['is_running'] == true;
                        final isDownloaded = status['image_downloaded'] == true;
                        
                        return Column(
                          children: [
                            _buildInfoRow(
                              context,
                              Icons.developer_board_rounded,
                              'Hypervisor State',
                              isRunning ? 'Online (Idle)' : 'Offline (Suspended)',
                              isRunning ? AppColors.success : AppColors.textTertiary,
                            ),
                            const Divider(height: 20),
                            _buildInfoRow(
                              context,
                              Icons.storage_rounded,
                              'Base Image',
                              isDownloaded ? 'Ready ~ 4.2 GB' : 'Missing',
                              isDownloaded ? AppColors.success : AppColors.error,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (!isDownloaded)
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Downloading VM image...')),
                                      );
                                      await ref.read(daemonClientProvider).ensureVmImage();
                                      // Force reload
                                      if (context.mounted) {
                                        (context as Element).markNeedsBuild();
                                      }
                                    },
                                    icon: const Icon(Icons.download_rounded),
                                    label: const Text('Download Image'),
                                  )
                                else ...[
                                  ElevatedButton.icon(
                                    onPressed: isRunning ? null : () async {
                                      await ref.read(daemonClientProvider).startVm();
                                      if (context.mounted) {
                                        (context as Element).markNeedsBuild();
                                      }
                                    },
                                    icon: const Icon(Icons.power_rounded),
                                    label: const Text('Start Sandbox'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: !isRunning ? null : () async {
                                      await ref.read(daemonClientProvider).stopVm();
                                      if (context.mounted) {
                                        (context as Element).markNeedsBuild();
                                      }
                                    },
                                    icon: const Icon(Icons.power_off_rounded),
                                    label: const Text('Suspend'),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── About Section ─────────────────────────────
                  _buildSectionTitle(context, 'About WineLayer'),
                  const SizedBox(height: 12),
                  GlassContainer(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Logo
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/logo.png',
                            width: 32,
                            height: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'WineLayer',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Version 0.1.0 · Phase 4',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'An experience orchestration engine for running\n'
                          'Windows applications on Linux — without a terminal.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatChip('Phase', '4/4'),
                            const SizedBox(width: 12),
                            _buildStatChip('Modules', '9'),
                            const SizedBox(width: 12),
                            _buildStatChip('License', 'LGPL'),
                          ],
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final daemon = ref.read(daemonClientProvider);
                            if (daemon.isConnected) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Syncing compatibility database...')),
                              );
                              try {
                                await daemon.syncCompatDb();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Database synced globally.'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Sync failed.'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.sync_rounded, size: 18),
                          label: const Text('Sync Compatibility Database'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color accentColor,
  ) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accentColor, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
