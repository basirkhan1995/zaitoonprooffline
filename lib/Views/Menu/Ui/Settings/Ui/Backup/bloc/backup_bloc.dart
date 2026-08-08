import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:zaitoonpro/Services/repositories.dart';

part 'backup_event.dart';
part 'backup_state.dart';

class BackupBloc extends Bloc<BackupEvent, BackupState> {
  final Repositories _repo;

  BackupBloc(this._repo) : super(BackupInitial()) {
    on<DownloadBackupEvent>(_onDownloadBackup);
    on<LoadBackupsEvent>(_onLoadBackups);
    on<DeleteBackupEvent>(_onDeleteBackup);
    on<RenameBackupEvent>(_onRenameBackup);
    on<RestoreBackupEvent>(_onRestoreBackup);
    on<CheckMySQLConnectionEvent>(_onCheckMySQLConnection);
    on<PickAndRestoreBackupEvent>(_onPickAndRestoreBackup);
    on<OpenBackupFolderEvent>(_onOpenBackupFolder);
  }
  Future<void> _onPickAndRestoreBackup(
      PickAndRestoreBackupEvent event,
      Emitter<BackupState> emit,
      ) async {
    try {
      // Open file picker
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sql'],
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null) {
          // Start restore
          emit(BackupRestoreProgress('Starting restore from selected file...'));

          await _repo.restoreBackup(
            filePath,
            onProgress: (message) {
              emit(BackupRestoreProgress(message));
            },
          );

          emit(BackupRestoreSuccess());

          // Reload backups list
          final backups = await _repo.getBackupFiles();
          emit(BackupsLoaded(backups));
        }
      }
    } catch (e) {
      if (e.toString().contains('User cancelled')) {
        // User cancelled the picker - just ignore
        final backups = await _repo.getBackupFiles();
        emit(BackupsLoaded(backups));
      } else {
        emit(BackupError(e.toString()));
      }
    }
  }

  Future<void> _onOpenBackupFolder(
      OpenBackupFolderEvent event,
      Emitter<BackupState> emit,
      ) async {
    try {
      // Open the backup folder
      await _repo.openBackupFolder();
    } catch (e) {
      emit(BackupError('Failed to open backup folder: $e'));
    }
  }
  Future<void> _onDownloadBackup(
      DownloadBackupEvent event,
      Emitter<BackupState> emit,
      ) async {
    emit(BackupLoading());
    try {
      final file = await _repo.downloadBackup();
      final filePath = file.path;
      emit(BackupDownloadSuccess(filePath));
      final backups = await _repo.getBackupFiles();
      emit(BackupsLoaded(backups));
    } catch (e) {
      emit(BackupError(e.toString()));
    }
  }

  Future<void> _onLoadBackups(
      LoadBackupsEvent event,
      Emitter<BackupState> emit,
      ) async {
    emit(BackupLoading());
    try {
      final backups = await _repo.getBackupFiles();
      emit(BackupsLoaded(backups));
    } catch (e) {
      emit(BackupError(e.toString()));
    }
  }

  Future<void> _onDeleteBackup(
      DeleteBackupEvent event,
      Emitter<BackupState> emit,
      ) async {
    emit(BackupLoading());
    try {
      await _repo.deleteBackup(event.filePath);
      emit(BackupDeleteSuccess());
      final backups = await _repo.getBackupFiles();
      emit(BackupsLoaded(backups));
    } catch (e) {
      emit(BackupError(e.toString()));
    }
  }

  Future<void> _onRenameBackup(
      RenameBackupEvent event,
      Emitter<BackupState> emit,
      ) async {
    emit(BackupLoading());
    try {
      await _repo.renameBackup(event.oldPath, event.newPath);
      emit(BackupRenameSuccess());
      final backups = await _repo.getBackupFiles();
      emit(BackupsLoaded(backups));
    } catch (e) {
      emit(BackupError(e.toString()));
    }
  }

  Future<void> _onRestoreBackup(
      RestoreBackupEvent event,
      Emitter<BackupState> emit,
      ) async {
    emit(BackupRestoreProgress('Starting database restore...'));
    try {
      await _repo.restoreBackup(
        event.filePath,
        onProgress: (message) {
          emit(BackupRestoreProgress(message));
        },
      );

      emit(BackupRestoreSuccess());

      // Reload backups after restore
      final backups = await _repo.getBackupFiles();
      emit(BackupsLoaded(backups));
    } catch (e) {
      emit(BackupError(e.toString()));
    }
  }

  Future<void> _onCheckMySQLConnection(
      CheckMySQLConnectionEvent event,
      Emitter<BackupState> emit,
      ) async {
    emit(BackupLoading());
    try {
      String mysqlPath;
      if (Platform.isWindows) {
        mysqlPath = 'C:\\xampp\\mysql\\bin\\mysql.exe';
      } else if (Platform.isMacOS) {
        mysqlPath = '/Applications/XAMPP/xamppfiles/bin/mysql';
      } else {
        mysqlPath = '/opt/lampp/bin/mysql';
      }

      // Test MySQL connection
      final result = await Process.run(
        mysqlPath,
        ['-u', 'root', '-e', 'SELECT 1'],
        runInShell: true,
      );

      final isConnected = result.exitCode == 0;
      emit(MySQLConnectionStatus(
        isConnected: isConnected,
        message: isConnected ? 'MySQL is connected' : 'MySQL connection failed',
      ));
    } catch (e) {
      emit(MySQLConnectionStatus(
        isConnected: false,
        message: 'MySQL is not accessible: $e',
      ));
    }
  }
}