import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// JSON-RPC 2.0 client for communicating with the WineLayer daemon
/// over a TCP socket connection.
class DaemonClient {
  final String host;
  final int port;

  Socket? _socket;
  int _requestId = 0;
  final Map<int, Completer<dynamic>> _pendingRequests = {};
  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  String _buffer = '';
  bool _isConnected = false;

  DaemonClient({this.host = '127.0.0.1', this.port = 9274});

  /// Stream of JSON-RPC notifications (e.g., progress updates)
  Stream<Map<String, dynamic>> get notifications =>
      _notificationController.stream;

  /// Stream of connection status changes
  Stream<bool> get connectionStatus => _connectionController.stream;

  /// Whether currently connected to the daemon
  bool get isConnected => _isConnected;

  /// Connect to the daemon
  Future<bool> connect() async {
    try {
      _socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 5));

      _isConnected = true;
      _connectionController.add(true);

      // Listen for responses (Socket stream provides Uint8List data)
      _socket!.listen(
        (Uint8List data) {
          _onData(utf8.decode(data));
        },
        onError: _onError,
        onDone: _onDone,
      );

      debugPrint('Connected to daemon at $host:$port');
      return true;
    } catch (e) {
      debugPrint('Failed to connect to daemon: $e');
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  /// Disconnect from the daemon
  Future<void> disconnect() async {
    _isConnected = false;
    _connectionController.add(false);

    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;

    // Reject all pending requests
    for (final completer in _pendingRequests.values) {
      completer.completeError('Disconnected from daemon');
    }
    _pendingRequests.clear();
    _buffer = '';
  }

  /// Send a JSON-RPC method call and await the result
  Future<dynamic> call(String method, [Map<String, dynamic>? params]) async {
    if (!_isConnected || _socket == null) {
      throw StateError('Not connected to daemon');
    }

    final id = ++_requestId;
    final request = {
      'jsonrpc': '2.0',
      'method': method,
      'params': params ?? {},
      'id': id,
    };

    final completer = Completer<dynamic>();
    _pendingRequests[id] = completer;

    final jsonStr = '${jsonEncode(request)}\n';
    _socket!.write(jsonStr);

    // Timeout after 20 minutes (1200s) because Wine prefix creation/downloads can take a long time
    return completer.future.timeout(
      const Duration(seconds: 1200),
      onTimeout: () {
        _pendingRequests.remove(id);
        throw TimeoutException('Request timed out: $method');
      },
    );
  }

  // ─── High-Level API Methods ─────────────────────────────────────

  /// List all installed apps
  Future<List<Map<String, dynamic>>> listApps() async {
    final result = await call('list_apps');
    return (result as List).cast<Map<String, dynamic>>();
  }

  /// Get details of a specific app
  Future<Map<String, dynamic>> getApp(String appId) async {
    final result = await call('get_app', {'app_id': appId});
    return result as Map<String, dynamic>;
  }

  /// Install a new app
  Future<Map<String, dynamic>> installApp({
    required String displayName,
    required String exePath,
    String architecture = 'win64',
    String wineVersion = 'stable',
  }) async {
    final result = await call('install_app', {
      'display_name': displayName,
      'exe_path': exePath,
      'architecture': architecture,
      'wine_version': wineVersion,
    });
    return result as Map<String, dynamic>;
  }

  /// Update an app's configuration
  Future<Map<String, dynamic>> updateApp(String appId, Map<String, dynamic> updates) async {
    final result = await call('update_app', {
      'app_id': appId,
      'updates': updates,
    });
    return result as Map<String, dynamic>;
  }

  /// Launch an installed app
  Future<Map<String, dynamic>> launchApp(String appId) async {
    final result = await call('launch_app', {'app_id': appId});
    return result as Map<String, dynamic>;
  }

  /// Delete/uninstall an app
  Future<Map<String, dynamic>> deleteApp(String appId) async {
    final result = await call('delete_app', {'app_id': appId});
    return result as Map<String, dynamic>;
  }

  /// Get Wine version info
  Future<Map<String, dynamic>> getWineInfo() async {
    final result = await call('get_wine_info');
    return result as Map<String, dynamic>;
  }

  /// Get daemon status
  Future<Map<String, dynamic>> getStatus() async {
    final result = await call('get_status');
    return result as Map<String, dynamic>;
  }

  // ─── Phase 3 API Methods ───────────────────────────────────────

  /// Analyze logs for an app and get fix suggestions
  Future<List<Map<String, dynamic>>> analyzeLogs(String appId) async {
    final result = await call('analyze_logs', {'app_id': appId});
    return (result as List).cast<Map<String, dynamic>>();
  }

  /// Apply a suggested fix
  Future<Map<String, dynamic>> applyFix(String appId, Map<String, dynamic> fixAction) async {
    final result = await call('apply_fix', {
      'app_id': appId,
      'fix_action': fixAction,
    });
    return result as Map<String, dynamic>;
  }

  /// Sync compatibility database
  Future<Map<String, dynamic>> syncCompatDb() async {
    final result = await call('sync_compat_db');
    return result as Map<String, dynamic>;
  }

  /// Submit a user report
  Future<Map<String, dynamic>> submitReport({
    required String appId,
    required String status,
    String description = '',
  }) async {
    final result = await call('submit_report', {
      'app_id': appId,
      'status': status,
      'description': description,
    });
    return result as Map<String, dynamic>;
  }

  // ─── Phase 4 API Methods ───────────────────────────────────────

  /// Get status of the Micro-VM engine
  Future<Map<String, dynamic>> getVmStatus() async {
    final result = await call('get_vm_status');
    return result as Map<String, dynamic>;
  }

  /// Manually start the Micro-VM
  Future<Map<String, dynamic>> startVm() async {
    final result = await call('start_vm');
    return result as Map<String, dynamic>;
  }

  /// Manually suspend/stop the Micro-VM
  Future<Map<String, dynamic>> stopVm() async {
    final result = await call('stop_vm');
    return result as Map<String, dynamic>;
  }

  /// Start background download/verify of the VM base image
  Future<Map<String, dynamic>> ensureVmImage() async {
    final result = await call('ensure_vm_image');
    return result as Map<String, dynamic>;
  }

  // ─── Internal Socket Handling ──────────────────────────────────

  void _onData(String data) {
    _buffer += data;

    // Process complete lines
    while (_buffer.contains('\n')) {
      final index = _buffer.indexOf('\n');
      final line = _buffer.substring(0, index).trim();
      _buffer = _buffer.substring(index + 1);

      if (line.isEmpty) continue;

      try {
        final response = jsonDecode(line) as Map<String, dynamic>;
        _handleResponse(response);
      } catch (e) {
        debugPrint('Failed to parse daemon response: $e');
      }
    }
  }

  void _handleResponse(Map<String, dynamic> response) {
    final id = response['id'];

    if (id == null) {
      // This is a notification (no id = notification in JSON-RPC)
      _notificationController.add(response);
      return;
    }

    final completer = _pendingRequests.remove(id);
    if (completer == null) {
      debugPrint('Received response for unknown request ID: $id');
      return;
    }

    if (response.containsKey('error')) {
      final error = response['error'] as Map<String, dynamic>;
      completer.completeError(
        Exception('${error['message']} (code: ${error['code']})'),
      );
    } else {
      completer.complete(response['result']);
    }
  }

  void _onError(dynamic error) {
    debugPrint('Socket error: $error');
    _handleDisconnect();
  }

  void _onDone() {
    debugPrint('Socket closed by daemon');
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _isConnected = false;
    _connectionController.add(false);
    _socket = null;

    for (final completer in _pendingRequests.values) {
      completer.completeError('Disconnected from daemon');
    }
    _pendingRequests.clear();
    _buffer = '';
  }

  /// Dispose all resources
  void dispose() {
    disconnect();
    _notificationController.close();
    _connectionController.close();
  }
}
