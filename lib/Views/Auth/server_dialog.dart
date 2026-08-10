// server_connect_dialog.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaitoonpro/Features/Other/toast.dart';
import 'package:zaitoonpro/Features/Widgets/outline_button.dart';
import 'package:zaitoonpro/Features/Widgets/textfield_entitled.dart';
import 'package:zaitoonpro/Localizations/l10n/translations/app_localizations.dart';
import 'dart:io';
import '../../Features/Other/responsive.dart';
import '../../Services/api_services.dart';

class ServerConnectDialog extends StatelessWidget {
  const ServerConnectDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: const _MobileServerConnect(),
      tablet: const _TabletServerConnect(),
      desktop: const _DesktopServerConnect(),
    );
  }
}

// ============= DESKTOP VIEW =============
class _DesktopServerConnect extends StatefulWidget {
  const _DesktopServerConnect();

  @override
  State<_DesktopServerConnect> createState() => _DesktopServerConnectState();
}

class _DesktopServerConnectState extends State<_DesktopServerConnect> {
  final TextEditingController ipController = TextEditingController();
  bool loading = false;
  bool autoFinding = false;
  String? _scanStatus;
  String? _myIP;
  bool _isServer = false;
  String? _currentServerIP;
  bool _connectedToLocalhost = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => loading = true);

    try {
      final ip = await _getLocalIP();
      final isServer = await ApiServices().isServerDevice();

      // Read directly from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedIP = prefs.getString('server_ip');

      // Check the actual base URL to determine connection state
      final baseUrl = ApiServices().baseUrl;
      final isLocalhost = !baseUrl.contains('192.168') &&
          !baseUrl.contains('10.') &&
          (baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1'));

      if (mounted) {
        setState(() {
          _myIP = ip;
          _isServer = isServer;
          _connectedToLocalhost = isLocalhost;

          // If we have a saved IP, we're connected to a remote server
          if (!isLocalhost && savedIP != null && savedIP.isNotEmpty) {
            _currentServerIP = savedIP;
          } else if (isLocalhost) {
            _currentServerIP = null;
          }
        });

        // Set text field
        if (isLocalhost) {
          ipController.text = '';
        } else if (_currentServerIP != null && _currentServerIP!.isNotEmpty) {
          ipController.text = _currentServerIP!;
        }
      }

      debugPrint('Dialog initialized - isLocalhost: $isLocalhost, savedIP: $savedIP, currentServerIP: $_currentServerIP');
    } catch (e) {
      debugPrint('Error initializing server dialog: $e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<String?> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list();

      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();

        if (name.contains('virtual') ||
            name.contains('vmware') ||
            name.contains('virtualbox') ||
            name.contains('bluetooth') ||
            name.contains('loopback') ||
            name.contains('hyper-v') ||
            name.contains('wsl') ||
            name.contains('docker') ||
            name.contains('vpn') ||
            name.contains('tunnel')) {
          continue;
        }

        if (name.contains('wi-fi') ||
            name.contains('wifi') ||
            name.contains('wireless') ||
            name.contains('wlan') ||
            name.contains('ethernet') ||
            name.contains('lan') ||
            name.contains('eth')) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 &&
                !addr.isLoopback &&
                !addr.address.startsWith('169.254') &&
                !addr.address.startsWith('0.')) {
              return addr.address;
            }
          }
        }
      }

      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('virtual') ||
            name.contains('vmware') ||
            name.contains('virtualbox') ||
            name.contains('bluetooth') ||
            name.contains('loopback') ||
            name.contains('hyper-v') ||
            name.contains('wsl') ||
            name.contains('docker') ||
            name.contains('vpn') ||
            name.contains('tunnel')) {
          continue;
        }

        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              !addr.address.startsWith('169.254') &&
              !addr.address.startsWith('0.')) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }

  Future<bool> _tryConnect(String ip) async {
    final urls = [
      'http://$ip/rapi/get_ip.php',
      'http://$ip:80/rapi/get_ip.php',
    ];

    for (final url in urls) {
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 2),
          receiveTimeout: const Duration(seconds: 2),
          validateStatus: (status) => status != null && status < 500,
        ));

        final response = await dio.get(url);

        if (response.statusCode == 200 && response.data is Map) {
          final data = response.data;
          if (data['success'] == true) {
            final connectedIP = data['ip'] ?? ip;
            final isLocalConnection = (connectedIP == 'localhost' ||
                connectedIP == '127.0.0.1' ||
                connectedIP == '::1');

            await ApiServices().setServerIP(
              isLocalConnection ? 'localhost' : ip,
              port: '80',
            );

            debugPrint('Connected! IP: $ip, isLocal: $isLocalConnection, savedIP will be: ${isLocalConnection ? "localhost" : ip}');

            if (mounted) {
              setState(() {
                _currentServerIP = isLocalConnection ? 'localhost' : ip;
                _connectedToLocalhost = isLocalConnection;
                ipController.text = isLocalConnection ? '' : ip;
              });

              ToastManager.show(
                context: context,
                title: "Connected",
                message: isLocalConnection ? "Connected to localhost" : "Connected to $ip",
                type: ToastType.success,
              );

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pop(context, true);
                }
              });
            }
            return true;
          }
        }
      } catch (e) {
        continue;
      }
    }
    return false;
  }

  Future<void> _connectToLocalhost() async {
    setState(() {
      loading = true;
      _scanStatus = AppLocalizations.of(context)!.connecting;
    });

    try {
      final connected = await _tryConnect('localhost');
      if (connected) return;

      final connected2 = await _tryConnect('127.0.0.1');
      if (connected2) return;

      if (mounted) {
        ToastManager.show(
          context: context,
          title: AppLocalizations.of(context)!.connectionFailed,
          message: AppLocalizations.of(context)!.connectionFailedMessage,
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          _scanStatus = null;
        });
      }
    }
  }

  Future<void> _quickConnect() async {
    setState(() {
      autoFinding = true;
      loading = true;
      _scanStatus = AppLocalizations.of(context)!.searching;
    });

    try {
      if (_isServer) {
        setState(() => _scanStatus = 'Checking localhost...');
        final connected = await _tryConnect('localhost');
        if (connected) return;
      }

      final savedIP = await ApiServices().getSavedServerIP();
      if (savedIP != null && savedIP.isNotEmpty) {
        setState(() => _scanStatus = 'Trying saved server: $savedIP');
        final connected = await _tryConnect(savedIP);
        if (connected) return;
      }

      if (_myIP != null && !_connectedToLocalhost) {
        setState(() => _scanStatus = 'Checking this device: $_myIP');
        final connected = await _tryConnect(_myIP!);
        if (connected) return;
      }

      final localIP = _myIP ?? await _getLocalIP();

      if (localIP != null) {
        final parts = localIP.split('.');
        if (parts.length == 4) {
          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

          final subnetsToTry = <String>[subnet];
          if (subnet != '192.168.0') subnetsToTry.add('192.168.0');
          if (subnet != '192.168.1') subnetsToTry.add('192.168.1');
          if (subnet != '10.0.0') subnetsToTry.add('10.0.0');

          for (final currentSubnet in subnetsToTry) {
            final priorityIPs = <String>[
              '$currentSubnet.109',
              '$currentSubnet.100',
              '$currentSubnet.50',
              '$currentSubnet.10',
              '$currentSubnet.20',
              '$currentSubnet.30',
              '$currentSubnet.1',
            ];

            for (final ip in priorityIPs) {
              if (ip == localIP) continue;
              setState(() => _scanStatus = 'Checking $ip...');
              final connected = await _tryConnect(ip);
              if (connected) return;
            }

            for (int i = 2; i <= 254; i++) {
              final ip = '$currentSubnet.$i';
              if (priorityIPs.contains(ip) || ip == localIP) continue;

              setState(() => _scanStatus = 'Scanning $ip...');
              final connected = await _tryConnect(ip);
              if (connected) return;

              await Future.delayed(const Duration(milliseconds: 50));
            }
          }
        }
      }

      if (mounted) {
        setState(() => _scanStatus = null);
        ToastManager.show(
          context: context,
          title: AppLocalizations.of(context)!.noServerFound,
          message: AppLocalizations.of(context)!.noServerFoundMessage,
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanStatus = null);
        ToastManager.show(
          context: context,
          title: "Scan Failed",
          message: "An error occurred while scanning the network.",
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          autoFinding = false;
          loading = false;
          _scanStatus = null;
        });
      }
    }
  }

  Future<void> connect() async {
    final ip = ipController.text.trim();

    if (ip.isEmpty) {
      ToastManager.show(
        context: context,
        title: "IP Required",
        message: "Please enter the server address.",
        type: ToastType.warning,
      );
      return;
    }

    if (ip.toLowerCase() == 'localhost' || ip == '127.0.0.1') {
      await _connectToLocalhost();
      return;
    }

    setState(() => loading = true);

    try {
      final connected = await _tryConnect(ip);

      if (!connected && mounted) {
        ToastManager.show(
          context: context,
          title: AppLocalizations.of(context)!.connectionFailed,
          message: "$ip | ${AppLocalizations.of(context)!.noServerFoundMessage}",
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        ToastManager.show(
          context: context,
          title: AppLocalizations.of(context)!.connectionFailed,
          message: "Failed to connect to $ip",
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => loading = true);

    try {
      await ApiServices().setServerIP('localhost');

      if (mounted) {
        setState(() {
          _currentServerIP = null;
          _connectedToLocalhost = true;
          ipController.text = '';
        });

        ToastManager.show(
          context: context,
          title: AppLocalizations.of(context)!.connected,
          message: AppLocalizations.of(context)!.connectedToLocal,
          type: ToastType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        ToastManager.show(
          context: context,
          title: "Error",
          message: "Failed to reset connection.",
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.45,
        constraints: const BoxConstraints(maxWidth: 550, minWidth: 420),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(theme, locale),
            const SizedBox(height: 16),

            // Current Connection Status
            _buildConnectionStatus(),
            const SizedBox(height: 16),

            // This device info
            if (_myIP != null) _buildDeviceInfo(),
            const SizedBox(height: 16),

            // Manual IP Input with Connect button
            _buildManualInput(),
            const SizedBox(height: 16),

            // Quick Connect Options
            _buildConnectionOptions(),
            const SizedBox(height: 16),

          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AppLocalizations locale) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.dns, color: theme.primaryColor, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            locale.connectToServer,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 22),
          onPressed: () => Navigator.pop(context, false),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildConnectionStatus() {
    // Check if connected to a remote server
    if (!_connectedToLocalhost && _currentServerIP != null && _currentServerIP!.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),  // Green for active connection
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.link, size: 25, color: Colors.green.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.connected,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$_currentServerIP',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: loading ? null : _disconnect,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                AppLocalizations.of(context)!.disconnect,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      );
    }

    // Connected to localhost (server device)
    if (_connectedToLocalhost && _isServer) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 20, color: Colors.green.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.connectedTo,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Not connected
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.link_off, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Text(
            AppLocalizations.of(context)!.notConnected,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppLocalizations.of(context)!.deviceIp} | $_myIP',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 5),
                if (_isServer)
                  Text(
                    AppLocalizations.of(context)!.serverIp,
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade600),
                  ),
              ],
            ),
          ),
          Icon(Icons.computer_rounded, size: 25, color: Colors.blue.shade700),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildManualInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 3,
          child: ZTextFieldEntitled(
            title: AppLocalizations.of(context)!.remoteServerIp,
            hint: _currentServerIP ?? _myIP,
            controller: ipController,
            isEnabled: !loading,
            onChanged: (_) => setState(() {}),
            onSubmit: (e) {
              if (!loading && ipController.text.trim().isNotEmpty) {
                connect();
              }
            },
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          flex: 1,
          child: ZOutlineButton(
            icon: Icons.settings_remote,
            isActive: true,
            height: 49,
            onPressed: (loading || ipController.text.trim().isEmpty) ? null : connect,
            label: loading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : Text(
              AppLocalizations.of(context)!.connect,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.quickConnect,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            // Localhost button
            if (_isServer)
              _buildActionChip(
                icon: Icons.computer,
                label: _connectedToLocalhost ? '${AppLocalizations.of(context)!.localhost} ✓' : AppLocalizations.of(context)!.localhost,
                onTap: _connectToLocalhost,
                isLoading: loading,
                isActive: _connectedToLocalhost,
              ),

            // Auto Find button
            _buildActionChip(
              icon: Icons.wifi_find,
              label: autoFinding ? AppLocalizations.of(context)!.searching : AppLocalizations.of(context)!.autoFind,
              onTap: _quickConnect,
              isLoading: loading || autoFinding,
              isActive: false,
            ),

            // This Device button
            if (_myIP != null)
              _buildActionChip(
                icon: Icons.phone_android,
                label: AppLocalizations.of(context)!.connectToDevice,
                onTap: () {
                  if (_myIP != null) {
                    ipController.text = _myIP!;
                    setState(() {});
                  }
                },
                isLoading: false,
                isActive: false,
              ),
          ],
        ),
        if (_scanStatus != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _scanStatus!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isLoading,
    required bool isActive,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isActive
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            width: isActive ? 1 : 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                icon,
                size: 16,
                color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade600,
              ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    ipController.dispose();
    super.dispose();
  }
}

// ============= MOBILE VIEW =============
class _MobileServerConnect extends StatefulWidget {
  const _MobileServerConnect();

  @override
  State<_MobileServerConnect> createState() => _MobileServerConnectState();
}

class _MobileServerConnectState extends State<_MobileServerConnect> {
  final TextEditingController ipController = TextEditingController();
  bool loading = false;
  bool autoFinding = false;
  String? _scanStatus;
  String? _myIP;
  bool _isServer = false;
  String? _currentServerIP;
  bool _connectedToLocalhost = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => loading = true);
    try {
      final ip = await _getLocalIP();
      final isServer = await ApiServices().isServerDevice();
      final currentIP = await ApiServices().getSavedServerIP();
      final isLocalhost = ApiServices().isLocalhost;

      if (mounted) {
        setState(() {
          _myIP = ip;
          _isServer = isServer;
          _currentServerIP = currentIP;
          _connectedToLocalhost = isLocalhost;
        });
        if (isLocalhost) {
          ipController.text = '';
        } else if (currentIP != null && currentIP.isNotEmpty) {
          ipController.text = currentIP;
        }
      }
    } catch (e) {
      // Ignore
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<String?> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('virtual') || name.contains('vmware') || name.contains('virtualbox') ||
            name.contains('bluetooth') || name.contains('loopback') || name.contains('hyper-v') ||
            name.contains('wsl') || name.contains('docker') || name.contains('vpn') || name.contains('tunnel')) {
          continue;
        }
        if (name.contains('wi-fi') || name.contains('wifi') || name.contains('wireless') || name.contains('wlan') ||
            name.contains('ethernet') || name.contains('lan') || name.contains('eth')) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback &&
                !addr.address.startsWith('169.254') && !addr.address.startsWith('0.')) {
              return addr.address;
            }
          }
        }
      }
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('virtual') || name.contains('vmware') || name.contains('virtualbox') ||
            name.contains('bluetooth') || name.contains('loopback') || name.contains('hyper-v') ||
            name.contains('wsl') || name.contains('docker') || name.contains('vpn') || name.contains('tunnel')) {
          continue;
        }
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback &&
              !addr.address.startsWith('169.254') && !addr.address.startsWith('0.')) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }

  Future<bool> _tryConnect(String ip) async {
    final urls = ['http://$ip/rapi/get_ip.php', 'http://$ip:80/rapi/get_ip.php'];
    for (final url in urls) {
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 2),
          receiveTimeout: const Duration(seconds: 2),
          validateStatus: (status) => status != null && status < 500,
        ));
        final response = await dio.get(url);
        if (response.statusCode == 200 && response.data is Map) {
          final data = response.data;
          if (data['success'] == true) {
            final connectedIP = data['ip'] ?? ip;
            final isLocalConnection = (connectedIP == 'localhost' || connectedIP == '127.0.0.1' || connectedIP == '::1');
            await ApiServices().setServerIP(isLocalConnection ? 'localhost' : ip, port: '80');
            if (mounted) {
              setState(() {
                _currentServerIP = isLocalConnection ? 'localhost' : ip;
                _connectedToLocalhost = isLocalConnection;
                ipController.text = isLocalConnection ? '' : ip;
              });
              ToastManager.show(
                context: context,
                title: "Connected",
                message: isLocalConnection ? "Connected to localhost" : "Connected to $ip",
                type: ToastType.success,
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.pop(context, true);
              });
            }
            return true;
          }
        }
      } catch (e) {
        continue;
      }
    }
    return false;
  }

  Future<void> _connectToLocalhost() async {
    setState(() { loading = true; _scanStatus = 'Connecting to localhost...'; });
    try {
      if (await _tryConnect('localhost')) return;
      if (await _tryConnect('127.0.0.1')) return;
      if (mounted) {
        ToastManager.show(
          context: context,
          title: "Connection Failed",
          message: "Could not connect to localhost. Is XAMPP running?",
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() { loading = false; _scanStatus = null; });
    }
  }

  Future<void> _quickConnect() async {
    setState(() { autoFinding = true; loading = true; _scanStatus = 'Searching for servers...'; });
    try {
      if (_isServer && await _tryConnect('localhost')) return;
      final savedIP = await ApiServices().getSavedServerIP();
      if (savedIP != null && savedIP.isNotEmpty && await _tryConnect(savedIP)) return;
      if (_myIP != null && !_connectedToLocalhost && await _tryConnect(_myIP!)) return;
      final localIP = _myIP ?? await _getLocalIP();
      if (localIP != null) {
        final parts = localIP.split('.');
        if (parts.length == 4) {
          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
          final subnetsToTry = <String>[subnet];
          if (subnet != '192.168.0') subnetsToTry.add('192.168.0');
          if (subnet != '192.168.1') subnetsToTry.add('192.168.1');
          if (subnet != '10.0.0') subnetsToTry.add('10.0.0');
          for (final currentSubnet in subnetsToTry) {
            final priorityIPs = ['$currentSubnet.109', '$currentSubnet.100', '$currentSubnet.50', '$currentSubnet.10', '$currentSubnet.20', '$currentSubnet.30', '$currentSubnet.1'];
            for (final ip in priorityIPs) {
              if (ip == localIP) continue;
              setState(() => _scanStatus = 'Checking $ip...');
              if (await _tryConnect(ip)) return;
            }
            for (int i = 2; i <= 254; i++) {
              final ip = '$currentSubnet.$i';
              if (priorityIPs.contains(ip) || ip == localIP) continue;
              setState(() => _scanStatus = 'Scanning $ip...');
              if (await _tryConnect(ip)) return;
              await Future.delayed(const Duration(milliseconds: 50));
            }
          }
        }
      }
      if (mounted) {
        setState(() => _scanStatus = null);
        ToastManager.show(
          context: context,
          title: "No Server Found",
          message: "Could not find any server. Please check if the server is running and try again.",
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanStatus = null);
        ToastManager.show(
          context: context,
          title: "Scan Failed",
          message: "An error occurred while scanning the network.",
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() { autoFinding = false; loading = false; _scanStatus = null; });
    }
  }

  Future<void> connect() async {
    final ip = ipController.text.trim();
    if (ip.isEmpty) {
      ToastManager.show(
        context: context,
        title: "IP Required",
        message: "Please enter the server address.",
        type: ToastType.warning,
      );
      return;
    }
    if (ip.toLowerCase() == 'localhost' || ip == '127.0.0.1') {
      await _connectToLocalhost();
      return;
    }
    setState(() => loading = true);
    try {
      if (!await _tryConnect(ip) && mounted) {
        ToastManager.show(
          context: context,
          title: "Connection Failed",
          message: "Could not connect to $ip. Make sure the server is running.",
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        ToastManager.show(
          context: context,
          title: "Connection Failed",
          message: "Failed to connect to $ip",
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => loading = true);

    try {
      // Reset to localhost
      await ApiServices().setServerIP('localhost');

      if (mounted) {
        setState(() {
          _currentServerIP = null;
          _connectedToLocalhost = true;
          ipController.text = '';
        });

        ToastManager.show(
          context: context,
          title: "Disconnected",
          message: "Reset to localhost connection.",
          type: ToastType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        ToastManager.show(
          context: context,
          title: "Error",
          message: "Failed to reset connection.",
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.92,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.dns, size: 20, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      locale.connectToServer,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context, false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Status
              _buildConnectionStatus(),
              const SizedBox(height: 12),

              // Manual IP Input
              TextField(
                controller: ipController,
                decoration: InputDecoration(
                  hintText: 'Enter server IP',
                  prefixIcon: const Icon(Icons.computer, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                  suffixIcon: ipController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () { ipController.clear(); setState(() {}); },
                  )
                      : null,
                ),
                enabled: !loading,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Quick Actions - Mobile Stacked
              Column(
                children: [
                  if (_isServer)
                    _buildActionChipMobile(
                      icon: Icons.computer,
                      label: _connectedToLocalhost ? 'Localhost ✓' : 'Localhost',
                      onTap: _connectToLocalhost,
                      isLoading: loading,
                      isActive: _connectedToLocalhost,
                    ),
                  const SizedBox(height: 6),
                  _buildActionChipMobile(
                    icon: Icons.wifi_find,
                    label: autoFinding ? 'Searching...' : 'Auto Find',
                    onTap: _quickConnect,
                    isLoading: loading || autoFinding,
                    isActive: false,
                  ),
                  if (_myIP != null) ...[
                    const SizedBox(height: 6),
                    _buildActionChipMobile(
                      icon: Icons.phone_android,
                      label: 'This Device',
                      onTap: () {
                        if (_myIP != null) {
                          ipController.text = _myIP!;
                          setState(() {});
                        }
                      },
                      isLoading: false,
                      isActive: false,
                    ),
                  ],
                  const SizedBox(height: 6),
                  _buildActionChipMobile(
                    icon: Icons.save,
                    label: 'Saved IP',
                    onTap: () async {
                      final savedIP = await ApiServices().getSavedServerIP();
                      if (savedIP != null && savedIP.isNotEmpty) {
                        ipController.text = savedIP;
                        setState(() {});
                      }
                    },
                    isLoading: false,
                    isActive: false,
                  ),
                ],
              ),
              if (_scanStatus != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_scanStatus!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: loading ? null : () => Navigator.pop(context, false),
                      child: Text(AppLocalizations.of(context)!.cancel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (loading || ipController.text.trim().isEmpty) ? null : connect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(AppLocalizations.of(context)!.connect),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionChipMobile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isLoading,
    required bool isActive,
  }) {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade200, width: isActive ? 2 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(icon, size: 16, color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    Color color;
    String text;
    IconData icon;

    if (!_connectedToLocalhost && _currentServerIP != null) {
      color = Colors.orange;
      text = 'Connected to $_currentServerIP';
      icon = Icons.link;
    } else if (_connectedToLocalhost && _isServer) {
      color = Colors.green;
      text = 'Connected to localhost';
      icon = Icons.check_circle;
    } else {
      color = Colors.grey;
      text = 'Not connected';
      icon = Icons.link_off;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
          ),
          if (!_connectedToLocalhost && _currentServerIP != null)
            TextButton(
              onPressed: loading ? null : _disconnect,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Disconnect', style: TextStyle(fontSize: 11, color: Colors.red)),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    ipController.dispose();
    super.dispose();
  }
}

// ============= TABLET VIEW =============
class _TabletServerConnect extends StatefulWidget {
  const _TabletServerConnect();

  @override
  State<_TabletServerConnect> createState() => _TabletServerConnectState();
}

class _TabletServerConnectState extends State<_TabletServerConnect> {
  final TextEditingController ipController = TextEditingController();
  bool loading = false;
  bool autoFinding = false;
  String? _scanStatus;
  String? _myIP;
  bool _isServer = false;
  String? _currentServerIP;
  bool _connectedToLocalhost = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => loading = true);

    try {
      final ip = await _getLocalIP();
      final isServer = await ApiServices().isServerDevice();
      final currentIP = await ApiServices().getSavedServerIP();

      // Get the actual connected IP from ApiServices
      final baseUrl = ApiServices().baseUrl;
      final isLocalhost = baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1');

      if (mounted) {
        setState(() {
          _myIP = ip;
          _isServer = isServer;
          _currentServerIP = isLocalhost ? null : (currentIP ?? baseUrl.replaceAll(RegExp(r'^https?://'), '').replaceAll(RegExp(r':\d+$'), '').replaceAll(RegExp(r'/.*$'), ''));
          _connectedToLocalhost = isLocalhost;
        });

        if (isLocalhost) {
          ipController.text = '';
        } else if (_currentServerIP != null && _currentServerIP!.isNotEmpty) {
          ipController.text = _currentServerIP!;
        }
      }
    } catch (e) {
      // Ignore
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<String?> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('virtual') || name.contains('vmware') || name.contains('virtualbox') ||
            name.contains('bluetooth') || name.contains('loopback') || name.contains('hyper-v') ||
            name.contains('wsl') || name.contains('docker') || name.contains('vpn') || name.contains('tunnel')) {
          continue;
        }
        if (name.contains('wi-fi') || name.contains('wifi') || name.contains('wireless') || name.contains('wlan') ||
            name.contains('ethernet') || name.contains('lan') || name.contains('eth')) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback &&
                !addr.address.startsWith('169.254') && !addr.address.startsWith('0.')) {
              return addr.address;
            }
          }
        }
      }
    } catch (e) { /* ignore */ }
    return null;
  }

  Future<bool> _tryConnect(String ip) async {
    final urls = ['http://$ip/rapi/get_ip.php', 'http://$ip:80/rapi/get_ip.php'];
    for (final url in urls) {
      try {
        final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 2), receiveTimeout: const Duration(seconds: 2)));
        final response = await dio.get(url);
        if (response.statusCode == 200 && response.data is Map) {
          final data = response.data;
          if (data['success'] == true) {
            final connectedIP = data['ip'] ?? ip;
            final isLocalConnection = (connectedIP == 'localhost' || connectedIP == '127.0.0.1' || connectedIP == '::1');
            await ApiServices().setServerIP(isLocalConnection ? 'localhost' : ip, port: '80');
            if (mounted) {
              setState(() {
                _currentServerIP = isLocalConnection ? 'localhost' : ip;
                _connectedToLocalhost = isLocalConnection;
                ipController.text = isLocalConnection ? '' : ip;
              });
              ToastManager.show(context: context, title: "Connected", message: isLocalConnection ? "Connected to localhost" : "Connected to $ip", type: ToastType.success);
              WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) Navigator.pop(context, true); });
            }
            return true;
          }
        }
      } catch (e) { continue; }
    }
    return false;
  }

  Future<void> _connectToLocalhost() async {
    setState(() { loading = true; _scanStatus = 'Connecting to localhost...'; });
    try {
      if (await _tryConnect('localhost')) return;
      if (await _tryConnect('127.0.0.1')) return;
      if (mounted) {
        ToastManager.show(context: context, title: "Connection Failed", message: "Could not connect to localhost. Is XAMPP running?", type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() { loading = false; _scanStatus = null; });
    }
  }

  Future<void> _quickConnect() async {
    setState(() { autoFinding = true; loading = true; _scanStatus = 'Searching...'; });
    try {
      if (_isServer && await _tryConnect('localhost')) return;
      final savedIP = await ApiServices().getSavedServerIP();
      if (savedIP != null && savedIP.isNotEmpty && await _tryConnect(savedIP)) return;
      if (_myIP != null && !_connectedToLocalhost && await _tryConnect(_myIP!)) return;
      if (mounted) {
        setState(() => _scanStatus = null);
        ToastManager.show(context: context, title: "No Server Found", message: "Could not find any server.", type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() { autoFinding = false; loading = false; _scanStatus = null; });
    }
  }

  Future<void> connect() async {
    final ip = ipController.text.trim();
    if (ip.isEmpty) {
      ToastManager.show(context: context, title: "Required", message: "Enter server IP address", type: ToastType.warning);
      return;
    }
    if (ip.toLowerCase() == 'localhost' || ip == '127.0.0.1') {
      await _connectToLocalhost();
      return;
    }
    setState(() => loading = true);
    try {
      if (!await _tryConnect(ip) && mounted) {
        ToastManager.show(context: context, title: "Connection Failed", message: "Could not connect to $ip", type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => loading = true);
    try {
      await ApiServices().setServerIP('localhost');
      if (mounted) {
        setState(() { _currentServerIP = null; _connectedToLocalhost = true; ipController.text = ''; });
        ToastManager.show(context: context, title: "Disconnected", message: "Reset to localhost connection.", type: ToastType.info);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.dns, size: 22, color: theme.primaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(locale.connectToServer, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    onPressed: () => Navigator.pop(context, false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status
              _buildConnectionStatus(),
              const SizedBox(height: 16),

              // Manual IP with Connect button
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: ipController,
                      decoration: InputDecoration(
                        hintText: 'Enter server IP',
                        prefixIcon: const Icon(Icons.computer, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        isDense: true,
                        suffixIcon: ipController.text.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { ipController.clear(); setState(() {}); })
                            : null,
                      ),
                      enabled: !loading,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: (loading || ipController.text.trim().isEmpty) ? null : connect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Connect', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quick Actions (Wrap)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_isServer)
                    _buildActionChip(
                      icon: Icons.computer,
                      label: _connectedToLocalhost ? 'Localhost ✓' : 'Localhost',
                      onTap: _connectToLocalhost,
                      isLoading: loading,
                      isActive: _connectedToLocalhost,
                    ),
                  _buildActionChip(
                    icon: Icons.wifi_find,
                    label: autoFinding ? 'Searching...' : 'Auto Find',
                    onTap: _quickConnect,
                    isLoading: loading || autoFinding,
                    isActive: false,
                  ),
                  if (_myIP != null)
                    _buildActionChip(
                      icon: Icons.phone_android,
                      label: 'This Device',
                      onTap: () { if (_myIP != null) { ipController.text = _myIP!; setState(() {}); } },
                      isLoading: false,
                      isActive: false,
                    ),
                  _buildActionChip(
                    icon: Icons.save,
                    label: 'Saved IP',
                    onTap: () async {
                      final savedIP = await ApiServices().getSavedServerIP();
                      if (savedIP != null && savedIP.isNotEmpty) { ipController.text = savedIP; setState(() {}); }
                    },
                    isLoading: false,
                    isActive: false,
                  ),
                ],
              ),
              if (_scanStatus != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_scanStatus!, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: loading ? null : () => Navigator.pop(context, false),
                    child: Text(AppLocalizations.of(context)!.cancel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isLoading,
    required bool isActive,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade200, width: isActive ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(icon, size: 16, color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    Color color;
    String text;
    IconData icon;

    if (!_connectedToLocalhost && _currentServerIP != null) {
      color = Colors.orange;
      text = 'Connected to $_currentServerIP';
      icon = Icons.link;
    } else if (_connectedToLocalhost && _isServer) {
      color = Colors.green;
      text = 'Connected to localhost';
      icon = Icons.check_circle;
    } else {
      color = Colors.grey;
      text = 'Not connected';
      icon = Icons.link_off;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
          ),
          if (!_connectedToLocalhost && _currentServerIP != null)
            TextButton(
              onPressed: loading ? null : _disconnect,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Disconnect', style: TextStyle(fontSize: 12, color: Colors.red)),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    ipController.dispose();
    super.dispose();
  }
}