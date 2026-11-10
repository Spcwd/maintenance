import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/maintenance_request.dart';

/// Full-page receipt. Everything is sized from the page width, so it looks
/// good on A4, A5 and Letter. The signature is pinned at the bottom center.
Future<Uint8List> buildReceiptPdf(
    MaintenanceRequest r, PdfPageFormat format) async {
  final doc = pw.Document(title: r.id, author: 'Maintenance System');

  const navy = PdfColor.fromInt(0xFF0B1B4D);
  const navy2 = PdfColor.fromInt(0xFF16296B);
  const blue = PdfColor.fromInt(0xFF2563EB);
  const green = PdfColor.fromInt(0xFF16A34A);
  const ink = PdfColor.fromInt(0xFF0F172A);
  const muted = PdfColor.fromInt(0xFF64748B);
  const line = PdfColor.fromInt(0xFFE2E8F0);
  const soft = PdfColor.fromInt(0xFFF8FAFC);
  const lightBlue = PdfColor.fromInt(0xFFBFD3FF);

  // Scale everything relative to A4 so it also fits A5 / Letter.
  final k = format.width / PdfPageFormat.a4.width;
  double s(double v) => v * k;
  final pad = s(40);
  final bodyWidth = format.width - pad * 2;

  pw.Widget label(String t, {PdfColor color = muted}) => pw.Text(
        t.toUpperCase(),
        style: pw.TextStyle(
          fontSize: s(8.5),
          color: color,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1.2,
        ),
      );

  pw.Widget field(String l, String v) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          label(l),
          pw.SizedBox(height: s(4)),
          pw.Text(
            v.isEmpty ? '-' : v,
            style: pw.TextStyle(
                fontSize: s(12.5), fontWeight: pw.FontWeight.bold, color: ink),
          ),
        ],
      );

  pw.Widget timeCard(
          String title, DateTime? when, String emptyText, PdfColor accent) =>
      pw.Expanded(
        child: pw.Container(
          padding: pw.EdgeInsets.fromLTRB(s(16), s(14), s(16), s(14)),
          decoration: pw.BoxDecoration(
            color: soft,
            borderRadius: pw.BorderRadius.circular(s(10)),
            border: pw.Border.all(color: line, width: 1),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: s(8),
                    height: s(8),
                    decoration: pw.BoxDecoration(
                        color: accent, shape: pw.BoxShape.circle),
                  ),
                  pw.SizedBox(width: s(6)),
                  label(title, color: accent),
                ],
              ),
              pw.SizedBox(height: s(10)),
              pw.Text(
                when == null ? '-' : formatDate(when),
                style: pw.TextStyle(
                    fontSize: s(17),
                    fontWeight: pw.FontWeight.bold,
                    color: ink),
              ),
              pw.SizedBox(height: s(3)),
              pw.Text(
                when == null ? emptyText : formatTime12(when),
                style: pw.TextStyle(
                    fontSize: s(14),
                    fontWeight: pw.FontWeight.bold,
                    color: when == null ? muted : accent),
              ),
            ],
          ),
        ),
      );

  pw.Widget block(String title, String text, double minHeight) => pw.Container(
        constraints: pw.BoxConstraints(minHeight: s(minHeight)),
        padding: pw.EdgeInsets.all(s(16)),
        decoration: pw.BoxDecoration(
          color: soft,
          border: pw.Border(left: pw.BorderSide(color: blue, width: s(4))),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            label(title, color: blue),
            pw.SizedBox(height: s(6)),
            pw.Text(
              text.isEmpty ? '-' : text,
              style: pw.TextStyle(
                  fontSize: s(12), lineSpacing: s(4), color: ink),
            ),
          ],
        ),
      );

  pw.Widget circle(double size, PdfColor color) => pw.Container(
        width: size,
        height: size,
        decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
      );

  pw.Widget header() => pw.Container(
        height: s(130),
        color: navy,
        child: pw.Stack(
          children: [
            pw.Positioned(right: -s(50), top: -s(70), child: circle(s(190), navy2)),
            pw.Positioned(right: s(150), bottom: s(12), child: circle(s(64), navy2)),
            pw.Center(
              child: pw.Padding(
                padding: pw.EdgeInsets.symmetric(horizontal: pad),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('MAINTENANCE SYSTEM',
                              style: pw.TextStyle(
                                  fontSize: s(10),
                                  color: lightBlue,
                                  letterSpacing: 2)),
                          pw.SizedBox(height: s(6)),
                          pw.Text('REQUEST RECEIPT',
                              style: pw.TextStyle(
                                  fontSize: s(30),
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: s(4)),
                          pw.Text('Official maintenance request copy',
                              style: pw.TextStyle(
                                  fontSize: s(10), color: lightBlue)),
                        ],
                      ),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.symmetric(
                          horizontal: s(18), vertical: s(12)),
                      decoration: pw.BoxDecoration(
                        color: navy2,
                        borderRadius: pw.BorderRadius.circular(s(12)),
                      ),
                      child: pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('REQUEST NO.',
                              style: pw.TextStyle(
                                  fontSize: s(8.5),
                                  color: lightBlue,
                                  letterSpacing: 1.2)),
                          pw.SizedBox(height: s(3)),
                          pw.Text(r.id,
                              style: pw.TextStyle(
                                  fontSize: s(24),
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  // Only the person the request is addressed to signs - bottom center.
  pw.Widget signatureBlock() => pw.Padding(
        padding: pw.EdgeInsets.only(bottom: s(24)),
        child: pw.Center(
          child: pw.SizedBox(
            width: s(240),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.SizedBox(height: s(46)),
                pw.Divider(height: 1, thickness: 1.2, color: navy),
                pw.SizedBox(height: s(6)),
                pw.Text(
                  r.addressedTo.isEmpty ? '-' : r.addressedTo,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: s(13),
                      fontWeight: pw.FontWeight.bold,
                      color: navy),
                ),
                if (r.addressedTitle.isNotEmpty) ...[
                  pw.SizedBox(height: s(2)),
                  pw.Text(
                    r.addressedTitle,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: s(10.5), color: muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      );

  pw.Widget footer() => pw.Container(
        height: s(34),
        color: navy,
        alignment: pw.Alignment.center,
        child: pw.Text(
          'Maintenance System   |   Printed on ${formatDateTime(DateTime.now())}',
          style: pw.TextStyle(fontSize: s(9), color: lightBlue),
        ),
      );

  doc.addPage(
    pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          header(),
          pw.Container(height: s(5), color: blue),

          // Body: scales down automatically if the text is very long,
          // so everything always stays on one full page.
          pw.Expanded(
            child: pw.Padding(
              padding: pw.EdgeInsets.fromLTRB(pad, s(22), pad, s(8)),
              child: pw.FittedBox(
                fit: pw.BoxFit.scaleDown,
                alignment: pw.Alignment.topCenter,
                child: pw.SizedBox(
                  width: bodyWidth,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      // Requested / Completed
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          timeCard('Requested', r.date, '-', blue),
                          pw.SizedBox(width: s(14)),
                          timeCard('Completed', r.completedAt,
                              'Not yet completed', green),
                        ],
                      ),
                      pw.SizedBox(height: s(18)),

                      // Subject
                      label('Subject', color: blue),
                      pw.SizedBox(height: s(4)),
                      pw.Text(
                        r.subject.isEmpty ? '-' : r.subject,
                        style: pw.TextStyle(
                            fontSize: s(20),
                            fontWeight: pw.FontWeight.bold,
                            color: navy),
                      ),
                      pw.SizedBox(height: s(6)),
                      pw.Container(width: s(48), height: s(3), color: blue),
                      pw.SizedBox(height: s(18)),

                      // Info panel
                      pw.Container(
                        padding: pw.EdgeInsets.all(s(18)),
                        decoration: pw.BoxDecoration(
                          borderRadius: pw.BorderRadius.circular(s(10)),
                          border: pw.Border.all(color: line, width: 1),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Expanded(
                                    child:
                                        field('Addressed to', r.addressedTo)),
                                pw.SizedBox(width: s(16)),
                                pw.Expanded(
                                    child:
                                        field('Requested by', r.requesterName)),
                              ],
                            ),
                            pw.SizedBox(height: s(14)),
                            pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Expanded(
                                    child: field('Designation', r.designation)),
                                pw.SizedBox(width: s(16)),
                                pw.Expanded(
                                    child: field('Location', r.location)),
                              ],
                            ),
                            pw.SizedBox(height: s(14)),
                            field('Request type', r.type),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: s(18)),

                      block('Details', r.details, 90),
                      pw.SizedBox(height: s(12)),
                      block('Reason / Purpose', r.reason, 66),
                    ],
                  ),
                ),
              ),
            ),
          ),

          signatureBlock(),
          footer(),
        ],
      ),
    ),
  );

  return doc.save();
}