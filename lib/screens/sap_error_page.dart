import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/firebaseDataManagement.dart';
import '../models/class.dart';

class SapErrorPage extends StatefulWidget {
  final String errorHeader;  // e.g., "500 Internal Server Error"
  final String detailText;   // e.g., "System error"
  final String serverTime;   // e.g., "2026-03-01 12:42:19"
  final String url;
  final VoidCallback? onRetry;
  final VoidCallback? onReload;
  final VoidCallback? onExit;

  const SapErrorPage({
    super.key,
    required this.errorHeader,
    required this.detailText,
    required this.serverTime,
    required this.url,
    this.onRetry,
    this.onReload,
    this.onExit,
  });

  @override
  State<SapErrorPage> createState() => _SapErrorPageState();
}

class _SapErrorPageState extends State<SapErrorPage> {
  @override
  void initState() {
    super.initState();
    // Log SAP error to Firestore
    final statusCode = _extractStatusCode();
    FirebaseDataManagement.writeError(
      errorType: ErrorType.sapError,
      errorDescription: widget.detailText,
      errorTitle: widget.errorHeader,
      httpStatusCode: statusCode,
      httpStatusMessage: widget.errorHeader,
      url: widget.url,
      serverTime: widget.serverTime,
    );
  }

  int _extractStatusCode() {
    // Extract status code from header like "500 Internal Server Error"
    final match = RegExp(r'(\d{3})').firstMatch(widget.errorHeader);
    return match != null ? int.tryParse(match.group(1)!) ?? 500 : 500;
  }

  Color _getErrorColor() {
    final statusCode = _extractStatusCode();
    if (statusCode >= 500) {
      return Colors.red;
    } else if (statusCode >= 400) {
      return Colors.orange;
    }
    return Colors.grey;
  }

  bool _isSessionTimeout() {
    // Check for session no longer exists error
    return widget.detailText.toLowerCase().contains('session no longer exists');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusCode = _extractStatusCode();
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // SAP Logo
                Image.asset(
                  'assets/images/sap_logo.png',
                  width: 80,
                  height: 80,
                ),
                const SizedBox(height: 16),
                
                // SAP Server Error badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.sapServerError,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // HTTP Status code badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getErrorColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getErrorColor(), width: 2),
                  ),
                  child: Text(
                    'HTTP $statusCode',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getErrorColor(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Error header (e.g., "500 Internal Server Error")
                Text(
                  widget.errorHeader,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Detail text (e.g., "System error")
                if (widget.detailText.isNotEmpty) ...[
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
                            Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Text(
                              l10n.errorDetails,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          widget.detailText,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Server time
                if (widget.serverTime.isNotEmpty) ...[
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
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              l10n.serverTime,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          widget.serverTime,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Action buttons - responsive layout based on screen dimensions
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useHorizontalLayout = constraints.maxWidth > 600 || 
                                                MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
                    
                    final isSessionTimeout = _isSessionTimeout();
                    
                    if (!useHorizontalLayout) {
                      // Portrait/narrow: Stack buttons vertically
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: ElevatedButton.icon(
                              onPressed: isSessionTimeout ? null : widget.onRetry,
                              icon: const Icon(Icons.refresh),
                              label: Text(l10n.retry),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                backgroundColor: Colors.lightGreen,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                disabledForegroundColor: Colors.grey.shade500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: OutlinedButton.icon(
                              onPressed: widget.onReload,
                              icon: const Icon(Icons.restart_alt),
                              label: Text(l10n.reload),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                side: BorderSide(color: Colors.blue.shade400, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: ElevatedButton.icon(
                              onPressed: widget.onExit,
                              icon: const Icon(Icons.home),
                              label: Text(l10n.quit),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Landscape/wide: Show buttons in a row
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: isSessionTimeout ? null : widget.onRetry,
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.retry),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              backgroundColor: Colors.lightGreen,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: widget.onReload,
                            icon: const Icon(Icons.restart_alt),
                            label: Text(l10n.reload),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              side: BorderSide(color: Colors.blue.shade400, width: 2),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: widget.onExit,
                            icon: const Icon(Icons.home),
                            label: Text(l10n.quit),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),
                
                // URL information (with scrolling)
                Container(
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxHeight: 80),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.link, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            l10n.urlLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SelectableText(
                            widget.url,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade800,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // SAP Copyright footer
                Text(
                  '® SAP SE',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
