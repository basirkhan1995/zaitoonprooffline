import 'dart:convert';

List<TotalDailyTxnModel> totalDailyTxnModelFromMap(String str) =>
    List<TotalDailyTxnModel>.from(json.decode(str).map((x) => TotalDailyTxnModel.fromMap(x)));

String totalDailyTxnModelToMap(List<TotalDailyTxnModel> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toMap())));

class TotalDailyTxnModel {
  final String? txnName;
  final double? totalAmount;
  final int? totalCount;

  TotalDailyTxnModel({
    this.txnName,
    this.totalAmount,
    this.totalCount,
  });

  TotalDailyTxnModel copyWith({
    String? txnName,
    double? totalAmount,
    int? totalCount,
  }) =>
      TotalDailyTxnModel(
        txnName: txnName ?? this.txnName,
        totalAmount: totalAmount ?? this.totalAmount,
        totalCount: totalCount ?? this.totalCount,
      );

  factory TotalDailyTxnModel.fromMap(Map<String, dynamic> json) {
    // Parse totalAmount
    double amount = 0.0;
    if (json["total"] != null) {
      amount = double.tryParse(json["total"].toString()) ?? 0.0;
    }

    // Parse totalCount - handle decimal strings like "4.0000"
    int count = 0;
    if (json["total_trn"] != null) {
      final countStr = json["total_trn"].toString();
      // First parse as double, then convert to int
      final countDouble = double.tryParse(countStr) ?? 0;
      count = countDouble.toInt();
    }

    return TotalDailyTxnModel(
      txnName: json["trntName"]?.toString(),
      totalAmount: amount,
      totalCount: count,
    );
  }

  Map<String, dynamic> toMap() => {
    "trntName": txnName,
    "total": totalAmount,
    "total_trn": totalCount,
  };
}