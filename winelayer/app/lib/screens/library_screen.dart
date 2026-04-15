import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../models/app_model.dart';
import '../providers/app_providers.dart';
import '../widgets/app_card.dart';
import '../widgets/glass_container.dart';

/// Library screen — displays all installed apps in a responsive grid.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(appListProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ──────────────────────────────────────────
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Library',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your Windows apps, running seamlessly on Linux',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ],
              ),
              const Spacer(),
              // Refresh button
              IconButton(
                onPressed: () {
                  ref.read(appListProvider.notifier).refresh();
                },
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.glassBg,
                  foregroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.glassBorder),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ─── Search Bar ──────────────────────────────────────
          SizedBox(
            width: 400,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
              decoration: InputDecoration(
                hintText: 'Search apps...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textTertiary,
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: AppColors.textTertiary,
                      )
                    : null,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ─── App Grid ────────────────────────────────────────
          Expanded(
            child: appsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
              error: (error, _) => _buildErrorState(context, error),
              data: (apps) {
                // Filter by search
                final filtered = searchQuery.isEmpty
                    ? apps
                    : apps
                        .where((app) => app.displayName
                            .toLowerCase()
                            .contains(searchQuery.toLowerCase()))
                        .toList();

                if (apps.isEmpty) {
                  return _buildEmptyState(context);
                }

                if (filtered.isEmpty) {
                  return _buildNoResultsState(context, searchQuery);
                }

                return _buildAppGrid(context, filtered);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppGrid(BuildContext context, List<WineApp> apps) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive grid: calculate columns based on width
        final columns = (constraints.maxWidth / 280).floor().clamp(1, 5);

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemCount: apps.length,
          itemBuilder: (context, index) {
            final app = apps[index];
            return AppCard(
              app: app,
              onLaunch: () => _launchApp(app),
              onDelete: () => _confirmDelete(context, app),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.secondary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Image.asset(
                'assets/logo.png',
                width: 40,
                height: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Apps Yet',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first Windows application to get started.\nWineLayer will create an isolated environment automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(selectedNavIndexProvider.notifier).state = 1;
              },
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add Your First App'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context, String query) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No apps matching "$query"',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load apps',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(appListProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _launchApp(WineApp app) async {
    try {
      await ref.read(appListProvider.notifier).launchApp(app.appId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Launching ${app.displayName}...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to launch: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, WineApp app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uninstall App'),
        content: Text(
          'Are you sure you want to uninstall "${app.displayName}"?\n\n'
          'This will delete the app\'s Wine prefix and all associated data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(appListProvider.notifier).deleteApp(app.appId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
  }
}
