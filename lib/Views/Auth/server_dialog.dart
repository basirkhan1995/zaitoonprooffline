// server_connect_dialog.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:zaitoonpro/Features/Other/toast.dart';
import 'package:zaitoonpro/Localizations/l10n/translations/app_localizations.dart';
import 'dart:io';
import '../../Services/api_services.dart';

class ServerConnectDialog extends StatefulWidget {
  const ServerConnectDialog({super.key});

  @override
  State<ServerConnectDialog> createState() => _ServerConnectDialogState();
}

class _ServerConnectDialogState extends State<ServerConnectDialog> {
  final ipController = TextEditingController();
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
      // Get this device's IP first
      final ip = await _getLocalIP();

      // Check if this device can act as a server
      final isServer = await ApiServices().isServerDevice();

      // Get current connection status
      final currentIP = await ApiServices().getSavedServerIP();
      final isLocalhost = ApiServices().isLocalhost;

      if (mounted) {
        setState(() {
          _myIP = ip;
          _isServer = isServer;
          _currentServerIP = currentIP;
          _connectedToLocalhost = isLocalhost;
        });

        // If already connected to a server (including localhost), show current status
        if (isLocalhost) {
          // Already on localhost, but allow changing
          ipController.text = '';
        } else if (currentIP != null && currentIP.isNotEmpty) {
          ipController.text = currentIP;
        }
      }
    } catch (e) {
      // Continue with manual input
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<String?> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list();

      // Priority 1: WiFi or Ethernet
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();

        if (name.contains('virtual') ||
            name.contains('vmware') ||
            name.contains('virtualbox') ||
            name.contains('bluetooth') ||
            name.contains('loopback') ||
            name.contains('local area connection*') ||
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
            name.contains('ethernet') ||
            name.contains('lan')) {

          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 &&
                !addr.isLoopback &&
                !addr.address.startsWith('169.254')) {
              return addr.address;
            }
          }
        }
      }

      // Priority 2: Any non-virtual adapter
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
              !addr.address.startsWith('169.254')) {
            return addr.address;
          }
        }
      }

      // Last resort
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      // Silently fail
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
            // Determine if we're connecting to localhost or remote
            final connectedIP = data['ip'] ?? ip;
            final isLocalConnection = (connectedIP == 'localhost' ||
                connectedIP == '127.0.0.1' ||
                connectedIP == '::1');

            await ApiServices().setServerIP(
                isLocalConnection ? 'localhost' : ip,
                port: '80'
            );

            if (mounted) {
              ipController.text = isLocalConnection ? '' : ip;

              String message;
              if (isLocalConnection) {
                message = 'Connected to localhost (this device)';
              } else {
                message = 'Connected to server at $ip';
              }

              ToastManager.show(
                  context: context,
                  title: "Connected",
                  message: message,
                  type: ToastType.success
              );
              Navigator.pop(context, true);
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
      _scanStatus = 'Connecting to localhost...';
    });

    try {
      final connected = await _tryConnect('localhost');
      if (connected) return;

      // If localhost fails, try 127.0.0.1
      final connected2 = await _tryConnect('127.0.0.1');
      if (connected2) return;

      if (mounted) {
        ToastManager.show(
            context: context,
            title: "Connection Failed",
            message: "Could not connect to localhost. Is XAMPP running?",
            type: ToastType.error
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
      _scanStatus = 'Searching for servers...';
    });

    try {
      // Try localhost first if this device can be a server
      if (_isServer) {
        setState(() => _scanStatus = 'Checking localhost...');
        final connected = await _tryConnect('localhost');
        if (connected) return;
      }

      // Try saved IP next
      final savedIP = await ApiServices().getSavedServerIP();
      if (savedIP != null && savedIP.isNotEmpty) {
        setState(() => _scanStatus = 'Trying saved server: $savedIP');
        final connected = await _tryConnect(savedIP);
        if (connected) return;
      }

      // Try this device's IP (in case we're the server with different config)
      if (_myIP != null && !_connectedToLocalhost) {
        setState(() => _scanStatus = 'Checking this device: $_myIP');
        final connected = await _tryConnect(_myIP!);
        if (connected) return;
      }

      // Scan the network
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
            // Try common server IPs first
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

            // Scan remaining IPs
            for (int i = 2; i <= 254; i++) {
              final ip = '$currentSubnet.$i';
              if (priorityIPs.contains(ip) || ip == localIP) continue;

              setState(() => _scanStatus = 'Scanning $ip...');
              final connected = await _tryConnect(ip);
              if (connected) return;

              // Small delay to prevent overwhelming the network
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
            type: ToastType.error
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanStatus = null);
        ToastManager.show(
            context: context,
            title: "Scan Failed",
            message: "An error occurred while scanning the network.",
            type: ToastType.error
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
          type: ToastType.warning
      );
      return;
    }

    // Handle special cases
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
            title: "Connection Failed",
            message: "Could not connect to $ip. Make sure the server is running.",
            type: ToastType.error
        );
      }
    } catch (e) {
      if (mounted) {
        ToastManager.show(
            context: context,
            title: "Connection Failed",
            message: "Failed to connect to $ip",
            type: ToastType.error
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
            type: ToastType.info
        );
      }
    } catch (e) {
      if (mounted) {
        ToastManager.show(
            context: context,
            title: "Error",
            message: "Failed to reset connection.",
            type: ToastType.error
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(20),
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

              // Current Connection Status
              _buildConnectionStatus(),

              const SizedBox(height: 16),

              // This device info
              if (_myIP != null) _buildDeviceInfo(),

              const SizedBox(height: 16),

              // Connection Options
              _buildConnectionOptions(),

              const SizedBox(height: 16),

              // Manual IP Input
              _buildManualInput(),

              const SizedBox(height: 16),

              // Help box
              _buildHelpBox(),

              const SizedBox(height: 20),

              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    if (!_connectedToLocalhost && _currentServerIP != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.link, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connected to: $_currentServerIP',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'You can switch to another server below',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_connectedToLocalhost && _isServer) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connected to localhost (this device)',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'You can connect to another server if needed',
                    style: TextStyle(fontSize: 11, color: Colors.green.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDeviceInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_android, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'This Device',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'IP: $_myIP',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
          ),
          if (_isServer) ...[
            const SizedBox(height: 4),
            Text(
              '✓ This device can act as a server',
              style: TextStyle(fontSize: 11, color: Colors.blue.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Connect Options:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),

        // Option 1: Connect to Localhost (if this device can be server)
        if (_isServer)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: loading ? null : _connectToLocalhost,
                icon: const Icon(Icons.computer, size: 18),
                label: Text(_connectedToLocalhost ? 'Reconnect to Localhost' : 'Connect to Localhost (This PC)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: _connectedToLocalhost ? Colors.green.shade700 : null,
                  side: BorderSide(color: _connectedToLocalhost ? Colors.green : Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ),

        // Option 2: Auto Find Server
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: loading ? null : _quickConnect,
            icon: autoFinding
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_find, size: 18),
            label: Text(autoFinding ? 'Searching...' : 'Auto Find Server on Network'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),

        if (_scanStatus != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _scanStatus!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildManualInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Or Enter Server IP Manually:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ipController,
                decoration: InputDecoration(
                  hintText: 'e.g. 192.168.0.109 or localhost',
                  prefixIcon: const Icon(Icons.computer, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                  suffixIcon: ipController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      ipController.clear();
                      setState(() {});
                    },
                  )
                      : null,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                enabled: !loading,
                style: const TextStyle(fontSize: 14),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHelpBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Connection Tips:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTip('Use "Connect to Localhost" if this PC is running the Server'),
          _buildTip('Use "Auto Find" to scan network for servers'),
          _buildTip('Enter IP manually if you know the server address'),
          _buildTip('On server PC: Run "ipconfig" in CMD to find IP'),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Disconnect button (only show if connected to remote server)
        if (_currentServerIP != null && !_connectedToLocalhost)
          TextButton(
            onPressed: loading ? null : _disconnect,
            child: const Text('Reset to Localhost', style: TextStyle(color: Colors.red)),
          ),

        const Spacer(),

        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context, false),
          child:  Text(AppLocalizations.of(context)!.cancel),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: (loading || ipController.text.trim().isEmpty) ? null : connect,
          icon: loading
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : const Icon(Icons.link, size: 16),
          label: Text(loading ? AppLocalizations.of(context)!.connecting : AppLocalizations.of(context)!.connect),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    ipController.dispose();
    super.dispose();
  }
}