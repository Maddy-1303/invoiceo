// Use instead of `package:pdf/widgets.dart`:
//
//   import 'shaped_pw.dart' as pw;
//
// Everything is re-exported unchanged except `Text`, which becomes the
// complex-script-aware [Text] from shaped_text.dart, and `TableHelper`,
// whose `fromTextArray` draws its string cells with that same [Text].
export 'package:pdf/widgets.dart' hide Text, TableHelper;
export 'shaped_table_helper.dart' show TableHelper;
export 'shaped_text.dart' show Text;
