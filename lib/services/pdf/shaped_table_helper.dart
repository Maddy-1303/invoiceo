import 'package:pdf/widgets.dart' as pw;

import 'shaped_text.dart';

/// Drop-in replacement for `pw.TableHelper` (same `fromTextArray` arguments).
///
/// `pw.TableHelper.fromTextArray` draws string cells with the plain `pw.Text`,
/// which cannot shape Tamil and other complex scripts. This turns every
/// string cell into the shaping-aware [Text] with the same style and
/// alignment, then lets `pw.TableHelper` build the table as before, so the
/// look (header, borders, row colours, column widths) does not change.
mixin TableHelper {
  static pw.TextAlign _textAlign(pw.Alignment align) {
    if (align.x == 0) return pw.TextAlign.center;
    if (align.x < 0) return pw.TextAlign.left;
    return pw.TextAlign.right;
  }

  static pw.Table fromTextArray({
    pw.Context? context,
    required List<List<dynamic>> data,
    pw.EdgeInsetsGeometry cellPadding = const pw.EdgeInsets.all(5),
    double cellHeight = 0,
    pw.AlignmentGeometry cellAlignment = pw.Alignment.topLeft,
    Map<int, pw.AlignmentGeometry>? cellAlignments,
    pw.TextStyle? cellStyle,
    pw.TextStyle? oddCellStyle,
    pw.OnCellFormat? cellFormat,
    pw.OnCellDecoration? cellDecoration,
    int headerCount = 1,
    List<dynamic>? headers,
    pw.EdgeInsetsGeometry? headerPadding,
    double? headerHeight,
    pw.AlignmentGeometry headerAlignment = pw.Alignment.center,
    Map<int, pw.AlignmentGeometry>? headerAlignments,
    pw.TextStyle? headerStyle,
    pw.OnCellFormat? headerFormat,
    pw.TableBorder? border = const pw.TableBorder(
      left: pw.BorderSide(),
      right: pw.BorderSide(),
      top: pw.BorderSide(),
      bottom: pw.BorderSide(),
      horizontalInside: pw.BorderSide(),
      verticalInside: pw.BorderSide(),
    ),
    Map<int, pw.TableColumnWidth>? columnWidths,
    pw.TableColumnWidth defaultColumnWidth = const pw.IntrinsicColumnWidth(),
    pw.TableWidth tableWidth = pw.TableWidth.max,
    pw.BoxDecoration? headerDecoration,
    pw.BoxDecoration? headerCellDecoration,
    pw.BoxDecoration? rowDecoration,
    pw.BoxDecoration? oddRowDecoration,
    pw.TextDirection? headerDirection,
    pw.TextDirection? tableDirection,
    pw.OnCell? cellBuilder,
    pw.OnCellTextStyle? textStyleBuilder,
  }) {
    // Same defaults pw.TableHelper uses, so the cells look the same.
    var hStyle = headerStyle;
    var cStyle = cellStyle;
    if (context != null) {
      final theme = pw.Theme.of(context);
      hStyle ??= theme.tableHeader;
      cStyle ??= theme.tableCell;
    }
    final oddStyle = oddCellStyle ?? cStyle;
    final cAligns = cellAlignments ?? const <int, pw.Alignment>{};
    final hAligns = headerAlignments ?? cAligns;
    final direction =
        context == null ? pw.TextDirection.ltr : pw.Directionality.of(context);

    // Cells in the `headers` list: no textAlign, like pw.TableHelper.
    final shapedHeaders = headers == null
        ? null
        : [
            for (var i = 0; i < headers.length; i++)
              headers[i] is pw.Widget
                  ? headers[i]
                  : Text(
                      headerFormat == null
                          ? headers[i].toString()
                          : headerFormat(i, headers[i]),
                      style: hStyle,
                      textDirection: headerDirection,
                    ),
          ];

    // Data rows that count as header rows (when headerCount > the number of
    // `headers` rows) are drawn in the header style.
    final firstRowNum = headers == null ? 0 : 1;
    final shapedData = [
      for (var r = 0; r < data.length; r++)
        if (firstRowNum + r < headerCount)
          [
            for (var i = 0; i < data[r].length; i++)
              data[r][i] is pw.Widget
                  ? data[r][i]
                  : Text(
                      headerFormat == null
                          ? data[r][i].toString()
                          : headerFormat(i, data[r][i]),
                      style: hStyle,
                      textAlign: _textAlign(
                          (hAligns[i] ?? headerAlignment).resolve(direction)),
                      textDirection: headerDirection,
                    ),
          ]
        else
          data[r],
    ];

    // Body cells: pw.TableHelper asks cellBuilder first, so the shaped Text
    // is built there with the style and alignment it would have used.
    pw.Widget? shapedCell(int index, dynamic cell, int rowNum) {
      final custom = cellBuilder?.call(index, cell, rowNum);
      if (custom != null) return custom;
      final isOdd = (rowNum - headerCount) % 2 != 0;
      final align = cAligns[index] ?? cellAlignment;
      return Text(
        cellFormat == null ? cell.toString() : cellFormat(index, cell),
        style: textStyleBuilder?.call(index, cell, rowNum) ??
            (isOdd ? oddStyle : cStyle),
        textAlign: _textAlign(align.resolve(direction)),
        textDirection: tableDirection,
      );
    }

    return pw.TableHelper.fromTextArray(
      context: context,
      data: shapedData,
      cellPadding: cellPadding,
      cellHeight: cellHeight,
      cellAlignment: cellAlignment,
      cellAlignments: cellAlignments,
      cellStyle: cellStyle,
      oddCellStyle: oddCellStyle,
      cellFormat: cellFormat,
      cellDecoration: cellDecoration,
      headerCount: headerCount,
      headers: shapedHeaders,
      headerPadding: headerPadding,
      headerHeight: headerHeight,
      headerAlignment: headerAlignment,
      headerAlignments: headerAlignments,
      headerStyle: headerStyle,
      headerFormat: headerFormat,
      border: border,
      columnWidths: columnWidths,
      defaultColumnWidth: defaultColumnWidth,
      tableWidth: tableWidth,
      headerDecoration: headerDecoration,
      headerCellDecoration: headerCellDecoration,
      rowDecoration: rowDecoration,
      oddRowDecoration: oddRowDecoration,
      headerDirection: headerDirection,
      tableDirection: tableDirection,
      cellBuilder: shapedCell,
      textStyleBuilder: textStyleBuilder,
    );
  }
}
