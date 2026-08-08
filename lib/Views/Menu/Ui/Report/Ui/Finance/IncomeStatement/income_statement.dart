import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:zaitoonpro/Features/Date/z_generic_date.dart';
import 'package:zaitoonpro/Features/Date/z_range_picker.dart';
import 'package:zaitoonpro/Features/Other/extensions.dart';
import 'package:zaitoonpro/Features/Other/responsive.dart';
import 'package:zaitoonpro/Features/Other/utils.dart';
import 'package:zaitoonpro/Features/Widgets/outline_button.dart';
import 'package:zaitoonpro/Localizations/Bloc/localizations_bloc.dart';
import 'package:zaitoonpro/Localizations/l10n/translations/app_localizations.dart';
import 'bloc/income_statement_bloc.dart';
import 'model/income_stmt_model.dart';

class IncomeStatementView extends StatelessWidget {
  const IncomeStatementView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: const _MobileIncomeStatement(),
      tablet: const _MobileIncomeStatement(),
      desktop: const _DesktopIncomeStatement(),
    );
  }
}

// Mobile Version with Larger Fonts
class _MobileIncomeStatement extends StatefulWidget {
  const _MobileIncomeStatement();

  @override
  State<_MobileIncomeStatement> createState() => _MobileIncomeStatementState();
}

class _MobileIncomeStatementState extends State<_MobileIncomeStatement> {
  String fromDate = DateTime.now().subtract(const Duration(days: 30)).toApiStartDate();
  String toDate = DateTime.now().toApiEndDate();
  String? myLocale;

  @override
  void initState() {
    myLocale = context.read<LocalizationBloc>().state.languageCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncomeStatementBloc>().add(ResetIncomeStatementEvent());
    });
    super.initState();
  }

  void _loadIncomeStatement() {
    context.read<IncomeStatementBloc>().add(
      LoadIncomeStatementEvent(
        startDate: fromDate,
        endDate: toDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          tr.incomeStatement,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        titleSpacing: 0,
      ),
      body: BlocBuilder<IncomeStatementBloc, IncomeStatementState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Range - Bigger fonts
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Select Period',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ZDatePicker(
                        label: tr.fromDate,
                        value: fromDate,
                        onDateChanged: (v) {
                          setState(() {
                            fromDate = v;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      ZDatePicker(
                        label: tr.toDate,
                        value: toDate,
                        onDateChanged: (v) {
                          setState(() {
                            toDate = v;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Generate Button - Bigger
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: state is IncomeStatementLoadingState
                        ? null
                        : _loadIncomeStatement,
                    icon: state is IncomeStatementLoadingState
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.assessment, size: 22),
                    label: Text(
                      state is IncomeStatementLoadingState
                          ? 'Generating...'
                          : 'Generate Income Statement',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Loading State
                if (state is IncomeStatementLoadingState)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading income statement...',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Error State
                if (state is IncomeStatementErrorState)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withAlpha(30),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            state.message,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 15,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Loaded State
                if (state is IncomeStatementLoadedState) ...[
                  // Summary Card - Bigger fonts
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Income Statement Summary',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 24),
                        _buildSummaryRow(
                          context,
                          tr.totalIncome,
                          state.summary.totalIncome ?? 0,
                          state.summary.baseCurrency ?? 'USD',
                          Colors.green,
                        ),
                        _buildSummaryRow(
                          context,
                          tr.totalExpense,
                          state.summary.totalExpenses ?? 0,
                          state.summary.baseCurrency ?? 'USD',
                          Colors.red,
                        ),
                        const Divider(height: 24),
                        _buildSummaryRow(
                          context,
                          tr.netProfit,
                          state.summary.netProfit ?? 0,
                          state.summary.baseCurrency ?? 'USD',
                          (state.summary.netProfit ?? 0) >= 0
                              ? Colors.green
                              : Colors.red,
                          bold: true,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: (state.summary.netProfit ?? 0) >= 0
                                ? Colors.green.withAlpha(25)
                                : Colors.red.withAlpha(25),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            state.summary.status ?? '',
                            style: TextStyle(
                              color: (state.summary.netProfit ?? 0) >= 0
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Income Section
                  _buildSection(
                    context,
                    tr.income.toUpperCase(),
                    state.incomeStatement
                        .where((item) => item.type == 'INCOME')
                        .toList(),
                    state.summary.baseCurrency ?? 'USD',
                    Colors.green,
                  ),

                  const SizedBox(height: 12),

                  // Expense Section
                  _buildSection(
                    context,
                    'EXPENSE',
                    state.incomeStatement
                        .where((item) => item.type == 'EXPENSE')
                        .toList(),
                    state.summary.baseCurrency ?? 'USD',
                    Colors.red,
                  ),

                  const SizedBox(height: 16),

                  // Net Profit - Bigger
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (state.summary.netProfit ?? 0) >= 0
                          ? Colors.green.withAlpha(10)
                          : Colors.red.withAlpha(10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (state.summary.netProfit ?? 0) >= 0
                            ? Colors.green
                            : Colors.red,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'NET PROFIT/LOSS',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '${(state.summary.netProfit ?? 0).toAmount()} ${state.summary.baseCurrency ?? 'USD'}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: (state.summary.netProfit ?? 0) >= 0
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Initial State
                if (state is IncomeStatementInitial)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.chartLine,
                          size: 80,
                          color: Theme.of(context).colorScheme.outline.withAlpha(80),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No Data Yet',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 20,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select a date range and tap Generate\nto view the income statement',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.outline,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(
      BuildContext context,
      String label,
      double amount,
      String currency,
      Color color, {
        bool bold = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${amount.toAmount()} $currency',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 15,
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context,
      String title,
      List<IncomeStatementModel> items,
      String baseCurrency,
      Color color,
      ) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withAlpha(10),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  title == 'INCOME' ? Icons.trending_up : Icons.trending_down,
                  size: 22,
                  color: color,
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...items.map((item) => _buildListItem(context, item, baseCurrency)),
        ],
      ),
    );
  }

  Widget _buildListItem(
      BuildContext context,
      IncomeStatementModel item,
      String baseCurrency,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(10),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.accountName ?? '',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.category != null && item.category!.isNotEmpty)
                  Text(
                    item.category!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  (item.amountBase ?? 0).toAmount(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.currency != null && item.currency != baseCurrency)
                  Text(
                    '${(item.amountOriginal ?? 0).toAmount()} ${item.currency}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Desktop Version with Larger Fonts
class _DesktopIncomeStatement extends StatefulWidget {
  const _DesktopIncomeStatement();

  @override
  State<_DesktopIncomeStatement> createState() =>
      _DesktopIncomeStatementState();
}

class _DesktopIncomeStatementState extends State<_DesktopIncomeStatement> {
  late String fromDate;
  late String toDate;
  String? myLocale;

  @override
  void initState() {
    myLocale = context.read<LocalizationBloc>().state.languageCode;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final todayOfMonth = DateTime(now.year, now.month, now.day);

    fromDate = startOfMonth.toApiStartDate();
    toDate = todayOfMonth.toApiEndDate();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncomeStatementBloc>().add(ResetIncomeStatementEvent());
    });
    super.initState();
  }

  void _loadIncomeStatement() {
    context.read<IncomeStatementBloc>().add(
      LoadIncomeStatementEvent(
        startDate: fromDate.toApiStartDate(),
        endDate: toDate.toApiEndDate(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Header - Larger
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Utils.zBackButton(context),
                    const SizedBox(width: 16),
                    Text(
                      tr.incomeStatement,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 275,
                      child: ZRangeDatePicker(
                        label: "",
                        initialStartDate: DateTime.tryParse(fromDate),
                        initialEndDate: DateTime.tryParse(toDate),
                        startValue: fromDate,
                        endValue: toDate,
                        onStartDateChanged: (startDate) {
                          setState(() {
                            fromDate = startDate;
                          });
                        },
                        onEndDateChanged: (endDate) {
                          setState(() {
                            toDate = endDate;
                          });
                          _loadIncomeStatement();
                        },
                        minYear: 2000,
                        maxYear: 2100,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ZOutlineButton(
                      height: 48,
                      isActive: true,
                      onPressed: _loadIncomeStatement,
                      icon: Icons.assessment,
                      label: Text(
                        tr.applyFilter,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: BlocBuilder<IncomeStatementBloc, IncomeStatementState>(
              builder: (context, state) {
                if (state is IncomeStatementLoadingState) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          tr.loading,
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                if (state is IncomeStatementErrorState) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withAlpha(30),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            state.message,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (state is IncomeStatementLoadedState) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main Table
                        Expanded(
                          flex: 3,
                          child: _buildTable(
                            context,
                            state.incomeStatement,
                            state.summary.baseCurrency ?? 'USD',
                            state.summary,
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Summary Card
                        SizedBox(
                          width: 500,
                          child: _buildSummaryCard(
                            context,
                            state.summary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.chartLine,
                        size: 80,
                        color: Theme.of(context).colorScheme.outline.withAlpha(60),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr.noDataFound,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: 22,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select a date range and click Generate',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(
      BuildContext context,
      List<IncomeStatementModel> items,
      String baseCurrency,
      IncomeStatementSummary summary,
      ) {
    final incomeItems = items.where((item) => item.type == 'INCOME').toList();
    final expenseItems = items.where((item) => item.type == 'EXPENSE').toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(20),
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header - Larger
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withAlpha(15),
                  Theme.of(context).colorScheme.primary.withAlpha(5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    AppLocalizations.of(context)!.accountName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    AppLocalizations.of(context)!.category,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${AppLocalizations.of(context)!.amount} ($baseCurrency)',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    AppLocalizations.of(context)!.amount,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Income Section
          if (incomeItems.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.green.withAlpha(8),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.trending_up, size: 20, color: Colors.green),
                        const SizedBox(width: 10),
                        Text(
                          AppLocalizations.of(context)!.income,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 17,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      '${summary.totalIncome?.toAmount() ?? '0'} $baseCurrency',
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...incomeItems.map((item) => _buildTableRow(
              context,
              item,
              baseCurrency,
            )),
          ],

          // Expense Section
          if (expenseItems.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.red.withAlpha(8),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.trending_down, size: 20, color: Colors.red),
                        const SizedBox(width: 10),
                        Text(
                          AppLocalizations.of(context)!.expenses,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 17,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      '${summary.totalExpenses?.toAmount() ?? '0'} $baseCurrency',
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...expenseItems.map((item) => _buildTableRow(
              context,
              item,
              baseCurrency,
            )),
          ],

          // Net Profit - Larger
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (summary.netProfit ?? 0) >= 0
                      ? Colors.green.withAlpha(20)
                      : Colors.red.withAlpha(20),
                  (summary.netProfit ?? 0) >= 0
                      ? Colors.green.withAlpha(5)
                      : Colors.red.withAlpha(5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withAlpha(20),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Icon(
                        (summary.netProfit ?? 0) >= 0
                            ? Icons.arrow_circle_up
                            : Icons.arrow_circle_down,
                        color: (summary.netProfit ?? 0) >= 0
                            ? Colors.green
                            : Colors.red,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'NET ${(summary.netProfit ?? 0) >= 0 ? AppLocalizations.of(context)!.profit : AppLocalizations.of(context)!.loss}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: (summary.netProfit ?? 0) >= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    '${(summary.netProfit ?? 0).toAmount()} $baseCurrency',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 22,
                      color: (summary.netProfit ?? 0) >= 0
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (summary.netProfit ?? 0) >= 0
                        ? Colors.green.withAlpha(20)
                        : Colors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    summary.status ?? '',
                    style: TextStyle(
                      color: (summary.netProfit ?? 0) >= 0
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(
      BuildContext context,
      IncomeStatementModel item,
      String baseCurrency,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(10),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.accountName ?? '',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.accountNumber != null && item.accountNumber != 0)
                  Text(
                    '#${item.accountNumber}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.category ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              baseCurrency == item.currency? "--" : (item.amountBase ?? 0).toAmount(),
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  (item.amountOriginal ?? 0).toAmount(),
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                  ),
                ),
                if (item.currency != null && item.currency != baseCurrency)
                  Text(
                    item.currency!,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      BuildContext context,
      IncomeStatementSummary summary,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(20),
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.summarize,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.summary,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryItem(
            context,
            AppLocalizations.of(context)!.financialPeriod,
            '${summary.startDate ?? ''} - ${summary.endDate ?? ''}',
            icon: Icons.calendar_today,
          ),

          _buildSummaryItem(
            context,
            AppLocalizations.of(context)!.baseCurrency,
            summary.baseCurrency ?? 'USD',
            icon: Icons.money,
          ),

          _buildSummaryItem(
            context,
            AppLocalizations.of(context)!.totalIncome,
            '${summary.totalIncome?.toAmount() ?? '0'} ${summary.baseCurrency ?? 'USD'}',
            color: Colors.green,
            icon: Icons.trending_up,
          ),

          _buildSummaryItem(
            context,
            AppLocalizations.of(context)!.totalExpense,
            '${summary.totalExpenses?.toAmount() ?? '0'} ${summary.baseCurrency ?? 'USD'}',
            color: Colors.red,
            icon: Icons.trending_down,
          ),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (summary.netProfit ?? 0) >= 0
                  ? Colors.green.withAlpha(10)
                  : Colors.red.withAlpha(10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (summary.netProfit ?? 0) >= 0
                    ? Colors.green.withAlpha(30)
                    : Colors.red.withAlpha(30),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Net ${(summary.netProfit ?? 0) >= 0 ? AppLocalizations.of(context)!.profit : AppLocalizations.of(context)!.loss}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: (summary.netProfit ?? 0) >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (summary.netProfit ?? 0) >= 0
                            ? Colors.green.withAlpha(20)
                            : Colors.red.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        summary.status ?? '',
                        style: TextStyle(
                          color: (summary.netProfit ?? 0) >= 0
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.totalTitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${(summary.netProfit ?? 0).toAmount()} ${summary.baseCurrency ?? 'USD'}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: (summary.netProfit ?? 0) >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      BuildContext context,
      String label,
      String value, {
        Color? color,
        IconData? icon,
      }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null)
              Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
            if (icon != null) const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 15,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}