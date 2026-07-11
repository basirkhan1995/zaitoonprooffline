part of 'backup_bloc.dart';

sealed class BackupEvent extends Equatable {
  const BackupEvent();
}

class DownloadBackupEvent extends BackupEvent {
  @override
  List<Object?> get props => [];
}

class LoadBackupsEvent extends BackupEvent {
  @override
  List<Object?> get props => [];
}

class DeleteBackupEvent extends BackupEvent {
  final String filePath;

  const DeleteBackupEvent(this.filePath);

  @override
  List<Object?> get props => [filePath];
}

class RenameBackupEvent extends BackupEvent {
  final String oldPath;
  final String newPath;

  const RenameBackupEvent(this.oldPath, this.newPath);

  @override
  List<Object?> get props => [oldPath, newPath];
}

class RestoreBackupEvent extends BackupEvent {
  final String filePath;

  const RestoreBackupEvent(this.filePath);

  @override
  List<Object?> get props => [filePath];
}

class CheckMySQLConnectionEvent extends BackupEvent {
  @override
  List<Object?> get props => [];
}