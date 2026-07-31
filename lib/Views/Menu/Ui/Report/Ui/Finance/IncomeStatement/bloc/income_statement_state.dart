part of 'income_statement_bloc.dart';

sealed class IncomeStatementState extends Equatable {
  const IncomeStatementState();
}

final class IncomeStatementInitial extends IncomeStatementState {
  @override
  List<Object> get props => [];
}

final class IncomeStatementLoadingState extends IncomeStatementState {
  @override
  List<Object> get props => [];
}

final class IncomeStatementLoadedState extends IncomeStatementState {
  final List<IncomeStatementModel> incomeStatement;
  final IncomeStatementSummary summary;

  const IncomeStatementLoadedState({
    required this.incomeStatement,
    required this.summary,
  });

  @override
  List<Object> get props => [incomeStatement, summary];
}

final class IncomeStatementErrorState extends IncomeStatementState {
  final String message;

  const IncomeStatementErrorState(this.message);

  @override
  List<Object> get props => [message];
}