import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../models/catalog_model.dart';
import '../providers/app_providers.dart';
import '../widgets/catalog_card.dart';
import '../widgets/glass_container.dart';

/// Catalog screen — browse and search the compat-db app catalog.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogProvider);
    final searchQuery = ref.watch(catalogSearchProvider);

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
                    'App Catalog',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Browse tested Windows apps from the community database',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ],
              ),
              const Spacer(),
              // Refresh catalog
              IconButton(
                onPressed: () {
                  ref.invalidate(catalogProvider);
                },
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh catalog',
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
                ref.read(catalogSearchProvider.notifier).state = value;
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
                          ref.read(catalogSearchProvider.notifier).state = '';
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: AppColors.textTertiary,
                      )
                    : null,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ─── Category Chips ──────────────────────────────────
          catalogAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) {
              final categories = data.categories;
              return SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildCategoryChip('all', 'All', Icons.apps_rounded, data.entries.length),
                    ...categories.map((cat) {
                      final count = data.entries
                          .where((e) => e.category == cat)
                          .length;
                      return _buildCategoryChip(
                        cat,
                        cat.replaceAll('-', ' '),
                        _categoryIcon(cat),
                        count,
                      );
                    }),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // ─── App Grid ────────────────────────────────────────
          Expanded(
            child: catalogAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => Center(
                child: GlassContainer(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('Failed to load catalog: $e',
                          style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(catalogProvider),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (data) {
                var entries = data.entries;

                // Filter by search
                if (searchQuery.isNotEmpty) {
                  final q = searchQuery.toLowerCase();
                  entries = entries
                      .where((e) =>
                          e.displayName.toLowerCase().contains(q) ||
                          e.category.toLowerCase().contains(q) ||
                          e.description.toLowerCase().contains(q))
                      .toList();
                }

                // Filter by category
                if (_selectedCategory != 'all') {
                  entries = entries
                      .where((e) => e.category == _selectedCategory)
                      .toList();
                }

                if (entries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded,
                            size: 48, color: AppColors.textTertiary),
                        const SizedBox(height: 16),
                        const Text(
                          'No apps found',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        (constraints.maxWidth / 310).floor().clamp(1, 4);
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.35,
                      ),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return CatalogCard(
                          entry: entry,
                          onInstall: () => _startInstall(entry),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
      String value, String label, IconData icon, int count) {
    final isSelected = _selectedCategory == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = value),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.glassBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.glassBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 14,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  label[0].toUpperCase() + label.substring(1),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppColors.primaryLight
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : AppColors.bgMedium,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  void _startInstall(CatalogEntry entry) {
    if (entry.hasScript) {
      // Navigate to install wizard
      ref.read(selectedNavIndexProvider.notifier).state = 4; // wizard index
      ref.read(wizardAppIdProvider.notifier).state = entry.appId;
    } else {
      // Navigate to manual add screen
      ref.read(selectedNavIndexProvider.notifier).state = 1;
    }
  }
}
