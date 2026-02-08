import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../utils/logger.dart';
import '../widgets/battery_indicator.dart';

class NetworkStatusScreen extends StatefulWidget {
  const NetworkStatusScreen({super.key});

  @override
  State<NetworkStatusScreen> createState() => _NetworkStatusScreenState();
}

class _NetworkStatusScreenState extends State<NetworkStatusScreen> {
  static const platform = MethodChannel('devicegate.app/shortcut');
  Map<String, dynamic>? _wifiInfo;
  Map<String, dynamic>? _websiteStatus;
  Map<String, dynamic>? _speedTest;
  Timer? _networkCheckTimer;
  bool _isCheckingWebsite = false;
  bool _isResettingInternet = false;
  bool _isTestingSpeed = false;
  final String _testUrl = 'https://www.google.com'; // Default test URL

  @override
  void initState() {
    super.initState();
    // Set up method call handler for progress updates
    platform.setMethodCallHandler(_handleMethodCall);
    _fetchWifiInfo();
    _checkWebsiteStatus(); // Check internet status immediately
    _startNetworkCheckTimer();
    // Don't auto-start - let user click refresh button to start test
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'speedTestProgress') {
      final data = Map<String, dynamic>.from(call.arguments as Map);
      if (mounted) {
        setState(() {
          _speedTest = data;
          _speedTest!['timestamp'] = DateTime.now().millisecondsSinceEpoch;
          _speedTest!['secondsAgo'] = 0;
          // Check if test is complete
          if (data['isComplete'] == true) {
            _isTestingSpeed = false;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _stopNetworkCheckTimer();
    super.dispose();
  }

  Future<void> _fetchWifiInfo() async {
    try {
      final wifiInfo = await platform.invokeMethod('getWifiInfo');
      log('WiFi info received: $wifiInfo');
      if (mounted) {
        setState(() {
          if (wifiInfo is Map) {
            _wifiInfo = Map<String, dynamic>.from(wifiInfo);
            log('WiFi info set: currentNetwork=${_wifiInfo!['currentNetwork']}, savedNetworks=${_wifiInfo!['savedNetworks']}');
          } else {
            log('WiFi info is not a Map, type: ${wifiInfo.runtimeType}');
          }
        });
      }
    } catch (e) {
      log('Error fetching WiFi info: $e');
      if (mounted) {
        setState(() {
          _wifiInfo = {}; // Set empty map on error so we don't show spinner forever
        });
      }
    }
  }

  void _startNetworkCheckTimer() {
    _networkCheckTimer?.cancel();
    _networkCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _fetchWifiInfo();
        if (!_isCheckingWebsite) {
          _checkWebsiteStatus();
        }
        // Update secondsAgo for speed test
        if (_speedTest != null && _speedTest!['timestamp'] != null) {
          final timestamp = _speedTest!['timestamp'] as int;
          final secondsAgo = ((DateTime.now().millisecondsSinceEpoch - timestamp) / 1000).round();
          setState(() {
            _speedTest!['secondsAgo'] = secondsAgo;
          });
        }
      }
    });
  }

  Future<void> _checkWebsiteStatus() async {
    if (_isCheckingWebsite) return;
    
    _isCheckingWebsite = true;
    try {
      final status = await platform.invokeMethod('checkWebsiteStatus', {
        'url': _testUrl,
      });
      
      if (mounted) {
        setState(() {
          if (status is Map) {
            _websiteStatus = Map<String, dynamic>.from(status);
          }
        });
      }
    } catch (e) {
      log('Error checking website status: $e');
    } finally {
      _isCheckingWebsite = false;
    }
  }

  void _stopNetworkCheckTimer() {
    _networkCheckTimer?.cancel();
    _networkCheckTimer = null;
  }

  Future<void> _startSpeedTest() async {
    if (_isTestingSpeed) return;
    
    setState(() {
      _isTestingSpeed = true;
      _speedTest = {
        'downloadSpeed': 0.0,
        'isComplete': false,
      }; // Initialize with 0 speed
    });
    
    try {
      // This just starts the test - results come via callback
      await platform.invokeMethod('testInternetSpeed');
    } catch (e) {
      log('Error testing internet speed: $e');
      if (mounted) {
        setState(() {
          _speedTest = {
            'downloadSpeed': 0.0,
            'error': e.toString(),
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'secondsAgo': 0,
            'isComplete': true,
          };
          _isTestingSpeed = false;
        });
      }
    }
  }

  Future<void> _resetInternet() async {
    setState(() {
      _isResettingInternet = true;
    });
    
    // Animate for 2 seconds before the blocking call
    for (int i = 0; i < 40; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    try {
      log('Attempting to reset internet connection');
      await platform.invokeMethod('resetInternet');
      
      // Animate for 2 seconds after the reset
      for (int i = 0; i < 40; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      log('Error resetting internet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec de la réinitialisation d\'Internet : $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResettingInternet = false;
        });
      }
    }
  }

  Widget _buildNetworkStatus(dynamic network) {
    if (network == null || network is! Map) {
      return const SizedBox.shrink();
    }

    final networkMap = Map<String, dynamic>.from(network as Map);
    final ssid = networkMap['ssid'] ?? 'Unknown';
    final status = networkMap['status'] ?? 'unknown';
    final isDisconnected = status == 'disconnected';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDisconnected ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDisconnected ? Colors.red.shade200 : Colors.green.shade200,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDisconnected ? Icons.wifi_off : Icons.wifi,
            size: 40,
            color: isDisconnected ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDisconnected ? 'Déconnecté' : ssid,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDisconnected ? Colors.red.shade800 : Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isDisconnected ? 'Aucune connexion WiFi' : 'Connecté',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDisconnected ? Colors.red.shade600 : Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (!isDisconnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Actif',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSavedNetworkItem(dynamic network) {
    if (network == null || network is! Map) {
      return const SizedBox.shrink();
    }

    final networkMap = Map<String, dynamic>.from(network as Map);
    final isConnected = networkMap['status'] == 'connected';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isConnected ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConnected ? Colors.blue.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.wifi : Icons.wifi_lock,
            size: 20,
            color: isConnected ? Colors.blue : Colors.grey.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              networkMap['ssid'] ?? 'Unknown',
              style: TextStyle(
                fontSize: 14,
                color: isConnected ? Colors.blue.shade800 : Colors.grey.shade700,
                fontWeight: isConnected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Connecté',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatIpAddress(int ip) {
    return '${ip & 0xff}.${(ip >> 8) & 0xff}.${(ip >> 16) & 0xff}.${(ip >> 24) & 0xff}';
  }

  Widget _buildInfoRow(String label, dynamic value, {bool isHighlight = false}) {
    final String displayValue = value is int ? value.toString() : value.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isHighlight ? 14 : 13,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                color: isHighlight ? Colors.blue.shade800 : Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                fontSize: isHighlight ? 14 : 13,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                color: isHighlight ? Colors.blue.shade900 : Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedGauge(double speed) {
    // Speed ranges:
    // 0-10: Very slow (red)
    // 10-25: Slow (orange)
    // 25-50: Average (yellow)
    // 50-100: Good (light green)
    // 100+: Excellent (green)
    
    final double percentage = (speed / 100).clamp(0.0, 1.0);
    final Color speedColor;
    final String quality;
    
    if (speed >= 100) {
      speedColor = Colors.green;
      quality = 'Excellent';
    } else if (speed >= 50) {
      speedColor = Colors.lightGreen;
      quality = 'Bon';
    } else if (speed >= 25) {
      speedColor = Colors.orange;
      quality = 'Moyen';
    } else if (speed >= 10) {
      speedColor = Colors.deepOrange;
      quality = 'Lent';
    } else if (speed > 0) {
      speedColor = Colors.red;
      quality = 'Très lent';
    } else {
      // During initial testing or no data
      speedColor = Colors.grey.shade600;
      quality = _isTestingSpeed ? 'Test...' : '';
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          tween: Tween<double>(
            begin: 0,
            end: speed,
          ),
          builder: (context, animatedSpeed, child) {
            final animatedPercentage = (animatedSpeed / 100).clamp(0.0, 1.0);
            return Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: (_isTestingSpeed && animatedSpeed == 0) ? null : animatedPercentage,
                    strokeWidth: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(speedColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      animatedSpeed.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: speedColor.withOpacity(_isTestingSpeed ? 0.6 : 1.0),
                      ),
                    ),
                    Text(
                      'Mbps',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade700.withOpacity(_isTestingSpeed ? 0.6 : 1.0),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          quality,
          style: TextStyle(
            fontSize: 10,
            color: speedColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSignalRow(int rssi) {
    // Signal quality based on dBm:
    // -30 to -50: Excellent (green)
    // -50 to -60: Very good (light green)
    // -60 to -67: Good (yellow-green)
    // -67 to -70: Fair (orange)
    // -70 to -80: Poor (red-orange)
    // -80 to -90: Very poor (red)
    
    final Color signalColor;
    final String quality;
    
    if (rssi >= -50) {
      signalColor = Colors.green;
      quality = 'Excellent';
    } else if (rssi >= -60) {
      signalColor = Colors.lightGreen;
      quality = 'Très bon';
    } else if (rssi >= -67) {
      signalColor = Colors.lime;
      quality = 'Bon';
    } else if (rssi >= -70) {
      signalColor = Colors.orange;
      quality = 'Moyen';
    } else if (rssi >= -80) {
      signalColor = Colors.deepOrange;
      quality = 'Faible';
    } else {
      signalColor = Colors.red;
      quality = 'Très faible';
    }
    
    // Calculate percentage for bar (from -90 to -30)
    final double percentage = ((rssi + 90) / 60).clamp(0.0, 1.0);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              'Signal',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$rssi dBm ($quality)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: signalColor,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.orange,
                        Colors.yellow,
                        Colors.lightGreen,
                        Colors.green,
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: percentage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Positioned(
                        left: percentage * MediaQuery.of(context).size.width * 0.3,
                        child: Container(
                          width: 3,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network'),
        backgroundColor: const Color.fromRGBO(51, 61, 71, 1),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: const [
          BatteryIndicator(),
        ],
      ),
      body: _wifiInfo == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    try {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT COLUMN
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // WiFi Connection Status
                  if (_wifiInfo!['currentNetwork'] != null) ...[
                    Text(
                      'Connexion WiFi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNetworkStatus(_wifiInfo!['currentNetwork']),
                    const SizedBox(height: 24),
                  ],

                  // Saved Networks
                  if (_wifiInfo!['savedNetworks'] != null && (_wifiInfo!['savedNetworks'] as List).isNotEmpty) ...[
                    Text(
                      'Réseaux enregistrés',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...(_wifiInfo!['savedNetworks'] as List).map((network) {
                      return _buildSavedNetworkItem(network);
                    }),
                    const SizedBox(height: 24),
                  ],

                  // Internet Status
                  Text(
                    'État Internet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final websiteCanConnect = _websiteStatus?['canConnect'] == true;
                      final websiteIsSuccess = _websiteStatus?['isSuccess'] == true;
                      final websiteError = _websiteStatus?['error'] as String?;
                      
                      final Color bgColor;
                      final Color borderColor;
                      final Color iconColor;
                      final Color textColor;
                      final IconData icon;
                      final String title;
                      final String subtitle;
                      
                      if (websiteIsSuccess && websiteCanConnect) {
                        bgColor = Colors.green.shade50;
                        borderColor = Colors.green.shade200;
                        iconColor = Colors.green;
                        textColor = Colors.green.shade800;
                        icon = Icons.cloud_done;
                        title = 'Internet OK';
                        subtitle = 'Connecté';
                      } else if (websiteError == 'connection_refused' || 
                                 websiteError == 'socket_timeout' || 
                                 websiteError == 'unknown_host' ||
                                 websiteError == 'http_error') {
                        bgColor = Colors.orange.shade50;
                        borderColor = Colors.orange.shade200;
                        iconColor = Colors.orange;
                        textColor = Colors.orange.shade800;
                        icon = Icons.cloud_off;
                        title = 'Erreur du site web';
                        subtitle = _websiteStatus?['errorMessage'] ?? 'Le site est inaccessible';
                      } else {
                        bgColor = Colors.red.shade50;
                        borderColor = Colors.red.shade200;
                        iconColor = Colors.red;
                        textColor = Colors.red.shade800;
                        icon = Icons.cloud_off;
                        title = 'Pas d\'Internet';
                        subtitle = 'Connexion impossible';
                      }
                      
                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor, width: 2),
                            ),
                            child: Row(
                              children: [
                                Icon(icon, size: 32, color: iconColor),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        subtitle,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Internet Speed Gauge - always show speed value, even during testing
                                Column(
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Gauge icon with label below
                                        Column(
                                          children: [
                                            Icon(
                                              Icons.speed,
                                              size: 40,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Internet\nSpeed',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 16),
                                        // Gauge with refresh button
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Always show gauge with live speed value
                                            if (_speedTest != null && _speedTest!['downloadSpeed'] != null)
                                              _buildSpeedGauge(_speedTest!['downloadSpeed'] ?? 0)
                                            else
                                              _buildSpeedGauge(0), // Show 0 if no test yet
                                            // Refresh button - always visible, disabled when testing
                                            const SizedBox(width: 8),
                                            IconButton(
                                              onPressed: _isTestingSpeed ? null : _startSpeedTest,
                                              icon: Icon(
                                                Icons.refresh,
                                                size: 24,
                                                color: _isTestingSpeed ? Colors.grey.shade400 : Colors.blue.shade600,
                                              ),
                                              tooltip: _isTestingSpeed ? 'Test en cours...' : 'Relancer le test',
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                          ],
                        ),
                      ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Reset Internet Button
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _isResettingInternet ? null : _resetInternet,
                      icon: _isResettingInternet 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.wifi_off, size: 20),
                      label: Text(
                        _isResettingInternet ? 'Réinitialisation...' : 'Réinitialiser Internet',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.orange.shade300,
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 16),
            
            // RIGHT COLUMN
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Access Point Identification (Antenna Information)
                  if (_wifiInfo!['currentNetwork'] != null && _wifiInfo!['currentNetwork']['status'] != 'disconnected') ...[
                    Row(
                      children: [
                        Icon(Icons.router, color: Colors.grey.shade700, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Identification de l\'antenne/point d\'accès',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200, width: 2),
                      ),
                      child: Column(
                        children: [
                          if (_wifiInfo!['currentNetwork']['bssid'] != null)
                            _buildInfoRow('BSSID (MAC Antenne)', _wifiInfo!['currentNetwork']['bssid'].toString(), isHighlight: true),
                          if (_wifiInfo!['currentNetwork']['routerManufacturer'] != null)
                            _buildInfoRow('Fabricant', _wifiInfo!['currentNetwork']['routerManufacturer'].toString(), isHighlight: true),
                          if (_wifiInfo!['currentNetwork']['gateway'] != null)
                            _buildInfoRow('Passerelle (IP Routeur)', _wifiInfo!['currentNetwork']['gateway'].toString(), isHighlight: true),
                          if (_wifiInfo!['currentNetwork']['channel'] != null)
                            _buildInfoRow('Canal WiFi', 'Canal ${_wifiInfo!['currentNetwork']['channel']}'),
                          if (_wifiInfo!['currentNetwork']['channelWidth'] != null)
                            _buildInfoRow('Largeur canal', _wifiInfo!['currentNetwork']['channelWidth'].toString()),
                          if (_wifiInfo!['currentNetwork']['frequencyBand'] != null)
                            _buildInfoRow('Bande', _wifiInfo!['currentNetwork']['frequencyBand'].toString()),
                          if (_wifiInfo!['currentNetwork']['frequency'] != null)
                            _buildInfoRow('Fréquence', '${_wifiInfo!['currentNetwork']['frequency']} MHz'),
                          if (_wifiInfo!['currentNetwork']['rssi'] != null)
                            _buildSignalRow(_wifiInfo!['currentNetwork']['rssi']),
                          if (_wifiInfo!['currentNetwork']['securityType'] != null)
                            _buildInfoRow('Sécurité', _wifiInfo!['currentNetwork']['securityType'].toString()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey.shade700, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Informations de connexion',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          if (_wifiInfo!['currentNetwork']['wifiStandard'] != null)
                            _buildInfoRow('Standard WiFi', _wifiInfo!['currentNetwork']['wifiStandard'].toString()),
                          if (_wifiInfo!['currentNetwork']['linkSpeed'] != null)
                            _buildInfoRow('Vitesse actuelle', '${_wifiInfo!['currentNetwork']['linkSpeed']} Mbps'),
                          if (_wifiInfo!['currentNetwork']['txLinkSpeed'] != null)
                            _buildInfoRow('Vitesse TX (Upload)', '${_wifiInfo!['currentNetwork']['txLinkSpeed']} Mbps'),
                          if (_wifiInfo!['currentNetwork']['rxLinkSpeed'] != null)
                            _buildInfoRow('Vitesse RX (Download)', '${_wifiInfo!['currentNetwork']['rxLinkSpeed']} Mbps'),
                          if (_wifiInfo!['currentNetwork']['maxLinkSpeed'] != null)
                            _buildInfoRow('Vitesse max', '${_wifiInfo!['currentNetwork']['maxLinkSpeed']} Mbps'),
                          if (_wifiInfo!['currentNetwork']['ipAddress'] != null)
                            _buildInfoRow('Adresse IP (Tablette)', _formatIpAddress(_wifiInfo!['currentNetwork']['ipAddress'])),
                          if (_wifiInfo!['currentNetwork']['dns'] != null)
                            _buildInfoRow('DNS', _wifiInfo!['currentNetwork']['dns'].toString()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      log('Error building network status screen: $e');
      log('Stack trace: $stackTrace');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Erreur d\'affichage',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }
  }
}
