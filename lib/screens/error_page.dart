import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../generated/l10n/app_localizations.dart';

/// Reusable error page widget that displays error information
/// with Retry and Reload buttons
class ErrorPage extends StatelessWidget {
  final String? errorTitle;
  final String? errorMessage;
  final Object? error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;
  final VoidCallback? onReload;
  final VoidCallback? onExit;
  final bool showTechnicalDetails;

  const ErrorPage({
    super.key,
    this.errorTitle,
    this.errorMessage,
    this.error,
    this.stackTrace,
    this.onRetry,
    this.onReload,
    this.onExit,
    this.showTechnicalDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayTitle = errorTitle ?? l10n.errorOccurred;
    final displayMessage = errorMessage ?? l10n.unexpectedError;
    
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 24),
              Text(
                displayTitle,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                displayMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Technical details section (error message only)
              if (showTechnicalDetails && error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            l10n.technicalDetails,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      Text(
                        l10n.errorLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SelectableText(
                          error.toString(),
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 32),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onRetry != null) ...[
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.retry),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        backgroundColor: Colors.lightGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (onReload != null) ...[
                    OutlinedButton.icon(
                      onPressed: onReload,
                      icon: const Icon(Icons.restart_alt),
                      label: Text(l10n.reload),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        side: BorderSide(color: Colors.blue.shade400, width: 2),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (onExit != null)
                    ElevatedButton.icon(
                      onPressed: onExit,
                      icon: const Icon(Icons.home),
                      label: Text(l10n.quit),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Stack Trace section
              if (showTechnicalDetails && stackTrace != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.stackTrace,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            stackTrace.toString(),
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // App version info
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(
                      '${l10n.version} ${snapshot.data!.version}+${snapshot.data!.buildNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
