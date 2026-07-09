// To parse this JSON data, do
//
//     final orderReportModel = orderReportModelFromMap(jsonString);

import 'dart:convert';

List<OrderReportModel> orderReportModelFromMap(String str) => List<OrderReportModel>.from(json.decode(str).map((x) => OrderReportModel.fromMap(x)));

String orderReportModelToMap(List<OrderReportModel> data) => json.encode(List<dynamic>.from(data.map((x) => x.toMap())));

class OrderReportModel {
  final int? no;
  final int? ordId;
  final String? ordName;
  final int? ordPersonal;
  final String? fullName;
  final String? ordBranchName;
  final int? ordBranch;
  final String? ordTrnRef;
  final String? ordxRef;
  final String? narration;
  final String? totalBill;
  final DateTime? timing;

  OrderReportModel({
    this.no,
    this.ordId,
    this.ordName,
    this.ordPersonal,
    this.narration,
    this.fullName,
    this.ordBranchName,
    this.ordBranch,
    this.ordTrnRef,
    this.ordxRef,
    this.totalBill,
    this.timing,
  });

  OrderReportModel copyWith({
    int? no,
    int? ordId,
    String? ordName,
    int? ordPersonal,
    String? fullName,
    String? ordBranchName,
    int? ordBranch,
    String? ordTrnRef,
    String? ordxRef,
    String? totalBill,
    DateTime? timing,
    String? narration,
  }) =>
      OrderReportModel(
        no: no ?? this.no,
        ordId: ordId ?? this.ordId,
        ordName: ordName ?? this.ordName,
        ordPersonal: ordPersonal ?? this.ordPersonal,
        fullName: fullName ?? this.fullName,
        ordBranchName: ordBranchName ?? this.ordBranchName,
        ordBranch: ordBranch ?? this.ordBranch,
        ordTrnRef: ordTrnRef ?? this.ordTrnRef,
        ordxRef: ordxRef ?? this.ordxRef,
        totalBill: totalBill ?? this.totalBill,
        timing: timing ?? this.timing,
        narration: narration ?? this.narration,
      );

  factory OrderReportModel.fromMap(Map<String, dynamic> json) => OrderReportModel(
    no: json["No"],
    ordId: json["ordID"],
    ordName: json["ordName"],
    ordPersonal: json["ordPersonal"],
    fullName: json["fullName"],
    ordBranchName: json["ordBranchName"],
    ordBranch: json["ordBranch"],
    ordTrnRef: json["ordTrnRef"],
    ordxRef: json["ordxRef"],
    totalBill: json["total_bill"],
    narration: json["narration"],
    timing: json["timing"] == null ? null : DateTime.parse(json["timing"]),
  );

  Map<String, dynamic> toMap() => {
    "No": no,
    "ordID": ordId,
    "ordName": ordName,
    "ordPersonal": ordPersonal,
    "fullName": fullName,
    "ordBranchName": ordBranchName,
    "ordBranch": ordBranch,
    "ordTrnRef": ordTrnRef,
    "ordxRef": ordxRef,
    "total_bill": totalBill,
    "narration":narration,
    "timing": "${timing!.year.toString().padLeft(4, '0')}-${timing!.month.toString().padLeft(2, '0')}-${timing!.day.toString().padLeft(2, '0')}",
  };
}
