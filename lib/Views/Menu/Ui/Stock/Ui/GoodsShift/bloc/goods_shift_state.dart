// goods_shift_state.dart
part of 'goods_shift_bloc.dart';

abstract class GoodsShiftState extends Equatable {
  const GoodsShiftState();
  @override
  List<Object?> get props => [];
}

class GoodsShiftInitial extends GoodsShiftState {}

class GoodsShiftLoadingState extends GoodsShiftState {}

class GoodsShiftSavingState extends GoodsShiftState {}

class GoodsShiftSavedState extends GoodsShiftState {
  final String message;
  const GoodsShiftSavedState({required this.message});
  @override
  List<Object?> get props => [message];
}

class GoodsShiftUpdatingState extends GoodsShiftState {}

class GoodsShiftUpdatedState extends GoodsShiftState {
  final String message;
  const GoodsShiftUpdatedState({required this.message});
  @override
  List<Object?> get props => [message];
}

class GoodsShiftDeletingState extends GoodsShiftState {}

class GoodsShiftDeletedState extends GoodsShiftState {
  final String message;
  const GoodsShiftDeletedState({required this.message});
  @override
  List<Object?> get props => [message];
}

class GoodsShiftDetailLoadingState extends GoodsShiftState {}

class GoodsShiftDetailLoadedState extends GoodsShiftState {
  final GoodShiftModel shift;
  const GoodsShiftDetailLoadedState(this.shift);
  @override
  List<Object?> get props => [shift];
}

class GoodsShiftErrorState extends GoodsShiftState {
  final String error;
  const GoodsShiftErrorState(this.error);
  @override
  List<Object?> get props => [error];
}

class GoodsShiftLoadedState extends GoodsShiftState {
  final List<GoodShiftModel> shifts;
  const GoodsShiftLoadedState(this.shifts);
  @override
  List<Object?> get props => [shifts];
}