import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:zaitoonpro/Features/Date/shamsi_converter.dart';
import 'package:zaitoonpro/Features/Other/amount_to_word.dart';
import 'package:zaitoonpro/Features/Other/extensions.dart';
import 'package:zaitoonpro/Features/PrintSettings/print_services.dart';
import 'package:zaitoonpro/Features/PrintSettings/report_model.dart';
import '../model/get_order_model.dart';

class OrderTxnPrintSettings extends PrintServices {

  Future<void> createDocument({
    required OrderTxnModel data,
    required ReportModel company,
    required String language,
    required pw.PageOrientation orientation,
    required pw.PdfPageFormat pageFormat,
  }) async {
    try {
      final document = await generateDocument(
        data: data,
        company: company,
        language: language,
        orientation: orientation,
        pageFormat: pageFormat,
      );

      await saveDocument(
        suggestedName: "${data.trnReference}_${DateTime.now().millisecondsSinceEpoch}.pdf",
        pdf: document,
      );
    } catch (e) {
      throw Exception('Failed to create document: $e');
    }
  }

  Future<void> printDocument({
    required OrderTxnModel data,
    required ReportModel company,
    required String language,
    required pw.PageOrientation orientation,
    required pw.PdfPageFormat pageFormat,
    required Printer selectedPrinter,
    required int copies,
    required String pages,
  }) async {
    try {
      final document = await generateDocument(
        data: data,
        company: company,
        language: language,
        orientation: orientation,
        pageFormat: pageFormat,
      );

      for (int i = 0; i < copies; i++) {
        await Printing.directPrintPdf(
          printer: selectedPrinter,
          onLayout: (pw.PdfPageFormat format) async {
            return document.save();
          },
        );

        if (i < copies - 1) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
    } catch (e) {
      throw Exception('Failed to print document: $e');
    }
  }

  Future<pw.Document> printPreview({
    required OrderTxnModel data,
    required ReportModel company,
    required String language,
    required pw.PageOrientation orientation,
    required pw.PdfPageFormat pageFormat,
  }) async {
    try {
      return await generateDocument(
        data: data,
        company: company,
        language: language,
        orientation: orientation,
        pageFormat: pageFormat,
      );
    } catch (e) {
      throw Exception('Failed to generate preview: $e');
    }
  }

  Future<pw.Document> generateDocument({
    required OrderTxnModel data,
    required ReportModel company,
    required String language,
    required pw.PageOrientation orientation,
    required pw.PdfPageFormat pageFormat,
  }) async {
    try {
      final document = pw.Document();


      final ByteData imageData = await rootBundle.load('assets/images/zaitoonLogo.png');
      final Uint8List imageBytes = imageData.buffer.asUint8List();
      final pw.MemoryImage logoImage = pw.MemoryImage(imageBytes);

      final isSale = data.trnType?.toLowerCase().contains('sale') ?? false;
      final isPurchase = data.trnType?.toLowerCase().contains('purchase') ?? false;
      final invoiceType = isSale ? 'SEL' : (isPurchase ? 'PUR' : 'TRN');

      final grandTotal = double.tryParse(data.totalBill ?? "0") ?? 0;
      final records = data.records ?? [];

      document.addPage(
        pw.MultiPage(
          maxPages: 1000,
          margin: const pw.EdgeInsets.symmetric(horizontal: 25, vertical: 15),
          pageFormat: pageFormat,
          textDirection: documentLanguage(language: language),
          orientation: orientation,
          build: (context) => [
            _invoiceHeaderWidget(
              language: language,
              invoiceType: invoiceType,
              invoiceNumber: data.trnReference ?? "",
              invoiceDate: data.trnEntryDate,
              reference: data.trnReference,
              status: data.trnStateText ?? "",
              branch: data.branch ?? "",
            ),
            _paymentSummary(
              language: language,
              grandTotal: grandTotal,
              records: records,
              currency: data.ccy,
              trnReference: data.trnReference ?? "",
              maker: data.maker ?? "",
              checker: data.checker ?? "",
              remark: data.remark,
              branch: data.branch ?? "",
            ),
            pw.SizedBox(height: 10),
            // Amount in words at the bottom
            _amountInWordsWidget(
              language: language,
              amount: grandTotal,
              currency: data.ccy ?? "",
            ),
          ],
          footer: (context) => footer(
            report: company,
            context: context,
            language: language,
            logoImage: logoImage,
          ),
        ),
      );
      return document;
    } catch (e) {
      throw Exception('Failed to generate document: $e');
    }
  }

  // Invoice Header Widget
  pw.Widget _invoiceHeaderWidget({
    required String language,
    required String invoiceType,
    required String invoiceNumber,
    required DateTime? invoiceDate,
    required String? reference,
    required String status,
    required String branch,
  }) {
    final invoiceTitle = invoiceType == 'SEL'
        ? tr(text: 'SEL', tr: language)
        : (invoiceType == 'PUR'
        ? tr(text: 'PUR', tr: language)
        : tr(text: 'transaction', tr: language));

    final isAuthorized = status.toLowerCase().contains('authorize');

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: pw.PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  zText(
                    text: invoiceTitle,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: pw.PdfColors.blue700,
                  ),
                  pw.SizedBox(height: 4),
                  zText(
                    text: "${tr(text: 'invoiceNumber', tr: language)}: $invoiceNumber",
                    fontSize: 10,
                  ),
                  zText(
                    text: "${tr(text: 'referenceNumber', tr: language)}: ${reference ?? '-'}",
                    fontSize: 10,
                  ),
                  zText(
                    text: "${tr(text: 'branch', tr: language)}: $branch",
                    fontSize: 10,
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  zText(
                    text: invoiceDate?.toDateTime ?? DateTime.now().toDateTime,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  pw.SizedBox(height: 2),
                  zText(
                    text: invoiceDate?.shamsiDateFormatted ?? DateTime.now().shamsiDateFormatted,
                    fontSize: 10,
                    color: pw.PdfColors.grey800,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: isAuthorized ? pw.PdfColors.green50 : pw.PdfColors.orange50,
                      border: pw.Border.all(
                        color: isAuthorized ? pw.PdfColors.green : pw.PdfColors.orange,
                        width: 1,
                      ),
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: zText(
                      text: status,
                      fontSize: 9,
                      color: isAuthorized ? pw.PdfColors.green : pw.PdfColors.orange,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Payment Summary Widget
  pw.Widget _paymentSummary({
    required String language,
    required double grandTotal,
    required List<Record> records,
    String? currency,
    required String trnReference,
    required String maker,
    required String checker,
    String? remark,
    required String branch,
  }) {
    final ccy = currency ?? '';

    // Separate debit and credit records
    final debitRecords = records.where((r) => r.debitCredit?.toLowerCase() == "debit").toList();
    final creditRecords = records.where((r) => r.debitCredit?.toLowerCase() == "credit").toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Grand Total
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: pw.BoxDecoration(
            color: pw.PdfColors.blue50,
            border: pw.Border.all(color: pw.PdfColors.blue100, width: 1),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              zText(
                text: tr(text: 'grandTotal', tr: language),
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: pw.PdfColors.blue700,
              ),
              zText(
                text: "${grandTotal.toAmount()} $ccy",
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: pw.PdfColors.blue700,
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 12),

        // Accounting Entries
        if (records.isNotEmpty) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: pw.PdfColors.grey300, width: 0.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                zText(
                  text: tr(text: 'transactionDetails', tr: language),
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: pw.PdfColors.blue700,
                ),
                pw.Divider(color: pw.PdfColors.grey300, thickness: 0.5, height: 8),

                // Debit Entries
                if (debitRecords.isNotEmpty) ...[
                  zText(
                    text: tr(text: 'debit', tr: language),
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: pw.PdfColors.red,
                  ),
                  pw.SizedBox(height: 4),
                  ...debitRecords.map((r) => _buildRecordRow(r, ccy, language)),
                  pw.SizedBox(height: 6),
                ],

                // Credit Entries
                if (creditRecords.isNotEmpty) ...[
                  zText(
                    text: tr(text: 'credit', tr: language),
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: pw.PdfColors.green,
                  ),
                  pw.SizedBox(height: 4),
                  ...creditRecords.map((r) => _buildRecordRow(r, ccy, language)),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 10),
        ],

        // Transaction Info
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: pw.PdfColors.grey300, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              zText(
                text: tr(text: 'transactionDetails', tr: language),
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: pw.PdfColors.blue700,
              ),
              pw.Divider(color: pw.PdfColors.grey300, thickness: 0.5, height: 8),
              _buildInfoRow(
                label: tr(text: 'maker', tr: language),
                value: maker,
              ),
              _buildInfoRow(
                label: tr(text: 'checker', tr: language),
                value: checker,
              ),
              _buildInfoRow(
                label: tr(text: 'branch', tr: language),
                value: branch,
              ),
              if (remark != null && remark.isNotEmpty) ...[
                _buildInfoRow(
                  label: tr(text: 'narration', tr: language),
                  value: remark,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Amount in Words Widget
  pw.Widget _amountInWordsWidget({
    required String language,
    required double amount,
    required String currency,
  }) {
    final lang = NumberToWords.getLanguageFromLocale(Locale(language));
    final cleanAmount = amount.toString().replaceAll(',', '');
    final parsedAmount = int.tryParse(
      double.tryParse(cleanAmount)?.toStringAsFixed(0) ?? "0",
    ) ?? 0;
    final amountInWords = NumberToWords.convert(parsedAmount, lang);

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: pw.PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          zText(
            text: tr(text: 'amountInWords', tr: language),
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
          pw.SizedBox(height: 2),
          zText(
            text: amountInWords.isNotEmpty ? "$amountInWords $currency" : "",
            fontSize: 10,
            fontStyle: pw.FontStyle.italic,
          ),
        ],
      ),
    );
  }

  // Record Row Widget
  pw.Widget _buildRecordRow(Record record, String ccy, String language) {
    final isDebit = record.debitCredit?.toLowerCase() == "debit";
    final amount = double.tryParse(record.amount ?? "0") ?? 0;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 3),
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 3,
            child: zText(
              text: "${record.accountName ?? "-"} (${record.accountNumber ?? "-"})",
              fontSize: 9,
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: zText(
              text: "${amount.toAmount()} $ccy",
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: isDebit ? pw.PdfColors.red : pw.PdfColors.green,
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // Info Row Widget
  pw.Widget _buildInfoRow({
    required String label,
    required String value,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: zText(
              text: "$label:",
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: pw.PdfColors.grey700,
            ),
          ),
          pw.Expanded(
            child: zText(
              text: value,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}