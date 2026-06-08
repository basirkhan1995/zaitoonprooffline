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
  @override
  void initState() {
    final auth = context.read<AuthBloc>().state;
    if(auth is AuthenticatedState){
      ccyCode = auth.loginData.company?.comLocalCcy == "USD"? "\$" : auth.loginData.company?.comLocalCcy == "AFN"? "؋" : auth.loginData.company?.comLocalCcy;
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
              const spacing = 8.0;
              const maxCardsPerRow = 4;

              // Calculate how many cards per row based on available width
              int cardsPerRow;
              if (constraints.maxWidth > 900) {
                cardsPerRow = 4;
              } else if (constraints.maxWidth > 650) {
                cardsPerRow = 3;
              } else if (constraints.maxWidth > 400) {
                cardsPerRow = 2;
              } else {
                cardsPerRow = 1;
              }

              cardsPerRow = cardsPerRow.clamp(1, maxCardsPerRow);

              final color = Theme.of(context).colorScheme;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(data.length, (index) {
                  final item = data[index];
                  final percentText = "${item.percentage.toStringAsFixed(1)} %";
                  final percentColor = item.isIncrease ? Colors.green : Colors.red;
                  final icon = item.isIncrease ? Icons.trending_up : Icons.trending_down;

                  // Calculate width for this specific card based on its row
                  final cardWidth = _calculateCardWidthForIndex(
                    index: index,
                    totalItems: data.length,
                    availableWidth: constraints.maxWidth,
                    cardsPerRow: cardsPerRow,
                    spacing: spacing,
                  );

                  return HoverCard(
                    child: SizedBox(
                      width: cardWidth,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.lightBlueAccent.withValues(alpha: .06),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: color.primary.withValues(alpha: .3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: .05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // TXN NAME
                            Text(
                              Utils.getTransactionNames(txn: item.today.txnName ?? '', context: context),
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
                                "${(item.today.totalAmount ?? 0).toAmount()}$ccyCode",
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
                                        size: 15,
                                        color: percentColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          percentText,
                                          style: TextStyle(
                                            color: percentColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
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
                    ),
                  );
                }),
              );
            },
          );
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  // Calculate card width based on its position (row-aware)
  double _calculateCardWidthForIndex({
    required int index,
    required int totalItems,
    required double availableWidth,
    required int cardsPerRow,
    required double spacing,
  }) {
    // Calculate which row this item is in (0-based)
    final rowIndex = index ~/ cardsPerRow;

    // Calculate total number of rows
    final totalRows = (totalItems / cardsPerRow).ceil();

    // Check if this is the last row
    final isLastRow = rowIndex == totalRows - 1;

    // Calculate items in the last row
    final itemsInLastRow = totalItems % cardsPerRow;

    // If it's the last row and has fewer items than cardsPerRow
    if (isLastRow && itemsInLastRow > 0 && itemsInLastRow < cardsPerRow) {
      // Calculate width based on actual items in the last row
      final lastRowSpacing = spacing * (itemsInLastRow - 1);
      return (availableWidth - lastRowSpacing) / itemsInLastRow;
    }

    // For all other rows, use standard calculation
    final fullRowSpacing = spacing * (cardsPerRow - 1);
    return (availableWidth - fullRowSpacing) / cardsPerRow;
  }
}





