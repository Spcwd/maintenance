import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/maintenance_request.dart';
import '../utils/receipt_pdf.dart';

class ReceiptPage extends StatelessWidget {
  final MaintenanceRequest request;
  const ReceiptPage({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE2E8F0),
      appBar: AppBar(
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
            ),
          ),
        ),
        title: Text('Receipt - ${request.id}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: PdfPreview(
        build: (format) => buildReceiptPdf(request, format),
        pdfFileName: '${request.id}.pdf',
        initialPageFormat: PdfPageFormat.a4,
        pageFormats: const {
          'A4': PdfPageFormat.a4,
          'Letter': PdfPageFormat.letter,
          'A5': PdfPageFormat.a5,
        },
        canChangeOrientation: false,
        canDebug: false,
        previewPageMargin: const EdgeInsets.all(16),
        scrollViewDecoration: const BoxDecoration(color: Color(0xFFE2E8F0)),
      ),
    );
  }
}