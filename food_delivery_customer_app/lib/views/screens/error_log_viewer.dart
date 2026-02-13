import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_customer_app/services/error_logger_service.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ErrorLogViewer extends StatelessWidget {
  const ErrorLogViewer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final errorLogger = Get.find<ErrorLoggerService>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text(
          'Error Debug Logs',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => _shareLogsAsFile(errorLogger),
            tooltip: 'Share Logs File',
          ),
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.white),
            onPressed: () => _exportLogs(errorLogger),
            tooltip: 'Copy to Clipboard',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onPressed: () => _confirmClearLogs(errorLogger),
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Obx(() {
        final logs = errorLogger.errorLogs;

        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Colors.green.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No errors logged',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your app is running smoothly!',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildStatsHeader(errorLogger),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return _buildLogCard(log);
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStatsHeader(ErrorLoggerService errorLogger) {
    final severityCounts = errorLogger.getErrorCountsBySeverity();
    final sourceCounts = errorLogger.getErrorCountsBySource();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Error Statistics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  'Critical',
                  severityCounts[ErrorSeverity.critical] ?? 0,
                  Colors.red.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatChip(
                  'Errors',
                  severityCounts[ErrorSeverity.error] ?? 0,
                  Colors.orange.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatChip(
                  'Warnings',
                  severityCounts[ErrorSeverity.warning] ?? 0,
                  Colors.amber.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(ErrorLogEntry log) {
    final severityColor = _getSeverityColor(log.severity);
    final icon = _getSeverityIcon(log.severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF2D2D2D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: severityColor.withOpacity(0.3), width: 1),
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: severityColor.withOpacity(0.1),
          highlightColor: severityColor.withOpacity(0.05),
        ),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: severityColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: severityColor, size: 20),
          ),
          title: Text(
            log.message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                _buildChip(log.sourceLabel, severityColor),
                const SizedBox(width: 8),
                Text(
                  log.formattedTimestamp,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (log.details != null) ...[
                    _buildDetailSection('Details', log.details!),
                    const SizedBox(height: 12),
                  ],
                  if (log.metadata != null && log.metadata!.isNotEmpty) ...[
                    _buildMetadataSection(log.metadata!),
                    const SizedBox(height: 12),
                  ],
                  if (log.stackTrace != null) ...[
                    _buildDetailSection('Stack Trace', log.stackTrace!),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          'Copy Details',
                          Icons.copy,
                          () => _copyLogDetails(log),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          'Copy All',
                          Icons.content_copy,
                          () => _copyFullLog(log),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: SelectableText(
            content,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataSection(Map<String, dynamic> metadata) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Metadata',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: metadata.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(
                  '${entry.key}: ${entry.value}',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.1),
        foregroundColor: Colors.white70,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
      ),
    );
  }

  Color _getSeverityColor(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return Colors.blue;
      case ErrorSeverity.warning:
        return Colors.amber;
      case ErrorSeverity.error:
        return Colors.orange;
      case ErrorSeverity.critical:
        return Colors.red;
    }
  }

  IconData _getSeverityIcon(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return Icons.info_outline;
      case ErrorSeverity.warning:
        return Icons.warning_amber_rounded;
      case ErrorSeverity.error:
        return Icons.error_outline;
      case ErrorSeverity.critical:
        return Icons.dangerous;
    }
  }

  void _copyLogDetails(ErrorLogEntry log) {
    final details =
        '''
Error: ${log.message}
Source: ${log.sourceLabel}
Time: ${log.formattedTimestamp}
${log.details != null ? '\nDetails:\n${log.details}' : ''}
${log.metadata != null ? '\nMetadata:\n${log.metadata}' : ''}
''';
    Clipboard.setData(ClipboardData(text: details));
    Get.snackbar(
      'Copied',
      'Error details copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.shade700,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(10),
    );
  }

  void _copyFullLog(ErrorLogEntry log) {
    final fullLog =
        '''
Error Log Entry
===============
ID: ${log.id}
Severity: ${log.severityLabel}
Source: ${log.sourceLabel}
Timestamp: ${log.formattedTimestamp}

Message:
${log.message}

${log.details != null ? 'Details:\n${log.details}\n\n' : ''}
${log.metadata != null ? 'Metadata:\n${log.metadata}\n\n' : ''}
${log.stackTrace != null ? 'Stack Trace:\n${log.stackTrace}\n' : ''}
''';
    Clipboard.setData(ClipboardData(text: fullLog));
    Get.snackbar(
      'Copied',
      'Full log entry copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.shade700,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(10),
    );
  }

  void _exportLogs(ErrorLoggerService errorLogger) {
    final logs = errorLogger.exportLogs();
    Clipboard.setData(ClipboardData(text: logs));
    Get.snackbar(
      'Copied',
      'All logs copied to clipboard (JSON format)',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.shade700,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(10),
    );
  }

  Future<void> _shareLogsAsFile(ErrorLoggerService errorLogger) async {
    try {
      // Get the error logs in JSON format
      final logs = errorLogger.exportLogs();

      // Get the temporary directory
      final directory = await getTemporaryDirectory();

      // Create a file name with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'error_logs_$timestamp.json';
      final filePath = '${directory.path}/$fileName';

      // Write the logs to the file
      final file = File(filePath);
      await file.writeAsString(logs);

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Error Logs - $timestamp',
        text: 'Error logs exported from Fudgo',
      );

      Get.snackbar(
        'Shared',
        'Error logs file shared successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(10),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to share logs: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(10),
      );
    }
  }

  void _confirmClearLogs(ErrorLoggerService errorLogger) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text(
          'Clear All Logs?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently delete all error logs. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              errorLogger.clearLogs();
              Get.back();
              Get.snackbar(
                'Cleared',
                'All error logs have been cleared',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.green.shade700,
                colorText: Colors.white,
                duration: const Duration(seconds: 2),
                margin: const EdgeInsets.all(10),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
