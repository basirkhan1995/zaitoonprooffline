import 'package:flutter/material.dart';
import 'package:zaitoonpro/Features/Date/shamsi_converter.dart';
import 'package:zaitoonpro/Features/Other/extensions.dart';
import 'package:zaitoonpro/Features/Other/responsive.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zaitoonpro/Features/Other/utils.dart';
import 'package:zaitoonpro/Views/Menu/Ui/Dashboard/Views/Stats/stats.dart';
import '../../../../../Auth/bloc/auth_bloc.dart';
import 'bloc/total_daily_bloc.dart';

class TotalDailyTxnView extends StatelessWidget {
  final String? fromDate;
  final String? toDate;
  const TotalDailyTxnView({super.key,this.fromDate,this.toDate});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(mobile: _Mobile(), desktop: _Desktop(fromDate, toDate),tablet: _Tablet(),);
  }
}

class _Mobile extends StatelessWidget {
  const _Mobile();

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}


class _Tablet extends StatelessWidget {
  const _Tablet();

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}


class _Desktop extends StatefulWidget {
  final String? fromDate;
  final String? toDate;

  const _Desktop(this.fromDate, this.toDate);

  @override
  State<_Desktop> createState() => _DesktopState();
}

class _DesktopState extends State<_Desktop> {
  String fromDate = DateTime.now().toFormattedDate();
  String toDate = DateTime.now().toFormattedDate();
  String? ccyCode;

  // Subtle accent colors for card accents
  final List<Color> _accentColors = [
    const Color(0xFF4FACFE),
    const Color(0xFF43E97B),
    const Color(0xFFFA709A),
    const Color(0xFFFEE140),
    const Color(0xFFA18CD1),
    const Color(0xFF00F2FE),
    const Color(0xFFFBC2EB),
    const Color(0xFFA1FFCE),
  ];

  final Map<int, Color> _assignedAccents = {};

  @override
  void initState() {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthenticatedState) {
      ccyCode = auth.loginData.company?.comLocalCcy == "USD"
          ? "\$"
          : auth.loginData.company?.comLocalCcy == "AFN"
          ? "؋"
          : auth.loginData.company?.comLocalCcy;
    }
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TotalDailyBloc>().add(
        LoadTotalDailyEvent(
          fromDate: widget.fromDate ?? fromDate,
          toDate: widget.toDate ?? toDate,
        ),
      );
    });
  }

  Color _getAccentColor(int index) {
    if (!_assignedAccents.containsKey(index)) {
      _assignedAccents[index] = _accentColors[index % _accentColors.length];
    }
    return _assignedAccents[index]!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<TotalDailyBloc, TotalDailyState>(
      builder: (context, state) {
        if (state is TotalDailyError) {
          return Center(
            child: Text(
              state.message,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (state is TotalDailyLoaded) {
          final data = state.data;

          if (data.isEmpty) {
            return const Center(child: SizedBox());
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 16.0;
              const maxCardsPerRow = 4;

              int cardsPerRow;
              if (constraints.maxWidth > 1200) {
                cardsPerRow = 4;
              } else if (constraints.maxWidth > 900) {
                cardsPerRow = 3;
              } else if (constraints.maxWidth > 600) {
                cardsPerRow = 2;
              } else {
                cardsPerRow = 1;
              }

              cardsPerRow = cardsPerRow.clamp(1, maxCardsPerRow);

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(data.length, (index) {
                  final item = data[index];
                  final percentText =
                      "${item.percentage.toStringAsFixed(1)}%";
                  final isPositive = item.isIncrease;
                  final percentColor = isPositive ? Colors.green : Colors.red;
                  final trendIcon = isPositive
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded;
                  final accentColor = _getAccentColor(index);

                  final txnName = Utils.getTransactionNames(
                    txn: item.today.txnName ?? '',
                    context: context,
                  );

                  final cardWidth = _calculateCardWidthForIndex(
                    index: index,
                    totalItems: data.length,
                    availableWidth: constraints.maxWidth,
                    cardsPerRow: cardsPerRow,
                    spacing: spacing,
                  );

                  return HoverCard(
                    child: Container(
                      width: cardWidth,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.06),
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Top accent bar
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                              ),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header with icon and label
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        txnName,
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          color: theme.colorScheme.outline.withValues(alpha: 0.7),
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.3,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: percentColor.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            trendIcon,
                                            size: 11,
                                            color: percentColor,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            percentText,
                                            style: TextStyle(
                                              color: percentColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // Amount
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        (item.today.totalAmount ?? 0).toAmount(),
                                        style: theme.textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 28,
                                          height: 1,
                                          color: theme.colorScheme.onSurface,
                                          letterSpacing: -0.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      ccyCode ?? '',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.outline.withValues(alpha: 0.4),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Footer with count
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Transaction count
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest
                                            .withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.receipt_long_outlined,
                                            size: 12,
                                            color: theme.colorScheme.outline
                                                .withValues(alpha: 0.4),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${item.today.totalCount ?? 0}',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Mini dot indicator
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: accentColor.withValues(alpha: 0.5),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            },
          );
        }

        return Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }

  double _calculateCardWidthForIndex({
    required int index,
    required int totalItems,
    required double availableWidth,
    required int cardsPerRow,
    required double spacing,
  }) {
    final rowIndex = index ~/ cardsPerRow;
    final totalRows = (totalItems / cardsPerRow).ceil();
    final isLastRow = rowIndex == totalRows - 1;
    final itemsInLastRow = totalItems % cardsPerRow;

    if (isLastRow && itemsInLastRow > 0 && itemsInLastRow < cardsPerRow) {
      final lastRowSpacing = spacing * (itemsInLastRow - 1);
      return (availableWidth - lastRowSpacing) / itemsInLastRow;
    }

    final fullRowSpacing = spacing * (cardsPerRow - 1);
    return (availableWidth - fullRowSpacing) / cardsPerRow;
  }
}