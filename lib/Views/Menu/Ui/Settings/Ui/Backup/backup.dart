import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zaitoonpro/Features/Other/cover.dart';
import 'package:zaitoonpro/Features/Other/responsive.dart';
import 'package:zaitoonpro/Features/Other/toast.dart';
import 'package:zaitoonpro/Features/Widgets/no_data_widget.dart';
import 'package:zaitoonpro/Features/Widgets/outline_button.dart';
import 'package:zaitoonpro/Localizations/l10n/translations/app_localizations.dart';
import 'bloc/backup_bloc.dart';

class BackupView extends StatelessWidget {
  const BackupView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _Mobile(),
      tablet: _Tablet(),
      desktop: _Desktop(),
    );
  }
}

class _Mobile extends StatelessWidget {
  const _Mobile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: _BackupContent(),
    );
  }
}

class _Tablet extends StatelessWidget {
  const _Tablet();

  @override
  Widget build(BuildContext context) {
    return _BackupContent();
  }
}

class _Desktop extends StatefulWidget {
  const _Desktop();

  @override
  State<_Desktop> createState() => _DesktopState();
}

class _DesktopState extends State<_Desktop> {
  @override
  void initState() {
    context.read<BackupBloc>().add(LoadBackupsEvent());
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: _BackupContent(),
    );
  }
}

class _BackupContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZCover(
            radius: 4,
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr.databaseBackup,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    tr.downloadBackupMsg,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: .8),
                    ),
                  ),
                  const SizedBox(height: 15),
                  BlocConsumer<BackupBloc, BackupState>(
                    listener: (context, state) {
                      if (state is BackupDownloadSuccess) {
                        ToastManager.show(
                            title: tr.backupTitle,
                            context: context, message: 'Backup downloaded to: ${state.filePath}', type: ToastType.success);
                      }
                    },
                    builder: (context, state) {
                      return ZOutlineButton(
                        height: 45,
                        isActive: true,
                        onPressed: state is BackupLoading
                            ? null
                            : () {
                          context.read<BackupBloc>().add(DownloadBackupEvent());
                        },
                        icon: Icons.cloud_download,
                        label: state is BackupLoading
                            ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : Text(
                          tr.downloadLatestBackup,
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: Row(
              spacing: 10,
              children: [
                Icon(Icons.backup),
                Text(
                  tr.existingBackups,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocConsumer<BackupBloc, BackupState>(
              listener: (context, state) {
                if (state is BackupDownloadSuccess) {
                  context.read<BackupBloc>().add(LoadBackupsEvent());
                }
                if (state is BackupDeleteSuccess) {
                  ToastManager.show(
                      title: tr.deletedTitle,
                      context: context, message: tr.deleteSuccessMessage, type: ToastType.success);
                  context.read<BackupBloc>().add(LoadBackupsEvent());
                }
                if (state is BackupRenameSuccess) {
                  ToastManager.show(
                      title: tr.renameTitle,
                      context: context, message: tr.successMessage, type: ToastType.success);
                  context.read<BackupBloc>().add(LoadBackupsEvent());
                }
                if (state is BackupError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${state.message}'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is BackupsLoaded) {
                  if (state.backups.isEmpty) {
                    return Center(
                      child: NoDataWidget(
                        message: "No Backup found",
                        onRefresh: (){
                          context.read<BackupBloc>().add(LoadBackupsEvent());
                        },
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: state.backups.length,
                    itemBuilder: (context, index) {
                      final file = state.backups[index];
                      final fileStat = file.statSync();

                      final fileName = file.path.split(Platform.pathSeparator).last;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: ZCover(
                          radius: 5,
                          color: Theme.of(context).colorScheme.surface,
                          child: ListTile(
                            leading: Icon(Icons.storage_rounded),
                            hoverColor: Theme.of(context).colorScheme.primary.withValues(alpha: .05),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8),
                            title: Text(
                              fileName, // This now shows only the file name
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Size: ${_formatBytes(fileStat.size)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  file.path,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert),
                              onSelected: (value) {
                                switch (value) {
                                  case 'rename':
                                    _showRenameDialog(context, file.path);
                                    break;
                                  case 'delete':
                                    _showDeleteDialog(context, file.path);
                                    break;
                                  case 'folder':
                                    _openFolder(context, file.path);
                                    break;
                                  case 'info':
                                    _showFileInfo(context, file.path);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                                      const SizedBox(width: 8),
                                      const Text('Rename'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'folder',
                                  child: Row(
                                    children: [
                                      Icon(Icons.folder_open, color: Theme.of(context).colorScheme.primary),
                                      const SizedBox(width: 8),
                                      const Text('Show in Folder'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'info',
                                  child: Row(
                                    children: [
                                      Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
                                      const SizedBox(width: 8),
                                      const Text('File Info'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                                      const SizedBox(width: 8),
                                      const Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              _showFileOptions(context, file.path);
                            },
                          ),
                        ),
                      );
                    },
                  );
                } else if (state is BackupError) {
                  return Center(
                    child: Text(
                      'Error: ${state.message}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  );
                } else if (state is BackupLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return const Center(child: Text('No data available'));
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / 1048576).toStringAsFixed(2)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showDeleteDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5)
        ),
        title: const Text('Delete Backup'),
        content: const Text('Are you sure you want to delete this backup file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<BackupBloc>().add(DeleteBackupEvent(filePath));
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, String filePath) {
    final file = File(filePath);
    final currentName = file.path.split('/').last;
    final textController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5)
        ),
        title: const Text('Rename Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter new name for the backup file:'),
            const SizedBox(height: 8),
            TextField(
              controller: textController,
              autofocus: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                hintText: 'Enter new file name',
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty && value != currentName) {
                  final parentDir = file.parent.path;
                  final newPath = '$parentDir/$value';
                  context.read<BackupBloc>().add(RenameBackupEvent(filePath, newPath));
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty && newName != currentName) {
                final parentDir = file.parent.path;
                final newPath = '$parentDir/$newName';
                context.read<BackupBloc>().add(RenameBackupEvent(filePath, newPath));
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }


  Future<void> _openFolder(BuildContext context, String filePath) async {
    final file = File(filePath);
    final directory = file.parent.path;

    try {
      Uri uri;

      if (Platform.isAndroid) {
        // For Android, use file:// URI
        uri = Uri.parse('file://$directory');
      } else if (Platform.isIOS) {
        // iOS - doesn't support opening folders directly
        if (context.mounted) {
          _showFolderLocation(context, filePath);
        }
        return;
      } else if (Platform.isWindows) {
        // Windows - use file:// URI
        uri = Uri.parse('file:///${directory.replaceAll('\\', '/')}');
      } else if (Platform.isMacOS) {
        // macOS - use file:// URI
        uri = Uri.parse('file://$directory');
      } else {
        // Linux and others
        uri = Uri.parse('file://$directory');
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: show dialog with the path
        if (context.mounted) {
          _showFolderLocation(context, filePath);
        }
      }
    } catch (e) {
      // If opening fails, show the folder location dialog
      if (context.mounted) {
        _showFolderLocation(context, filePath);
      }
    }
  }

  // Keep this as fallback for iOS and error cases
  void _showFolderLocation(BuildContext context, String filePath) {
    final file = File(filePath);
    final directory = file.parent.path;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5)
        ),
        title: const Text('Folder Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Backup file is located in:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                directory,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              Platform.isIOS
                  ? 'iOS doesn\'t support opening folders directly. You can find the file in the above path.'
                  : 'You can find this file in the above folder.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!Platform.isIOS) ...[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Try opening again
                _openFolder(context, filePath);
              },
              child: const Text('Try Again'),
            ),
          ],
        ],
      ),
    );
  }

  void _showFileOptions(BuildContext context, String filePath) {
    showModalBottomSheet(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8)
          )
      ),
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, filePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Show in Folder'),
              onTap: () {
                Navigator.pop(context);
                _openFolder(context, filePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('View File Info'),
              onTap: () {
                Navigator.pop(context);
                _showFileInfo(context, filePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Backup'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, filePath);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showFileInfo(BuildContext context, String filePath) {
    final file = File(filePath);
    final stat = file.statSync();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5)
        ),
        title: const Text('File Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${file.path.split('/').last}'),
            Text('Path: ${file.path}'),
            Text('Size: ${_formatBytes(stat.size)}'),
            Text('Created: ${_formatDate(stat.accessed)}'),
            Text('Modified: ${_formatDate(stat.modified)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}