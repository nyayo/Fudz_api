import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Lightweight startup performance tracker.
/// Prints a timing table to the console and persists the last
/// full startup trace so it can be viewed in the Error Log Viewer.
class PerformanceTracker extends GetxService {
  static const String _storageKey = 'perf_startup_trace';

  final Map<String, _TimingEntry> _entries = {};
  final List<String> _completionOrder = [];
  late final DateTime _appStartTime;

  // Reactive summary available in UI
  final RxString lastStartupSummary = ''.obs;
  final RxInt lastStartupMs = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _appStartTime = DateTime.now();
    _loadLastTrace();
  }

  // ── Public API ──────────────────────────────────────────

  /// Call at the START of an operation.
  void start(String label) {
    _entries[label] = _TimingEntry(label: label, startTime: DateTime.now());
    debugPrint('⏱️ START  ➜ $label');
  }

  /// Call at the END of an operation.
  void end(String label, {bool success = true, String? error}) {
    final entry = _entries[label];
    if (entry == null) {
      debugPrint('⚠️ PerformanceTracker.end("$label") called without start');
      return;
    }
    entry.endTime = DateTime.now();
    entry.success = success;
    entry.error = error;
    _completionOrder.add(label);

    final ms = entry.durationMs;
    final icon = success ? '✅' : '❌';
    final slow = ms > 2000 ? ' 🐢 SLOW!' : (ms > 800 ? ' ⚠️' : '');
    debugPrint('$icon END   ➜ $label  (${ms}ms)$slow');
    if (error != null) {
      debugPrint('   Error: $error');
    }
  }

  /// Mark overall startup complete and print summary.
  void finishStartup() {
    final totalMs = DateTime.now().difference(_appStartTime).inMilliseconds;
    lastStartupMs.value = totalMs;

    final buffer = StringBuffer();
    buffer.writeln('');
    buffer.writeln('╔══════════════════════════════════════════════════╗');
    buffer.writeln('║         STARTUP PERFORMANCE REPORT              ║');
    buffer.writeln('╠══════════════════════════════════════════════════╣');
    buffer.writeln('║ Total startup time: ${totalMs}ms');
    buffer.writeln('╠══════════════════════════════════════════════════╣');

    // Sort by start time
    final sorted = _entries.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    for (final entry in sorted) {
      final ms = entry.durationMs;
      final status = entry.endTime == null
          ? '⏳ STILL RUNNING'
          : entry.success
          ? '✅ ${ms}ms'
          : '❌ ${ms}ms FAILED';
      final slow = ms > 2000 ? '  🐢' : (ms > 800 ? '  ⚠️' : '');
      buffer.writeln('║  ${entry.label.padRight(35)} $status$slow');
      if (entry.error != null) {
        buffer.writeln('║    └─ Error: ${entry.error}');
      }
    }

    buffer.writeln('╚══════════════════════════════════════════════════╝');

    final summary = buffer.toString();
    lastStartupSummary.value = summary;
    debugPrint(summary);

    // Persist for Error Log Viewer
    _saveTrace(summary);
  }

  /// Get a map of label → duration for programmatic access.
  Map<String, int> get timings {
    return _entries.map((key, value) => MapEntry(key, value.durationMs));
  }

  /// Identify operations that took longer than [thresholdMs].
  List<String> getSlowOperations({int thresholdMs = 1000}) {
    return _entries.entries
        .where((e) => e.value.durationMs > thresholdMs)
        .map((e) => '${e.key}: ${e.value.durationMs}ms')
        .toList();
  }

  // ── Persistence ─────────────────────────────────────────

  void _loadLastTrace() {
    try {
      final stored = GetStorage().read<String>(_storageKey);
      if (stored != null) {
        lastStartupSummary.value = stored;
      }
    } catch (_) {}
  }

  void _saveTrace(String summary) {
    try {
      GetStorage().write(_storageKey, summary);
    } catch (_) {}
  }
}

class _TimingEntry {
  final String label;
  final DateTime startTime;
  DateTime? endTime;
  bool success;
  String? error;

  _TimingEntry({
    required this.label,
    required this.startTime,
    this.success = true,
    this.error,
  });

  int get durationMs =>
      (endTime ?? DateTime.now()).difference(startTime).inMilliseconds;
}
