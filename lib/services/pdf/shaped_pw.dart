// Use instead of `package:pdf/widgets.dart`:
//
//   import 'shaped_pw.dart' as pw;
//
// Everything is re-exported unchanged except `Text`, which becomes the
// complex-script-aware [Text] from shaped_text.dart.
export 'package:pdf/widgets.dart' hide Text;
export 'shaped_text.dart' show Text;
