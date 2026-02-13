import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';

/// A reusable widget that shows when there's no internet connection.
class NoConnectionWidget extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? message;

  const NoConnectionWidget({super.key, this.onRetry, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Internet Connection',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: TColor.primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message ?? 'Please check your connection and try again.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TColor.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A reusable widget for displaying user-friendly error messages
/// without exposing URLs or backend error details.
class ErrorDisplayWidget extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorDisplayWidget({
    super.key,
    this.errorMessage,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: Colors.orange[400]),
            ),
            const SizedBox(height: 24),
            Text(
              'Something Went Wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: TColor.primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _sanitizeError(errorMessage),
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TColor.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Cleans error messages to never show URLs, status codes, or technical details
  static String _sanitizeError(String? raw) {
    if (raw == null || raw.isEmpty) {
      return 'We couldn\'t load the data. Please try again.';
    }

    final lower = raw.toLowerCase();

    // Connection errors
    if (lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('connection timed out') ||
        lower.contains('network is unreachable') ||
        lower.contains('failed host lookup')) {
      return 'Unable to connect to the server. Please check your internet connection.';
    }

    // Timeout errors
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'The request took too long. Please try again.';
    }

    // Auth errors
    if (lower.contains('session expired') || lower.contains('login again')) {
      return 'Your session has expired. Please log in again.';
    }

    // Server errors
    if (lower.contains('status: 5') || lower.contains('internal server')) {
      return 'Our servers are experiencing issues. Please try again later.';
    }

    // Strip technical details (URLs, status codes, exception prefixes)
    String cleaned = raw;
    // Remove "Exception: " prefix
    cleaned = cleaned.replaceAll(
      RegExp(r'^Exception:\s*', caseSensitive: false),
      '',
    );
    // Remove URLs
    cleaned = cleaned.replaceAll(RegExp(r'https?://[^\s]+'), '');
    // Remove status codes like (Status: 404)
    cleaned = cleaned.replaceAll(RegExp(r'\(Status:\s*\d+\)'), '');
    // Remove anything that looks like a stack trace
    cleaned = cleaned.replaceAll(RegExp(r'#\d+\s+.*'), '');

    cleaned = cleaned.trim();
    if (cleaned.isEmpty) {
      return 'Something went wrong. Please try again.';
    }

    return cleaned;
  }
}

/// Utility to sanitize error strings for snackbars, etc.
String sanitizeErrorMessage(String? raw) {
  return ErrorDisplayWidget._sanitizeError(raw);
}
