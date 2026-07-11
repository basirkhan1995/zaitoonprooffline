// backup_bloc.dart
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
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
}