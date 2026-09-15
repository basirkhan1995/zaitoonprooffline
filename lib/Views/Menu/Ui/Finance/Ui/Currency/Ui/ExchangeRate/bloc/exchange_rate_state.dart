part of 'exchange_rate_bloc.dart';

sealed class ExchangeRateState extends Equatable {
  const ExchangeRateState();
}

final class ExchangeRateInitial extends ExchangeRateState {
  @override
  List<Object> get props => [];
}

final class ExchangeRateLoadingState extends ExchangeRateState {
  @override
  List<Object> get props => [];
}

final class ExchangeRateSuccessState extends ExchangeRateState {
  @override
  List<Object> get props => [];
}

final class ExchangeRateErrorState extends ExchangeRateState {
  final String message;
  const ExchangeRateErrorState(this.message);
  @override
  List<Object> get props => [message];
}

final class ExchangeRateLoadedState extends ExchangeRateState {
  final List<ExchangeRateModel> rates;
  final String? rate;
  final String? fromCcy;
  final String? toCcy;
  final int requestId;

  const ExchangeRateLoadedState({
    required this.rates,
    this.rate,
    this.fromCcy,
    this.toCcy,
    this.requestId = 0,
  });

  @override
  List<Object> get props => [
    rates,
    rate ?? "0.00",
    fromCcy ?? "",
    toCcy ?? "",
    requestId,
  ];
}


