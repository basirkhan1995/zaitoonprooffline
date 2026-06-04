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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Get fresh IP every time dialog opens
    await _getMyIP();
    await _loadSavedIP();

    // If this device's IP changed, update the saved IP hint
    if (_myIP != null && _myIP != ipController.text) {
      // Check if current device might be the server
      final isServer = await _checkIfServer(_myIP!);
      if (isServer && mounted) {
        setState(() {
          ipController.text = _myIP!;
        });
      }
    }
  }

  Future<void> _loadSavedIP() async {
    final ip = await ApiServices().getSavedServerIP();
    if (ip != null && ip.isNotEmpty && mounted) {
      ipController.text = ip;
    }
  }

  Future<void> _getMyIP() async {
    final ip = await _getLocalIP();
    if (mounted) {
      setState(() {
        _myIP = ip;
      });
    }
  }

  // Quick check if an IP is running the server
  Future<bool> _checkIfServer(String ip) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 1),
        receiveTimeout: const Duration(seconds: 1),
        validateStatus: (status) => status != null && status < 500,
      ));
      final response = await dio.get('http://$ip/rapi/get_ip.php');
      return response.statusCode == 200;
    } catch (e) {
      return false;
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

  Future<void> _quickConnect() async {
    setState(() {
      autoFinding = true;
      loading = true;
      _scanStatus = 'Detecting network...';
    });

    try {
      // FIRST: Try current device IP (most likely the server if running on this PC)
      final currentIP = await _getLocalIP();
      if (currentIP != null) {
        setState(() => _scanStatus = 'Checking this device: $currentIP');
        final connected = await _tryConnect(currentIP);
        if (connected) return;
      }

      // SECOND: Try saved IP
      final savedIP = await ApiServices().getSavedServerIP();
      if (savedIP != null && savedIP.isNotEmpty && savedIP != currentIP) {
        setState(() => _scanStatus = 'Trying saved server: $savedIP');
        final connected = await _tryConnect(savedIP);
        if (connected) return;
      }

      if (currentIP != null) {
        final parts = currentIP.split('.');
        if (parts.length == 4) {
          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
          final gateway = '$subnet.1';

          // THIRD: Try gateway first (some setups have server on .1)
          if (gateway != currentIP && gateway != savedIP) {
            setState(() => _scanStatus = 'Checking gateway: $gateway');
            final connected = await _tryConnect(gateway);
            if (connected) return;
          }

          // FOURTH: Try different subnets
          final subnetsToTry = <String>[subnet];
          if (subnet != '192.168.0') subnetsToTry.add('192.168.0');
          if (subnet != '192.168.1') subnetsToTry.add('192.168.1');
          if (subnet != '10.0.0') subnetsToTry.add('10.0.0');

          for (final currentSubnet in subnetsToTry) {
            setState(() => _scanStatus = 'Scanning $currentSubnet.x...');

            // Quick scan common IPs
            final commonIPs = [2, 5, 6, 10, 20, 30, 50, 100, 109, 150, 200];
            for (final lastOctet in commonIPs) {
              final ip = '$currentSubnet.$lastOctet';
              if (ip == currentIP || ip == savedIP) continue;

              final connected = await _tryConnect(ip);
              if (connected) return;
            }
          }
        }
      }

      if (mounted) {
        setState(() => _scanStatus = null);
        ToastManager.show(
          context: context,
          title: "No Server Found",
          message: "Make sure XAMPP is running and firewall allows connections",
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanStatus = null);
        ToastManager.show(
          context: context,
          title: "Scan Failed",
          message: "Please try manual entry",
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

  Future<bool> _tryConnect(String ip) async {
    final urls = [
      'http://$ip/rapi/get_ip.php',
      'http://$ip:80/rapi/get_ip.php',
      'http://$ip:8080/rapi/get_ip.php',
    ];

    for (final url in urls) {
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 1),
          receiveTimeout: const Duration(seconds: 1),
          validateStatus: (status) => status != null && status < 500,
        ));

        final response = await dio.get(url);

        if (response.statusCode == 200 && response.data is Map) {
          final data = response.data;
          if (data['success'] == true) {
            final port = Uri.parse(url).port.toString();
            await ApiServices().setServerIP(ip, port: port);

            if (mounted) {
              ipController.text = ip;
              ToastManager.show(
                context: context,
                title: "Connected",
                message: "Server found at $ip",
                type: ToastType.success,
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

  Future<void> connect() async {
    final ip = ipController.text.trim();

    if (ip.isEmpty) {
      ToastManager.show(
        context: context,
        title: "IP Required",
        message: "Please enter the server address",
        type: ToastType.warning,
      );
      return;
    }

    setState(() => loading = true);

    try {
      // Try multiple URLs
      final urls = [
        'http://$ip/rapi/get_ip.php',
        'http://$ip:80/rapi/get_ip.php',
        'http://$ip:8080/rapi/get_ip.php',
      ];

      bool connected = false;

      for (final url in urls) {
        try {
          final dio = Dio(BaseOptions(
            connectTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 3),
            validateStatus: (status) => status != null && status < 500,
          ));

          final response = await dio.get(url);

          if (response.statusCode == 200 && response.data is Map) {
            final data = response.data;
            if (data['success'] == true) {
              final port = Uri.parse(url).port.toString();
              await ApiServices().setServerIP(ip, port: port);

              if (mounted) {
                ToastManager.show(
                  context: context,
                  title: "Connected",
                  message: "Successfully connected to $ip",
                  type: ToastType.success,
                );
                Navigator.pop(context, true);
              }
              connected = true;
              break;
            }
          }
        } catch (e) {
          continue;
        }
      }

      if (!connected && mounted) {
        ToastManager.show(
          context: context,
          title: "Connection Failed",
          message: "Cannot reach server at $ip. Check if XAMPP is running.",
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        ToastManager.show(
          context: context,
          title: "Error",
          message: "Failed to connect to $ip",
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.dns, size: 20, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.connectToServer,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),

              if (_myIP != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.phone_android, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text('This device: ', style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                      Text(_myIP!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.refresh, size: 18, color: Colors.blue.shade700),
                        onPressed: _getMyIP,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: loading ? null : _quickConnect,
                  icon: autoFinding
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_find, size: 18),
                  label: Text(autoFinding ? 'Scanning...' : 'Auto Find Server'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),

              if (_scanStatus != null) ...[
                const SizedBox(height: 8),
                Text(_scanStatus!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
              ],

              const SizedBox(height: 16),

              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 16),

              Text('Enter server address manually:', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 8),

              TextField(
                controller: ipController,
                decoration: InputDecoration(
                  hintText: 'e.g. 192.168.1.6',
                  prefixIcon: const Icon(Icons.computer, size: 20),
                  suffixIcon: _myIP != null && _myIP != ipController.text
                      ? TextButton(
                    onPressed: () {
                      ipController.text = _myIP!;
                    },
                    child: const Text('Use mine', style: TextStyle(fontSize: 11)),
                  )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                enabled: !loading,
                style: const TextStyle(fontSize: 14),
              ),

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(4),
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
                          child: Text('How to find server address:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey.shade700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Press Win+R, type "cmd"', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const Text('2. Type "ipconfig"', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const Text('3. Find IPv4 Address under Wi-Fi', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    if (_myIP != null) ...[
                      const SizedBox(height: 4),
                      Text('Your IP: $_myIP', style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: loading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: loading ? null : connect,
                    icon: loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.link, size: 16),
                    label: Text(loading ? 'Connecting...' : 'Connect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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

  @override
  void dispose() {
    ipController.dispose();
    super.dispose();
  }
}