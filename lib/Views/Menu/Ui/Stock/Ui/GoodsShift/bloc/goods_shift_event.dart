// goods_shift_event.dart
part of 'goods_shift_bloc.dart';

abstract class GoodsShiftEvent extends Equatable {
  const GoodsShiftEvent();
  @override
  List<Object?> get props => [];
}

class LoadGoodsShiftsEvent extends GoodsShiftEvent {}

class LoadGoodsShiftByIdEvent extends GoodsShiftEvent {
  final int orderId;
  const LoadGoodsShiftByIdEvent(this.orderId);
  @override
  List<Object?> get props => [orderId];
}

class AddGoodsShiftEvent extends GoodsShiftEvent {
  final String usrName;
  final String account;
  final String amount;
  final List<ShiftRecord> records;
  const AddGoodsShiftEvent({
    required this.usrName,
    required this.account,
    required this.amount,
    required this.records,
  });
  @override
  List<Object?> get props => [usrName, account, amount, records];
}

class UpdateGoodsShiftEvent extends GoodsShiftEvent {
  final int ordID;
  final String usrName;
  final String account;
  final String amount;
  final List<ShiftRecord> records;
  const UpdateGoodsShiftEvent({
    required this.ordID,
    required this.usrName,
    required this.account,
    required this.amount,
    required this.records,
  });
  @override
  List<Object?> get props => [ordID, usrName, account, amount, records];
}

class DeleteGoodsShiftEvent extends GoodsShiftEvent {
  final int orderId;
  final String usrName;
  const DeleteGoodsShiftEvent({
    required this.orderId,
    required this.usrName,
  });
  @override
  List<Object?> get props => [orderId, usrName];
}

class ReturnToShiftsListEvent extends GoodsShiftEvent {}