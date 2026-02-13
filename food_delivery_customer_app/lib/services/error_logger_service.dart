import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';

/// Error severity levels
enum ErrorSeverity {
  info,
  warning,
  error,
  critical,
}

/// Error source for tracking where errors originate
enum ErrorSource {
  googleSignIn,
  googleApi,
  backendApi,
  authentication,
  network,
  storage,
  unknown,
}

/// Error log entry model
class ErrorLogEntry {
  final String id;
  final DateTime timestamp;
  final ErrorSeverity severity;
  final ErrorSource source;
  final String message;
  final String? details;
  final String? stackTrace;
  final Map<String, dynamic>? metadata;

  ErrorLogEntry({
    required this.id,
    required this.timestamp,
    required this.severity,
    required this.source,
    required this.message,
    this.details,
    this.stackTrace,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'severity': severity.toString(),
        'source': source.toString(),
        'message': message,
        'details': details,
        'stackTrace': stackTrace,
        'metadata': metadata,
      };

  factory ErrorLogEntry.fromJson(Map<String, dynamic> json) => ErrorLogEntry(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        severity: ErrorSeverity.values.firstWhere(
          (e) => e.toString() == json['severity'],
          orElse: () => ErrorSeverity.error,
        ),
        source: ErrorSource.values.firstWhere(
          (e) => e.toString() == json['source'],
          orElse: () => ErrorSource.unknown,
        ),
        message: json['message'] as String,
        details: json['details'] as String?,
        stackTrace: json['stackTrace'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );

  String get formattedTimestamp =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp.toLocal());

  String get severityLabel {
    switch (severity) {
      case ErrorSeverity.info:
        return 'INFO';
      case ErrorSeverity.warning:
        return 'WARNING';
      case ErrorSeverity.error:
        return 'ERROR';
      case ErrorSeverity.critical:
        return 'CRITICAL';
    }
  }

  String get sourceLabel {
    switch (source) {
      case ErrorSource.googleSignIn:
        return 'Google Sign-In';
      case ErrorSource.googleApi:
        return 'Google API';
      case ErrorSource.backendApi:
        return 'Backend API';
      case ErrorSource.authentication:
        return 'Authentication';
      case ErrorSource.network:
        return 'Network';
      case ErrorSource.storage:
        return 'Storage';
      case ErrorSource.unknown:
        return 'Unknown';
    }
  }
}

/// Centralized error logging service
class ErrorLoggerService extends GetxService {
  static const String _storageKey = 'error_logs';
  static const int _maxLogEntries = 100;

  final GetStorage _storage = GetStorage();
  final RxList<ErrorLogEntry> _errorLogs = <ErrorLogEntry>[].obs;

  List<ErrorLogEntry> get errorLogs => _errorLogs;

  @override
  void onInit() {
    super.onInit();
    _loadLogs();
  }

  /// Load error logs from storage
  void _loadLogs() {
    try {
      final storedLogs = _storage.read<List>(_storageKey);
      if (storedLogs != null) {
        _errorLogs.value = storedLogs
            .map((log) => ErrorLogEntry.fromJson(
                Map<String, dynamic>.from(log as Map)))
            .toList();
        debugPrint('📋 Loaded ${_errorLogs.length} error logs from storage');
      }
    } catch (e) {
      debugPrint('❌ Failed to load error logs: $e');
    }
  }

  /// Save error logs to storage
  Future<void> _saveLogs() async {
    try {
      final logsJson = _errorLogs.map((log) => log.toJson()).toList();
      await _storage.write(_storageKey, logsJson);
    } catch (e) {
      debugPrint('❌ Failed to save error logs: $e');
    }
  }

  /// Log an error with context
  Future<void> logError({
    required ErrorSeverity severity,
    required ErrorSource source,
    required String message,
    String? details,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) async {
    final entry = ErrorLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      severity: severity,
      source: source,
      message: message,
      details: details ?? error?.toString(),
      stackTrace: stackTrace?.toString(),
      metadata: metadata,
    );

    _errorLogs.insert(0, entry);

    // Keep only the last N entries
    if (_errorLogs.length > _maxLogEntries) {
      _errorLogs.removeRange(_maxLogEntries, _errorLogs.length);
    }

    await _saveLogs();

    // Console logging with emoji indicators
    final emoji = _getSeverityEmoji(severity);
    final sourceTag = '[${entry.sourceLabel}]';
    debugPrint('$emoji $sourceTag $message');
    if (details != null) {
      debugPrint('   Details: $details');
    }
    if (error != null) {
      debugPrint('   Error: $error');
    }
    if (metadata != null) {
      debugPrint('   Metadata: ${jsonEncode(metadata)}');
    }
  }

  /// Log Google Sign-in error
  Future<void> logGoogleSignInError({
    required String message,
    String? details,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) async {
    await logError(
      severity: ErrorSeverity.error,
      source: ErrorSource.googleSignIn,
      message: message,
      details: details,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
    );
  }

  /// Log Google API error
  Future<void> logGoogleApiError({
    required String message,
    String? details,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) async {
    await logError(
      severity: ErrorSeverity.error,
      source: ErrorSource.googleApi,
      message: message,
      details: details,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
    );
  }

  /// Log Backend API error with request/response details
  Future<void> logBackendError({
    required String message,
    String? endpoint,
    int? statusCode,
    String? requestBody,
    String? responseBody,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    final metadata = <String, dynamic>{};
    if (endpoint != null) metadata['endpoint'] = endpoint;
    if (statusCode != null) metadata['statusCode'] = statusCode;
    if (requestBody != null) metadata['requestBody'] = requestBody;
    if (responseBody != null) metadata['responseBody'] = responseBody;

    await logError(
      severity: statusCode != null && statusCode >= 500
          ? ErrorSeverity.critical
          : ErrorSeverity.error,
      source: ErrorSource.backendApi,
      message: message,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata.isNotEmpty ? metadata : null,
    );
  }

  /// Log authentication flow steps (info level)
  Future<void> logAuthInfo(String message, {Map<String, dynamic>? metadata}) async {
    await logError(
      severity: ErrorSeverity.info,
      source: ErrorSource.authentication,
      message: message,
      metadata: metadata,
    );
  }

  /// Log authentication warning
  Future<void> logAuthWarning(String message, {Map<String, dynamic>? metadata}) async {
    await logError(
      severity: ErrorSeverity.warning,
      source: ErrorSource.authentication,
      message: message,
      metadata: metadata,
    );
  }

  /// Log network error
  Future<void> logNetworkError({
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    await logError(
      severity: ErrorSeverity.error,
      source: ErrorSource.network,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Get logs filtered by source
  List<ErrorLogEntry> getLogsBySource(ErrorSource source) {
    return _errorLogs.where((log) => log.source == source).toList();
  }

  /// Get logs filtered by severity
  List<ErrorLogEntry> getLogsBySeverity(ErrorSeverity severity) {
    return _errorLogs.where((log) => log.severity == severity).toList();
  }

  /// Get recent errors (last N)
  List<ErrorLogEntry> getRecentErrors([int count = 10]) {
    return _errorLogs.take(count).toList();
  }

  /// Clear all logs
  Future<void> clearLogs() async {
    _errorLogs.clear();
    await _storage.remove(_storageKey);
    debugPrint('🗑️ All error logs cleared');
  }

  /// Export logs as JSON string
  String exportLogs() {
    final logsJson = _errorLogs.map((log) => log.toJson()).toList();
    return jsonEncode(logsJson);
  }

  /// Get severity emoji for console logging
  String _getSeverityEmoji(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return 'ℹ️';
      case ErrorSeverity.warning:
        return '⚠️';
      case ErrorSeverity.error:
        return '❌';
      case ErrorSeverity.critical:
        return '🔥';
    }
  }

  /// Get count of errors by severity
  Map<ErrorSeverity, int> getErrorCountsBySeverity() {
    final counts = <ErrorSeverity, int>{};
    for (final severity in ErrorSeverity.values) {
      counts[severity] = _errorLogs.where((log) => log.severity == severity).length;
    }
    return counts;
  }

  /// Get count of errors by source
  Map<ErrorSource, int> getErrorCountsBySource() {
    final counts = <ErrorSource, int>{};
    for (final source in ErrorSource.values) {
      counts[source] = _errorLogs.where((log) => log.source == source).length;
    }
    return counts;
  }
}
