import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zaitoonpro/Features/Other/cover.dart';
import 'package:zaitoonpro/Features/Other/responsive.dart';
import 'package:zaitoonpro/Features/Other/toast.dart';
import 'package:zaitoonpro/Features/Widgets/no_data_widget.dart';
import 'package:zaitoonpro/Features/Widgets/outline_button.dart';
import 'package:zaitoonpro/Features/Widgets/textfield_entitled.dart';
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
                  SizedBox(height: 5),
                  Text(
                    tr.downloadBackupMsg,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: .8),
                      fontSize: 14
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
                      return Row(
                        spacing: 8,

                        children: [
                          ZOutlineButton(
                            height: 45,
                            isActive: true,
                            onPressed: state is BackupLoading
                                ? null
                                : () {
                              context.read<BackupBloc>().add(DownloadBackupEvent());
                            },
                            icon: Icons.cloud_download_outlined,
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
                          ),
                          ZOutlineButton(
                            height: 45,

                            onPressed: state is BackupLoading
                                ? null
                                : () {
                              _showBrowseRestoreDialog(context);
                            },
                            icon: Icons.folder_outlined,
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
                              tr.browse,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
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
                Icon(Icons.backup_rounded),
                Text(
                  tr.recentBackup,
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
                if (state is BackupRestoreSuccess) {
                  ToastManager.show(
                      title: tr.restoreComplete,
                      context: context,
                      message: tr.restoreSuccessMessage,
                      type: ToastType.success);
                  context.read<BackupBloc>().add(LoadBackupsEvent());
                }
                if (state is BackupError) {
                  ToastManager.show(
                      title: tr.errorTitle,
                      context: context,
                      message: state.message,
                      type: ToastType.error);
                }
              },
              builder: (context, state) {
                if (state is BackupsLoaded) {
                  if (state.backups.isEmpty) {
                    return Center(
                      child: NoDataWidget(
                        message: tr.noBackupFound,
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
                              fileName,
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
                                  case 'restore':
                                    _showRestoreDialog(context, file.path);
                                    break;
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
                                  value: 'restore',
                                  child: Row(
                                    children: [
                                      Icon(Icons.restore, color: Colors.orange),
                                      const SizedBox(width: 8),
                                        Text(tr.restoreDatabase),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                                      const SizedBox(width: 8),
                                        Text(tr.renameTitle),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'folder',
                                  child: Row(
                                    children: [
                                      Icon(Icons.folder_open, color: Theme.of(context).colorScheme.primary),
                                      const SizedBox(width: 8),
                                        Text(tr.showInFolder),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'info',
                                  child: Row(
                                    children: [
                                      Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
                                      const SizedBox(width: 8),
                                        Text(tr.fileInfo),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                                      const SizedBox(width: 8),
                                        Text(tr.delete),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else if (state is BackupRestoreProgress) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          state.message,
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
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
  void _showBrowseRestoreDialog(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5)
        ),
        title: Row(
          children: [
            Icon(Icons.folder_open, color: Theme.of(context).colorScheme.primary),
            SizedBox(width: 8),
            Text(tr.restoreDatabase),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
               tr.sqlMessage,
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: .1),
                border: Border.all(color: Colors.orange.withValues(alpha: .3)),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr.restoreMessage  ,
                      style: TextStyle(fontSize: 15, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr.cancel),
          ),
          ZOutlineButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Open file picker and restore
              context.read<BackupBloc>().add(PickAndRestoreBackupEvent());
            },
            icon: Icons.file_open,
            label: Text(tr.browse),

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

  void _showRestoreDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5)
        ),
        title: Row(
          children: [
            Icon(Icons.restore, color: Colors.orange),
            SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.restoreDatabase),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: .1),
                border: Border.all(color: Colors.orange.withValues(alpha: .3)),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.restoreMessage,
                      style: TextStyle(fontSize: 15, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // File info
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Restoring from:',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    filePath.split(Platform.pathSeparator).last,
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ZOutlineButton(
            isActive: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<BackupBloc>().add(RestoreBackupEvent(filePath));
            },
            icon: Icons.restore,
            label: Text(AppLocalizations.of(context)!.restoreTitle),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5)
        ),
        title: Text(AppLocalizations.of(context)!.delete),
        content: Text(AppLocalizations.of(context)!.deleteMessage),
        actions: [
          ZOutlineButton(
            onPressed: () => Navigator.pop(context),
            label: Text(AppLocalizations.of(context)!.cancel),
          ),
          ZOutlineButton(
            isActive: true,
            backgroundHover: Theme.of(context).colorScheme.error,
            onPressed: () {
              context.read<BackupBloc>().add(DeleteBackupEvent(filePath));
              Navigator.pop(context);
            },
            label: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, String filePath) {
    final file = File(filePath);
    final currentName = file.path.split('/').last;
    final textController = TextEditingController(text: currentName);
    final tr = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5)
        ),
        title: Text(tr.renameBackup),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ZTextFieldEntitled(
              controller: textController,
              title: tr.fileInfo,
              onSubmit: (value) {
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
          ZOutlineButton(
            onPressed: () => Navigator.pop(context),
            label: Text(tr.cancel),
          ),
          ZOutlineButton(
            isActive: true,
            onPressed: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty && newName != currentName) {
                final parentDir = file.parent.path;
                final newPath = '$parentDir/$newName';
                context.read<BackupBloc>().add(RenameBackupEvent(filePath, newPath));
                Navigator.pop(context);
              }
            },
            label: Text(tr.renameTitle),
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
        uri = Uri.parse('file://$directory');
      } else if (Platform.isIOS) {
        if (context.mounted) {
          _showFolderLocation(context, filePath);
        }
        return;
      } else if (Platform.isWindows) {
        uri = Uri.parse('file:///${directory.replaceAll('\\', '/')}');
      } else if (Platform.isMacOS) {
        uri = Uri.parse('file://$directory');
      } else {
        uri = Uri.parse('file://$directory');
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          _showFolderLocation(context, filePath);
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showFolderLocation(context, filePath);
      }
    }
  }

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
                _openFolder(context, filePath);
              },
              child: const Text('Try Again'),
            ),
          ],
        ],
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