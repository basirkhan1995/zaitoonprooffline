import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:zaitoonpro/Features/Date/shamsi_converter.dart';
import 'package:zaitoonpro/Features/Other/cover.dart';
import 'package:zaitoonpro/Features/Other/extensions.dart';
import 'package:zaitoonpro/Features/Other/zDialog.dart';
import 'package:zaitoonpro/Features/Widgets/no_data_widget.dart';
import 'package:zaitoonpro/Localizations/l10n/translations/app_localizations.dart';
import 'package:zaitoonpro/Views/Menu/Ui/Settings/Ui/Company/CompanyProfile/bloc/company_profile_bloc.dart';
import 'package:zaitoonpro/Features/Widgets/outline_button.dart';
import 'package:zaitoonpro/Views/Auth/bloc/auth_bloc.dart';
import '../../../../../../Features/PrintSettings/print_preview.dart';
import '../../../../../../Features/PrintSettings/report_model.dart';
import '../bloc/transactions_bloc.dart';
import 'Print/txn_order_print.dart';
import 'bloc/order_txn_bloc.dart';
import 'model/get_order_model.dart';

class OrderTxnView extends StatelessWidget {
  final String reference;
  const OrderTxnView({super.key, required this.reference});

  @override
  Widget build(BuildContext context) => const _OrderTxnDialog();
}

class _OrderTxnDialog extends StatefulWidget {
  const _OrderTxnDialog();
  @override
  State<_OrderTxnDialog> createState() => _OrderTxnDialogState();
}

class _OrderTxnDialogState extends State<_OrderTxnDialog> {
  OrderTxnModel? orderTxn;
  bool isPrint = true;
  final company = ReportModel();

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthBloc>().state;

    if (auth is! AuthenticatedState) return const SizedBox();
    final login = auth.loginData;

    return BlocBuilder<CompanyProfileBloc, CompanyProfileState>(
      builder: (context, state) => ZFormDialog(
        padding: const EdgeInsets.all(15),
        onAction: null,
        title: tr.transactionDetails,
        isActionTrue: false,
        width: MediaQuery.of(context).size.width * .7,
        child: BlocBuilder<OrderTxnBloc, OrderTxnState>(
          builder: (context, state) {
            if (state is OrderTxnErrorState) {
              return NoDataWidget(message: state.message);
            }
            if (state is OrderTxnLoadingState) {
              return SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (state is OrderTxnLoadedState) {
              orderTxn = state.data;
              final records = orderTxn?.records ?? [];

              final showDeleteButton = orderTxn?.trnStatus == 0 && orderTxn?.maker == login.usrName;
              final showAuthorizeButton = orderTxn?.trnStatus == 0 && orderTxn?.maker != login.usrName;
              final isDeleteLoading = context.watch<TransactionsBloc>().state is TxnDeleteLoadingState;
              final isAuthorizeLoading = context.watch<TransactionsBloc>().state is TxnAuthorizeLoadingState;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "${tr.referenceNumber}: ",
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: color.onSurface.withAlpha(150),
                                    ),
                                  ),
                                  Text(
                                    orderTxn?.trnReference ?? "-",
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ZCover(
                                color: color.primary.withAlpha(30),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                child: Text(
                                  orderTxn?.trntName ?? orderTxn?.trnType ?? "-",
                                  style: textTheme.titleMedium?.copyWith(
                                    color: color.primary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              spacing: 8,
                              children: [
                                InkWell(
                                  onTap: () => getPrinted(data: orderTxn!, company: company),
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: color.primary.withValues(alpha: .06),
                                    child: Icon(Icons.print, size: 18, color: color.outline.withValues(alpha: .9)),
                                  ),
                                ),
                                _buildStatusBadge(context, orderTxn?.trnStateText ?? ""),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              orderTxn?.trnEntryDate?.toDateTime ?? "-",
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Total Amount Card
                    ZCover(
                      color: color.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr.totalAmount,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: color.onSurface.withAlpha(150),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    orderTxn?.totalBill?.toAmount() ?? "0.00",
                                    style: textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: color.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    orderTxn?.ccy ?? "USD",
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: color.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (orderTxn?.remark?.isNotEmpty == true)
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(left: 16),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: color.primary.withAlpha(10),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr.remark,
                                      style: textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: color.primary,
                                      ),
                                    ),
                                    Text(
                                      orderTxn?.remark ?? "",
                                      style: textTheme.bodySmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Accounting Records - COMPRESSED
                    ZCover(
                      color: color.surface,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(FontAwesomeIcons.buildingColumns, size: 16, color: color.primary),
                              const SizedBox(width: 8),
                              Text(
                                tr.accountingEntries,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (records.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  tr.noRecords,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: color.onSurface.withAlpha(150),
                                  ),
                                ),
                              ),
                            )
                          else
                            Column(
                              children: records.map((record) => _buildCompactRecordItem(record, context)).toList(),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Additional Info - COMPRESSED
                    ZCover(
                      color: color.surface,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.operation,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(height: 12, thickness: 1),
                          _buildCompactDetailRow(tr.maker, orderTxn?.maker ?? "-"),
                          _buildCompactDetailRow(tr.checker, orderTxn?.checker ?? "-"),
                          _buildCompactDetailRow(tr.currencyTitle, orderTxn?.ccy ?? "-"),
                          _buildCompactDetailRow(tr.branch, orderTxn?.branch ?? "-"),
                        ],
                      ),
                    ),

                    // Action Buttons
                    if (showDeleteButton || showAuthorizeButton) ...[
                      const SizedBox(height: 12),
                      ZCover(
                        color: color.surface,
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr.actions,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(thickness: 1, height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              spacing: 10,
                              children: [
                                if (showDeleteButton)
                                  ZOutlineButton(
                                    width: 130,
                                    height: 38,
                                    icon: isDeleteLoading ? null : Icons.delete_outline_rounded,
                                    isActive: true,
                                    backgroundHover: color.error,
                                    onPressed: () {
                                      context.read<TransactionsBloc>().add(
                                        DeletePendingTxnEvent(
                                          reference: orderTxn?.trnReference ?? "",
                                          usrName: login.usrName ?? "",
                                        ),
                                      );
                                    },
                                    label: isDeleteLoading
                                        ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: color.primary,
                                      ),
                                    )
                                        : Text(tr.delete, style: textTheme.bodyMedium),
                                  ),
                                if (showAuthorizeButton)
                                  ZOutlineButton(
                                    width: 130,
                                    height: 38,
                                    onPressed: () {
                                      context.read<TransactionsBloc>().add(
                                        AuthorizeTxnEvent(
                                          reference: orderTxn?.trnReference ?? "",
                                          usrName: login.usrName ?? "",
                                        ),
                                      );
                                    },
                                    icon: isAuthorizeLoading ? null : Icons.check_circle_outline,
                                    isActive: true,
                                    backgroundColor: color.primary,
                                    textColor: color.onPrimary,
                                    label: isAuthorizeLoading
                                        ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: color.surface,
                                      ),
                                    )
                                        : Text(tr.authorize, style: textTheme.bodyMedium),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }

  // COMPACT Status Badge
  Widget _buildStatusBadge(BuildContext context, String status) {
    final color = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context)!;
    final isAuthorized = status.toLowerCase().contains("authorize");

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAuthorized ? color.primary.withAlpha(30) : Colors.orange.withAlpha(30),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: isAuthorized ? color.primary.withAlpha(100) : Colors.orange.withAlpha(100),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAuthorized ? Icons.verified : Icons.pending,
            size: 12,
            color: isAuthorized ? color.primary : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            isAuthorized ? tr.authorizedTitle : tr.pendingTitle,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isAuthorized ? color.primary : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  // COMPACT Record Item
  Widget _buildCompactRecordItem(Record record, BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final isDebit = record.debitCredit?.toLowerCase() == "debit";
    final tr = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.outline.withAlpha(30), width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.accountName ?? "-",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "${tr.accountNumber}: ${record.accountNumber ?? "-"}",
                  style: TextStyle(
                    fontSize: 10,
                    color: color.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isDebit ? Colors.red.withAlpha(30) : Colors.green.withAlpha(30),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  record.debitCredit ?? "-",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isDebit ? Colors.red[700] : Colors.green[700],
                  ),
                ),
              ),
              Text(
                "${record.amount?.toAmount()} ${orderTxn?.ccy ?? ""}",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDebit ? Colors.red[700] : Colors.green[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // COMPACT Detail Row
  Widget _buildCompactDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void getPrinted({required OrderTxnModel data, required ReportModel company}) {
    if (isPrint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (_) => PrintPreviewDialog<OrderTxnModel>(
            data: data,
            company: company,
            buildPreview: ({
              required data,
              required language,
              required orientation,
              required pageFormat,
            }) =>
                OrderTxnPrintSettings().printPreview(
                  company: company,
                  language: language,
                  orientation: orientation,
                  pageFormat: pageFormat,
                  data: data,
                ),
            onPrint: ({
              required data,
              required language,
              required orientation,
              required pageFormat,
              required selectedPrinter,
              required copies,
              required pages,
            }) =>
                OrderTxnPrintSettings().printDocument(
                  company: company,
                  language: language,
                  orientation: orientation,
                  pageFormat: pageFormat,
                  selectedPrinter: selectedPrinter,
                  data: data,
                  copies: copies,
                  pages: pages,
                ),
            onSave: ({
              required data,
              required language,
              required orientation,
              required pageFormat,
            }) =>
                OrderTxnPrintSettings().createDocument(
                  data: data,
                  company: company,
                  language: language,
                  orientation: orientation,
                  pageFormat: pageFormat,
                ),
          ),
        );
      });
    }
  }
}