/// WineLayer app data model — mirrors the daemon's App database model.
class WineApp {
  final int? id;
  final String appId;
  final String displayName;
  final String exePath;
  final String? iconPath;
  final String architecture;
  final String wineVersion;
  final String status;
  final String? installSource;
  final DateTime? createdAt;
  final DateTime? lastLaunched;
  final String? prefixPath;
  final String executionEngine;

  const WineApp({
    this.id,
    required this.appId,
    required this.displayName,
    required this.exePath,
    this.iconPath,
    this.architecture = 'win64',
    this.wineVersion = 'stable',
    this.status = 'pending',
    this.installSource,
    this.executionEngine = 'wine',
    this.createdAt,
    this.lastLaunched,
    this.prefixPath,
  });

  factory WineApp.fromJson(Map<String, dynamic> json) {
    return WineApp(
      id: json['id'] as int?,
      appId: json['app_id'] as String,
      displayName: json['display_name'] as String,
      exePath: json['exe_path'] as String,
      iconPath: json['icon_path'] as String?,
      architecture: json['architecture'] as String? ?? 'win64',
      wineVersion: json['wine_version'] as String? ?? 'stable',
      status: json['status'] as String? ?? 'pending',
      installSource: json['install_source'] as String?,
      executionEngine: json['execution_engine'] as String? ?? 'wine',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      lastLaunched: json['last_launched'] != null
          ? DateTime.tryParse(json['last_launched'] as String)
          : null,
      prefixPath: json['prefix_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'app_id': appId,
      'display_name': displayName,
      'exe_path': exePath,
      'icon_path': iconPath,
      'architecture': architecture,
      'wine_version': wineVersion,
      'status': status,
      'install_source': installSource,
      'execution_engine': executionEngine,
      'created_at': createdAt?.toIso8601String(),
      'last_launched': lastLaunched?.toIso8601String(),
      'prefix_path': prefixPath,
    };
  }

  /// Is the app in a launchable state?
  bool get isLaunchable =>
      status == 'installed' || status == 'running';

  /// Is the app currently being installed?
  bool get isInstalling => status == 'installing';

  /// Has the app encountered an error?
  bool get hasError => status == 'error';

  /// Human-readable status label
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'installing':
        return 'Installing...';
      case 'installed':
        return 'Ready';
      case 'running':
        return 'Running';
      case 'error':
        return 'Error';
      case 'uninstalled':
        return 'Uninstalled';
      default:
        return status;
    }
  }

  WineApp copyWith({
    int? id,
    String? appId,
    String? displayName,
    String? exePath,
    String? iconPath,
    String? architecture,
    String? wineVersion,
    String? status,
    String? installSource,
    String? executionEngine,
    DateTime? createdAt,
    DateTime? lastLaunched,
    String? prefixPath,
  }) {
    return WineApp(
      id: id ?? this.id,
      appId: appId ?? this.appId,
      displayName: displayName ?? this.displayName,
      exePath: exePath ?? this.exePath,
      iconPath: iconPath ?? this.iconPath,
      architecture: architecture ?? this.architecture,
      wineVersion: wineVersion ?? this.wineVersion,
      status: status ?? this.status,
      installSource: installSource ?? this.installSource,
      executionEngine: executionEngine ?? this.executionEngine,
      createdAt: createdAt ?? this.createdAt,
      lastLaunched: lastLaunched ?? this.lastLaunched,
      prefixPath: prefixPath ?? this.prefixPath,
    );
  }
}

/// Daemon connection status
enum DaemonStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// Wine runtime info from daemon
class WineInfo {
  final String version;
  final String? path;
  final String? arch;
  final bool isStaging;
  final bool isGe;

  const WineInfo({
    required this.version,
    this.path,
    this.arch,
    this.isStaging = false,
    this.isGe = false,
  });

  factory WineInfo.fromJson(Map<String, dynamic> json) {
    return WineInfo(
      version: json['version'] as String? ?? 'unknown',
      path: json['path'] as String?,
      arch: json['arch'] as String?,
      isStaging: json['is_staging'] as bool? ?? false,
      isGe: json['is_ge'] as bool? ?? false,
    );
  }
}
