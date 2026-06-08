import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:zaitoonpro/Features/Date/shamsi_converter.dart';
import 'package:zaitoonpro/Features/Other/cover.dart';
import 'package:zaitoonpro/Features/Other/extensions.dart';
import 'package:zaitoonpro/Localizations/l10n/translations/app_localizations.dart';
import 'bloc/total_daily_bloc.dart';
import 'model/total_daily_compare.dart';

class TotalDailyColumnView extends StatefulWidget {
  const TotalDailyColumnView({super.key});

  @override
  State<TotalDailyColumnView> createState() => _TotalDailyColumnViewState();
}

class _TotalDailyColumnViewState extends State<TotalDailyColumnView>
    with SingleTickerProviderStateMixin {
  late String fromDate;
  late String toDate;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    fromDate = DateTime.now().toFormattedDate();
    toDate = DateTime.now().toFormattedDate();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TotalDailyBloc>().add(
        LoadTotalDailyEvent(fromDate: fromDate, toDate: toDate),
      );
    });
    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<TotalDailyBloc, TotalDailyState>(
      builder: (context, state) {
        if (state is TotalDailyError) {
          return const SizedBox();
        }

        if (state is TotalDailyLoaded) {
          final todayData = _prepareTodayData(state.data);
          _animationController.forward();

          if (todayData.isEmpty) {
            return _buildNoDataWidget(context);
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: ZCover(
              radius: 8,
              margin: const EdgeInsets.all(4),
              borderColor: theme.colorScheme.outline.withValues(alpha: 0.08),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 12),
                  _buildChartWithStats(context, todayData),
                ],
              ),
            ),
          );
        }

        if (state is TotalDailyLoading) {
          return _buildLoadingWidget(context);
        }

        return const SizedBox();
      },
    );
  }

  // ============================================
  // HEADER
  // ============================================
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.pie_chart_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.dailyTransactions,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            context.read<TotalDailyBloc>().add(
              LoadTotalDailyEvent(fromDate: fromDate, toDate: toDate),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.refresh_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================
  // CHART + STATS IN ROW
  // ============================================
  Widget _buildChartWithStats(BuildContext context, List<_ChartItem> data) {
    final totalCount = data.fold<int>(0, (sum, item) => sum + item.count);
    final totalAmount = data.fold<double>(0, (sum, item) => sum + item.amount);
    final highestAmount = data.first;
    final mostFrequent = data.reduce((a, b) => a.count > b.count ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pie Chart - takes remaining space
        Expanded(
          flex: 4,
          child: _buildPieChart(context, data),
        ),

        const SizedBox(width: 12),

        // Summary Stats - right side column
        Expanded(
          flex: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatTile(
                context,
                icon: Icons.account_balance_wallet_outlined,
                label: AppLocalizations.of(context)!.totalVolume,
                value: totalAmount.toAmount(),
                color: Colors.blue,
              ),
              const SizedBox(height: 6),
              _buildStatTile(
                context,
                icon: Icons.receipt_long_outlined,
                label: AppLocalizations.of(context)!.totalTransactions,
                value: totalCount.toAmount(decimal: 0),
                color: Colors.green,
              ),
              const SizedBox(height: 6),
              _buildStatTile(
                context,
                icon: Icons.category_outlined,
                label: AppLocalizations.of(context)!.category,
                value: data.length.toString(),
                color: Colors.orange,
              ),
              const SizedBox(height: 6),
              _buildStatTile(
                context,
                icon: Icons.trending_up,
                label: AppLocalizations.of(context)!.highestTitle,
                value: highestAmount.name,
                subtitle: highestAmount.amount.toAmount(),
                color: Colors.purple,
              ),
              const SizedBox(height: 6),
              _buildStatTile(
                context,
                icon: Icons.repeat,
                label: AppLocalizations.of(context)!.mostFrequent,
                value: mostFrequent.name,
                subtitle: '${mostFrequent.count}',
                color: Colors.teal,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(
      BuildContext context, {
        required IconData icon,
        required String label,
        required String value,
        String? subtitle,
        required Color color,
      }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // Leading icon
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),

          // Label (left side)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.6),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Value (right side - trailing)
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // LOADING WIDGET
  // ============================================
  Widget _buildLoadingWidget(BuildContext context) {
    final theme = Theme.of(context);

    return ZCover(
      radius: 8,
      margin: const EdgeInsets.all(4),
      borderColor: theme.colorScheme.outline.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          Container(
            height: 280,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // NO DATA WIDGET
  // ============================================
  Widget _buildNoDataWidget(BuildContext context) {
    final theme = Theme.of(context);

    return ZCover(
      radius: 8,
      margin: const EdgeInsets.all(4),
      borderColor: theme.colorScheme.outline.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          Container(
            height: 280,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 48,
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Transactions Yet',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Transactions recorded today will appear here',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // DATA PREPARATION
  // ============================================
  List<_ChartItem> _prepareTodayData(List<TotalDailyCompare> data) {
    final items = <_ChartItem>[];

    for (final item in data) {
      final name = item.today.txnName ?? 'Unknown';

      double amount = 0;
      if (item.today.totalAmount != null) {
        final amountStr = item.today.totalAmount.toString();
        amount = double.tryParse(amountStr) ?? 0;
      }

      int count = 0;
      if (item.today.totalCount != null) {
        final countStr = item.today.totalCount.toString();
        count = (double.tryParse(countStr) ?? 0).round();
      }

      if (amount > 0 || count > 0) {
        items.add(_ChartItem(
          name: name,
          amount: amount,
          count: count,
        ));
      }
    }

    items.sort((a, b) => b.amount.compareTo(a.amount));
    return items;
  }

  // ============================================
  // PIE CHART - No Legend (saves space)
  // ============================================
  Widget _buildPieChart(BuildContext context, List<_ChartItem> data) {
    final theme = Theme.of(context);
    final totalAmount = data.fold<double>(0, (sum, item) => sum + item.amount);
    final colors = _getPieColors(data.length);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SfCircularChart(
          margin: const EdgeInsets.all(10),
          backgroundColor: Colors.transparent,

          // Legend - inside the chart to save space
          legend: Legend(
            isVisible: true,
            position: LegendPosition.bottom,
            overflowMode: LegendItemOverflowMode.wrap,
            textStyle: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
            iconHeight: 8,
            iconWidth: 8,
            itemPadding: 2,
          ),

          // Tooltip
          tooltipBehavior: TooltipBehavior(
            enable: true,
            header: '',
            color: theme.colorScheme.inverseSurface,
            textStyle: TextStyle(
              color: theme.colorScheme.onInverseSurface,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            builder: (dynamic data, dynamic point, dynamic series,
                int pointIndex, int seriesIndex) {
              final item = (series.dataSource as List<_ChartItem>)[pointIndex];
              final percentage = totalAmount > 0
                  ? ((item.amount / totalAmount) * 100).toStringAsFixed(1)
                  : '0';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  '${item.name}\n${_formatCurrency(item.amount)} ($percentage%)',
                  style: TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontSize: 11,
                  ),
                ),
              );
            },
          ),

          // Series
          series: <CircularSeries<_ChartItem, String>>[
            PieSeries<_ChartItem, String>(
              dataSource: data,
              xValueMapper: (_ChartItem item, _) => item.name,
              yValueMapper: (_ChartItem item, _) => item.amount,
              pointColorMapper: (_ChartItem item, index) => colors[index],

              // Data labels - percentages outside
              dataLabelSettings: DataLabelSettings(
                isVisible: true,
                labelPosition: ChartDataLabelPosition.outside,
                connectorLineSettings: const ConnectorLineSettings(
                  type: ConnectorType.curve,
                  width: 1,
                ),
                textStyle: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                builder: (dynamic label, dynamic point, dynamic series,
                    int pointIndex, int seriesIndex) {
                  final item = data[pointIndex];
                  final percentage = totalAmount > 0
                      ? ((item.amount / totalAmount) * 100).toStringAsFixed(0)
                      : '0';
                  return Text('$percentage%');
                },
              ),

              animationDuration: 1000,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // PIE COLORS
  // ============================================
  List<Color> _getPieColors(int count) {
    const baseColors = [
      Color(0xFF1565C0),
      Color(0xFF2E7D32),
      Color(0xFFC62828),
      Color(0xFFE65100),
      Color(0xFF6A1B9A),
      Color(0xFF00695C),
    ];

    if (count <= baseColors.length) {
      return baseColors.sublist(0, count);
    }

    return List.generate(count, (index) {
      if (index < baseColors.length) return baseColors[index];
      final baseColor = baseColors[index % baseColors.length];
      final hsl = HSLColor.fromColor(baseColor);
      final variation = (index ~/ baseColors.length) * 15.0;
      return hsl
          .withHue((hsl.hue + variation) % 360)
          .withSaturation((hsl.saturation - 0.1).clamp(0.4, 1.0))
          .toColor();
    });
  }

  // ============================================
  // FORMATTING HELPERS
  // ============================================
  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      symbol: 'AFN ',
      decimalDigits: 2,
    ).format(amount);
  }

}

// ============================================
// DATA MODELS
// ============================================
class _ChartItem {
  final String name;
  final double amount;
  final int count;

  _ChartItem({
    required this.name,
    required this.amount,
    required this.count,
  });
}