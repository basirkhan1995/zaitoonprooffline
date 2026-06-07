import 'package:flutter/material.dart';
import 'package:zaitoonpro/Features/Date/shamsi_converter.dart';
import 'package:zaitoonpro/Features/Other/extensions.dart';
import 'package:zaitoonpro/Features/Other/responsive.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  @override
  void initState() {
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
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data.map((item) {
                  final percentText = "${item.percentage.toStringAsFixed(1)} %";
                  final percentColor = item.isIncrease ? Colors.green : Colors.red;
                  final icon = item.isIncrease ? Icons.trending_up : Icons.trending_down;

                  // Calculate width: always expand to fill row
                  // 1 card = full width, 2 cards = half width each, 3 = third, 4 = quarter
                  final cardWidth = _calculateCardWidth(constraints.maxWidth, data.length);

                  return SizedBox(
                    width: cardWidth,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: .25),
                          strokeAlign: BorderSide.strokeAlignInside,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .04),
                            blurRadius: 1,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TXN NAME
                          Text(
                            item.today.txnName ?? '',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.outline.withValues(alpha: .6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 4),

                          // AMOUNT
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              (item.today.totalAmount ?? 0).toAmount(),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // PERCENTAGE + ICON + COUNT
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Percentage with icon
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      icon,
                                      size: 18,
                                      color: percentColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        percentText,
                                        style: TextStyle(
                                          color: percentColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Transaction count
                              Text(
                                '${item.today.totalCount ?? 0}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                  color: theme.colorScheme.outline.withValues(alpha: .7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          );
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  // Calculate card width: always fill the row (max 4 cards per row)
  double _calculateCardWidth(double availableWidth, int itemCount) {
    const spacing = 8.0;
    const maxCardsPerRow = 4;

    // Determine how many cards will be in the current row
    final cardsInRow = itemCount.clamp(1, maxCardsPerRow);

    // Calculate total spacing for this row
    final totalSpacing = spacing * (cardsInRow - 1);

    // Calculate width: (available space - total spacing) / number of cards
    final cardWidth = (availableWidth - totalSpacing) / cardsInRow;

    return cardWidth;
  }
}





