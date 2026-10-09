// UsageStatsService: what is sent, how often, and that the switch stops it.
// The HTTP call is replaced, so nothing leaves the computer.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:invoiceo/services/usage_stats_service.dart';

void main() {
  late List<Map<String, String>> sent;
  var online = true;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sent = [];
    online = true;
    UsageStatsService.sendOverride = (body) async {
      if (!online) return false;
      sent.add(body);
      return true;
    };
  });
  tearDown(() => UsageStatsService.sendOverride = null);

  List<String> events() => sent.map((b) => b['event']!).toList();

  test('first open sends install and active; a second open the same day sends nothing', () async {
    await UsageStatsService.onAppOpen();
    expect(events(), ['install', 'active']);
    await UsageStatsService.onAppOpen();
    expect(events(), ['install', 'active']);
  });

  test('only the version, OS, event and a random ID are sent', () async {
    await UsageStatsService.onAppOpen();
    final body = sent.first;
    expect(body.keys.toSet(), {'id', 'event', 'version', 'os'});
    expect(body['version'], matches(RegExp(r'^\d+\.\d+\.\d+$')));
    expect(['windows', 'macos', 'linux', 'other'], contains(body['os']));
    // The same random ID every time, and not the reset-code installation ID.
    expect(sent.map((b) => b['id']).toSet().length, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('usage_stats_id'), body['id']);
  });

  test('first_invoice is sent once, for invoices only', () async {
    await UsageStatsService.onDocumentCreated('Quotation');
    await UsageStatsService.onDocumentCreated('Receipt');
    expect(events(), isEmpty);
    await UsageStatsService.onDocumentCreated('Invoice');
    await UsageStatsService.onDocumentCreated('Invoice');
    expect(events(), ['first_invoice']);
  });

  test('offline: first_invoice waits and goes out on the next start', () async {
    online = false;
    await UsageStatsService.onDocumentCreated('Invoice');
    expect(events(), isEmpty);
    online = true;
    await UsageStatsService.onAppOpen();
    expect(events(), ['install', 'active', 'first_invoice']);
    await UsageStatsService.onAppOpen();
    expect(events(), ['install', 'active', 'first_invoice']);
  });

  test('switched off: nothing is sent', () async {
    expect(await UsageStatsService.isEnabled(), isTrue);
    await UsageStatsService.setEnabled(false);
    await UsageStatsService.onAppOpen();
    await UsageStatsService.onDocumentCreated('Invoice');
    expect(events(), isEmpty);
  });
}
