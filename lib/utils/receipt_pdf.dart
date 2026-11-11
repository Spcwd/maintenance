import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/maintenance_request.dart';

/// Clean black-and-white receipt that fills the page.
/// - Acknowledgement box: the person who will do the work signs there.
/// - Bottom center: the person the request is addressed to signs there.
Future<Uint8List> buildReceiptPdf(
    MaintenanceRequest r, PdfPageFormat format) async {
  final doc = pw.Document(title: r.id, author: 'Maintenance System');

  const ink = PdfColor.fromInt(0xFF111827);
  const text = PdfColor.fromInt(0xFF374151);
  const muted = PdfColor.fromInt(0xFF6B7280);
  const line = PdfColor.fromInt(0xFFD1D5DB);
  const soft = PdfColor.fromInt(0xFFF3F4F6);

  // Scale everything relative to A4 so it also fits A5 / Letter.
  final k = format.width / PdfPageFormat.a4.width;
  double s(double v) => v * k;
  final outer = s(18); // paper margin (also keeps printers happy)
  final pad = s(32); // space inside the frame
  final bodyWidth = format.width - outer * 2 - pad * 2 - 2;

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
            v,
            style: pw.TextStyle(
                fontSize: s(12), fontWeight: pw.FontWeight.bold, color: ink),
          ),
        ],
      );

  pw.Widget timeCard(String title, DateTime? when, String emptyText) =>
      pw.Expanded(
        child: pw.Container(
          padding: pw.EdgeInsets.fromLTRB(s(14), s(12), s(14), s(12)),
          decoration: pw.BoxDecoration(
            color: soft,
            border: pw.Border.all(color: line, width: 1),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              label(title),
              pw.SizedBox(height: s(8)),
              pw.Text(
                when == null ? '-' : formatDate(when),
                style: pw.TextStyle(
                    fontSize: s(16),
                    fontWeight: pw.FontWeight.bold,
                    color: ink),
              ),
              pw.SizedBox(height: s(2)),
              pw.Text(
                when == null ? emptyText : formatTime12(when),
                style: pw.TextStyle(fontSize: s(13), color: text),
              ),
            ],
          ),
        ),
      );

  pw.Widget block(String title, String body, double minHeight) => pw.Container(
        constraints: pw.BoxConstraints(minHeight: s(minHeight)),
        padding: pw.EdgeInsets.all(s(14)),
        decoration: pw.BoxDecoration(
          color: soft,
          border: pw.Border(left: pw.BorderSide(color: ink, width: s(3))),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            label(title, color: ink),
            pw.SizedBox(height: s(5)),
            pw.Text(
              body,
              style: pw.TextStyle(
                  fontSize: s(11.5), lineSpacing: s(3), color: text),
            ),
          ],
        ),
      );

  // A signature line with the printed name (and designation) under it.
  pw.Widget signLine({
    String name = '',
    String title = '',
    String caption = '',
  }) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(height: 1, color: ink),
          pw.SizedBox(height: s(4)),
          if (name.isNotEmpty)
            pw.Text(name,
                style: pw.TextStyle(
                    fontSize: s(11.5),
                    fontWeight: pw.FontWeight.bold,
                    color: ink)),
          if (title.isNotEmpty)
            pw.Text(title, style: pw.TextStyle(fontSize: s(9.5), color: muted)),
          if (caption.isNotEmpty)
            pw.Text(caption, style: pw.TextStyle(fontSize: s(9), color: muted)),
        ],
      );

  // Acknowledgement: the person who will carry out the request signs here.
  pw.Widget acknowledgement() => pw.Container(
        padding: pw.EdgeInsets.all(s(14)),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: ink, width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            label('Acknowledgement', color: ink),
            pw.SizedBox(height: s(5)),
            pw.Text(
              'I acknowledge receipt of this request and will carry out the work described above.',
              style: pw.TextStyle(fontSize: s(10), color: text),
            ),
            pw.SizedBox(height: s(30)),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: signLine(
                    name: r.acknowledgedBy,
                    title: r.acknowledgedTitle,
                    caption:
                        r.acknowledgedBy.isEmpty ? 'Name and signature' : '',
                  ),
                ),
                pw.SizedBox(width: s(28)),
                pw.Expanded(
                  flex: 2,
                  child: signLine(caption: 'Date'),
                ),
              ],
            ),
          ],
        ),
      );

  pw.Widget header() => pw.Padding(
        padding: pw.EdgeInsets.fromLTRB(pad, s(30), pad, 0),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('MAINTENANCE SYSTEM',
                          style: pw.TextStyle(
                              fontSize: s(9.5),
                              color: muted,
                              letterSpacing: 2)),
                      pw.SizedBox(height: s(6)),
                      pw.Text('REQUEST RECEIPT',
                          style: pw.TextStyle(
                              fontSize: s(28),
                              color: ink,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1)),
                    ],
                  ),
                ),
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(
                      horizontal: s(16), vertical: s(10)),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: ink, width: 1.2),
                  ),
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      label('Request no.'),
                      pw.SizedBox(height: s(3)),
                      pw.Text(r.id,
                          style: pw.TextStyle(
                              fontSize: s(22),
                              color: ink,
                              fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: s(16)),
            pw.Container(height: 2.4, color: ink),
            pw.SizedBox(height: 3),
            pw.Container(height: 0.7, color: ink),
          ],
        ),
      );

  // The person the request is addressed to signs here - bottom center.
  pw.Widget signatureBlock() => pw.Padding(
        padding: pw.EdgeInsets.only(bottom: s(12)),
        child: pw.Center(
          child: pw.SizedBox(
            width: s(240),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.SizedBox(height: s(40)),
                pw.Container(height: 1.2, color: ink),
                pw.SizedBox(height: s(5)),
                if (r.addressedTo.trim().isNotEmpty)
                  pw.Text(
                    r.addressedTo,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                        fontSize: s(13),
                        fontWeight: pw.FontWeight.bold,
                        color: ink),
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

  pw.Widget footer() => pw.Padding(
        padding: pw.EdgeInsets.fromLTRB(pad, 0, pad, s(14)),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(height: 0.7, color: line),
            pw.SizedBox(height: s(6)),
            pw.Text(
              'Maintenance System   |   Printed on ${formatDateTime(DateTime.now())}',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: s(8.5), color: muted),
            ),
          ],
        ),
      );

  final infoFields = <pw.Widget>[
    if (r.addressedTo.trim().isNotEmpty)
      pw.Expanded(child: field('Addressed to', r.addressedTo)),
    if (r.requesterName.trim().isNotEmpty)
      pw.Expanded(child: field('Requested by', r.requesterName)),
    if (r.designation.trim().isNotEmpty)
      pw.Expanded(child: field('Designation', r.designation)),
    if (r.location.trim().isNotEmpty)
      pw.Expanded(child: field('Location', r.location)),
  ];
  final hasAcknowledgement = r.acknowledgedBy.trim().isNotEmpty ||
      r.acknowledgedTitle.trim().isNotEmpty;
  final hasRecipientSignature =
      r.addressedTo.trim().isNotEmpty || r.addressedTitle.trim().isNotEmpty;

  doc.addPage(
    pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.all(outer),
      build: (ctx) => pw.Container(
        width: double.infinity,
        height: double.infinity,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: ink, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            header(),

            // Body: scales down automatically if the text is very long,
            // so everything always stays on one full page.
            pw.Expanded(
              child: pw.Padding(
                padding: pw.EdgeInsets.fromLTRB(pad, s(18), pad, s(6)),
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
                            timeCard('Requested', r.date, '-'),
                            if (r.completedAt != null) ...[
                              pw.SizedBox(width: s(14)),
                              timeCard('Completed', r.completedAt, ''),
                            ],
                          ],
                        ),
                        pw.SizedBox(height: s(16)),

                        // Subject
                        if (r.subject.trim().isNotEmpty) ...[
                          label('Subject'),
                          pw.SizedBox(height: s(4)),
                          pw.Text(
                            r.subject,
                            style: pw.TextStyle(
                                fontSize: s(19),
                                fontWeight: pw.FontWeight.bold,
                                color: ink),
                          ),
                          pw.SizedBox(height: s(6)),
                          pw.Align(
                            alignment: pw.Alignment.centerLeft,
                            child: pw.Container(
                                width: s(44), height: s(2.5), color: ink),
                          ),
                          pw.SizedBox(height: s(16)),
                        ],

                        // Info panel (3 columns)
                        if (infoFields.isNotEmpty) ...[
                          pw.Container(
                            padding: pw.EdgeInsets.all(s(16)),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: line, width: 1),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              mainAxisSize: pw.MainAxisSize.min,
                              children: [
                                for (var i = 0;
                                    i < infoFields.length;
                                    i += 3) ...[
                                  if (i > 0) pw.SizedBox(height: s(12)),
                                  pw.Row(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: [
                                      for (var j = i;
                                          j < i + 3 && j < infoFields.length;
                                          j++) ...[
                                        if (j > i) pw.SizedBox(width: s(14)),
                                        infoFields[j],
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          pw.SizedBox(height: s(16)),
                        ],

                        if (r.details.trim().isNotEmpty) ...[
                          block('Details', r.details, 64),
                          if (r.reason.trim().isNotEmpty)
                            pw.SizedBox(height: s(10)),
                        ],
                        if (r.reason.trim().isNotEmpty) ...[
                          block('Reason / Purpose', r.reason, 48),
                          pw.SizedBox(height: s(16)),
                        ] else if (r.details.trim().isNotEmpty) ...[
                          pw.SizedBox(height: s(16)),
                        ],

                        if (hasAcknowledgement) acknowledgement(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (hasRecipientSignature) signatureBlock(),
            footer(),
          ],
        ),
      ),
    ),
  );

  return doc.save();
}
