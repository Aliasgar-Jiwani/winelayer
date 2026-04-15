import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/app_model.dart';
import '../models/catalog_model.dart';
import '../services/daemon_client.dart';

// ─── Daemon Client Provider ──────────────────────────────────────────
final daemonClientProvider = Provider<DaemonClient>((ref) {
  final client = DaemonClient();
  ref.onDispose(() => client.dispose());
  return client;
});

// ─── Daemon Connection Status ────────────────────────────────────────
final daemonStatusProvider =
    NotifierProvider<DaemonStatusNotifier, DaemonStatus>(
        DaemonStatusNotifier.new);

class DaemonStatusNotifier extends Notifier<DaemonStatus> {
  Timer? _reconnectTimer;

  @override
  DaemonStatus build() {
    final client = ref.read(daemonClientProvider);
    client.connectionStatus.listen((connected) {
      state = connected ? DaemonStatus.connected : DaemonStatus.disconnected;
      if (!connected) {
        _scheduleReconnect();
      }
    });
    return DaemonStatus.disconnected;
  }

  Future<void> connect() async {
    state = DaemonStatus.connecting;
    final client = ref.read(daemonClientProvider);
    final success = await client.connect();
    state = success ? DaemonStatus.connected : DaemonStatus.error;

    if (!success) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (state != DaemonStatus.connected) {
        connect();
      }
    });
  }
}

// ─── App List Provider ───────────────────────────────────────────────
final appListProvider =
    AsyncNotifierProvider<AppListNotifier, List<WineApp>>(AppListNotifier.new);

class AppListNotifier extends AsyncNotifier<List<WineApp>> {
  @override
  Future<List<WineApp>> build() async {
    return [];
  }

  Future<void> refresh() async {
    final client = ref.read(daemonClientProvider);
    try {
      if (!client.isConnected) {
        state = const AsyncValue.data([]);
        return;
      }
      final appsJson = await client.listApps();
      final apps = appsJson.map((json) => WineApp.fromJson(json)).toList();
      state = AsyncValue.data(apps);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> installApp({
    required String displayName,
    required String exePath,
    String architecture = 'win64',
  }) async {
    final client = ref.read(daemonClientProvider);
    try {
      await client.installApp(
        displayName: displayName,
        exePath: exePath,
        architecture: architecture,
      );
      await refresh();
    } catch (e) {
      debugPrint('Install error: $e');
      rethrow;
    }
  }

  Future<void> launchApp(String appId) async {
    final client = ref.read(daemonClientProvider);
    try {
      await client.launchApp(appId);
      await refresh();
    } catch (e) {
      debugPrint('Launch error: $e');
      rethrow;
    }
  }

  Future<void> deleteApp(String appId) async {
    final client = ref.read(daemonClientProvider);
    try {
      await client.deleteApp(appId);
      await refresh();
    } catch (e) {
      debugPrint('Delete error: $e');
      rethrow;
    }
  }
}

// ─── Wine Info Provider ──────────────────────────────────────────────
final wineInfoProvider = FutureProvider<WineInfo?>((ref) async {
  final client = ref.read(daemonClientProvider);
  if (!client.isConnected) return null;

  try {
    final json = await client.getWineInfo();
    return WineInfo.fromJson(json);
  } catch (e) {
    return null;
  }
});

// ─── Progress Notifications Provider ─────────────────────────────────
final progressProvider =
    StreamProvider<Map<String, dynamic>>((ref) {
  final client = ref.read(daemonClientProvider);
  return client.notifications;
});

// ─── Catalog Provider (Phase 2) ──────────────────────────────────────

class CatalogData {
  final List<CatalogEntry> entries;
  final List<String> categories;

  CatalogData({required this.entries, required this.categories});
}

final catalogProvider = FutureProvider<CatalogData>((ref) async {
  final client = ref.read(daemonClientProvider);
  if (!client.isConnected) {
    return CatalogData(entries: [], categories: []);
  }

  try {
    final result = await client.call('get_catalog');
    final rawEntries = (result['entries'] as List?) ?? [];
    final rawCategories = (result['categories'] as List?) ?? [];

    return CatalogData(
      entries: rawEntries
          .map((e) => CatalogEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: rawCategories.map((c) => c.toString()).toList(),
    );
  } catch (e) {
    debugPrint('Catalog load error: $e');
    return CatalogData(entries: [], categories: []);
  }
});

// ─── Job Queue Provider (Phase 2) ────────────────────────────────────
final jobQueueProvider = FutureProvider<List<JobInfo>>((ref) async {
  final client = ref.read(daemonClientProvider);
  if (!client.isConnected) return [];

  try {
    final jobs = await client.call('list_jobs', {'include_completed': false});
    return (jobs as List)
        .map((j) => JobInfo.fromJson(j as Map<String, dynamic>))
        .toList();
  } catch (e) {
    debugPrint('Job queue load error: $e');
    return [];
  }
});

// ─── State Providers ─────────────────────────────────────────────────
final selectedNavIndexProvider = StateProvider<int>((ref) => 0);
final searchQueryProvider = StateProvider<String>((ref) => '');
final catalogSearchProvider = StateProvider<String>((ref) => '');
final wizardAppIdProvider = StateProvider<String?>((ref) => null);
