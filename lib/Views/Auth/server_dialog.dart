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
    _loadSavedIP();
    _getMyIP();
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
      _scanStatus = 'Getting your IP...';
    });

    try {
      final savedIP = await ApiServices().getSavedServerIP();
      if (savedIP != null && savedIP.isNotEmpty) {
        setState(() => _scanStatus = 'Trying saved server: $savedIP');
        final connected = await _tryConnect(savedIP);
        if (connected) return;
      }

      final localIP = await _getLocalIP();

      if (localIP != null) {
        setState(() => _scanStatus = 'Trying this device: $localIP');

        final connected = await _tryConnect(localIP);
        if (connected) return;

        final parts = localIP.split('.');
        if (parts.length == 4) {
          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

          final subnetsToTry = <String>[subnet];
          if (subnet != '192.168.0') subnetsToTry.add('192.168.0');
          if (subnet != '192.168.1') subnetsToTry.add('192.168.1');

          for (final currentSubnet in subnetsToTry) {
            final priorityIPs = <String>[
              '$currentSubnet.109',
              '$currentSubnet.100',
              '$currentSubnet.50',
              '$currentSubnet.10',
              '$currentSubnet.20',
              '$currentSubnet.30',
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
            }
          }
        }
      }

      if (mounted) {
        setState(() => _scanStatus = null);
        ToastManager.show(context: context,title: "Connection Failed",  message: "No server found", type: ToastType.error);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanStatus = null);
        ToastManager.show(context: context,title: "Scan Failed",  message: "No server found", type: ToastType.error);
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
            await ApiServices().setServerIP(ip, port: '80');

            if (mounted) {
              ipController.text = ip;
              ToastManager.show(context: context,title: "Connection Succeed",  message: "Connected to $ip", type: ToastType.success);
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
      ToastManager.show(context: context,title: "IP REQUIRED",  message: "Please enter the server address.", type: ToastType.warning);
      return;
    }

    setState(() => loading = true);

    try {
      final url = 'http://$ip/rapi/get_ip.php';

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        validateStatus: (status) => status != null && status < 500,
      ));

      final response = await dio.get(url);

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data;

        if (data['success'] == true) {
          await ApiServices().setServerIP(ip, port: '80');

          if (mounted) {
            ToastManager.show(context: context,title: "Connection Succeed",  message: "Connected to $ip", type: ToastType.success);
            Navigator.pop(context, true);
          }
        } else {
          throw Exception('Server returned error');
        }
      } else {
        throw Exception('Invalid response');
      }
    } on DioException catch (e) {
      if (mounted) {
        ToastManager.show(context: context,title: "Connection Failed",  message: "Failed to connect ${e.message}", type: ToastType.error);
      }
    } catch (e) {
      if (mounted) {
        ToastManager.show(context: context,title: "Connection Failed",  message: "Failed to connect $ip", type: ToastType.error);
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

              // This device IP info box
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.phone_android, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'This device IP: ',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                          ),
                          Text(
                            _myIP!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'If this device is the server, use this IP',
                        style: TextStyle(fontSize: 10, color: Colors.blue.shade500, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Auto Scan Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: loading ? null : _quickConnect,
                  icon: autoFinding
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_find, size: 18),
                  label: Text(autoFinding ? 'Searching...' : 'Auto Find Server'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),

              if (_scanStatus != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    _scanStatus!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ),
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

              Text(
                'Enter server address manually:',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: ipController,
                decoration: InputDecoration(
                  hintText: 'e.g. 192.168.0.109',
                  prefixIcon: const Icon(Icons.computer, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                enabled: !loading,
                style: const TextStyle(fontSize: 14),
              ),

              const SizedBox(height: 16),

              // Help box
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
                          child: Text(
                            'How to find server address:',
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
                    Text(
                      'On the SERVER computer:',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                    ),
                    const Text('1. Press Win+R, type "cmd"', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const Text('2. Type "ipconfig"', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const Text('3. Find IPv4 Address under Wi-Fi', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
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