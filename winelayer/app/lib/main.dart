import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'models/app_model.dart';
import 'providers/app_providers.dart';
import 'screens/library_screen.dart';
import 'screens/add_app_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/install_wizard_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/sidebar.dart';
import 'widgets/job_queue_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1200, 750),
    minimumSize: Size(900, 600),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'WineLayer',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: WineLayerApp()));
}

class WineLayerApp extends ConsumerWidget {
  const WineLayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingDone = ref.watch(onboardingCompleteProvider);
    return MaterialApp(
      title: 'WineLayer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: onboardingDone ? const AppShell() : const OnboardingScreen(),
    );
  }
}

/// Main application shell with sidebar and content area.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    // Auto-connect to daemon on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(daemonStatusProvider.notifier).connect();
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);

    // Refresh app list when daemon connects
    ref.listen(daemonStatusProvider, (prev, next) {
      if (next == DaemonStatus.connected) {
        ref.read(appListProvider.notifier).refresh();
      }
    });

    return Scaffold(
      body: Column(
        children: [
          // ─── Custom Title Bar ──────────────────────────────
          _buildTitleBar(context),

          // ─── Main Content ─────────────────────────────────
          Expanded(
            child: Row(
              children: [
                // Sidebar
                const Sidebar(),

                // Content area
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _buildScreen(selectedIndex),
                        ),
                      ),
                      // Job Queue Panel
                      const JobQueuePanel(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.bgDarkest,
          border: Border(
            bottom: BorderSide(color: AppColors.glassBorder, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Image.asset(
              'assets/logo.png',
              width: 16,
              height: 16,
            ),
            const SizedBox(width: 8),
            const Text(
              'WineLayer',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            // Window controls
            _WindowButton(
              icon: Icons.minimize_rounded,
              onTap: () => windowManager.minimize(),
            ),
            _WindowButton(
              icon: Icons.crop_square_rounded,
              onTap: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
            ),
            _WindowButton(
              icon: Icons.close_rounded,
              onTap: () => windowManager.close(),
              isClose: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const LibraryScreen(key: ValueKey('library'));
      case 1:
        return const AddAppScreen(key: ValueKey('add_app'));
      case 2:
        return const CatalogScreen(key: ValueKey('catalog'));
      case 3:
        return const SettingsScreen(key: ValueKey('settings'));
      case 4:
        return const InstallWizardScreen(key: ValueKey('wizard'));
      default:
        return const LibraryScreen(key: ValueKey('library'));
    }
  }
}

/// Individual window control button.
class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onTap,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 36,
          color: _isHovered
              ? widget.isClose
                  ? AppColors.error
                  : AppColors.glassBg
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: _isHovered && widget.isClose
                ? Colors.white
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
