import 'package:flutter/material.dart';

class HttpErrorPage extends StatelessWidget {
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

  String _getErrorTitle() {
    switch (statusCode) {
      case 400:
        return 'Requête incorrecte';
      case 401:
        return 'Non autorisé';
      case 403:
        return 'Accès refusé';
      case 404:
        return 'Page introuvable';
      case 500:
        return 'Erreur serveur interne';
      case 502:
        return 'Passerelle incorrecte';
      case 503:
        return 'Service indisponible';
      case 504:
        return 'Délai d\'attente dépassé';
      default:
        return 'Erreur HTTP $statusCode';
    }
  }

  String _getErrorDescription() {
    switch (statusCode) {
      case 400:
        return 'Le serveur ne peut pas traiter la requête en raison d\'une erreur client.';
      case 401:
        return 'Une authentification est requise pour accéder à cette ressource.';
      case 403:
        return 'Vous n\'avez pas la permission d\'accéder à cette ressource.';
      case 404:
        return 'La page demandée n\'existe pas sur le serveur.';
      case 500:
        return 'Le serveur a rencontré une erreur interne et n\'a pas pu traiter la requête.';
      case 502:
        return 'Le serveur a reçu une réponse invalide du serveur en amont.';
      case 503:
        return 'Le serveur est temporairement indisponible, probablement en maintenance.';
      case 504:
        return 'Le serveur n\'a pas reçu de réponse à temps du serveur en amont.';
      default:
        return 'Le serveur a renvoyé un code d\'erreur HTTP $statusCode.';
    }
  }

  IconData _getErrorIcon() {
    switch (statusCode) {
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
    switch (statusCode) {
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
                    'HTTP $statusCode',
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
                  _getErrorTitle(),
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
                  _getErrorDescription(),
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
                            'URL :',
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
                        url,
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
                if (serverMessage != null && serverMessage!.isNotEmpty) ...[
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
                              'Message du serveur :',
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
                          serverMessage!,
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
                          if (onRetry != null) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: ElevatedButton.icon(
                                onPressed: onRetry,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Réessayer'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  backgroundColor: Colors.lightGreen,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (onReload != null) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: OutlinedButton.icon(
                                onPressed: onReload,
                                icon: const Icon(Icons.restart_alt),
                                label: const Text('Recharger'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  side: BorderSide(color: Colors.blue.shade400, width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (onExit != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: ElevatedButton.icon(
                                onPressed: onExit,
                                icon: const Icon(Icons.home),
                                label: const Text('Quitter'),
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
                          if (onRetry != null) ...[
                            ElevatedButton.icon(
                              onPressed: onRetry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
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
                              label: const Text('Recharger'),
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
                              label: const Text('Quitter'),
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
