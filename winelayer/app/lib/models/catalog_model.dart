// Data models for the app catalog and install plans.

/// Represents an entry in the compatibility catalog.
class CatalogEntry {
  final String appId;
  final String displayName;
  final String status; // working, partial, broken, unknown
  final int reportCount;
  final String lastUpdated;
  final String configFile;
  final String category;
  final String description;
  final String website;
  final String iconUrl;
  final String sizeEstimate;
  final bool hasScript;

  CatalogEntry({
    required this.appId,
    required this.displayName,
    this.status = 'unknown',
    this.reportCount = 0,
    this.lastUpdated = '',
    this.configFile = '',
    this.category = 'other',
    this.description = '',
    this.website = '',
    this.iconUrl = '',
    this.sizeEstimate = '',
    this.hasScript = false,
  });

  factory CatalogEntry.fromJson(Map<String, dynamic> json) {
    return CatalogEntry(
      appId: json['app_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      reportCount: json['report_count'] as int? ?? 0,
      lastUpdated: json['last_updated'] as String? ?? '',
      configFile: json['config_file'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      description: json['description'] as String? ?? '',
      website: json['website'] as String? ?? '',
      iconUrl: json['icon_url'] as String? ?? '',
      sizeEstimate: json['size_estimate'] as String? ?? '',
      hasScript: json['has_script'] as bool? ?? false,
    );
  }
}

/// Represents an install plan preview for a catalog app.
class InstallPlan {
  final String appId;
  final String displayName;
  final String wineVersion;
  final String windowsVersion;
  final String architecture;
  final List<String> dependencies;
  final int registryCount;
  final int postInstallCount;
  final bool dxvk;
  final bool esync;
  final List<KnownIssue> knownIssues;

  InstallPlan({
    required this.appId,
    required this.displayName,
    this.wineVersion = 'stable',
    this.windowsVersion = 'win10',
    this.architecture = 'win64',
    this.dependencies = const [],
    this.registryCount = 0,
    this.postInstallCount = 0,
    this.dxvk = false,
    this.esync = false,
    this.knownIssues = const [],
  });

  factory InstallPlan.fromJson(Map<String, dynamic> json) {
    return InstallPlan(
      appId: json['app_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      wineVersion: json['wine_version'] as String? ?? 'stable',
      windowsVersion: json['windows_version'] as String? ?? 'win10',
      architecture: json['architecture'] as String? ?? 'win64',
      dependencies: (json['dependencies'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      registryCount: json['registry_count'] as int? ?? 0,
      postInstallCount: json['post_install_count'] as int? ?? 0,
      dxvk: json['dxvk'] as bool? ?? false,
      esync: json['esync'] as bool? ?? false,
      knownIssues: (json['known_issues'] as List?)
              ?.map((e) => KnownIssue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// A known issue from the install script.
class KnownIssue {
  final String description;
  final String severity;

  KnownIssue({
    required this.description,
    this.severity = 'minor',
  });

  factory KnownIssue.fromJson(Map<String, dynamic> json) {
    return KnownIssue(
      description: json['description'] as String? ?? '',
      severity: json['severity'] as String? ?? 'minor',
    );
  }
}

/// Represents a background job status.
class JobInfo {
  final String id;
  final String appId;
  final String action;
  final String status;
  final String progressStage;
  final String progressMessage;
  final String? error;
  final String createdAt;
  final String? startedAt;
  final String? completedAt;

  JobInfo({
    required this.id,
    required this.appId,
    required this.action,
    required this.status,
    this.progressStage = '',
    this.progressMessage = '',
    this.error,
    this.createdAt = '',
    this.startedAt,
    this.completedAt,
  });

  factory JobInfo.fromJson(Map<String, dynamic> json) {
    return JobInfo(
      id: json['id'] as String? ?? '',
      appId: json['app_id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      status: json['status'] as String? ?? '',
      progressStage: json['progress_stage'] as String? ?? '',
      progressMessage: json['progress_message'] as String? ?? '',
      error: json['error'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      startedAt: json['started_at'] as String?,
      completedAt: json['completed_at'] as String?,
    );
  }

  bool get isRunning => status == 'running';
  bool get isQueued => status == 'queued';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
}
