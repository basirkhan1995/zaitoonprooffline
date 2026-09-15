import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zaitoonpro/Features/Other/extensions.dart';
import 'package:zaitoonpro/Features/Other/responsive.dart';
import 'package:zaitoonpro/Features/Other/utils.dart';
import 'package:zaitoonpro/Features/Widgets/section_title.dart';
import 'package:zaitoonpro/Views/Menu/Ui/Stakeholders/Ui/IndividualDetails/Ui/Accounts/edit_add.dart';
import 'package:zaitoonpro/Views/Menu/Ui/Stakeholders/Ui/Accounts/bloc/accounts_bloc.dart';
import 'package:zaitoonpro/Views/Menu/Ui/Stakeholders/Ui/Individuals/model/individual_model.dart';
import 'package:zaitoonpro/Views/Menu/Ui/Finance/Ui/Currency/Ui/ExchangeRate/bloc/exchange_rate_bloc.dart';
import 'package:zaitoonpro/Views/Auth/bloc/auth_bloc.dart';
import '../../../../../../../../Features/Generic/shimmer.dart';
import '../../../../../../../../Features/Other/cover.dart';
import '../../../../../../../../Features/Other/znavigator.dart';
import '../../../../../../../../Features/Widgets/mobile_acc_card.dart';
import '../../../../../../../../Features/Widgets/no_data_widget.dart';
import '../../../../../../../../Features/Widgets/outline_button.dart';
import '../../../../../../../../Features/Widgets/search_field.dart';
import '../../../../../../../../Features/Widgets/zcard_mobile.dart';
import '../../../../../../../../Localizations/l10n/translations/app_localizations.dart';
import '../../../../../Report/Ui/Finance/AccountStatement/acc_statement.dart';
import '../../../Accounts/model/acc_model.dart';

class AccountsByPerIdView extends StatelessWidget {
  final IndividualsModel ind;
  const AccountsByPerIdView({super.key, required this.ind});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _Mobile(ind),
      tablet: _Desktop(ind),
      desktop: _Desktop(ind),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// MOBILE
// ═══════════════════════════════════════════════════════════════════════

class _Mobile extends StatefulWidget {
  final IndividualsModel ind;
  const _Mobile(this.ind);

  @override
  State<_Mobile> createState() => _MobileState();
}

class _MobileState extends State<_Mobile> {
  final ScrollController _scrollController = ScrollController();
  bool _isFabVisible = true;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountsBloc>().add(
        LoadAccountsEvent(ownerId: widget.ind.perId),
      );
    });

    _scrollController.addListener(_onScroll);
    super.initState();
  }

  void _onScroll() {
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (_isFabVisible) {
        setState(() {
          _isFabVisible = false;
        });
      }
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (!_isFabVisible) {
        setState(() {
          _isFabVisible = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final locale = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: color.surface,
      floatingActionButton: AnimatedSlide(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        offset: _isFabVisible ? Offset.zero : const Offset(0, 2),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _isFabVisible ? 1.0 : 0.0,
          child: FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AccountsAddEditView(perId: widget.ind.perId);
                },
              );
            },
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 4),
            child: ZSearchField(
              controller: searchController,
              hint: locale.search,
              onChanged: (value) => setState(() {}),
              icon: Icons.search,
              title: '',
            ),
          ),
          Expanded(
            child: BlocConsumer<AccountsBloc, AccountsState>(
              listener: (context, state) {
                if (state is AccountSuccessState) {
                  Navigator.of(context).pop();
                }
              },
              builder: (context, state) {
                if (state is AccountLoadingState) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is AccountErrorState) {
                  return NoDataWidget(
                    message: state.message,
                    onRefresh: () {
                      context.read<AccountsBloc>().add(
                        LoadAccountsEvent(ownerId: widget.ind.perId),
                      );
                    },
                  );
                }
                if (state is AccountLoadedState) {
                  final query = searchController.text.toLowerCase().trim();
                  final q = query.toLowerCase();

                  final filteredList = state.accounts.where((item) {
                    final name = item.accName?.toLowerCase() ?? '';
                    final number =
                    (item.accNumber ?? '').toString().toLowerCase();
                    return name.contains(q) || number.contains(q);
                  }).toList();

                  if (filteredList.isEmpty) {
                    return NoDataWidget(message: locale.noDataFound);
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<AccountsBloc>().add(
                        LoadAccountsEvent(ownerId: widget.ind.perId),
                      );
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final acc = filteredList[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4,
                          ),
                          child: MobileAccountCard(
                            showBalanceDetails: true,
                            accountName: acc.accName ?? '',
                            accountNumber: acc.accNumber?.toString() ?? '',
                            currencyCode: acc.actCurrency ?? '',
                            availableBalance:
                            acc.accAvailBalance.toDoubleAmount(),
                            currentBalance: acc.accBalance.toDoubleAmount(),
                            status: MobileStatus(
                              label: acc.accStatus == 1
                                  ? locale.active
                                  : locale.blocked,
                              color: acc.accStatus == 1
                                  ? Colors.green
                                  : Colors.red,
                              backgroundColor: (acc.accStatus == 1
                                  ? Colors.green
                                  : Colors.red)
                                  .withValues(alpha: .1),
                            ),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AccountsAddEditView(
                                  model: acc,
                                  perId: widget.ind.perId,
                                ),
                              );
                            },
                            accentColor: Utils.currencyColors(
                              acc.actCurrency ?? "",
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// DESKTOP
// ═══════════════════════════════════════════════════════════════════════

class _Desktop extends StatefulWidget {
  final IndividualsModel ind;
  const _Desktop(this.ind);

  @override
  State<_Desktop> createState() => _DesktopState();
}

class _DesktopState extends State<_Desktop> {
  final TextEditingController searchController = TextEditingController();

  /// One controller per foreign currency (auto-filled, editable).
  final Map<String, TextEditingController> _rateControllers = {};

  /// Last value we wrote into each controller via a fetch.
  /// Used to avoid clobbering user-edited values on subsequent fetches.
  final Map<String, String> _lastFetchedText = {};

  /// In-flight fetches, keyed by "FROM:TO".
  final Map<String, Completer<double>> _pendingRateRequests = {};

  /// Last built currency set — used to detect when to re-sync controllers.
  List<_BalanceLine> _lastLines = const [];

  /// Base currency from AuthBloc.
  String _baseCurrency = 'USD';
  Widget _buildRowMenu(BuildContext context, AccountsModel acc) {
    final tr = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      tooltip: '',
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      color: color.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.outline.withValues(alpha: .15)),
      ),
      icon: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.outline.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          size: 20,
          color: color.outline,
        ),
      ),
      onSelected: (value) {
        switch (value) {
          case 'statement':
            ZNavigator.goto(
              AccountStatementView(initialAccountNumber: acc.accNumber),
            );
            break;
          case 'edit':
            showDialog(
              context: context,
              builder: (_) => AccountsAddEditView(
                model: acc,
                perId: widget.ind.perId,
              ),
            );
            break;
        }
      },
      itemBuilder: (context) => [
        _menuItem(
          context,
          value: 'statement',
          icon: Icons.receipt_long_outlined,
          label: tr.accountStatement,
          iconColor: color.primary,
          subtitle: 'View transactions & balance',
        ),
        const PopupMenuDivider(height: 1),
        _menuItem(
          context,
          value: 'edit',
          icon: Icons.edit_outlined,
          label: tr.edit,
          iconColor: Colors.orange.shade700,
          subtitle: 'Modify account details',
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
      BuildContext context, {
        required String value,
        required IconData icon,
        required String label,
        required Color iconColor,
        String? subtitle,
      }) {
    final color = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopupMenuItem<String>(
      value: value,
      height: subtitle != null ? 58 : 44,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: color.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncBaseCurrency();
      context.read<AccountsBloc>().add(
        LoadAccountsEvent(ownerId: widget.ind.perId),
      );
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    for (final c in _rateControllers.values) {
      c.dispose();
    }
    // Resolve pending completers so awaiting futures don't hang.
    for (final c in _pendingRateRequests.values) {
      if (!c.isCompleted) c.complete(1.0);
    }
    _pendingRateRequests.clear();
    super.dispose();
  }

  void _syncBaseCurrency() {
    final s = context.read<AuthBloc>().state;
    if (s is AuthenticatedState) {
      final c = s.loginData.company?.comLocalCcy;
      if (c != null && c.isNotEmpty) {
        _baseCurrency = c.toUpperCase();
      }
    }
  }

  /// Dispatch a fetch for `fromCcy -> toCcy` and await the result.
  /// Does NOT cache results across screen entries — always fresh.
  Future<double> _fetchExchangeRate(String fromCcy, String toCcy) async {
    fromCcy = fromCcy.toUpperCase();
    toCcy = toCcy.toUpperCase();

    if (fromCcy == toCcy) return 1.0;

    final key = '$fromCcy:$toCcy';

    // Coalesce concurrent requests for the same pair.
    if (_pendingRateRequests.containsKey(key)) {
      return await _pendingRateRequests[key]!.future;
    }

    final completer = Completer<double>();
    _pendingRateRequests[key] = completer;

    context.read<ExchangeRateBloc>().add(
      GetExchangeRateEvent(fromCcy: fromCcy, toCcy: toCcy),
    );

    final rate = await completer.future;
    _pendingRateRequests.remove(key);
    return rate;
  }

  /// Called from the listener when the bloc emits a loaded state.
  void _handleExchangeRateResponse(
      String fromCcy, String toCcy, double rate) {
    fromCcy = fromCcy.toUpperCase();
    toCcy = toCcy.toUpperCase();

    if (toCcy != _baseCurrency) return;
    if (rate <= 0) return;

    // Fill the controller, but preserve user edits:
    // Only replace if the field is empty or still equals our last fetched value.
    final ctrl = _rateControllers[fromCcy];
    if (ctrl != null) {
      final current = ctrl.text.trim();
      final last = _lastFetchedText[fromCcy];
      if (current.isEmpty || current == last) {
        final newText = rate.toStringAsFixed(6);
        ctrl.text = newText;
        _lastFetchedText[fromCcy] = newText;
      }
    }

    // Complete any matching pending completer.
    final key = '$fromCcy:$toCcy';
    final pending = _pendingRateRequests[key];
    if (pending != null && !pending.isCompleted) {
      pending.complete(rate);
    }

    if (mounted) setState(() {});
  }

  /// Ensure one controller per foreign currency; fetch each one fresh.
  void _syncRateControllers(List<_BalanceLine> lines) {
    final foreign = lines
        .map((l) => l.currency)
        .where((c) => c.isNotEmpty && c != _baseCurrency)
        .toSet();

    // Remove controllers for currencies no longer present.
    final stale =
    _rateControllers.keys.where((c) => !foreign.contains(c)).toList();
    for (final c in stale) {
      _rateControllers.remove(c)?.dispose();
      _lastFetchedText.remove(c);
    }

    // Add controllers + always fetch fresh.
    for (final c in foreign) {
      _rateControllers.putIfAbsent(
        c,
            () => TextEditingController()..addListener(() => setState(() {})),
      );
      _fetchExchangeRate(c, _baseCurrency);
    }
  }

  double? _rateFor(String ccy) {
    if (ccy == _baseCurrency) return 1.0;
    final txt = _rateControllers[ccy]?.text.trim() ?? '';
    if (txt.isEmpty) return null;
    final v = double.tryParse(txt);
    if (v == null || v <= 0) return null;
    return v;
  }

  List<_BalanceLine> _buildLines(List<dynamic> accounts) {
    return accounts
        .map((a) => _BalanceLine(
      currency: (a.actCurrency ?? '').toString().toUpperCase(),
      current: (a.accBalance?.toString() ?? '0').toDoubleAmount(),
      available:
      (a.accAvailBalance?.toString() ?? '0').toDoubleAmount(),
    ))
        .where((l) => l.currency.isNotEmpty)
        .toList();
  }

  bool _sameCurrencySet(List<_BalanceLine> a, List<_BalanceLine> b) {
    final sa = a.map((l) => l.currency).toSet();
    final sb = b.map((l) => l.currency).toSet();
    return sa.length == sb.length && sa.containsAll(sb);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final locale = AppLocalizations.of(context)!;

    return BlocListener<ExchangeRateBloc, ExchangeRateState>(
      listener: (context, state) {
        if (state is! ExchangeRateLoadedState) return;
        if (state.rate == null ||
            state.fromCcy == null ||
            state.toCcy == null) {
          return;
        }
        final rate = double.tryParse(state.rate!) ?? 0;
        if (rate <= 0) return;
        _handleExchangeRateResponse(state.fromCcy!, state.toCcy!, rate);
      },
      child: Scaffold(
        backgroundColor: color.surface,
        body: Column(
          children: [
            // ── Toolbar ─────────────────────────────────────────
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 5.0, vertical: 8),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: ZSearchField(
                      icon: Icons.search_rounded,
                      controller: searchController,
                      hint: locale.accNameOrNumber,
                      onChanged: (_) => setState(() {}),
                      title: "",
                    ),
                  ),
                  ZOutlineButton(
                    width: 120,
                    icon: Icons.refresh,
                    onPressed: onRefresh,
                    label: Text(locale.refresh),
                  ),
                  ZOutlineButton(
                    width: 120,
                    isActive: true,
                    icon: Icons.add,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AccountsAddEditView(
                            perId: widget.ind.perId),
                      );
                    },
                    label: Text(locale.newKeyword),
                  ),
                ],
              ),
            ),

            // ── List + summary ──────────────────────────────────
            Expanded(
              child: BlocConsumer<AccountsBloc, AccountsState>(
                listener: (context, state) {
                  if (state is AccountSuccessState) {
                    Navigator.of(context).pop();
                    context.read<AccountsBloc>().add(
                      LoadAccountsEvent(ownerId: widget.ind.perId),
                    );
                  }
                },
                builder: (context, state) {
                  final textTheme = Theme.of(context).textTheme;
                  final color = Theme.of(context).colorScheme;

                  final amountTitle = textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: color.outline,
                  );
                  final amountStyle = textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  );

                  if (state is AccountLoadingState) {
                    return UniversalShimmer.accountList(
                      itemCount: 8,
                      useAlternatingColors: true,
                    );
                  }
                  if (state is AccountErrorState) {
                    return NoDataWidget(
                      message: state.message,
                      onRefresh: () {
                        context.read<AccountsBloc>().add(
                          LoadAccountsEvent(ownerId: widget.ind.perId),
                        );
                      },
                    );
                  }
                  if (state is AccountLoadedState) {
                    final query =
                    searchController.text.toLowerCase().trim();
                    final q = query.toLowerCase();

                    final filteredList = state.accounts.where((item) {
                      final name = item.accName?.toLowerCase() ?? '';
                      final number =
                      (item.accNumber ?? '').toString().toLowerCase();
                      return name.contains(q) || number.contains(q);
                    }).toList();

                    final lines = _buildLines(state.accounts);

                    if (!_sameCurrencySet(_lastLines, lines)) {
                      _lastLines = lines;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _syncRateControllers(lines);
                      });
                    }

                    return Column(
                      children: [
                        _buildSummaryCard(context, lines),
                        SizedBox(height: 8),
                        SectionTitle(title: "${locale.accounts} | ${filteredList.length}"),
                        Expanded(
                          child: filteredList.isEmpty
                              ? NoDataWidget(message: locale.noDataFound)
                              : ListView.builder(
                            padding: EdgeInsets.all(5),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final acc = filteredList[index];
                              final isAvailableEqualCurrent =
                                  acc.accAvailBalance == acc.accBalance;

                              return InkWell(
                                highlightColor: color.primary
                                    .withValues(alpha: .06),
                                hoverColor: color.primary
                                    .withValues(alpha: .06),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AccountsAddEditView(
                                      model: acc,
                                      perId: widget.ind.perId,
                                    ),
                                  );
                                },
                                child: ZCover(
                                  padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                        Utils.currencyColors(
                                          acc.actCurrency ?? "",
                                        ),
                                        radius: 22,
                                        child: Text(
                                          acc.accName
                                              ?.getFirstLetter ??
                                              "",
                                          style: TextStyle(
                                            color: color.surface,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              acc.accName ?? "",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                            const SizedBox(height: 1),
                                            Row(
                                              children: [
                                                Padding(
                                                  padding:
                                                  const EdgeInsets
                                                      .only(
                                                      right: 3.0),
                                                  child: ZCover(
                                                    color:
                                                    color.surface,
                                                    child: Text(acc
                                                        .accNumber
                                                        .toString()),
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                  const EdgeInsets
                                                      .only(
                                                      right: 3.0),
                                                  child: ZCover(
                                                    color:
                                                    color.surface,
                                                    child: Text(acc
                                                        .actCurrency
                                                        .toString()),
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                  const EdgeInsets
                                                      .only(
                                                      right: 3.0),
                                                  child: ZCover(
                                                    color:
                                                    color.surface,
                                                    child: Text(
                                                      acc.accStatus ==
                                                          1
                                                          ? locale
                                                          .active
                                                          : locale
                                                          .blocked,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        mainAxisAlignment:
                                        MainAxisAlignment.end,
                                        crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                        children: [
                                          if (!isAvailableEqualCurrent)
                                            Column(
                                              mainAxisAlignment:
                                              MainAxisAlignment
                                                  .end,
                                              crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .end,
                                              children: [
                                                Text(
                                                  locale
                                                      .currentBalance,
                                                  style:
                                                  amountTitle,
                                                  textAlign:
                                                  TextAlign.right,
                                                ),
                                                Text(
                                                  "${acc.accBalance?.toAmount()} ${acc.actCurrency}",
                                                  style:
                                                  amountStyle,
                                                  textAlign:
                                                  TextAlign.right,
                                                ),
                                              ],
                                            ),
                                          Column(
                                            mainAxisAlignment:
                                            MainAxisAlignment.end,
                                            crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                locale
                                                    .availableBalance,
                                                style: amountTitle,
                                                textAlign:
                                                TextAlign.right,
                                              ),
                                              Text(
                                                "${acc.accAvailBalance?.toAmount()} ${acc.actCurrency}",
                                                style: amountStyle,
                                                textAlign:
                                                TextAlign.right,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 5),
                                      _buildRowMenu(context, acc),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Summary card
  // ─────────────────────────────────────────────────────────────────
  Widget _buildSummaryCard(BuildContext context, List<_BalanceLine> lines) {
    final color = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = AppLocalizations.of(context)!;

    final Map<String, double> perCurrCurrent = {};
    final Map<String, double> perCurrAvail = {};
    for (final l in lines) {
      perCurrCurrent.update(
        l.currency,
            (v) => v + l.current,
        ifAbsent: () => l.current,
      );
      perCurrAvail.update(
        l.currency,
            (v) => v + l.available,
        ifAbsent: () => l.available,
      );
    }

    double totalCurrent = 0;
    double totalAvail = 0;
    bool anyMissingRate = false;

    perCurrCurrent.forEach((ccy, curr) {
      final avail = perCurrAvail[ccy] ?? 0;
      final rate = _rateFor(ccy);
      if (rate == null) {
        anyMissingRate = true;
      } else {
        totalCurrent += curr * rate;
        totalAvail += avail * rate;
      }
    });

    final foreignCurrencies = perCurrCurrent.keys
        .where((c) => c != _baseCurrency)
        .toList()
      ..sort();

    return Card(
      elevation: 0,
      color: color.primaryContainer.withValues(alpha: .30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: BorderSide(color: color.primary.withValues(alpha: .18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.balance_rounded,
                    size: 25, color: color.primary),
                const SizedBox(width: 6),
                Text(
                  '${locale.balance} | $_baseCurrency',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: color.primary,
                  ),
                ),
                const Spacer(),
                if (anyMissingRate)
                  Tooltip(
                    message:
                    'Fetching or enter rate(s) to complete the total',
                    child: const Icon(Icons.info_outline,
                        size: 18, color: Colors.orange),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: _AmountBlock(
                    label: locale.availableBalance,
                    value: '${totalAvail.toAmount()} $_baseCurrency',
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold,fontSize: 20),
                  ),
                ),
                if(totalAvail != totalCurrent)
                Expanded(
                  child: _AmountBlock(
                    label: locale.currentBalance,
                    value: '${totalCurrent.toAmount()} $_baseCurrency',
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold,fontSize: 20),
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            if (foreignCurrencies.isNotEmpty) ...[
              const Divider(height: 18),
              ...foreignCurrencies.map((ccy) {
                final curr = perCurrCurrent[ccy] ?? 0;
                final avail = perCurrAvail[ccy] ?? 0;
                final rate = _rateFor(ccy);
                final chipColor = Utils.currencyColors(ccy);

                final convertedAvail = rate == null ? null : avail * rate;
                final convertedCurr = rate == null ? null : curr * rate;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: chipColor.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                              color: chipColor.withValues(alpha: .4)),
                        ),
                        child: Text(
                          ccy,
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${avail.toAmount()} $ccy',
                              style: textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (convertedAvail != null)
                              Text(
                                '≈ ${convertedAvail.toAmount()} $_baseCurrency',
                                style: textTheme.bodySmall?.copyWith(
                                  color: color.outline,
                                ),
                              ),
                            if (convertedCurr != null &&
                                convertedCurr != convertedAvail)
                              Text(
                                'Current: ≈ ${convertedCurr.toAmount()} $_baseCurrency',
                                style: textTheme.bodySmall?.copyWith(
                                  color: color.outline,
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _rateControllers[ccy],
                          keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '1 $ccy = ?',
                            labelText: '${locale.rate} → $_baseCurrency',
                            labelStyle: textTheme.bodySmall,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  void onRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountsBloc>().add(
        LoadAccountsEvent(ownerId: widget.ind.perId),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════

class _BalanceLine {
  final String currency;
  final double current;
  final double available;
  const _BalanceLine({
    required this.currency,
    required this.current,
    required this.available,
  });
}

class _AmountBlock extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? style;
  final bool alignEnd;
  const _AmountBlock({
    required this.label,
    required this.value,
    this.style,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment:
      alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall
              ?.copyWith(fontSize: 10, color: color.outline),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: style,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        ),
      ],
    );
  }
}