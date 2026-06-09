import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../../../../../Features/Other/extensions.dart';
import '../../../../../../../Features/Other/toast.dart';
import '../../../../../../../Features/Widgets/outline_button.dart';
import '../../../../../../../Localizations/l10n/translations/app_localizations.dart';
import 'model/product_report_model.dart';


class ProductReportExcelService {

  static Future<void> exportToExcel({
    required List<ProductReportModel> productList,
    required String baseCurrency,
    required String fileName,
    required BuildContext context,
  }) async {

    if (productList.isEmpty) {
      _showToast(context, "No data to export", isError: true);
      return;
    }

    try {
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = "Product Report";

      int currentRow = 1;

      /// TITLE
      final titleRange = sheet.getRangeByName('A$currentRow:J$currentRow');
      titleRange.merge();
      titleRange.setText("PRODUCT REPORT");

      titleRange.cellStyle
        ..fontSize = 16
        ..bold = true
        ..hAlign = HAlignType.center
        ..vAlign = VAlignType.center
        ..backColor = '#005994'
        ..fontColor = '#FFFFFF';

      currentRow++;

      /// GENERATED TIME
      final timeRange = sheet.getRangeByName('A$currentRow:J$currentRow');
      timeRange.merge();
      timeRange.setText(
          "Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}");

      timeRange.cellStyle
        ..fontSize = 10
        ..italic = true
        ..hAlign = HAlignType.center;

      currentRow += 2;

      /// HEADERS
      List<String> headers = [
        "No",
        "Product Name",
        "Storage",
        "Unit",
        "Available",
        "Batch",
        "Available Items",
        "Recent Purchase Price",
        "Sell Price",
        "Average Price",
        "Total Value"
      ];

      // Adjust merged range for title and time to match new column count
      // Update the title and time ranges from J to K
      // Actually, let's update the previous ranges

      for (int col = 0; col < headers.length; col++) {
        final cell = sheet.getRangeByIndex(currentRow, col + 1);
        cell.setText(headers[col]);

        cell.cellStyle
          ..fontSize = 12
          ..bold = true
          ..hAlign = HAlignType.center
          ..vAlign = VAlignType.center
          ..backColor = '#005994'
          ..fontColor = '#FFFFFF';

        cell.cellStyle.borders.all.lineStyle = LineStyle.thin;
      }

      currentRow++;

      /// DATA
      double totalValue = 0;
      int totalQuantity = 0;
      int totalBatch = 0;
      int totalAvailableItems = 0;

      for (int i = 0; i < productList.length; i++) {
        var product = productList[i];

        double recentPrice = double.tryParse(product.recentPurPrice ?? '0') ?? 0;
        double sellPrice = double.tryParse(product.sellPrice ?? '0') ?? 0;
        double avgPrice = double.tryParse(product.averagePrice ?? '0') ?? 0;
        int available = int.tryParse(product.available ?? '0') ?? 0;
        int batch = product.batch ?? 0;
        int availableItem = int.tryParse(product.availableItem ?? '0') ?? 0;
        double itemTotalValue = double.tryParse(product.totalValue ?? '0') ?? 0;

        totalValue += itemTotalValue;
        totalQuantity += available;
        totalBatch += batch;
        totalAvailableItems += availableItem;

        List<dynamic> values = [
          i + 1,
          product.proName ?? "",
          product.stgName ?? "",
          product.proUnit ?? "",
          available,
          batch,
          availableItem,
          recentPrice,
          sellPrice,
          avgPrice,
          itemTotalValue
        ];

        for (int col = 0; col < values.length; col++) {
          final cell = sheet.getRangeByIndex(currentRow, col + 1);

          if (values[col] is double || values[col] is int) {
            cell.setNumber((values[col] as num).toDouble());

            // Format currency columns
            if (col >= 7) { // Price columns
              cell.numberFormat = '#,##0.00';
            } else if (col == 4 || col == 5 || col == 6) { // Quantity columns
              cell.numberFormat = '#,##0';
            }

            cell.cellStyle.hAlign = HAlignType.right;
          } else {
            cell.setText(values[col].toString());
            cell.cellStyle.hAlign = HAlignType.left;
          }

          cell.cellStyle.borders.all.lineStyle = LineStyle.thin;
        }

        currentRow++;
      }

      currentRow++;

      /// SUMMARY
      void summaryRow(String title, String value, {bool isBold = true}) {
        final t = sheet.getRangeByIndex(currentRow, 1, currentRow, 5);
        t.merge();
        t.setText(title);
        t.cellStyle
          ..fontSize = 12
          ..bold = isBold
          ..hAlign = HAlignType.right;

        final v = sheet.getRangeByIndex(currentRow, 6, currentRow, 11);
        v.merge();
        v.setText(value);
        v.cellStyle
          ..fontSize = 12
          ..bold = isBold
          ..hAlign = HAlignType.left;

        currentRow++;
      }

      summaryRow("TOTAL ITEMS:", productList.length.toString());
      summaryRow("TOTAL QUANTITY:", totalQuantity.toAmount(decimal: 0));
      summaryRow("TOTAL BATCH:", totalBatch.toAmount(decimal: 0));
      summaryRow("TOTAL AVAILABLE ITEMS:", totalAvailableItems.toAmount(decimal: 0));
      summaryRow("TOTAL VALUE:", "${totalValue.toAmount(decimal: 2)} $baseCurrency");

      /// SET COLUMN WIDTHS
      List<double> columnWidths = [
        5.0,   // A: No
        35.0,  // B: Product Name
        25.0,  // C: Storage
        8.0,   // D: Unit
        12.0,  // E: Available
        12.0,  // F: Batch
        15.0,  // G: Available Items
        20.0,  // H: Recent Purchase Price
        15.0,  // I: Sell Price
        15.0,  // J: Average Price
        18.0,  // K: Total Value
      ];

      // Apply widths to each column
      for (int col = 0; col < columnWidths.length; col++) {
        try {
          final column = sheet.getRangeByIndex(1, col + 1);
          column.columnWidth = columnWidths[col];
        } catch (e) {
          // Ignore column width errors
        }
      }

      // Update the merged ranges for title and time since we now have 11 columns (A to K)
      // Re-merge with correct ranges
      final titleRangeUpdated = sheet.getRangeByName('A1:K1');
      titleRangeUpdated.merge();

      final timeRangeUpdated = sheet.getRangeByName('A2:K2');
      timeRangeUpdated.merge();

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      if (!context.mounted) return;

      await _saveFile(bytes, fileName, context);

    } catch (e) {
      if (context.mounted) {
        _showToast(context, "Error exporting to Excel: $e", isError: true);
      }
    }
  }

  static Future<void> _saveFile(List<int> bytes, String fileName, BuildContext context) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!context.mounted) return;

      _showToast(
        context,
        "Excel file saved successfully",
        isError: false,
      );

      final openFile = await _showOpenFileDialog(context);

      if (openFile == true && context.mounted) {
        await _openFile(file.path, context);
      }

    } catch (e) {
      if (context.mounted) {
        _showToast(context, "Error saving file: $e", isError: true);
      }
    }
  }

  static Future<bool?> _showOpenFileDialog(BuildContext context) async {
    if (!context.mounted) return false;

    return await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          elevation: 0,
          title: const Text(
            'Export Successful',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Do you want to open the Excel file?',
            style: TextStyle(fontSize: 14),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          titlePadding: const EdgeInsets.fromLTRB(15, 20, 15, 8),
          contentPadding: const EdgeInsets.fromLTRB(15, 8, 15, 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          actions: [
            ZOutlineButton(
              width: 80,
              height: 40,
              onPressed: () => Navigator.of(dialogContext).pop(false),
              label: Text(
                AppLocalizations.of(context)!.cancel,
              ),
            ),
            ZOutlineButton(
              height: 38,
              width: 80,
              isActive: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              label: Text(
                AppLocalizations.of(context)!.yes,
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _openFile(String filePath, BuildContext context) async {
    try {
      final Uri fileUri = Uri.file(filePath);

      if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri);
      } else {
        if (context.mounted) {
          _showToast(
            context,
            "Could not open file. Please open manually at:\n$filePath",
            isError: true,
            duration: const Duration(seconds: 5),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showToast(
          context,
          "Error opening file: $e",
          isError: true,
        );
      }
    }
  }

  static void _showToast(
      BuildContext context,
      String message, {
        bool isError = false,
        Duration duration = const Duration(seconds: 3),
      }) {
    if (!context.mounted) return;

    ToastManager.show(
      context: context,
      title: isError ? "Error" : "Success Exported",
      message: message,
      type: isError ? ToastType.error : ToastType.success,
    );
  }
}