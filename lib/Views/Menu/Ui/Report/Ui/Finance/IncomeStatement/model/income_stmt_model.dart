
class IncomeStatementModel {
  final String? type;
  final int? accountNumber;
  final String? category;
  final String? accountName;
  final String? currency;
  final double? amountOriginal;
  final double? amountBase;
  final String? baseCurrency;
  final double? exchangeRateUsed;

  IncomeStatementModel({
    this.type,
    this.accountNumber,
    this.category,
    this.accountName,
    this.currency,
    this.amountOriginal,
    this.amountBase,
    this.baseCurrency,
    this.exchangeRateUsed,
  });

  factory IncomeStatementModel.fromMap(Map<String, dynamic> map) {
    return IncomeStatementModel(
      type: map['type'],
      accountNumber: map['account_number']?.toInt(),
      category: map['category'],
      accountName: map['account_name'],
      currency: map['currency'],
      amountOriginal: map['amount_original']?.toDouble(),
      amountBase: map['amount_base']?.toDouble(),
      baseCurrency: map['base_currency'],
      exchangeRateUsed: map['exchange_rate_used']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'account_number': accountNumber,
      'category': category,
      'account_name': accountName,
      'currency': currency,
      'amount_original': amountOriginal,
      'amount_base': amountBase,
      'base_currency': baseCurrency,
      'exchange_rate_used': exchangeRateUsed,
    };
  }
}

class IncomeStatementSummary {
  final String? startDate;
  final String? endDate;
  final String? baseCurrency;
  final double? totalIncome;
  final double? totalExpenses;
  final double? netProfit;
  final String? status;

  IncomeStatementSummary({
    this.startDate,
    this.endDate,
    this.baseCurrency,
    this.totalIncome,
    this.totalExpenses,
    this.netProfit,
    this.status,
  });

  factory IncomeStatementSummary.fromMap(Map<String, dynamic> map) {
    return IncomeStatementSummary(
      startDate: map['start_date'],
      endDate: map['end_date'],
      baseCurrency: map['base_currency'],
      totalIncome: map['total_income']?.toDouble(),
      totalExpenses: map['total_expenses']?.toDouble(),
      netProfit: map['net_profit']?.toDouble(),
      status: map['status'],
    );
  }
}