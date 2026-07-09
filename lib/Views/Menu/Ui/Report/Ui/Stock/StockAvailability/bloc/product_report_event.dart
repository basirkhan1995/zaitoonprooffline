part of 'product_report_bloc.dart';

sealed class ProductReportEvent extends Equatable {
  const ProductReportEvent();
}


class LoadProductsReportEvent extends ProductReportEvent{
  final int? productId;
  final int? storageId;
  final int? categoryId;
  final int? isNoStock;
  final int? lowStock;
  final String? salesFilter;

  const LoadProductsReportEvent({this.productId, this.storageId, this.categoryId, this.isNoStock, this.lowStock,this.salesFilter});
  @override
  List<Object?> get props => [productId, storageId,categoryId, isNoStock, lowStock,salesFilter];
}

class ResetProductReportEvent extends ProductReportEvent{
  @override
  List<Object?> get props => [];
}