import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../models/app_model.dart';
import '../providers/app_providers.dart';
import '../widgets/glass_container.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  final WineApp app;

  const DiagnosticsScreen({super.key, required this.app});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  bool _isAnalyzing = true;
  List<Map<String, dynamic>> _fixes = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _analyzeLogs();
  }

  Future<void> _analyzeLogs() async {
    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final daemon = ref.read(daemonClientProvider);
      final fixes = await daemon.analyzeLogs(widget.app.appId);
      setState(() {
        _fixes = fixes;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _applyFix(Map<String, dynamic> fix) async {
    try {
      final daemon = ref.read(daemonClientProvider);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Applying fix: ${fix['description']}...'),
          backgroundColor: AppColors.info,
        ),
      );

      await daemon.applyFix(widget.app.appId, fix['action']);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fix applied successfully! Please try launching the app again.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to apply fix: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _submitReport(String status) async {
    try {
      final daemon = ref.read(daemonClientProvider);
      await daemon.submitReport(
        appId: widget.app.appId,
        status: status,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted! Thank you for your feedback.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: GlassContainer(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Diagnostics: ${widget.app.displayName}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'WineLayer Log Analyzer has scanned the latest crash logs for known patterns.',
                  style: TextStyle(color: AppColors.textTertiary),
                ),
                const SizedBox(height: 24),
                
                // Content
                Expanded(
                  child: _isAnalyzing
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      : _error != null
                          ? Center(
                              child: Text('Error analyzing logs: $_error',
                                  style: const TextStyle(color: AppColors.error)),
                            )
                          : _fixes.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No known crash patterns detected in recent logs.\nIf the app is failing, please submit a report below.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _fixes.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final fix = _fixes[index];
                                    final confidence = (fix['confidence'] as double) * 100;
                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.bgDarkest,
                                        border: Border.all(color: AppColors.glassBorder),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.build_circle, color: AppColors.primary, size: 36),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(fix['description'],
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                Text('Confidence: ${confidence.toStringAsFixed(0)}%',
                                                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => _applyFix(fix),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Apply Fix'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                ),

                const Divider(color: AppColors.glassBorder, height: 48),
                
                // Report Section
                const Text(
                  'Community Feedback',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Does this app work correctly for you? Your feedback improves the global compatibility database.',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _submitReport('working'),
                      icon: const Icon(Icons.thumb_up, color: AppColors.success),
                      label: const Text('Works Perfectly'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _submitReport('broken'),
                      icon: const Icon(Icons.thumb_down, color: AppColors.error),
                      label: const Text('Broken / Crashes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
