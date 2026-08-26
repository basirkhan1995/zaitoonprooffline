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

  // ============================================================
  // ✅ REUSABLE: Create backup before any restore operation
  // ============================================================
  Future<void> _createBackupBeforeRestore(Emitter<BackupState> emit) async {
    emit(const BackupInProgress());
    await _repo.downloadBackup();
    // Backup created successfully - no unused variables
  }

  // ============================================================
  // ✅ DOWNLOAD BACKUP
  // ============================================================
  Future<void> _onDownloadBackup(
      DownloadBackupEvent event,
      Emitter<BackupState> emit,
      ) async {
    emit(BackupLoading());
    try {
      final file = await _repo.downloadBackup();
      emit(BackupDownloadSuccess(file.path));
      final backups = await _repo.getBackupFiles();
      emit(BackupsLoaded(backups));
    } catch (e) {
      emit(BackupError(e.toString()));
    }
  }

  // ============================================================
  // ✅ LOAD BACKUPS
  // ============================================================
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

  // ============================================================
  // ✅ DELETE BACKUP
  // ============================================================
  Future<void> _onDeleteBackup(
      DeleteBackupEvent event,
      Emitter<BackupState> emit,
      ) async {
    emit(BackupLoading());
    try {
      await _repo.deleteBackup(event.filePath);
      emit(const BackupDeleteSuccess());
      final backups = await _repo.getBackupFiles();
      emit(BackupsLoaded(backups));
    } catch (e) {
      emit(BackupError(e.toString()));
    }
  }

  // ============================================================
  // ✅ RENAME BACKUP
  // ============================================================
  Future<void> _onRenameBackup(
      RenameBackupEvent event,
      Emitter<BackupState> emit,
      ) async {
    emit(BackupLoading());
    try {
      await _repo.renameBackup(event.oldPath, event.newPath);
      emit(const BackupRenameSuccess());
      final backups = await _repo.getBackupFiles();
      emit(BackupsLoaded(backups));
    } catch (e) {
      emit(BackupError(e.toString()));
    }
  }

  // ============================================================
  // ✅ RESTORE FROM BACKUP LIST (with auto-backup)
  // ============================================================
  Future<void> _onRestoreBackup(
      RestoreBackupEvent event,
      Emitter<BackupState> emit,
      ) async {
    try {
      // Step 1: Create backup before restore
      await _createBackupBeforeRestore(emit);

      // Step 2: Restore the selected backup
      emit(const RestoreAfterBackupProgress('Restoring database...'));
      await _repo.restoreBackup(
        event.filePath,
        onProgress: (message) {
          emit(RestoreAfterBackupProgress(message));
        },
      );

      emit(const BackupRestoreSuccess());
      final backups = await _repo.getBackupFiles();
      emit(BackupsLoaded(backups));
    } catch (e) {
      emit(BackupError(e.toString()));
    }
  }

  // ============================================================
  // ✅ PICK FILE AND RESTORE (with auto-backup)
  // ============================================================
  Future<void> _onPickAndRestoreBackup(
      PickAndRestoreBackupEvent event,
      Emitter<BackupState> emit,
      ) async {
    try {
      // Step 1: Pick file from device
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sql'],
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null) {
          // Step 2: Create backup before restore
          await _createBackupBeforeRestore(emit);

          // Step 3: Restore the picked file
          emit(const RestoreAfterBackupProgress('Restoring from selected file...'));
          await _repo.restoreBackup(
            filePath,
            onProgress: (message) {
              emit(RestoreAfterBackupProgress(message));
            },
          );

          emit(const BackupRestoreSuccess());
          final backups = await _repo.getBackupFiles();
          emit(BackupsLoaded(backups));
        }
      }
    } catch (e) {
      if (e.toString().contains('User cancelled')) {
        final backups = await _repo.getBackupFiles();
        emit(BackupsLoaded(backups));
      } else {
        emit(BackupError(e.toString()));
      }
    }
  }

  // ============================================================
  // ✅ CHECK MYSQL CONNECTION
  // ============================================================
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

  // ============================================================
  // ✅ OPEN BACKUP FOLDER
  // ============================================================
  Future<void> _onOpenBackupFolder(
      OpenBackupFolderEvent event,
      Emitter<BackupState> emit,
      ) async {
    try {
      await _repo.openBackupFolder();
    } catch (e) {
      emit(BackupError('Failed to open backup folder: $e'));
    }
  }
}