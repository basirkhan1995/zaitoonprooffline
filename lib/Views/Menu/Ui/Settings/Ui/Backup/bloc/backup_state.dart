part of 'backup_bloc.dart';

sealed class BackupState extends Equatable {
  const BackupState();
}

final class BackupInitial extends BackupState {
  @override
  List<Object> get props => [];
}

final class BackupLoading extends BackupState {
  @override
  List<Object> get props => [];
}

final class BackupDownloadSuccess extends BackupState {
  final String filePath;

  const BackupDownloadSuccess(this.filePath);

  @override
  List<Object> get props => [filePath];
}

final class BackupDeleteSuccess extends BackupState {
  const BackupDeleteSuccess();

  @override
  List<Object> get props => [];
}

final class BackupRenameSuccess extends BackupState {
  const BackupRenameSuccess();

  @override
  List<Object> get props => [];
}

final class BackupRestoreSuccess extends BackupState {
  const BackupRestoreSuccess();

  @override
  List<Object> get props => [];
}

final class BackupRestoreProgress extends BackupState {
  final String message;

  const BackupRestoreProgress(this.message);

  @override
  List<Object> get props => [message];
}

final class BackupsLoaded extends BackupState {
  final List<FileSystemEntity> backups;

  const BackupsLoaded(this.backups);

  @override
  List<Object> get props => [backups];
}

final class BackupError extends BackupState {
  final String message;

  const BackupError(this.message);

  @override
  List<Object> get props => [message];
}

final class MySQLConnectionStatus extends BackupState {
  final bool isConnected;
  final String message;

  const MySQLConnectionStatus({required this.isConnected, required this.message});

  @override
  List<Object> get props => [isConnected, message];
}