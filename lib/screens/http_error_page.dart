import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/firebaseDataManagement.dart';
import '../models/class.dart';

class HttpErrorPage extends StatefulWidget {
  final int statusCode;
  final String url;
  final String? serverMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onReload;
  final VoidCallback? onExit;

  const HttpErrorPage({
    super.key,
    required this.statusCode,
    required this.url,
    this.serverMessage,
    this.onRetry,
    this.onReload,
    this.onExit,
  });

  @override
  State<HttpErrorPage> createState() => _HttpErrorPageState();
}

class _HttpErrorPageState extends State<HttpErrorPage> {
  @override
  void initState() {
    super.initState();
    // Log HTTP error to Firestore
    FirebaseDataManagement.writeError(
      errorType: ErrorType.httpError,
      errorDescription: 'HTTP ${widget.statusCode} error',
      httpStatusCode: widget.statusCode,
      httpStatusMessage: _getHttpStatusMessage(widget.statusCode),
      url: widget.url,
      serverMessage: widget.serverMessage ?? '',
    );
  }

  String _getHttpStatusMessage(int statusCode) {
    switch (statusCode) {
      case 400: return 'Bad Request';
      case 401: return 'Unauthorized';
      case 403: return 'Forbidden';
      case 404: return 'Not Found';
      case 500: return 'Internal Server Error';
      case 502: return 'Bad Gateway';
      case 503: return 'Service Unavailable';
      case 504: return 'Gateway Timeout';
      default: return 'HTTP Error $statusCode';
    }
  }

  String _getErrorTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (widget.statusCode) {
      case 400:
        return l10n.httpError400Title;
      case 401:
        return l10n.httpError401Title;
      case 403:
        return l10n.httpError403Title;
      case 404:
        return l10n.httpError404Title;
      case 500:
        return l10n.httpError500Title;
      case 502:
        return l10n.httpError502Title;
      case 503:
        return l10n.httpError503Title;
      case 504:
        return l10n.httpError504Title;
      default:
        return l10n.httpErrorDefaultTitle(widget.statusCode);
    }
  }

  String _getErrorDescription(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (widget.statusCode) {
      case 400:
        return l10n.httpError400Desc;
      case 401:
        return l10n.httpError401Desc;
      case 403:
        return l10n.httpError403Desc;
      case 404:
        return l10n.httpError404Desc;
      case 500:
        return l10n.httpError500Desc;
      case 502:
        return l10n.httpError502Desc;
      case 503:
        return l10n.httpError503Desc;
      case 504:
        return l10n.httpError504Desc;
      default:
        return l10n.httpErrorDefaultDesc(widget.statusCode);
    }
  }

  IconData _getErrorIcon() {
    switch (widget.statusCode) {
      case 404:
        return Icons.search_off;
      case 401:
      case 403:
        return Icons.lock_outline;
      case 500:
      case 502:
      case 503:
      case 504:
        return Icons.dns_outlined;
      default:
        return Icons.error_outline;
    }
  }

  Color _getErrorColor() {
    switch (widget.statusCode) {
      case 401:
      case 403:
        return Colors.orange;
      case 404:
        return Colors.blue;
      case 500:
      case 502:
      case 503:
      case 504:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error icon with status code
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _getErrorColor().withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getErrorIcon(),
                    size: 80,
                    color: _getErrorColor(),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Status code badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getErrorColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getErrorColor(), width: 2),
                  ),
                  child: Text(
                    'HTTP ${widget.statusCode}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getErrorColor(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Error title
                Text(
                  _getErrorTitle(context),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Error description
                Text(
                  _getErrorDescription(context),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // URL information
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
                          Icon(Icons.link, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            l10n.urlLabel,
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
                        widget.url,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Server message (if available)
                if (widget.serverMessage != null && widget.serverMessage!.isNotEmpty) ...[
                  const SizedBox(height: 16),
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
                            Icon(Icons.info_outline, size: 16, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Text(
                              l10n.serverMessage,
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
                          widget.serverMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Action buttons - responsive layout based on screen dimensions
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Use screen width to determine layout
                    // If width > 600, use horizontal layout (landscape or tablet)
                    final useHorizontalLayout = constraints.maxWidth > 600 || 
                                                MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
                    
                    if (!useHorizontalLayout) {
                      // Portrait/narrow: Stack buttons vertically
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.onRetry != null) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: ElevatedButton.icon(
                                onPressed: widget.onRetry,
                                icon: const Icon(Icons.refresh),
                                label: Text(l10n.retryButton),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  backgroundColor: Colors.lightGreen,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (widget.onReload != null) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: OutlinedButton.icon(
                                onPressed: widget.onReload,
                                icon: const Icon(Icons.restart_alt),
                                label: Text(l10n.reloadButton),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  side: BorderSide(color: Colors.blue.shade400, width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (widget.onExit != null)
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
                          if (widget.onRetry != null) ...[
                            ElevatedButton.icon(
                              onPressed: widget.onRetry,
                              icon: const Icon(Icons.refresh),
                              label: Text(l10n.retryButton),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                backgroundColor: Colors.lightGreen,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (widget.onReload != null) ...[
                            OutlinedButton.icon(
                              onPressed: widget.onReload,
                              icon: const Icon(Icons.restart_alt),
                              label: Text(l10n.reloadButton),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                side: BorderSide(color: Colors.blue.shade400, width: 2),
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (widget.onExit != null)
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
