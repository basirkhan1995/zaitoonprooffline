import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zaitoonpro/Features/Date/shamsi_converter.dart';
import 'package:zaitoonpro/Features/Other/alert_dialog.dart';
import 'package:zaitoonpro/Features/Other/cover.dart';
import 'package:zaitoonpro/Features/Other/extensions.dart';
import 'package:zaitoonpro/Features/Other/responsive.dart';
import 'package:zaitoonpro/Features/Other/shortcut.dart';
import 'package:zaitoonpro/Features/Other/toast.dart';
import 'package:zaitoonpro/Features/Widgets/section_title.dart';
import 'package:zaitoonpro/Views/Auth/models/login_model.dart';
import 'package:zaitoonpro/Views/Menu/Ui/Reminder/add_edit_reminders.dart';
import 'package:zaitoonpro/Views/Menu/Ui/Stakeholders/Ui/Individuals/bloc/individuals_bloc.dart';
import 'package:zaitoonpro/Views/Menu/Ui/Stakeholders/Ui/Individuals/model/individual_model.dart';
import 'package:zaitoonpro/Views/Menu/Ui/Stock/Ui/OrderScreen/NewSale/bloc/sale_invoice_bloc.dart';
import '../../../../../../../Features/Generic/complex_textfield.dart';
import '../../../../../../../Features/Generic/shimmer.dart';
import '../../../../../../../Features/Generic/stock_product_field.dart';
import '../../../../../../../Features/Generic/rounded_searchable_textfield.dart';
import '../../../../../../../Features/Other/utils.dart';
import '../../../../../../../Features/Other/z_dialog.dart';
import '../../../../../../../Features/PrintSettings/print_preview.dart';
import '../../../../../../../Features/PrintSettings/report_model.dart';
import '../../../../../../../Features/Widgets/amount_display.dart';
import '../../../../../../../Features/Widgets/outline_button.dart';
import '../../../../../../../Features/Widgets/textfield_entitled.dart';
import '../../../../../../../Localizations/l10n/translations/app_localizations.dart';
import '../../../../../../Auth/bloc/auth_bloc.dart';
import '../../../../Finance/Ui/Currency/Ui/Currencies/model/ccy_model.dart';
import '../../../../Finance/Ui/Currency/Ui/ExchangeRate/bloc/exchange_rate_bloc.dart';
import '../../../../Settings/Ui/Stock/Ui/Products/bloc/products_bloc.dart';
import '../../../../Settings/Ui/Stock/Ui/Products/model/product_stock_model.dart';
import '../../../../Settings/features/Visibility/bloc/settings_visible_bloc.dart';
import '../../../../Stakeholders/Ui/Accounts/bloc/accounts_bloc.dart';
import '../../../../Stakeholders/Ui/Accounts/model/acc_model.dart';
import '../../Orders/bloc/orders_bloc.dart';
import '../Print/print.dart';
import '../Print/stock_document.dart';
import 'model/sale_invoice_items.dart';

class NewSaleView extends StatelessWidget {
  final dynamic orderId;
  const NewSaleView({super.key, this.orderId});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _DesktopNewSaleView(orderId),
      desktop: _DesktopNewSaleView(orderId),
      tablet: _DesktopNewSaleView(orderId),
    );
  }
}


class _DesktopNewSaleView extends StatefulWidget {
  final dynamic orderId;
  const _DesktopNewSaleView(this.orderId);

  @override
  State<_DesktopNewSaleView> createState() => _DesktopNewSaleViewState();
}
class _DesktopNewSaleViewState extends State<_DesktopNewSaleView> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _personController = TextEditingController();
  final TextEditingController _reference = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _generalDiscountController = TextEditingController();
  final TextEditingController _exchangeRateController = TextEditingController();
  final TextEditingController _extraChargesController = TextEditingController();
  Timer? _remarkDebounce;
  final List<List<FocusNode>> _rowFocusNodes = [];
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Uint8List _companyLogo = Uint8List(0);
  final company = ReportModel();
  String? _userName;
  String? baseCurrency;
  int? signatory;
  bool _isEditMode = false;
  final FocusNode _customerFocusNode = FocusNode();
  final FocusNode _accountFocusNode = FocusNode();
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, TextEditingController> _pcsControllers = {};
  final Map<String, TextEditingController> _discountControllers = {};
  final Map<String, TextEditingController> _localeAmountControllers = {};
  int? _selectedAccountNumber;
  Timer? _debounce;
  bool toggleProfit = true;

  void _confirmDeleteOrder() {
    final tr = AppLocalizations.of(context)!;
    final saleState = context.read<SaleInvoiceBloc>().state;
    String? ref;
    int? ordId;
    if (saleState is SaleInvoiceLoaded) {
      ref = saleState.trnRef;
      ordId = saleState.orderId;
    }
    showDialog(
        context: context,
        builder: (context) => ZAlertDialog(
            title: tr.areYouSure,
            content: tr.deleteMessage,
            onYes: (){
              context.read<OrdersBloc>().add(
                DeleteOrderEvent(
                  orderId: ordId!,
                  usrName: _userName??"",
                  ref: ref,
                  orderName: 'Sale',
                ),
              );
            })
    );
  }

  void _onRemarkChanged(String value) {
    // Cancel existing timer
    _remarkDebounce?.cancel();

    // Start new timer
    _remarkDebounce = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        context.read<SaleInvoiceBloc>().add(UpdateRemarkEvent(value));
      }
    });
  }
  void _onExchangeRateChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 1500), () {
      final rate = double.tryParse(value.replaceAll(',', ''));
      final state = context.read<SaleInvoiceBloc>().state;
      if (rate != null && rate > 0 && state is SaleInvoiceLoaded) {
        final current = state;
        if (current.exchangeRate != rate &&
            current.fromCurrency != null &&
            current.toCurrency != null) {
          context.read<SaleInvoiceBloc>().add(
            UpdateExchangeRateEvent(
              rate: rate,
              fromCurrency: current.fromCurrency!,
              toCurrency: current.toCurrency!,
            ),
          );
        }
      }
    });
  }

  Future<void> _fetchExchangeRate(String fromCurrency, String toCurrency) async {
    try {
      if (mounted) {
        context.read<SaleInvoiceBloc>().add(
          UpdateExchangeRateEvent(
            rate: -1,
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
          ),
        );
        _exchangeRateController.text = AppLocalizations.of(context)!.loading;
      }

      await context.read<SaleInvoiceBloc>().fetchExchangeRate(fromCurrency, toCurrency);
    } catch (e) {
      if (mounted) {
        ToastManager.show(
          context: context,
          title: "Error",
          message: "Failed to fetch exchange rate: $e",
          type: ToastType.error,
        );
        context.read<SaleInvoiceBloc>().add(
          UpdateExchangeRateEvent(
            rate: 1.0,
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
          ),
        );
        _exchangeRateController.text = "1.0000";
      }
    }
  }

  void _updateControllersFromState(SaleInvoiceState state) {
    if (state is SaleInvoiceLoaded) {
      if (state.exchangeRate != null && state.exchangeRate! > 0) {
        if (_exchangeRateController.text != state.exchangeRate!.toStringAsFixed(4)) {
          _exchangeRateController.text = state.exchangeRate!.toStringAsFixed(4);
        }
      }

      for (var i = 0; i < state.items.length; i++) {
        final item = state.items[i];
        if (item.localAmount != null && item.localAmount! > 0) {
          final controller = _localeAmountControllers[item.rowId];
          if (controller != null && controller.text != item.localAmount!.toAmount()) {
            controller.text = item.localAmount!.toAmount();
          }
        }
      }
    }
  }
  int? ordNumber;
  @override
  void initState() {
    super.initState();

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthenticatedState) {
      final auth = authState.loginData;
      baseCurrency = auth.company?.comLocalCcy ?? "";
      company.comName = auth.company?.comName ?? "";
      company.comAddress = auth.company?.comAddress ?? "";
      company.compPhone = auth.company?.comPhone ?? "";
      company.comEmail = auth.company?.comEmail ?? "";
      company.slogan = auth.company?.comDetails ?? '';
      company.usrPrintedBy = auth.usrName??'';
      company.comWhatsApp = auth.company?.comWhatsapp??"";
      company.comFacebook = auth.company?.comFb??"";
      company.comWebsite = auth.company?.comWebsite??"";
      company.comInstagram = auth.company?.comInsta??"";
      company.statementDate = DateTime.now().toFullDateTime;

      final base64Logo = auth.company?.comLogo;
      if (base64Logo != null && base64Logo.isNotEmpty) {
        try {
          _companyLogo = base64Decode(base64Logo);
          company.comLogo = _companyLogo;
        } catch (e) {
          _companyLogo = Uint8List(0);
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _customerFocusNode.requestFocus();
        }
      });
      final saleBloc = context.read<SaleInvoiceBloc>();
      final exchangeBloc = context.read<ExchangeRateBloc>();

      // Set base currency on bloc
      if (baseCurrency != null && baseCurrency!.isNotEmpty) {
        saleBloc.setBaseCurrency(baseCurrency!);
      }

      saleBloc.setExchangeRateBloc(exchangeBloc);

      if (widget.orderId != null) {
        _isEditMode = true;
        saleBloc.add(LoadSaleInvoiceForEditEvent(
          orderId: widget.orderId!,
          baseCurrency: baseCurrency ?? '',
        ));
      } else {
        saleBloc.add(InitializeSaleInvoiceEvent());
      }

      _clearAllControllers();
    });
  }



  @override
  void dispose() {
    _customerFocusNode.dispose();
    _accountFocusNode.dispose();
    _debounce?.cancel();
    for (final row in _rowFocusNodes) {
      for (final node in row) {
        node.dispose();
      }
    }
    _remarkDebounce?.cancel();
    _accountController.dispose();
    _personController.dispose();
    _reference.dispose();
    _remarkController.dispose();
    _generalDiscountController.dispose();
    _exchangeRateController.dispose();
    _extraChargesController.dispose();

    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    for (final controller in _pcsControllers.values) {
      controller.dispose();
    }
    for (final controller in _discountControllers.values) {
      controller.dispose();
    }
    for (final controller in _localeAmountControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Request focus when dependencies change (after first build)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _personController.text.isEmpty) {
        _customerFocusNode.requestFocus();
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final state = context.watch<AuthBloc>().state;
    if (state is! AuthenticatedState) {
      return const SizedBox();
    }

    void triggerSave() {
      final state = context.read<SaleInvoiceBloc>().state;

      if (state is SaleInvoiceLoaded) {
        _saveInvoice(context, state);
      }
    }

    void onReminder() {
      double? creditAmount;

      final saleState = context.read<SaleInvoiceBloc>().state;
      if (saleState is SaleInvoiceLoaded) {
        if (saleState.paymentMode == PaymentMode.credit) {
          // Full credit - use grand total
          creditAmount = saleState.needsExchangeRate
              ? saleState.grandTotalLocal
              : saleState.grandTotal;
        } else if (saleState.paymentMode == PaymentMode.mixed) {
          // Mixed payment - use the credit portion
          creditAmount = saleState.needsExchangeRate
              ? saleState.creditAmountLocal
              : saleState.creditAmount;
        }
      }

      showDialog(
        context: context,
        builder: (context) {
          return AddEditReminderView(
            accNumber: _selectedAccountNumber,
            dueParameter: "Receivable",
            isEnable: true,
            autoFillAmount: creditAmount, // Pass the credit amount
          );
        },
      );
    }

    final shortcuts = {
      const SingleActivator(LogicalKeyboardKey.f9): () => _onSalePrint(),
      const SingleActivator(LogicalKeyboardKey.f10): () => _onPrintStockPaper(),
      const SingleActivator(LogicalKeyboardKey.f8): () => triggerSave(),

      const SingleActivator(LogicalKeyboardKey.f1): () => _resetForm(),
      const SingleActivator(LogicalKeyboardKey.f2): () => onReminder(),
    };

    final login = state.loginData;
    _userName = login.usrName ?? "";

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthenticatedState) {
          _userName = state.loginData.usrName ?? '';
        }
      },
      child: GlobalShortcuts(
        shortcuts: shortcuts,
        child: BlocListener<SaleInvoiceBloc, SaleInvoiceState>(
          listener: (context, state) {

            if (state is SaleInvoiceLoaded && state.exchangeRate != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                 ordNumber = state.orderId;
                // Update all local amount controllers when exchange rate changes
                for (var item in state.items) {
                  final controller = _localeAmountControllers[item.rowId];
                  if (controller != null && state.safeExchangeRate > 0) {
                    final newLocalAmount = (item.salePrice ?? 0) * state.safeExchangeRate;
                    if (controller.text != newLocalAmount.toAmount()) {
                      controller.text = newLocalAmount.toAmount();
                    }
                  }
                }
              });
            }
            if (state is SaleInvoiceError) {
              ToastManager.show(
                context: context,
                title: tr.errorTitle,
                message: state.message,
                type: ToastType.error,
              );
            }
            if (state is SaleInvoiceSaved) {
              Navigator.of(context).pop();
              if (state.success) {
                String? savedInvoiceNumber = state.invoiceNumber;
                ToastManager.show(
                  context: context,
                  title: tr.successTitle,
                  message: tr.successPurchaseInvoiceMsg,
                  type: ToastType.success,
                );
                _clearAllControllers();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (savedInvoiceNumber != null && savedInvoiceNumber.isNotEmpty) {
                    _onSalePrint(invoiceNumber: savedInvoiceNumber);
                  }
                });
              } else {
                Utils.showOverlayMessage(
                  context,
                  message: "Failed to create invoice",
                  isError: true,
                );
              }
            }

            if (state is SaleInvoiceLoaded && _isEditMode) {
              setState(() {
                ordNumber = state.orderId;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Set customer name
                if (state.customer != null) {
                  _personController.text = state.customer!.perName ?? '';
                  signatory = state.customer!.perId;

                  company.partyAddress = state.customer!.addName;
                  company.partyPhone = state.customer!.perPhone;
                  company.partyCity = state.customer!.addCity;
                  company.partyProvince = state.customer!.addProvince;
                }

                // Set account (SHOW ACCOUNT NUMBER ONLY since name is empty)
                if (state.customerAccount != null) {
                  _accountController.text = '${state.customerAccount!.accNumber}';
                  _selectedAccountNumber = state.customerAccount!.accNumber;
                }

                // Set reference and remark
                _reference.text = state.trnRef ?? '';
                _remarkController.text = state.remark ?? '';

                // Set exchange rate
                if (state.exchangeRate != null && state.exchangeRate! > 0) {
                  _exchangeRateController.text = state.exchangeRate!.toStringAsFixed(4);
                }

                _isEditMode = false;
              });
            }

            if (state is SaleInvoiceLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _focusNewRowIfNeeded(state);
                _updateControllersFromState(state);
              });
            }
          },


          child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
              titleSpacing: 0,
              title: Text((widget.orderId != null)? "${tr.update.toUpperCase()} ${tr.sale.toUpperCase()} #$ordNumber" : tr.saleEntry,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 20)),
              actionsPadding: EdgeInsets.symmetric(horizontal: 10),
              actions: [
                if (_accountController.text.isNotEmpty) ...[
                  ZOutlineButton(
                    toolTip: "${tr.setReminder} - F2",
                    icon: Icons.alarm_rounded,
                    onPressed: onReminder,
                    label: Text(tr.setReminder),
                  ),
                  const SizedBox(width: 8),
                ],
                if(widget.orderId !=null)...[
                  ZOutlineButton(
                    icon: Icons.delete_outline_rounded,
                    backgroundHover: Theme.of(context).colorScheme.error,
                    onPressed: _confirmDeleteOrder,
                    label: Text(tr.delete),
                  ),
                  const SizedBox(width: 8),
                ],

                if(widget.orderId ==null)...[
                  ZOutlineButton(
                    toolTip: "${tr.newSale} - F1",
                    icon: Icons.refresh,
                    onPressed: _resetForm,
                    label: Text(tr.newSale),
                  ),
                  const SizedBox(width: 8),
                ],

                ZOutlineButton(
                  toolTip: "${tr.stockPaper} - F10",
                  icon: Icons.receipt,
                  onPressed: () => _onPrintStockPaper(),
                  label: Text(tr.stockPaper),
                ),
                const SizedBox(width: 8),
                ZOutlineButton(
                  toolTip: "${tr.print} - F9",
                  icon: Icons.print,
                  onPressed: () => _onSalePrint(invoiceNumber: ordNumber.toString()),
                  label: Text(tr.print.toUpperCase()),
                ),
                const SizedBox(width: 8),

                if(widget.orderId == null)...[
                  BlocBuilder<SaleInvoiceBloc, SaleInvoiceState>(
                    builder: (context, state) {
                      if (state is SaleInvoiceLoaded || state is SaleInvoiceSaving) {
                        final current = state is SaleInvoiceSaving ? state : (state as SaleInvoiceLoaded);
                        final isSaving = state is SaleInvoiceSaving;
                        return ZOutlineButton(
                          toolTip: "${tr.print} - F8",
                          isActive: true,
                          icon: Icons.save_rounded,
                          onPressed: (isSaving)
                              ? null
                              : () => _saveInvoice(context, current),
                          label: isSaving
                              ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.surface,
                            ),
                          ) : Text(tr.saveTitle),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ] else ...[
                  BlocBuilder<SaleInvoiceBloc, SaleInvoiceState>(
                    builder: (context, state) {
                      if (state is SaleInvoiceLoaded || state is SaleInvoiceSaving) {
                        final current = state is SaleInvoiceSaving ? state : (state as SaleInvoiceLoaded);
                        final isSaving = state is SaleInvoiceSaving;

                        return ZOutlineButton(
                          isActive: true,
                          icon: Icons.refresh,
                          onPressed: (isSaving)
                              ? null
                              :  ()=> _updateInvoice(context, current),
                          label: isSaving
                              ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.surface,
                            ),
                          )
                              : Text(tr.update),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ]
              ],
            ),
            body: Container(
              margin: EdgeInsets.all(15),
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.all(0.0),
                  child: BlocBuilder<SaleInvoiceBloc, SaleInvoiceState>(
                      builder: (context,state) {
                        // Check if we're in loading state
                        final isLoading = state is SaleInvoiceLoading ||
                            (state is SaleInvoiceLoaded && state.items.isEmpty && state.customer == null && _isEditMode);

                        if (isLoading) {
                          // Show full shimmer while loading
                          return UniversalShimmer.invoiceLoading();
                        }
                        if(state is SaleInvoiceLoaded || state is SaleInvoiceSaving){
                          final current = state is SaleInvoiceSaving ? state : (state as SaleInvoiceLoaded);
                          _synchronizeFocusNodes(current.items.length);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Customer and Account Selection
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: GenericTextField<IndividualsModel, IndividualsBloc, IndividualsState>(
                                      key: const ValueKey('person_field'),
                                      focusNode: _customerFocusNode,
                                      controller: _personController,
                                      title: tr.customer,
                                      hintText: tr.customer,
                                      isRequired: true,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return tr.required(tr.customer);
                                        }
                                        return null;
                                      },
                                      bloc: context.read<IndividualsBloc>(),
                                      fetchAllFunction: (bloc) => bloc.add(const LoadIndividualsEvent()),
                                      searchFunction: (bloc, query) => bloc.add(LoadIndividualsEvent(search: query)),
                                      itemBuilder: (context, ind) => Padding(
                                        padding: const EdgeInsets.all(5.0),
                                        child: Text("${ind.perName ?? ''} ${ind.perLastName ?? ''}",style: Theme.of(context).textTheme.titleSmall,),
                                      ),
                                      itemToString: (individual) => "${individual.perName} ${individual.perLastName}",
                                      stateToLoading: (state) => state is IndividualLoadingState,
                                      stateToItems: (state) {
                                        if (state is IndividualLoadedState) {
                                          return state.individuals;
                                        }
                                        return [];
                                      },
                                      onSelected: (value) {
                                        _personController.text = "${value.perName} ${value.perLastName}";
                                        context.read<SaleInvoiceBloc>().add(SelectCustomerEvent(value));
                                        context.read<AccountsBloc>().add(LoadAccountsEvent(ownerId: value.perId));
                                        setState(() {
                                          signatory = value.perId;
                                          company.partyAddress = value.addName;
                                          company.partyPhone = value.perPhone;
                                          company.partyCity = value.addCity;
                                          company.partyProvince = value.addProvince;
                                        });
                                        _shouldAutoFocusProduct = false;
                                        Future.delayed(const Duration(milliseconds: 300), () {
                                          if (mounted) {
                                            _accountFocusNode.requestFocus();
                                          }
                                        });
                                      },
                                      showClearButton: true,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: BlocBuilder<SaleInvoiceBloc, SaleInvoiceState>(
                                      builder: (context, state) {
                                        if (state is SaleInvoiceLoaded) {
                                          final current = state;
                                          return GenericTextField<AccountsModel, AccountsBloc, AccountsState>(
                                            key: const ValueKey('account_field'),
                                            focusNode: _accountFocusNode,
                                            controller: _accountController,
                                            title: tr.accounts,
                                            hintText: tr.selectAccount,
                                            isRequired: current.paymentMode != PaymentMode.cash,
                                            validator: (value) {
                                              if (current.paymentMode != PaymentMode.cash && (value == null || value.isEmpty)) {
                                                return tr.selectCreditAccountMsg;
                                              }
                                              return null;
                                            },
                                            bloc: context.read<AccountsBloc>(),
                                            fetchAllFunction: (bloc) => bloc.add(LoadAccountsEvent(ownerId: signatory)),
                                            searchFunction: (bloc, query) => bloc.add(LoadAccountsEvent(ownerId: signatory)),
                                            itemBuilder: (context, account) => ListTile(
                                              visualDensity: const VisualDensity(vertical: -4, horizontal: -4),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 5),
                                              title: Text(account.accName ?? ''),
                                              subtitle: Text('${account.accNumber}'),
                                              trailing: Column(
                                                mainAxisAlignment: MainAxisAlignment.start,
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    tr.balance,
                                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                      color: Theme.of(context).colorScheme.outline,
                                                    ),
                                                  ),
                                                  Text(
                                                    "${account.accAvailBalance?.toAmount() ?? "0.0"} ${account.actCurrency}",
                                                    style: Theme.of(context).textTheme.titleSmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            itemToString: (account) => '${account.accName} (${account.accNumber})',
                                            stateToLoading: (state) => state is AccountLoadingState,
                                            stateToItems: (state) {
                                              if (state is AccountLoadedState) {
                                                return state.accounts;
                                              }
                                              return [];
                                            },
                                            onSelected: (value) {
                                              setState(() {
                                                _accountController.text = '${value.accName} (${value.accNumber})';
                                                _selectedAccountNumber = value.accNumber;
                                              });
                                              context.read<SaleInvoiceBloc>().add(SelectCustomerAccountEvent(value));

                                              _shouldAutoFocusProduct = true;
                                              final authState = context.read<AuthBloc>().state;
                                              if (authState is AuthenticatedState) {
                                                final baseCurr = authState.loginData.company?.comLocalCcy ?? '';
                                                final accountCurrency = value.actCurrency ?? '';

                                                if (baseCurr.isNotEmpty && accountCurrency.isNotEmpty && baseCurr != accountCurrency) {
                                                  _fetchExchangeRate(baseCurr, accountCurrency);
                                                } else {
                                                  context.read<SaleInvoiceBloc>().add(
                                                    UpdateExchangeRateEvent(
                                                      rate: 1.0,
                                                      fromCurrency: baseCurr,
                                                      toCurrency: accountCurrency,
                                                    ),
                                                  );
                                                  _exchangeRateController.text = "1.0000";
                                                }
                                              }
                                            },
                                            showClearButton: true,
                                          );
                                        }
                                        return GenericTextField<AccountsModel, AccountsBloc, AccountsState>(
                                          key: const ValueKey('account_field'),
                                          controller: _accountController,
                                          focusNode: _accountFocusNode,
                                          title: tr.accounts,
                                          hintText: tr.selectAccount,
                                          isRequired: false,
                                          bloc: context.read<AccountsBloc>(),
                                          fetchAllFunction: (bloc) => bloc.add(LoadAccountsFilterEvent(include: '8', exclude: '')),
                                          searchFunction: (bloc, query) => bloc.add(LoadAccountsFilterEvent(input: query, include: '8', exclude: '')),
                                          itemBuilder: (context, account) => ListTile(
                                            title: Text(account.accName ?? ''),
                                            subtitle: Text('${account.accNumber} - ${tr.balance}: ${account.accAvailBalance?.toAmount() ?? "0.0"}'),
                                            trailing: Text(account.actCurrency ?? ""),
                                          ),
                                          itemToString: (account) => '${account.accName} (${account.accNumber})',
                                          stateToLoading: (state) => state is AccountLoadingState,
                                          stateToItems: (state) {
                                            if (state is AccountLoadedState) {
                                              return state.accounts;
                                            }
                                            return [];
                                          },
                                          onSelected: (value) {
                                            setState(() {
                                              _accountController.text = '${value.accName} (${value.accNumber})';
                                              _selectedAccountNumber = value.accNumber;
                                            });

                                            context.read<SaleInvoiceBloc>().add(SelectCustomerAccountEvent(value));
                                            _shouldAutoFocusProduct = true;
                                            final authState = context.read<AuthBloc>().state;
                                            if (authState is AuthenticatedState) {
                                              final baseCurr = authState.loginData.company?.comLocalCcy ?? '';
                                              final accountCurrency = value.actCurrency ?? '';

                                              if (baseCurr.isNotEmpty && accountCurrency.isNotEmpty && baseCurr != accountCurrency) {
                                                _fetchExchangeRate(baseCurr, accountCurrency);
                                              } else {
                                                context.read<SaleInvoiceBloc>().add(
                                                  UpdateExchangeRateEvent(
                                                    rate: 1.0,
                                                    fromCurrency: baseCurr,
                                                    toCurrency: accountCurrency,
                                                  ),
                                                );
                                                _exchangeRateController.text = "1.0000";
                                              }
                                            }
                                          },
                                          showClearButton: true,
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 4),

                                  BlocBuilder<SaleInvoiceBloc, SaleInvoiceState>(
                                    builder: (context, state) {
                                      // Check condition INSIDE the builder
                                      bool shouldShowExchangeRate = false;
                                      if (state is SaleInvoiceLoaded) {
                                        final base = baseCurrency ?? state.fromCurrency ?? '';
                                        final toCcy = state.toCurrency ?? '';
                                        shouldShowExchangeRate = base.isNotEmpty && toCcy.isNotEmpty && base != toCcy;
                                      }

                                      if (shouldShowExchangeRate && state is SaleInvoiceLoaded && state.needsExchangeRate) {
                                        final isLoading = state.isExchangeRateLoading;
                                        return Expanded(
                                          child: ZTextFieldEntitled(
                                            controller: _exchangeRateController,
                                            isRequired: true,
                                            showClearButton: true,
                                            title: tr.exchangeRate,
                                            hint: isLoading ? tr.loading : tr.exchangeRate,
                                            isEnabled: !isLoading,
                                            validator: (value){
                                              if(value.isEmpty){
                                                return tr.required(tr.exchangeRate);
                                              }
                                              return null;
                                            },
                                            compactMode: true,
                                            onChanged: _onExchangeRateChanged,
                                            onSubmit: _onExchangeRateChanged,
                                            trailing: isLoading ? Container(
                                              padding: EdgeInsets.all(2),
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ) : null,
                                            inputFormat: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,6}'))],
                                          ),
                                        );
                                      }
                                      return const SizedBox();
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    flex: 2,
                                    child: ZTextFieldEntitled(
                                        showClearButton: true,
                                        controller: _remarkController,
                                        maxLength: 100,
                                        title: tr.remark,
                                        onChanged: _onRemarkChanged
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              BlocBuilder<SaleInvoiceBloc, SaleInvoiceState>(
                                builder: (context, state) {
                                  return _buildItemsHeader(context);
                                },
                              ),
                              const SizedBox(height: 8),

                              Expanded(
                                child: BlocBuilder<SaleInvoiceBloc, SaleInvoiceState>(
                                  builder: (context, state) {
                                    if (state is SaleInvoiceLoaded || state is SaleInvoiceSaving) {
                                      final current = state is SaleInvoiceSaving ? state : (state as SaleInvoiceLoaded);
                                      _synchronizeFocusNodes(current.items.length);
                                      return ListView.builder(
                                        itemCount: current.items.length,

                                        itemBuilder: (context, index) {
                                          final item = current.items[index];
                                          final isLastRow = index == current.items.length - 1;
                                          final nodes = _rowFocusNodes[index];
                                          return _buildItemRow(
                                            item: item,
                                            nodes: nodes,
                                            isLastRow: isLastRow,
                                            index: index,
                                            context: context,
                                          );
                                        },
                                      );
                                    }
                                    return const Center(child: CircularProgressIndicator());
                                  },
                                ),
                              ),

                              _buildSummarySection(context),
                            ],
                          );
                        }
                        return const SizedBox();
                      }
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _resetForm() {
    _clearAllControllers();
    context.read<SaleInvoiceBloc>().add(ResetSaleInvoiceEvent());
    _rowFocusNodes.clear();
    _priceControllers.clear();
    _qtyControllers.clear();
    _pcsControllers.clear();
    _discountControllers.clear();
    _localeAmountControllers.clear();
    context.read<SaleInvoiceBloc>().add(InitializeSaleInvoiceEvent());

    //TO reset
    context.read<SaleInvoiceBloc>().add(const UpdateRemarkEvent(''));
  }

  void _clearAllControllers() {
    _accountController.clear();
    _personController.clear();
    _reference.clear();
    _remarkController.clear();
    _generalDiscountController.clear();
    _exchangeRateController.clear();
    _extraChargesController.clear();
    _priceControllers.clear();
    _qtyControllers.clear();
    _pcsControllers.clear();
    _discountControllers.clear();
    _localeAmountControllers.clear();
  }

  String _getAccountCurrency(BuildContext context) {
    final state = context.read<SaleInvoiceBloc>().state;
    if (state is SaleInvoiceLoaded && state.customerAccount != null) {
      return state.customerAccount!.actCurrency ?? '';
    }
    return '';
  }

  Widget _buildItemsHeader(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme;
    TextStyle? title = Theme.of(context).textTheme.titleSmall?.copyWith(color: color.surface);
    final visibility = context.read<SettingsVisibleBloc>().state;
    final needsLocalConv = _needsLocalConversion(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.primary,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          const SizedBox(width: 30, child: Text('#', textAlign: TextAlign.center)),
          Expanded(child: Text(locale.products, style: title)),
          SizedBox(width: 80, child: Text(locale.qty)),
          if(visibility.isWholeSale)
            SizedBox(width: 100, child: Text(locale.batchTitle)),
          SizedBox(width: 100, child: Text(locale.unit)),
          SizedBox(width: 130, child: Text("${locale.unitPrice} | $baseCurrency")),
          if (needsLocalConv)
            SizedBox(width: 130, child: Text("${locale.unitPrice} | ${_getAccountCurrency(context)}")),
          SizedBox(width: 140, child: Text(locale.discountTitle)),
          SizedBox(width: 140, child: Text("${locale.totalTitle} | $baseCurrency")),
          SizedBox(width: 60, child: Text(locale.actions)),
        ].map((child) => DefaultTextStyle(style: title!, child: child)).toList(),
      ),
    );
  }

  Widget _buildItemRow({required BuildContext context, required SaleInvoiceItem item, required List<FocusNode> nodes, required bool isLastRow, required int index,}) {
    final visibility = context.read<SettingsVisibleBloc>().state;
    final tr = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme;
    final needsLocalConv = _needsLocalConversion(context);

    // Flags to prevent recursive updates
    bool isUpdatingFromLocal = false;
    bool isUpdatingFromBase = false;
    bool isLocalEditing = false;
    Timer? localEditTimer;
    Timer? localAmountDebounceTimer; // Debounce timer for local amount changes
    bool isProgrammaticUpdate = false; // Flag to prevent cursor jumping on programmatic updates

    final productController = TextEditingController(text: item.productName);
    final headerProductController = TextEditingController(text: item.productName);

    final qtyController = _qtyControllers.putIfAbsent(
      item.rowId,
          () => TextEditingController(text: item.qty > 0 ? item.qty.toString() : ''),
    );

    final salePriceController = _priceControllers.putIfAbsent(
      "sale_${item.rowId}",
          () => TextEditingController(
        text: item.salePrice != null && item.salePrice! > 0 ? item.salePrice!.toAmount(decimal: 4) : '',
      ),
    );

    final discountController = _discountControllers.putIfAbsent(
      "sale_${item.rowId}",
          () => TextEditingController(
        text: item.discount != null && item.discount! > 0 ? item.discount!.toAmount() : '',
      ),
    );

    final batchController = _pcsControllers.putIfAbsent(
      "sale_${item.rowId}",
          () => TextEditingController(
        text: item.batch != null && item.batch! > 0 ? item.batch!.toAmount(decimal: 0) : '',
      ),
    );

    final unitController = TextEditingController(text: item.unit ?? '');
    final localAmountController = _localeAmountControllers.putIfAbsent(
      item.rowId,
          () => TextEditingController(),
    );

    // Get focus nodes
    final basePriceFocusNode = nodes[2];
    final discountFocusNode = needsLocalConv && nodes.length > 4 ? nodes[3] : nodes[3];
    final localAmountFocusNode = needsLocalConv && nodes.length > 4 ? nodes[4] : null;

    // Save cursor positions
    int lastLocalCursorPosition = 0;
    int lastBaseCursorPosition = 0;

    // Listen to focus changes to save cursor positions
    basePriceFocusNode.addListener(() {
      if (basePriceFocusNode.hasFocus) {
        lastBaseCursorPosition = salePriceController.selection.baseOffset;
      }
    });

    localAmountFocusNode?.addListener(() {
      if (localAmountFocusNode.hasFocus) {
        lastLocalCursorPosition = localAmountController.selection.baseOffset;
      } else {
        // Clear editing flag when focus is lost
        isLocalEditing = false;
        localEditTimer?.cancel();
      }
    });

    // Smooth update for local amount without losing cursor
    void updateLocalAmountSmoothly(double newLocalAmount) {
      if (isProgrammaticUpdate) return;
      if (isLocalEditing) return;

      final newText = newLocalAmount.toAmount();
      final currentText = localAmountController.text;

      if (currentText != newText && newText.isNotEmpty) {
        isProgrammaticUpdate = true;

        final hadFocus = localAmountFocusNode?.hasFocus ?? false;
        final savedPosition = lastLocalCursorPosition;

        localAmountController.text = newText;

        // Restore cursor position if the field had focus
        if (hadFocus && savedPosition <= newText.length && savedPosition > 0) {
          localAmountController.selection = TextSelection.collapsed(offset: savedPosition);
        } else if (hadFocus && newText.isNotEmpty) {
          localAmountController.selection = TextSelection.collapsed(offset: newText.length);
        }

        // Reset the flag after a short delay
        Future.delayed(const Duration(milliseconds: 50), () {
          isProgrammaticUpdate = false;
        });
      }
    }

    // Schedule local amount update with debounce
    void scheduleLocalAmountUpdate(double newLocalAmount) {
      if (isLocalEditing) return;

      localAmountDebounceTimer?.cancel();
      localAmountDebounceTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted && !isLocalEditing) {
          updateLocalAmountSmoothly(newLocalAmount);
        }
      });
    }

    // Update local amount display when exchange rate changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<SaleInvoiceBloc>().state;
      if (state is SaleInvoiceLoaded && !isUpdatingFromLocal && !isUpdatingFromBase && !isLocalEditing) {
        if (state.safeExchangeRate > 0 && (item.salePrice ?? 0) > 0) {
          final newLocalAmount = (item.salePrice ?? 0) * state.safeExchangeRate;
          scheduleLocalAmountUpdate(newLocalAmount);
        }
      }
    });

    void updateSalePrice(double newPrice) {
      if (isUpdatingFromLocal) return;
      isUpdatingFromBase = true;

      // Save base price cursor
      final hadBaseFocus = basePriceFocusNode.hasFocus;
      final savedBaseCursor = salePriceController.selection.baseOffset;

      context.read<SaleInvoiceBloc>().add(
        UpdateSaleItemEvent(
          rowId: item.rowId,
          salePrice: newPrice,
        ),
      );

      // Update local amount after price change
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final state = context.read<SaleInvoiceBloc>().state;
        if (state is SaleInvoiceLoaded && state.safeExchangeRate > 0 && newPrice > 0) {
          final updatedLocalAmount = newPrice * state.safeExchangeRate;
          if (!isLocalEditing) {
            scheduleLocalAmountUpdate(updatedLocalAmount);
          }
        }

        // Restore base price cursor
        if (hadBaseFocus && mounted) {
          final newText = salePriceController.text;
          if (savedBaseCursor <= newText.length && savedBaseCursor > 0) {
            salePriceController.selection = TextSelection.collapsed(offset: savedBaseCursor);
          } else if (newText.isNotEmpty) {
            salePriceController.selection = TextSelection.collapsed(offset: newText.length);
          }
        }

        isUpdatingFromBase = false;
      });
    }

    void updateLocalAmount(double newLocalAmount) {
      if (isUpdatingFromBase) return;

      // Cancel any pending debounced updates
      localAmountDebounceTimer?.cancel();

      // Allow zero or empty
      if (newLocalAmount <= 0) {
        if (newLocalAmount == 0) {
          updateSalePrice(0);
          salePriceController.text = '0';
        }
        return;
      }

      // Mark that user is editing
      isLocalEditing = true;
      localEditTimer?.cancel();
      localEditTimer = Timer(const Duration(milliseconds: 800), () {
        isLocalEditing = false;
      });

      isUpdatingFromLocal = true;

      // Save cursor position
      final savedCursorPos = localAmountController.selection.baseOffset;

      final state = context.read<SaleInvoiceBloc>().state;
      if (state is SaleInvoiceLoaded && state.safeExchangeRate > 0) {
        final newSalePrice = newLocalAmount / state.safeExchangeRate;

        // Update sale price controller immediately
        final newSalePriceText = newSalePrice.toAmount(decimal: 4);
        if (salePriceController.text != newSalePriceText) {
          final hadBaseFocus = basePriceFocusNode.hasFocus;
          final savedBasePos = lastBaseCursorPosition;

          salePriceController.text = newSalePriceText;

          // Restore base price cursor if it had focus
          if (hadBaseFocus && savedBasePos <= newSalePriceText.length && savedBasePos > 0) {
            salePriceController.selection = TextSelection.collapsed(offset: savedBasePos);
          }
        }

        // Use the dedicated event for local amount update
        context.read<SaleInvoiceBloc>().add(
          UpdateItemLocalAmountEvent(
            rowId: item.rowId,
            localAmount: newLocalAmount,
          ),
        );
      }

      // Restore local amount cursor position after rebuild
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (localAmountFocusNode?.hasFocus == true && mounted) {
          final newText = localAmountController.text;
          if (savedCursorPos <= newText.length && savedCursorPos > 0) {
            localAmountController.selection = TextSelection.collapsed(offset: savedCursorPos);
          } else if (newText.isNotEmpty) {
            localAmountController.selection = TextSelection.collapsed(offset: newText.length);
          }
        }
        isUpdatingFromLocal = false;
      });
    }

    void onLocalAmountChanged(String value) {
      // Cancel any pending debounced updates
      localAmountDebounceTimer?.cancel();

      // Debounce the actual update
      localAmountDebounceTimer = Timer(const Duration(milliseconds: 400), () {
        if (value.isEmpty) {
          updateLocalAmount(0);
          return;
        }
        final localAmount = double.tryParse(value) ?? 0;
        updateLocalAmount(localAmount);
      });
    }

    void addProduct(ProductsStockModel product) {
      if (!mounted) return;

      final salePrice = double.tryParse(product.sellPrice?.toAmount(decimal: 8) ?? "0.0") ?? 0.0;
      final averagePrice = double.tryParse(product.averagePrice?.toAmount(decimal: 8) ?? "0.0") ?? 0.0;
      final landedPrice = double.tryParse(product.recentLandedPurPrice?.toAmount(decimal: 8) ?? "0.0") ?? 0.0;
      final purchasePrice = double.tryParse(product.recentPurPrice?.toAmount(decimal: 8) ?? "0.0") ?? 0.0;
      final batch = product.stkQtyInBatch;

      context.read<SaleInvoiceBloc>().add(
        UpdateSaleItemEvent(
          rowId: item.rowId,
          productId: product.proId.toString(),
          productName: product.proName ?? '',
          storageId: product.stkStorage,
          storageName: product.stgName ?? '',
          sku: product.proCode,
          purPrice: averagePrice,
          salePrice: salePrice,
          landedPrice: landedPrice,
          purchasePrice: purchasePrice,
          batch: batch ?? 0,
        ),
      );

      if (product.proUnit != null && product.proUnit!.isNotEmpty) {
        context.read<SaleInvoiceBloc>().add(UpdateItemUnitEvent(rowId: item.rowId, unit: product.proUnit!));
        unitController.text = product.proUnit!;
      }

      if (batch != null && batch > 0) {
        batchController.text = batch.toString();
      }

      salePriceController.text = salePrice.toAmount(decimal: 4);

      // Update local amount based on exchange rate
      final state = context.read<SaleInvoiceBloc>().state;
      if (state is SaleInvoiceLoaded && state.safeExchangeRate > 0 && salePrice > 0) {
        final localAmount = salePrice * state.safeExchangeRate;
        updateLocalAmountSmoothly(localAmount);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (nodes.length > 1 && nodes[1].canRequestFocus) {
          nodes[1].requestFocus();
        }
      });
    }

    void onProductSelected(ProductsStockModel? product) {
      if (product == null) return;

      final currentState = context.read<SaleInvoiceBloc>().state;
      if (currentState is! SaleInvoiceLoaded) return;

      final productId = product.proId.toString();
      final batch = product.stkQtyInBatch;

      // Check for duplicate
      final isDuplicate = currentState.items.any((item) =>
      item.productId == productId && item.batch == batch
      );

      if (isDuplicate) {
        // Store the selected product
        final selectedProduct = product;

        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: .6),
          builder: (dialogContext) {
            final FocusNode dialogFocusNode = FocusNode();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              dialogFocusNode.requestFocus();
            });

            return TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: Focus(
                focusNode: dialogFocusNode,
                autofocus: true,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.escape) {
                      Navigator.pop(dialogContext);
                      productController.clear();
                      headerProductController.clear();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (nodes.length > 1 && nodes[1].canRequestFocus) {
                          nodes[1].requestFocus();
                        }
                      });
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                      Navigator.pop(dialogContext);
                      addProduct(selectedProduct);
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: AlertDialog(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                  content: Container(
                    width: 450,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr.duplicateProduct.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tr.itemAlreadyExists,
                                      style: TextStyle(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Product info card
                              TweenAnimationBuilder(
                                tween: Tween<double>(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutQuad,
                                builder: (context, opacity, child) {
                                  return Opacity(
                                    opacity: opacity,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: .2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.inventory_2_rounded,
                                            color: Theme.of(context).colorScheme.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            tr.productDetails.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context).colorScheme.primary,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        selectedProduct.proName ?? '',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                      if (batch != null && batch > 0) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.local_offer_outlined,
                                                size: 12,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${tr.batchTitle}: $batch',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(context).colorScheme.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Warning message
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.error.withValues(alpha: .2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: Theme.of(context).colorScheme.error,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        tr.duplicateEntry,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context).colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Action buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ZOutlineButton(
                                      backgroundHover: Theme.of(context).colorScheme.error,
                                      onPressed: () {
                                        Navigator.pop(dialogContext);
                                        productController.clear();
                                        headerProductController.clear();
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          Future.delayed(const Duration(milliseconds: 50), () {
                                            if (mounted && nodes.isNotEmpty && nodes[0].canRequestFocus) {
                                              nodes[0].requestFocus();
                                            }
                                          });
                                        });
                                      },
                                      label: Text(
                                        tr.cancel.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: ZOutlineButton(
                                      onPressed: () {
                                        Navigator.pop(dialogContext);
                                        addProduct(selectedProduct);
                                      },
                                      isActive: true,
                                      label: Text(
                                        tr.addAgain,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
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
                ),
              ),
            );
          },
        );
        return;
      }

      // No duplicate - add product directly
      addProduct(product);
    }

    // Handle focus navigation
    void onBasePriceSubmitted() {
      if (needsLocalConv && localAmountFocusNode != null) {
        // Focus local amount field if it exists
        localAmountFocusNode.requestFocus();
      } else {
        // Focus discount field
        discountFocusNode.requestFocus();
      }
    }

    void onLocalAmountSubmitted() {
      // Cancel any pending debounce and trigger immediate update
      localAmountDebounceTimer?.cancel();
      final currentValue = double.tryParse(localAmountController.text) ?? 0;
      if (currentValue > 0) {
        updateLocalAmount(currentValue);
      }
      // Move to discount field
      discountFocusNode.requestFocus();
    }

    void onDiscountSubmitted() {
      if (isLastRow) {
        _addNewRowAndFocus();
      } else {
        if (index + 1 < _rowFocusNodes.length && _rowFocusNodes[index + 1].isNotEmpty) {
          _rowFocusNodes[index + 1][0].requestFocus();
        }
      }
    }

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              // Row number
              SizedBox(width: 50, child: Text((index + 1).toString(), textAlign: TextAlign.center)),

              // Product field
              Expanded(
                child: ProductSearchField<ProductsStockModel, ProductsBloc, ProductsState>(
                  controller: productController,
                  headerSearchController: headerProductController,
                  hintText: tr.products,
                  focusNode: nodes[0],
                  bloc: context.read<ProductsBloc>(),
                  searchFunction: (bloc, query) => bloc.add(LoadProductsStockEvent(input: query)),
                  fetchAllFunction: (bloc) => bloc.add(LoadProductsStockEvent()),
                  stateToItems: (state) {
                    if (state is ProductsStockLoadedState) return state.products;
                    return [];
                  },
                  stateToLoading: (state) => state is ProductsLoadingState,
                  itemToString: (product) => product.proName ?? '',
                  getProductId: (product) => product.proId?.toString(),
                  getProductName: (product) => product.proName,
                  getProductCode: (product) => product.proCode,
                  getStorageId: (product) => product.stkStorage,
                  getStorageName: (product) => product.stgName,
                  getAvailable: (product) => product.available,
                  getBatch: (product) => product.stkQtyInBatch,
                  getLandedPrice: (product) => product.recentLandedPurPrice,
                  getProductUnit: (product) => product.proUnit,
                  getAveragePrice: (product) => product.averagePrice,
                  getRecentPrice: (product) => product.recentPurPrice,
                  getSellPrice: (product) => product.sellPrice,
                  onProductSelected: onProductSelected,
                  onSubmit: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (nodes.length > 1 && nodes[1].canRequestFocus) {
                        nodes[1].requestFocus();
                      }
                    });
                  },
                  openOverlayOnFocus: item.productId.isEmpty,
                  showAllOnFocus: true,
                ),
              ),

              // Quantity field
              SizedBox(
                width: 80,
                child: TextField(
                  controller: qtyController,
                  focusNode: nodes[1],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(hintText: tr.qty, border: InputBorder.none, isDense: true),
                  onChanged: (value) {
                    final qty = int.tryParse(value) ?? 0;
                    context.read<SaleInvoiceBloc>().add(UpdateSaleItemEvent(rowId: item.rowId, qty: qty));
                  },
                  onSubmitted: (_) => basePriceFocusNode.requestFocus(),
                ),
              ),

              // Batch field
              if(visibility.isWholeSale)
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: batchController,
                    readOnly: true,
                    decoration: InputDecoration(hintText: tr.batchTitle, border: InputBorder.none, isDense: true),
                  ),
                ),

              // Unit field
              SizedBox(
                width: 100,
                child: TextField(
                  controller: unitController,
                  readOnly: true,
                  decoration: InputDecoration(hintText: tr.unit, border: InputBorder.none, isDense: true),
                ),
              ),

              // Base Price field (editable)
              SizedBox(
                width: 130,
                child: TextField(
                  controller: salePriceController,
                  focusNode: basePriceFocusNode,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
                  decoration: InputDecoration(hintText: tr.unitPrice, border: InputBorder.none, isDense: true),
                  onChanged: (value) {
                    final price = double.tryParse(value) ?? 0;
                    updateSalePrice(price);
                  },
                  onSubmitted: (_) => onBasePriceSubmitted(),
                ),
              ),

              // Local Amount field (editable - bidirectional)
              if (needsLocalConv)
                SizedBox(
                  width: 130,
                  child: BlocBuilder<SaleInvoiceBloc, SaleInvoiceState>(
                    builder: (context, state) {
                      if (state is SaleInvoiceLoaded && state.isExchangeRateLoading) {
                        return const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      return TextField(
                        controller: localAmountController,
                        focusNode: localAmountFocusNode,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
                        decoration: InputDecoration(
                          hintText: tr.localAmount,
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: TextStyle(color: color.primary, fontWeight: FontWeight.w500),
                        onChanged: onLocalAmountChanged,
                        onSubmitted: (_) => onLocalAmountSubmitted(),
                      );
                    },
                  ),
                ),

              // Discount field
              SizedBox(
                width: 140,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: discountController,
                        focusNode: discountFocusNode,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
                        decoration: InputDecoration(
                          hintText: tr.discountTitle,
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (value) {
                          final discount = double.tryParse(value) ?? 0;
                          context.read<SaleInvoiceBloc>().add(UpdateItemDiscountValueEvent(rowId: item.rowId, discountValue: discount));
                        },
                        onSubmitted: (_) => onDiscountSubmitted(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(item.discountType == DiscountType.percentage ? Icons.percent : Icons.attach_money, size: 16),
                      onPressed: () {
                        final newType = item.discountType == DiscountType.percentage ? DiscountType.amount : DiscountType.percentage;
                        context.read<SaleInvoiceBloc>().add(UpdateItemDiscountTypeEvent(rowId: item.rowId, discountType: newType));
                      },
                    ),
                  ],
                ),
              ),

              // Total field
              SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.totalSale.toAmount(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color.primary)),
                    if (item.discountAmount > 0)
                      Text(
                        '${item.displayDiscountPerUnit.toAmount()} × ${item.totalUnits} = -${item.discountAmount.toAmount()}',
                        style: const TextStyle(fontSize: 10, color: Colors.red),
                      ),
                  ],
                ),
              ),

              // Delete button
              SizedBox(
                width: 67,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () {
                    _priceControllers.remove("sale_${item.rowId}");
                    _qtyControllers.remove(item.rowId);
                    _discountControllers.remove("sale_${item.rowId}");
                    _pcsControllers.remove("sale_${item.rowId}");
                    _localeAmountControllers.remove(item.rowId);
                    context.read<SaleInvoiceBloc>().add(RemoveSaleItemEvent(item.rowId));
                  },
                ),
              ),
            ],
          ),
        ),
        if (isLastRow)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                ZOutlineButton(
                  width: 120,
                  height: 35,
                  backgroundColor: color.primary.withValues(alpha: .08),
                  icon: Icons.add,
                  label: Text(tr.addItem),
                  onPressed: _addNewRowAndFocus,
                ),
              ],
            ),
          ),
      ],
    );
  }
  bool _needsLocalConversion(BuildContext context) {
    final state = context.read<SaleInvoiceBloc>().state;
    if (state is SaleInvoiceLoaded && state.customerAccount != null) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthenticatedState) {
        final baseCurrency = authState.loginData.company?.comLocalCcy ?? '';
        final accountCurrency = state.customerAccount!.actCurrency ?? '';
        return baseCurrency.isNotEmpty && accountCurrency.isNotEmpty && baseCurrency != accountCurrency;
      }
    }
    return false;
  }

  void _addNewRowAndFocus() {
    final state = context.read<SaleInvoiceBloc>().state;
    if (state is SaleInvoiceLoaded && state.items.isNotEmpty) {
      final lastItem = state.items.last;
      if (lastItem.productId.isEmpty) {
        // Focus the existing empty row's product field
        if (_rowFocusNodes.isNotEmpty && _rowFocusNodes.last.isNotEmpty) {
          _rowFocusNodes.last[0].requestFocus();
        }
        return;
      }
    }
    context.read<SaleInvoiceBloc>().add(AddNewSaleItemEvent());
  }

  void _synchronizeFocusNodes(int itemCount) {
    final needsLocalConv = _needsLocalConversion(context);

    while (_rowFocusNodes.length < itemCount) {
      if (needsLocalConv) {
        // 5 focus nodes: product, qty, unitPrice, discount, localAmount
        _rowFocusNodes.add([
          FocusNode(),
          FocusNode(),
          FocusNode(),
          FocusNode(),
          FocusNode(),
        ]);
      } else {
        // 4 focus nodes: product, qty, unitPrice, discount
        _rowFocusNodes.add([
          FocusNode(),
          FocusNode(),
          FocusNode(),
          FocusNode(),
        ]);
      }
    }

    while (_rowFocusNodes.length > itemCount) {
      final removed = _rowFocusNodes.removeLast();
      for (final node in removed) {
        node.dispose();
      }
    }
  }
  bool _shouldAutoFocusProduct = true;

  void _focusNewRowIfNeeded(SaleInvoiceLoaded state) {
    if (!mounted) return;

    // Don't auto-focus product if we're in account selection mode
    if (!_shouldAutoFocusProduct) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_personController.text.isEmpty) return;
      for (int i = 0; i < state.items.length; i++) {
        final item = state.items[i];
        if (item.productId.isEmpty) {
          if (i < _rowFocusNodes.length && _rowFocusNodes[i].isNotEmpty) {
            _rowFocusNodes[i][0].requestFocus();
            context.read<ProductsBloc>().add(LoadProductsStockEvent());
            break;
          }
        }
      }
    });
  }

  Widget _buildProfitSection({
    required SaleInvoiceLoaded current,
    required String baseCurr,
    required String profitLabel,
  }) {
    final isProfit = current.totalProfit >= 0;
    final color = isProfit ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: .05),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(profitLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    toggleProfit = !toggleProfit;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(toggleProfit ? Icons.visibility_off : Icons.visibility, size: 18, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                toggleProfit ? "••••••" : "${current.totalProfit.toAmount()} $baseCurr",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
              ),
              Text(
                toggleProfit ? "••••" : "${current.profitPercentage.toStringAsFixed(1)}%",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
  String _getBalanceStatus(double balance) {
    if (balance < 0) return AppLocalizations.of(context)!.debtor;
    if (balance > 0) return AppLocalizations.of(context)!.creditor;
    return AppLocalizations.of(context)!.noAccountsFound;
  }
  Widget _buildSummarySection(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context)!;
    final visibility = context.read<SettingsVisibleBloc>().state;
    final state = context.watch<AuthBloc>().state;

    if (state is! AuthenticatedState) {
      return const SizedBox();
    }
    final login = state.loginData;
    return BlocBuilder<SaleInvoiceBloc, SaleInvoiceState>(
      builder: (context, state) {
        if (state is SaleInvoiceLoaded || state is SaleInvoiceSaving) {
          final current = state is SaleInvoiceSaving ? state : (state as SaleInvoiceLoaded);
          final bool hasCreditAccount = current.customerAccount != null && current.creditAmount > 0;
          final bool needsConversion = current.needsExchangeRate;
          final bool isLoading = current.isExchangeRateLoading;

          final String baseCurr = baseCurrency ?? '';
          final String accountCurr = current.customerAccount?.actCurrency ?? '';

          // Calculate account amounts correctly
          final double remainingAmountInAccountCurrency = hasCreditAccount
              ? current.creditAmountLocal
              : 0.0;

          // New balance calculation
          final double newBalanceInAccountCurrency = hasCreditAccount
              ? current.currentBalance - remainingAmountInAccountCurrency
              : 0.0;

          return ZCover(
            padding: const EdgeInsets.all(15),
            radius: 10,
            shadowColor: Theme.of(context).colorScheme.surfaceContainer,
            borderColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            color: Theme.of(context).colorScheme.surface,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            spacing: 8,
                            children: [
                              Icon(Icons.summarize_outlined),
                              Text(tr.invoiceSummary.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Divider(height: 1, color: color.outline.withValues(alpha: .5)),
                          const SizedBox(height: 4),


                          _buildSummaryRow(label: tr.subtotal, fontSize: 17, value: current.subtotal, currency: baseCurr),

                          if (current.totalItemDiscount > 0)
                            _buildSummaryRow(label: tr.itemDiscounts, value: -current.totalItemDiscount, color: Colors.red, currency: baseCurr),

                          if (current.totalItemDiscount > 0)
                            _buildSummaryRow(label: tr.afterItemDiscount, value: current.totalAfterItemDiscount, isBold: true, currency: baseCurr),

                          // Display general discount as text (not editable)
                          if (current.generalDiscountAmount > 0)
                            _buildSummaryRow(
                              label: tr.generalDiscount,
                              value: -current.generalDiscountAmount,
                              color: Colors.red,
                              currency: baseCurr,
                            ),

                          // Display extra charges as text (not editable)
                          if (current.extraCharges > 0)
                            _buildSummaryRow(
                              label: tr.extraCharges,
                              value: current.extraCharges,
                              color: Colors.orange,
                              currency: baseCurr,
                            ),

                          const SizedBox(height: 5),
                          Divider(height: 1, color: color.outline.withValues(alpha: .5)),
                          const SizedBox(height: 5),
                          _buildSummaryRow(label: tr.grandTotal, value: current.grandTotal, isBold: true, fontSize: 17, currency: baseCurr),

                          if (needsConversion && !isLoading)
                            _buildSummaryRow(
                              label: '${tr.grandTotal} (${current.toCurrency})',
                              value: current.grandTotalLocal,
                              fontSize: 14,
                              color: color.primary.withValues(alpha: .8),
                              currency: current.toCurrency ?? '',
                            ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(width: 12),
                  VerticalDivider(width: 20, thickness: 1, color: color.outline.withValues(alpha: .2)),
                  SizedBox(width: 12),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                spacing: 8,
                                children: [
                                  Icon(Icons.payment_rounded),
                                  Text(tr.paymentDetails.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ],
                              ),
                              InkWell(
                                onTap: () => _showPaymentDialog(current),
                                child: Row(
                                  children: [
                                    Text(_getPaymentModeLabel(current.paymentMode).toUpperCase(),
                                        style: TextStyle(color: color.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Icon(Icons.more_vert_rounded, size: 18, color: color.primary),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Divider(height: 1, color: color.outline.withValues(alpha: .5)),
                          const SizedBox(height: 8),

                          if (current.paymentMode == PaymentMode.cash) ...[
                            AmountDisplay(
                              title: tr.cashReceipt,
                              baseAmount: current.cashPayment,
                              baseCurrency: baseCurr,
                              convertedAmount: (current.cashCurrency != null && current.cashCurrency!.isNotEmpty && current.cashCurrency != baseCurr)?
                              current.cashPayment * current.cashExchangeRate : null,
                              convertedCurrency: current.cashCurrency,
                            ),

                          ]
                          else if(current.paymentMode == PaymentMode.credit)...[
                            AmountDisplay(
                              title: tr.accountReceivable,
                              baseAmount: current.creditAmount,
                              baseCurrency: baseCurr,
                              convertedAmount: (needsConversion && !isLoading) ? current.creditAmountLocal : null,
                              convertedCurrency: current.toCurrency,
                              fontSize: 16,
                              baseColor: Colors.green.withValues(alpha: .9),
                            ),
                          ]
                          else if (current.paymentMode == PaymentMode.mixed) ...[
                              AmountDisplay(
                                title: tr.cashReceipt,
                                baseAmount: current.cashPayment,
                                baseCurrency: baseCurr,
                                convertedAmount:
                                (current.cashCurrency != null && current.cashCurrency!.isNotEmpty && current.cashCurrency != baseCurr) ?
                                current.cashPayment * current.cashExchangeRate : null,
                                convertedCurrency: current.cashCurrency,
                                fontSize: 16,
                                baseColor: Colors.green.withValues(alpha: .9),
                              ),

                              Divider(),
                              AmountDisplay(
                                title: tr.accountReceivable,
                                baseAmount: current.creditAmount,
                                baseCurrency: baseCurr,
                                convertedAmount: (needsConversion && !isLoading) ? current.creditAmountLocal : null,
                                convertedCurrency: current.toCurrency,
                                fontSize: 16,
                                baseColor: Colors.green.withValues(alpha: .9),
                              ),


                            ],

                          if (visibility.benefit && current.totalPurchaseCost > 0 && login.hasPermission(8) == true) ...[
                            const SizedBox(height: 8),
                            _buildProfitSection(
                              current: current,
                              baseCurr: baseCurr,
                              profitLabel: tr.profitAndLoss.toUpperCase(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Account Information Section
                  if (hasCreditAccount) ...[
                    SizedBox(width: 12),
                    VerticalDivider(width: 20, thickness: 1, color: color.outline.withValues(alpha: .2)),
                    SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              spacing: 8,
                              children: [
                                Icon(Icons.account_balance_rounded,size: 20),
                                Text(tr.accountInformation.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                            const SizedBox(height: 11),
                            Divider(height: 1, color: color.outline.withValues(alpha: .5)),
                            const SizedBox(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(current.customerAccount!.accName ?? '', style: const TextStyle(fontSize: 15)),
                                      Text('#${current.customerAccount!.accNumber}', style: TextStyle(fontSize: 17, color: color.outline)),
                                    ],
                                  ),

                                  _buildSummaryRow(
                                    label: tr.currentBalance,
                                    value: current.currentBalance,
                                    fontSize: 15,
                                    currency: accountCurr,
                                  ),

                                  AmountDisplay(
                                    title: tr.amountAddedToAR,
                                    baseColor: Theme.of(context).colorScheme.error,
                                    baseAmount: current.creditAmount,
                                    baseCurrency: baseCurr,
                                    convertedCurrency: accountCurr,
                                    isPositive: true,
                                    showSign: true,
                                    convertedAmount: (needsConversion && !isLoading) ? remainingAmountInAccountCurrency : null,
                                  ),

                                  const SizedBox(height: 8),
                                  Divider(height: 1, color: color.outline.withValues(alpha: .5)),
                                  const SizedBox(height: 4),

                                  _buildSummaryRow(
                                    label: "${tr.newBalance} | ${_getBalanceStatus(current.newBalance)}",
                                    value: newBalanceInAccountCurrency,
                                    isBold: true,
                                    fontSize: 17,
                                    color: newBalanceInAccountCurrency < 0 ? Colors.red : Colors.green,
                                    currency: accountCurr,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required double value,
    bool isBold = false,
    Color? color,
    double fontSize = 14,
    required String currency,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text('${value.toAmount()} $currency',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(SaleInvoiceLoaded current) {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
          builder: (context,setState) {
            return SalePaymentDialog(state: current);
          }
      ),
    );
  }

  String _getPaymentModeLabel(PaymentMode mode) {
    switch (mode) {
      case PaymentMode.cash:
        return AppLocalizations.of(context)!.cash;
      case PaymentMode.credit:
        return AppLocalizations.of(context)!.creditTitle;
      case PaymentMode.mixed:
        return AppLocalizations.of(context)!.combinedPayment;
    }
  }

  void _saveInvoice(BuildContext context, SaleInvoiceLoaded state) {
    // Check if customer exists
    if (state.customer == null) {
      ToastManager.show(
        context: context,
        title: AppLocalizations.of(context)!.errorTitle,
        message: AppLocalizations.of(context)!.selectCustomer,
        type: ToastType.error,
      );
      return;
    }

    // If payment is cash but no cash amount set, open dialog to set it
    if (state.paymentMode == PaymentMode.cash) {
      if(state.cashPayment <= 0 || state.cashPaymentLocal <=0 && state.cashPayment != state.grandTotal || state.cashPaymentLocal != state.grandTotalLocal){
        _showPaymentDialog(state);
        return;
      }
    }

    // Let Bloc handle all validation and show errors
    final completer = Completer<String>();
    context.read<SaleInvoiceBloc>().add(
      SaveSaleInvoiceEvent(
        usrName: _userName ?? '',
        orderName: "Sale",
        ordPersonal: state.customer!.perId!,
        reference: _reference.text.isNotEmpty ? _reference.text : null,
        remark: _remarkController.text.isNotEmpty ? _remarkController.text : null,
        completer: completer,
      ),
    );
  }
  void _updateInvoice(BuildContext context, SaleInvoiceLoaded state) {
    // Check if customer exists
    if (state.customer == null) {
      ToastManager.show(
        context: context,
        title: AppLocalizations.of(context)!.errorTitle,
        message: AppLocalizations.of(context)!.selectCustomer,
        type: ToastType.error,
      );
      return;
    }

    // If payment is cash but no cash amount set, open dialog to set it
    if (state.paymentMode == PaymentMode.cash) {
      if(state.cashPayment <= 0 || state.cashPaymentLocal <=0 && state.cashPayment != state.grandTotal || state.cashPaymentLocal != state.grandTotalLocal){
        _showPaymentDialog(state);
        return;
      }
    }

    // Let Bloc handle all validation and show errors
    final completer = Completer<String>();
    context.read<SaleInvoiceBloc>().add(
      UpdateSaleInvoiceEvent(
        usrName: _userName ?? '',
        orderId: state.orderId ?? widget.orderId,
        orderName: "Sale",
        ordPersonal: state.customer!.perId!,
        reference: _reference.text.isNotEmpty ? _reference.text : null,
        remark: _remarkController.text.isNotEmpty ? _remarkController.text : null,
        completer: completer,
      ),
    );
  }
  void _onSalePrint({String? invoiceNumber}) {
    final visibilityState = context.read<SettingsVisibleBloc>().state;
    final state = context.read<SaleInvoiceBloc>().state;
    SaleInvoiceLoaded? current;

    // Fix: Properly handle the state after save
    if (state is SaleInvoiceLoaded) {
      current = state;
    } else if (state is SaleInvoiceSaved && state.invoiceData != null) {
      current = state.invoiceData;
    }

    if (current == null && mounted) {
      // Show loading indicator
      ToastManager.show(
        context: context,
        title: "Info",
        message: "Preparing print...",
        type: ToastType.info,
      );

      // Wait for state to be ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _onSalePrint(invoiceNumber: invoiceNumber);
        }
      });
      return;
    }
    if (current == null) {
      ToastManager.show(context: context, message: "No data available", type: ToastType.warning);
      return;
    }

    // Determine the invoice number to use
    final String finalInvoiceNumber;
    if (invoiceNumber != null && invoiceNumber.isNotEmpty) {
      // Case 1: After saving, use the returned invoice number
      finalInvoiceNumber = invoiceNumber;
    } else if (widget.orderId != null) {
      // Case 2: When loading an existing invoice, use the widget.orderId
      finalInvoiceNumber = widget.orderId.toString();
    } else if (current.orderId != null) {
      // Case 3: Use from current state if available
      finalInvoiceNumber = current.orderId.toString();
    } else {
      // Case 4: New invoice without ID - show error
      ToastManager.show(context: context, message: "No data available", type: ToastType.warning);
      return;
    }

    // Rest of your print logic remains the same...
    final needsConversion = current.needsExchangeRate;

    final List<InvoiceItem> invoiceItems = current.items.map((item) {
      return SaleInvoiceItemForPrint(
        productName: item.productName,
        quantity: item.qty.toDouble(),
        unitPrice: item.salePrice ?? 0.0,
        total: item.totalSale,
        batch: item.batch ?? 0,
        unit: item.unit ?? '',
        storageName: item.storageName,
        purchasePrice: item.purPrice ?? 0.0,
        profit: (item.salePrice ?? 0.0) - (item.purPrice ?? 0.0),
        localAmount: needsConversion ? item.singleLocalAmount : null,
        localCurrency: needsConversion ? current?.toCurrency : null,
        exchangeRate: needsConversion ? current?.safeExchangeRate : null,
      );
    }).toList();

    showDialog(
      context: context,
      builder: (_) => PrintPreviewDialog<dynamic>(
        data: null,
        showRoll80: true,
        company: company,
        buildPreview: ({required data, required language, required orientation, required pageFormat}) {
          return InvoicePrintService().printInvoicePreview(
            invoiceType: "Sale",
            invoiceNumber: finalInvoiceNumber,
            reference: _reference.text,
            invoiceDate: DateTime.tryParse(current?.orderDate?.toFormattedDate() ?? DateTime.now().toFormattedDate()),
            customerSupplierName: current?.customer?.perName ?? "",
            items: invoiceItems,
            grandTotal: current?.grandTotal ?? 0.0,
            cashPayment: current?.cashPayment ?? 0.0,
            creditAmount: current?.creditAmount ?? 0.0,
            account: current?.customerAccount,
            language: language,
            remark: current?.remark,
            orientation: orientation,
            company: company.copyWith(visible: visibilityState),
            pageFormat: pageFormat,
            currency: baseCurrency,
            isSale: true,
            totalLocalAmount: needsConversion ? current?.totalLocalAmount : null,
            localCurrency: needsConversion ? current?.toCurrency : null,
            exchangeRate: needsConversion ? current?.safeExchangeRate : null,
            subtotal: current?.subtotal,
            totalItemDiscount: current?.totalItemDiscount,
            generalDiscount: current?.generalDiscountAmount,
            extraCharges: current?.extraCharges,
          );
        },
        onPrint: ({required data, required language, required orientation, required pageFormat, required selectedPrinter, required copies, required pages}) {
          return InvoicePrintService().printInvoiceDocument(
            invoiceType: "Sale",
            invoiceNumber: finalInvoiceNumber,
            reference: _reference.text,
            invoiceDate: DateTime.tryParse(current?.orderDate?.toFormattedDate() ?? DateTime.now().toFormattedDate()),
            customerSupplierName: current?.customer?.perName ?? "",
            items: invoiceItems,
            grandTotal: current?.grandTotal ??0.0,
            remark: current?.remark ?? "",
            cashPayment: current?.cashPayment ?? 0.0,
            creditAmount: current?.creditAmount ?? 0.0,
            account: current?.customerAccount,
            language: language,
            orientation: orientation,
            company: company.copyWith(visible: visibilityState),
            selectedPrinter: selectedPrinter,
            pageFormat: pageFormat,
            copies: copies,
            currency: baseCurrency,
            isSale: true,
            totalLocalAmount: needsConversion ? current?.totalLocalAmount : null,
            localCurrency: needsConversion ? current?.toCurrency : null,
            exchangeRate: needsConversion ? current?.safeExchangeRate : null,
            subtotal: current?.subtotal,
            totalItemDiscount: current?.totalItemDiscount,
            generalDiscount: current?.generalDiscountAmount,
            extraCharges: current?.extraCharges,
          );
        },
        onSave: ({required data, required language, required orientation, required pageFormat}) {
          return InvoicePrintService().createInvoiceDocument(
            invoiceType: "Sale",
            invoiceNumber: finalInvoiceNumber,
            reference: _reference.text,
            invoiceDate: DateTime.tryParse(current?.orderDate?.toFormattedDate()??""),
            customerSupplierName: "${current?.customer?.perName} ${current?.customer?.perLastName}",
            items: invoiceItems,
            grandTotal: current?.grandTotal?? 0.0,
            cashPayment: current?.cashPayment ?? 0.0,
            creditAmount: current?.creditAmount ?? 0.0,
            account: current?.customerAccount,
            remark: current?.remark,
            language: language,
            orientation: orientation,
            company: company.copyWith(visible: visibilityState),
            pageFormat: pageFormat,
            currency: baseCurrency,
            isSale: true,
            totalLocalAmount: needsConversion ? current?.totalLocalAmount : null,
            localCurrency: needsConversion ? current?.toCurrency : null,
            exchangeRate: needsConversion ? current?.safeExchangeRate : null,
            subtotal: current?.subtotal,
            totalItemDiscount: current?.totalItemDiscount,
            generalDiscount: current?.generalDiscountAmount,
            extraCharges: current?.extraCharges,
          );
        },
      ),
    );
  }

  void _onPrintStockPaper({String? invoiceNumber}) {
    final state = context.read<SaleInvoiceBloc>().state;
    final visibilityState = context.read<SettingsVisibleBloc>().state;
    SaleInvoiceLoaded? current;

    if (state is SaleInvoiceLoaded) {
      current = state;
    } else if (state is SaleInvoiceSaved && state.invoiceData != null) {
      current = state.invoiceData;
    }

    if (current == null) {
      Utils.showOverlayMessage(context, message: 'Cannot print: No invoice data available', isError: true);
      return;
    }

    // Determine the invoice number to use
    dynamic finalInvoiceNumber;
    if (invoiceNumber != null && invoiceNumber.isNotEmpty) {
      // Case 1: After saving, use the returned invoice number
      finalInvoiceNumber = invoiceNumber;
    } else if (current.orderId !=null || widget.orderId != null && widget.orderId! > 0) {
      // Case 2: When loading an existing invoice, use the widget.orderId
      finalInvoiceNumber = current.orderId;
    } else {
      // Case 3: New invoice - leave empty
      finalInvoiceNumber = '';
    }

    // Convert to StockDocumentItem (only needs: productName, quantity, batch, storageName)
    final List<StockDocumentItem> stockItems = current.items.map((item) {
      return SaleStockItem(
          unit: item.unit ?? '',
          productName: item.productName,
          quantity: item.qty.toDouble(),
          batch: item.batch ?? 0,
          storageName: item.storageName,
          sku: item.productId
      );
    }).toList();

    // Calculate total quantity
    final double totalQuantity = stockItems.fold(0.0, (sum, item) => sum + item.quantity);

    showDialog(
      context: context,
      builder: (_) => PrintPreviewDialog<dynamic>(
        data: null,
        company: company,
        buildPreview: ({required data, required language, required orientation, required pageFormat}) {
          return StockDocumentPrintService().previewStockDocument(
            documentType: "Sale",
            documentNumber: finalInvoiceNumber,
            reference: _reference.text,
            documentDate: DateTime.tryParse(current?.orderDate?.toFormattedDate() ?? ""),
            customerSupplierName: current?.customer?.perName ?? "",
            items: stockItems,
            totalQuantity: totalQuantity,
            language: language,
            orientation: orientation,
            company: company.copyWith(visible: visibilityState),
            pageFormat: pageFormat,
          );
        },
        onPrint: ({required data, required language, required orientation, required pageFormat, required selectedPrinter, required copies, required pages}) {
          return StockDocumentPrintService().printStockDocument(
            documentType: "Sale",
            documentNumber: finalInvoiceNumber,
            reference: _reference.text,
            documentDate: DateTime.tryParse(current?.orderDate?.toFormattedDate()??""),
            customerSupplierName: current?.customer?.perName ?? "",
            items: stockItems,
            totalQuantity: totalQuantity,
            language: language,
            orientation: orientation,
            company: company.copyWith(visible: visibilityState),
            selectedPrinter: selectedPrinter,
            pageFormat: pageFormat,
            copies: copies,
          );
        },
        onSave: ({required data, required language, required orientation, required pageFormat}) {
          return StockDocumentPrintService().createStockDocument(
            documentType: "Sale",
            documentNumber: finalInvoiceNumber,
            reference: _reference.text,
            documentDate: DateTime.tryParse(current?.orderDate?.toFormattedDate()??""),
            customerSupplierName: current?.customer?.perName ?? "",
            items: stockItems,
            totalQuantity: totalQuantity,
            language: language,
            orientation: orientation,
            company: company.copyWith(visible: visibilityState),
            pageFormat: pageFormat,
          );
        },
      ),
    );
  }
}

class SalePaymentDialog extends StatefulWidget {
  final SaleInvoiceLoaded state;

  const SalePaymentDialog({super.key, required this.state});

  @override
  State<SalePaymentDialog> createState() => _SalePaymentDialogState();
}
class _SalePaymentDialogState extends State<SalePaymentDialog> {
  late TextEditingController _cashPaymentController;
  late TextEditingController _exchangeRateController;
  late TextEditingController _extraChargesController;
  late TextEditingController _cashExchangeRateController;
  late TextEditingController _remainingDiscountController;
  late TextEditingController _generalDiscountController;

  Timer? _debounce;
  late StreamSubscription _blocSubscription;

  String _selectedCashCurrency = '';
  double _cashExchangeRate = 1.0;
  bool _isLoadingCashRate = false;
  String _baseCurrency = '';

  // Track current cash amount in selected currency
  double _currentCashAmountInSelectedCurrency = 0.0;

  // Track if we're in pure cash mode (no account selected)
  bool get _isPureCashMode => widget.state.customerAccount == null;

  // Track current state to rebuild when bloc updates
  SaleInvoiceLoaded _currentState = const SaleInvoiceLoaded(
    items: [],
    payments: [],
    cashPayment: 0.0,
    paymentMode: PaymentMode.cash,
    extraCharges: 0.0,
    generalDiscount: 0.0,
    cashExchangeRate: 1.0,
  );

  @override
  void initState() {
    super.initState();

    _currentState = widget.state;

    // Get base currency from auth state
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthenticatedState) {
      _baseCurrency = authState.loginData.company?.comLocalCcy ?? '';
    }

    if (_baseCurrency.isEmpty) {
      _baseCurrency = _currentState.fromCurrency ?? '';
    }

    // Load existing cash currency from state
    _selectedCashCurrency = (_currentState.cashCurrency != null && _currentState.cashCurrency!.isNotEmpty)
        ? _currentState.cashCurrency!
        : _baseCurrency;

    _cashExchangeRate = _currentState.cashExchangeRate > 0
        ? _currentState.cashExchangeRate
        : 1.0;

    // Calculate initial cash amount in selected currency
    final cashAmountInBase = _currentState.cashPayment;
    double initialAmountInSelectedCurrency;

    if (_isPureCashMode) {
      initialAmountInSelectedCurrency = _currentState.grandTotal * _cashExchangeRate;
    } else {
      // If selected currency is the same as base, amount in base is correct
      // If different, convert from base to selected currency
      if (_selectedCashCurrency == _baseCurrency) {
        initialAmountInSelectedCurrency = cashAmountInBase;
      } else {
        initialAmountInSelectedCurrency = cashAmountInBase * _cashExchangeRate;
      }
    }

    _currentCashAmountInSelectedCurrency = initialAmountInSelectedCurrency;

    _cashPaymentController = TextEditingController(
      text: _currentCashAmountInSelectedCurrency > 0
          ? _currentCashAmountInSelectedCurrency.toStringAsFixed(2)
          : '',
    );


    _exchangeRateController = TextEditingController(
      text: _currentState.exchangeRate != null && _currentState.exchangeRate! > 0
          ? _currentState.exchangeRate!.toStringAsFixed(4)
          : '',
    );

    _generalDiscountController = TextEditingController(
      text: _currentState.generalDiscount > 0 ? _currentState.generalDiscount.toString() : '',
    );

    _cashExchangeRateController = TextEditingController(
      text: _cashExchangeRate.toStringAsFixed(4),
    );

    _extraChargesController = TextEditingController(
      text: _currentState.extraCharges > 0 ? _currentState.extraCharges.toString() : '',
    );

    _remainingDiscountController = TextEditingController();

    // Set initial cash currency if not set
    if (_currentState.cashCurrency == null || _currentState.cashCurrency!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // For pure cash mode, set the cash payment to full grand total
        if (_isPureCashMode) {
          context.read<SaleInvoiceBloc>().add(UpdateCashPaymentEvent(_currentState.grandTotal));
          context.read<SaleInvoiceBloc>().add(UpdateCashCurrencyEvent(
            currency: _baseCurrency,
            exchangeRate: 1.0,
          ));
        } else {
          context.read<SaleInvoiceBloc>().add(UpdateCashCurrencyEvent(
            currency: _baseCurrency,
            exchangeRate: 1.0,
          ));
        }
      });
    } else if (_isPureCashMode && _currentState.cashPayment != _currentState.grandTotal) {
      // Ensure cash payment matches grand total in pure cash mode
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SaleInvoiceBloc>().add(UpdateCashPaymentEvent(_currentState.grandTotal));
      });
    }

    // LISTEN to bloc state changes to update dialog when exchange rate changes
    _blocSubscription = context.read<SaleInvoiceBloc>().stream.listen((state) {
      if (state is SaleInvoiceLoaded && mounted) {
        setState(() {
          _currentState = state;

          // Update exchange rate controller if changed
          final newRate = _currentState.exchangeRate != null && _currentState.exchangeRate! > 0
              ? _currentState.exchangeRate!.toStringAsFixed(6)
              : '';
          if (_exchangeRateController.text != newRate) {
            _exchangeRateController.text = newRate;
          }

          // Update cash amount if needed
          if (_isPureCashMode) {
            // In pure cash mode, ensure cash payment matches grand total
            final expectedCashInSelectedCurrency = _currentState.grandTotal * _cashExchangeRate;
            if (_currentCashAmountInSelectedCurrency != expectedCashInSelectedCurrency) {
              _currentCashAmountInSelectedCurrency = expectedCashInSelectedCurrency;
              _cashPaymentController.text = expectedCashInSelectedCurrency.toStringAsFixed(2);
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _blocSubscription.cancel();
    _cashPaymentController.dispose();
    _exchangeRateController.dispose();
    _extraChargesController.dispose();
    _cashExchangeRateController.dispose();
    _generalDiscountController.dispose();
    _remainingDiscountController.dispose();
    super.dispose();
  }

  void _updateCashPayment(double amountInSelectedCurrency) {
    if (_isPureCashMode) {
      // In pure cash mode, we don't allow manual editing of the amount
      // The amount should always be the full grand total
      // Just refresh the display with the correct amount
      final correctAmount = _currentState.grandTotal * _cashExchangeRate;
      if (_currentCashAmountInSelectedCurrency != correctAmount) {
        setState(() {
          _currentCashAmountInSelectedCurrency = correctAmount;
          _cashPaymentController.text = correctAmount.toStringAsFixed(2);
        });
      }
      return;
    }

    setState(() {
      _currentCashAmountInSelectedCurrency = amountInSelectedCurrency;
    });

    final amountInBaseCurrency = amountInSelectedCurrency / _cashExchangeRate;
    context.read<SaleInvoiceBloc>().add(UpdateCashPaymentEvent(amountInBaseCurrency));
  }

  void _updateCashCurrencyAndRate(String currency, double rate) {
    setState(() {
      _selectedCashCurrency = currency;
      _cashExchangeRate = rate;
      _cashExchangeRateController.text = rate.toStringAsFixed(6);

      // Update displayed amount with new rate
      double newAmountInSelectedCurrency;

      if (_isPureCashMode) {
        // In pure cash mode, the amount should be grand total converted to new currency
        newAmountInSelectedCurrency = _currentState.grandTotal * rate;
      } else {
        final currentAmountInBase = _currentState.cashPayment;
        newAmountInSelectedCurrency = currentAmountInBase * rate;
      }

      _currentCashAmountInSelectedCurrency = newAmountInSelectedCurrency;
      _cashPaymentController.text = newAmountInSelectedCurrency > 0
          ? newAmountInSelectedCurrency.toStringAsFixed(2)
          : '';
    });

    context.read<SaleInvoiceBloc>().add(UpdateCashCurrencyEvent(
      currency: currency,
      exchangeRate: rate,
    ));
  }

  double get _cashAmountInBase {
    if (_isPureCashMode) {
      // In pure cash mode, return the grand total in base currency
      return _currentState.grandTotal;
    }
    return _currentCashAmountInSelectedCurrency / _cashExchangeRate;
  }

  // Get remaining amount in BASE CURRENCY that still needs to be paid
  double get _remainingAmountInBase {
    if (_isPureCashMode) {
      return 0.0; // No remaining amount in pure cash mode
    }
    final grandTotal = _currentState.grandTotal;
    final cashAmount = _cashAmountInBase;
    return (grandTotal - cashAmount).clamp(0, grandTotal);
  }

  // Get remaining amount in ACCOUNT CURRENCY (if account is selected)
  double get _remainingAmountInAccountCurrency {
    if (_currentState.customerAccount == null) return 0.0;

    // If account currency matches base currency, don't convert
    if (_currentState.customerAccount!.actCurrency == _baseCurrency) {
      return _remainingAmountInBase;
    }

    return _remainingAmountInBase * _currentState.safeExchangeRate;
  }

  double get _newBalanceInAccountCurrency {
    if (_currentState.customerAccount == null) return 0.0;
    final currentBalance = _currentState.currentBalance;
    return currentBalance - _remainingAmountInAccountCurrency;
  }

  PaymentMode get _calculatedPaymentMode {
    if (_isPureCashMode) {
      return PaymentMode.cash;
    }

    final grandTotal = _currentState.grandTotal;
    final cashAmount = _cashAmountInBase;

    if (cashAmount <= 0) {
      return PaymentMode.credit;
    } else if (cashAmount >= grandTotal) {
      return PaymentMode.cash;
    } else {
      return PaymentMode.mixed;
    }
  }

  void _onCashCurrencyChanged(CurrenciesModel? currency) {
    if (currency == null) return;

    final newCurrency = currency.ccyCode!;
    if (newCurrency == _selectedCashCurrency) return;

    setState(() {
      _selectedCashCurrency = newCurrency;
      _isLoadingCashRate = true;
    });

    if (_baseCurrency.isNotEmpty && newCurrency != _baseCurrency) {
      _fetchCashExchangeRate(_baseCurrency, newCurrency);
    } else {
      setState(() {
        _cashExchangeRate = 1.0;
        _cashExchangeRateController.text = '1.0000';
        _isLoadingCashRate = false;
      });
      _updateCashCurrencyAndRate(newCurrency, 1.0);
    }
  }

  Future<void> _fetchCashExchangeRate(String fromCurrency, String toCurrency) async {
    try {
      final rateStr = await context.read<SaleInvoiceBloc>().repo.getSingleRate(
        fromCcy: fromCurrency,
        toCcy: toCurrency,
      );
      final rate = double.tryParse(rateStr ?? "1.0") ?? 1.0;

      setState(() {
        _cashExchangeRate = rate;
        _cashExchangeRateController.text = rate.toStringAsFixed(6);
        _isLoadingCashRate = false;
      });
      _updateCashCurrencyAndRate(toCurrency, rate);
    } catch (e) {
      setState(() {
        _cashExchangeRate = 1.0;
        _cashExchangeRateController.text = '1.0000';
        _isLoadingCashRate = false;
      });
      _updateCashCurrencyAndRate(toCurrency, 1.0);
    }
  }

  // void _updateExchangeRate(double rate) {
  //   _debounce?.cancel();
  //   _debounce = Timer(const Duration(milliseconds: 800), () {
  //     if (_currentState.customerAccount != null) {
  //       context.read<SaleInvoiceBloc>().add(
  //         UpdateExchangeRateManuallyEvent(
  //           rate: rate,
  //           fromCurrency: _baseCurrency,
  //           toCurrency: _currentState.customerAccount!.actCurrency ?? '',
  //         ),
  //       );
  //     }
  //   });
  // }

  void _updateCashExchangeRate(double rate) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (rate > 0) {
        _updateCashCurrencyAndRate(_selectedCashCurrency, rate);
      }
    });

  }

  void _updateExtraCharges(double value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      context.read<SaleInvoiceBloc>().add(UpdateExtraChargesEvent(value));
    });
  }

  void _onConfirm() {
    if (_isPureCashMode) {
      // In pure cash mode, ensure the full grand total is set as cash payment
      context.read<SaleInvoiceBloc>().add(UpdateCashPaymentEvent(_currentState.grandTotal));
    } else {
      // Update the cash payment with the entered amount
      final finalCashAmount = _cashAmountInBase;
      context.read<SaleInvoiceBloc>().add(UpdateCashPaymentEvent(finalCashAmount));
    }

    // Close the dialog - user will click main Save button to save invoice
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme;
    final needsAccountConversion = _currentState.needsExchangeRate;
    final grandTotal = _currentState.grandTotal;
    final cashAmountInBase = _cashAmountInBase;
    final remainingAmountInBase = _remainingAmountInBase;

    final remainingAmountInAccountCurrency = _remainingAmountInAccountCurrency;
    final newBalanceInAccountCurrency = _newBalanceInAccountCurrency;
    final paymentMode = _calculatedPaymentMode;

    final bool isActionEnabled;
    if (_isPureCashMode) {
      // Pure cash mode - always enabled since amount is set automatically
      isActionEnabled = true;
    } else if (_currentState.customerAccount == null) {
      // No account selected - must pay full amount in cash
      isActionEnabled = remainingAmountInBase <= 0.01;
    } else {
      // Account selected - any cash amount is valid
      isActionEnabled = true;
    }

    final bool needsCashConversion = _selectedCashCurrency.isNotEmpty &&
        _baseCurrency.isNotEmpty &&
        _selectedCashCurrency != _baseCurrency;

    final accountCurrency = _currentState.customerAccount?.actCurrency ?? '';

    return ZFormDialog(
      title: "${tr.payment} - ${_getPaymentModeLabel(paymentMode)}",
      icon: Icons.payment,
      width: 550,
      actionLabel: Text(tr.confirm),
      isActionTrue: isActionEnabled,
      onAction: _onConfirm,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Summary Section
              SectionTitle(title: tr.orderSummary.toUpperCase()),
              const SizedBox(height: 8),

              ZCover(
                padding: const EdgeInsets.all(12),
                radius: 8,
                child: Column(
                  children: [
                    _infoRow(
                      label: tr.subtotal.toUpperCase(),
                      value: _currentState.subtotal,
                      currency: _baseCurrency,
                      isBold: true,
                    ),
                    if (_currentState.totalItemDiscount > 0)
                      _infoRow(
                        label: tr.itemDiscounts,
                        value: -_currentState.totalItemDiscount,
                        currency: _baseCurrency,
                        color: Colors.red,
                      ),
                    if (_currentState.totalAfterItemDiscount != _currentState.subtotal)
                      _infoRow(
                        label: tr.afterItemDiscount,
                        value: _currentState.totalAfterItemDiscount,
                        currency: _baseCurrency,
                        isBold: true,
                      ),

                    // General Discount Field
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr.generalDiscount,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: Icon(_currentState.generalDiscountType == DiscountType.percentage ? Icons.percent : Icons.monetization_on_outlined, size: 16),
                          onPressed: () {
                            final newType = _currentState.generalDiscountType == DiscountType.percentage
                                ? DiscountType.amount
                                : DiscountType.percentage;
                            context.read<SaleInvoiceBloc>().add(UpdateGeneralDiscountEvent(
                              discountValue: _currentState.generalDiscount,
                              discountType: newType,
                            ));
                          },
                        ),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _generalDiscountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                            decoration: InputDecoration(
                              hintText: '0',
                              border: InputBorder.none,
                              isDense: true,
                              suffixText: _currentState.generalDiscountType == DiscountType.percentage ? '%' : _baseCurrency,
                            ),
                            textAlign: TextAlign.end,
                            onChanged: (value) {
                              final discount = double.tryParse(value.replaceAll(',', '')) ?? 0;
                              context.read<SaleInvoiceBloc>().add(UpdateGeneralDiscountEvent(
                                discountValue: discount,
                                discountType: _currentState.generalDiscountType,
                              ));
                            },
                          ),
                        ),
                      ],
                    ),

                    // Extra Charges Field
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr.extraCharges,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 40),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _extraChargesController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                            decoration: InputDecoration(
                              hintText: '0',
                              border: InputBorder.none,
                              isDense: true,
                              suffixText: _baseCurrency,
                            ),
                            textAlign: TextAlign.end,
                            onChanged: (value) {
                              final charges = double.tryParse(value.replaceAll(',', '')) ?? 0;
                              _updateExtraCharges(charges);
                            },
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 15),
                    _infoRow(
                      label: tr.grandTotal,
                      value: grandTotal,
                      currency: _baseCurrency,
                      isBold: true,
                      fontSize: 20,
                    ),
                    if (needsAccountConversion && _currentState.exchangeRate != null && _currentState.exchangeRate! > 0 && _currentState.toCurrency != null)
                      _infoRow(
                        label: "${tr.grandTotal} (${_currentState.toCurrency})",
                        value: grandTotal * _currentState.safeExchangeRate,
                        currency: _currentState.toCurrency!,
                        fontSize: 14,
                        color: color.outline.withValues(alpha: .7),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Payment Section
              SectionTitle(title: tr.payment),
              const SizedBox(height: 10),

              // Cash Payment Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [

                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: ZGenericTextField(
                          controller: _cashPaymentController,
                          title: _isPureCashMode
                              ? "${tr.cashAmount} ($_selectedCashCurrency) - ${tr.fullCashPayment}"
                              : "${tr.cashAmount} ($_selectedCashCurrency)",
                          hint: "0.00",
                          readOnly: _isPureCashMode, // Make read-only in pure cash mode
                          defaultCurrencyCode: _selectedCashCurrency,
                          fieldType: ZTextFieldType.currency,
                          onCurrencyChanged: _onCashCurrencyChanged,
                          inputFormat: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                          ],
                          onChanged: (value) {
                            if (_isPureCashMode) {
                              // In pure cash mode, don't allow editing, just refresh with correct amount
                              final correctAmount = grandTotal * _cashExchangeRate;
                              if (_cashPaymentController.text != correctAmount.toStringAsFixed(2)) {
                                _cashPaymentController.text = correctAmount.toStringAsFixed(2);
                              }
                              return;
                            }

                            final amountInSelectedCurrency = double.tryParse(value.replaceAll(',', '')) ?? 0;
                            _updateCashPayment(amountInSelectedCurrency);
                          },
                          end: needsCashConversion? Wrap(
                            spacing: 5,
                            children: [
                              Text("${grandTotal * _cashExchangeRate}".toAmount()),
                              Text(_selectedCashCurrency)
                            ],
                          ) : null,
                          showFlag: true,
                          showClearButton: true,
                          showSymbol: false,
                          isRequired: true,
                          onSubmit: (e) => _onConfirm(),
                        ),
                      ),

                      // Exchange Rate Section for Cash
                      if (needsCashConversion) ...[
                        SizedBox(width: 5),
                        Expanded(
                          flex: 3,
                          child: ZTextFieldEntitled(
                            controller: _cashExchangeRateController,
                            title: "${tr.exchangeRate} (1 $_baseCurrency = $_selectedCashCurrency)",
                            hint: "1 $_baseCurrency = ",
                            inputFormat: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,6}'))
                            ],
                            onChanged: (value) {
                              final rate = double.tryParse(value.replaceAll(',', '')) ?? 1.0;
                              if (rate > 0) {
                                _updateCashExchangeRate(rate);
                              }
                            },
                            trailing: _isLoadingCashRate
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Account Payment Exchange Rate Section
                  // if (!_isPureCashMode && _currentState.customerAccount != null && remainingAmountInBase > 0)
                  // if (needsAccountConversion && !_isPureCashMode && _currentState.toCurrency != null) ...[
                  //   Divider(color: Theme.of(context).colorScheme.primary, endIndent: 4, indent: 4, thickness: 1.5),
                  //   const SizedBox(height: 8),
                  //   Row(
                  //     crossAxisAlignment: CrossAxisAlignment.end,
                  //     children: [
                  //       Expanded(
                  //         child: ZTextFieldEntitled(
                  //           controller: _exchangeRateController,
                  //           title: "${tr.exchangeRate} ($_baseCurrency → ${_currentState.toCurrency})",
                  //           hint: "1 $_baseCurrency = ?",
                  //           inputFormat: [
                  //             FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,6}'))
                  //           ],
                  //           onChanged: (value) {
                  //             final rate = double.tryParse(value.replaceAll(',', '')) ?? 1.0;
                  //             if (rate > 0) {
                  //               _updateExchangeRate(rate);
                  //             }
                  //           },
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ],
                ],
              ),

              const SizedBox(height: 12),

              // Credit Account Section
              if (!_isPureCashMode && _currentState.customerAccount != null && remainingAmountInBase > 0)
                ZCover(
                  padding: const EdgeInsets.all(12),
                  radius: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.credit_card, size: 20, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(tr.paymentSummary.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text("${_currentState.customerAccount?.accName} (${_currentState.customerAccount?.accNumber})", style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      AmountDisplay(
                          title: tr.cashReceipt,
                          baseAmount: cashAmountInBase,
                          baseCurrency: _baseCurrency,
                          convertedAmount: (needsCashConversion && cashAmountInBase > 0)
                              ? _currentCashAmountInSelectedCurrency
                              : null,
                          convertedCurrency: _selectedCashCurrency
                      ),
                      AmountDisplay(
                        title: tr.amountAddedToAR,
                        baseAmount: remainingAmountInBase,
                        baseCurrency: _baseCurrency,
                        convertedAmount: (widget.state.fromCurrency != widget.state.toCurrency && remainingAmountInBase > 0)
                            ? remainingAmountInAccountCurrency
                            : null,
                        isPositive: true,
                        showSign: true,
                        baseColor: Colors.green,
                        signColor: Colors.green,
                        convertedCurrency: accountCurrency,
                      ),

                      Divider(),
                      const SizedBox(height: 4),
                      _infoRow(
                        label: tr.currentBalance,
                        value: _currentState.currentBalance,
                        currency: accountCurrency,
                        fontSize: 15,
                      ),
                      _infoRow(
                        label: tr.newBalance,
                        value: newBalanceInAccountCurrency,
                        currency: accountCurrency,
                        isBold: true,
                        fontSize: 17,
                        color: newBalanceInAccountCurrency < 0 ? Colors.red : Colors.green,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPaymentModeLabel(PaymentMode mode) {
    switch (mode) {
      case PaymentMode.cash:
        return AppLocalizations.of(context)!.cash;
      case PaymentMode.credit:
        return AppLocalizations.of(context)!.creditTitle;
      case PaymentMode.mixed:
        return AppLocalizations.of(context)!.mixedTitle;
    }
  }

  Widget _infoRow({
    required String label,
    required double value,
    required String currency,
    bool isBold = false,
    FontWeight? fontWeight,
    Color? color,
    double fontSize = 14,
  }) {
    final themeColor = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
              label,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.bold : (fontWeight ?? FontWeight.normal)
              )
          ),
          Text(
            "${value.toAmount()} $currency",
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : (fontWeight ?? FontWeight.normal),
              fontSize: fontSize,
              color: color ?? themeColor.primary,
            ),
          ),
        ],
      ),
    );
  }
}
