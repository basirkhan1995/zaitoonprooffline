part of 'income_statement_bloc.dart';

sealed class IncomeStatementEvent extends Equatable {
  const IncomeStatementEvent();
}

final class LoadIncomeStatementEvent extends IncomeStatementEvent {
  final String startDate;
  final String endDate;

  const LoadIncomeStatementEvent({
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object> get props => [startDate, endDate];
}

final class ResetIncomeStatementEvent extends IncomeStatementEvent {
  const ResetIncomeStatementEvent();

  @override
  List<Object> get props => [];
}