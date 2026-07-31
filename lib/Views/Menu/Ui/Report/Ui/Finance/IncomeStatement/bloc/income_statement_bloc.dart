import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:zaitoonpro/Services/repositories.dart';
import '../model/income_stmt_model.dart';

part 'income_statement_event.dart';
part 'income_statement_state.dart';

class IncomeStatementBloc extends Bloc<IncomeStatementEvent, IncomeStatementState> {
  final Repositories _repo;

  IncomeStatementBloc(this._repo) : super(IncomeStatementInitial()) {
    on<LoadIncomeStatementEvent>(_onLoadIncomeStatement);
    on<ResetIncomeStatementEvent>(_onReset);
  }

  Future<void> _onLoadIncomeStatement(
      LoadIncomeStatementEvent event,
      Emitter<IncomeStatementState> emit,
      ) async {
    emit(IncomeStatementLoadingState());

    try {
      final records = await _repo.getIncomeStatement(
        startDate: event.startDate,
        endDate: event.endDate,
      );

      if (records.isEmpty) {
        emit(IncomeStatementErrorState('No records found'));
        return;
      }

      // Calculate summary
      double totalIncome = 0;
      double totalExpenses = 0;
      double netProfit = 0;
      String baseCurrency = 'USD';

      for (var item in records) {
        if (item.type == 'INCOME') {
          totalIncome += item.amountBase ?? 0;
          if (item.baseCurrency != null) {
            baseCurrency = item.baseCurrency!;
          }
        } else if (item.type == 'EXPENSE') {
          totalExpenses += item.amountBase ?? 0;
          if (item.baseCurrency != null) {
            baseCurrency = item.baseCurrency!;
          }
        } else if (item.type == 'NET PROFIT') {
          netProfit = item.amountBase ?? 0;
          if (item.baseCurrency != null) {
            baseCurrency = item.baseCurrency!;
          }
        }
      }

      final summary = IncomeStatementSummary(
        startDate: event.startDate,
        endDate: event.endDate,
        baseCurrency: baseCurrency,
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        netProfit: netProfit,
        status: netProfit >= 0 ? 'PROFIT' : 'LOSS',
      );

      emit(IncomeStatementLoadedState(
        incomeStatement: records,
        summary: summary,
      ));
    } catch (e) {
      emit(IncomeStatementErrorState(e.toString()));
    }
  }

  void _onReset(
      ResetIncomeStatementEvent event,
      Emitter<IncomeStatementState> emit,
      ) {
    emit(IncomeStatementInitial());
  }
}