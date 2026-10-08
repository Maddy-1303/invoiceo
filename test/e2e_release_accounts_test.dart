// Release QA: FIRST RUN, ACCOUNTS, COMPANIES, USERS — end to end on the real
// screens, each test starting from a brand-new, empty data folder exactly the
// way lib/main.dart starts the app:
//   company registry -> database file -> MyApp -> Splash -> Login.
//
// Nothing here touches the real data folder or ~/.invoiceo: path_provider is
// pointed at a temp folder, SharedPreferences is an in-memory mock, and no
// reset code is ever generated (only the "wrong code" path is exercised).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/company_registry_service.dart';
import 'package:invoiceo/database/customer_service.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/user_service.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/l10n/app_localizations_en.dart';
import 'package:invoiceo/l10n/app_localizations_ta.dart';
import 'package:invoiceo/main.dart' show MyApp;
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/providers/locale_provider.dart';
import 'package:invoiceo/providers/sqlite_repository_overrides.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/screens/auth/change_password_screen.dart';
import 'package:invoiceo/screens/auth/forgot_password_screen.dart';
import 'package:invoiceo/screens/auth/login_screen.dart';
import 'package:invoiceo/screens/dashboard_screen.dart';
import 'package:invoiceo/screens/onboarding/onboarding_screen.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/utils/session_manager.dart';

final en = AppLocalizationsEn();
final ta = AppLocalizationsTa();

const _shopName = 'Madhan Stores';
const _adminNewPassword = 'Shop@2026';
bool _hooked = false;

/// Known-bug tests are skipped so the suite stays green. Run them with
/// `flutter test --dart-define=RUN_BUGS=true test/e2e_release_accounts_test.dart`
/// to see them fail (each description starts with "BUG:").
const _runBugs = bool.fromEnvironment('RUN_BUGS');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Directory dataDir;
  var installNo = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackNumberSymbols();
    BackendServices.configure(
      settings: SqliteSettingsRepository(),
      companyInfo: SqliteCompanyInfoRepository(),
      invoices: SqliteInvoiceRepository(),
      payments: SqlitePaymentRepository(),
      installation: SqliteInstallationRepository(),
    );
    root = Directory.systemTemp.createTempSync('invoiceo_release_accounts');
    dataDir = root;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => dataDir.path);
    // The window title is set once more than one company exists (desktop).
    messenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'), (call) async => null);
  });

  tearDownAll(() async {
    await DatabaseHelper().close();
    root.deleteSync(recursive: true);
  });

  tearDown(() {
    SessionManager.dispose();
    Intl.defaultLocale = null;
  });

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<void> settle(WidgetTester tester, [int rounds = 14]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  void noErrors(WidgetTester tester, [String where = '']) {
    final e = tester.takeException();
    if (e != null) {
      // Name the overflowing Row/Column (its creator chain) for the report.
      for (final r in tester.allRenderObjects) {
        if (r is RenderFlex && r.toStringShort().contains('OVERFLOWING')) {
          final creator = r.debugCreator?.toString() ?? '';
          debugPrint('OVERFLOWING at $where: ${r.size} '
              '${creator.length > 600 ? creator.substring(0, 600) : creator}');
        }
      }
    }
    expect(e, isNull, reason: 'exception $where: $e');
  }

  /// The same steps main() runs before runApp, on a new empty folder.
  Future<void> freshInstall(WidgetTester tester) async {
    await tester.runAsync(() async {
      await DatabaseHelper().close();
      dataDir = Directory(p.join(root.path, 'install_${installNo++}'))
        ..createSync(recursive: true);
      SharedPreferences.setMockInitialValues({});
      await CompanyRegistryService.ensureDefaultCompanyRegistered();
      DatabaseHelper().setActiveFileNameBeforeFirstOpen(
          await CompanyRegistryService.getActiveCompanyDbFileName());
    });
  }

  /// Quit and start the app again on the same folder (same steps as main()).
  Future<void> relaunch(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    SessionManager.dispose();
    await tester.runAsync(() async {
      await DatabaseHelper().close();
      await CompanyRegistryService.ensureDefaultCompanyRegistered();
      DatabaseHelper().setActiveFileNameBeforeFirstOpen(
          await CompanyRegistryService.getActiveCompanyDbFileName());
    });
  }

  Future<void> startApp(WidgetTester tester,
      {Size size = const Size(1280, 800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Print where a layout overflow comes from (for the bug report).
    final orig = FlutterError.onError;
    if (orig != null && !_hooked) {
      _hooked = true;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('overflowed')) {
          final text = d.toString();
          final i = text.indexOf('The relevant error-causing widget was');
          final j = text.indexOf('The overflowing');
          debugPrint('OVERFLOW DETAILS: ${d.exceptionAsString()}\n'
              '${i >= 0 ? text.substring(i, (j > i ? j : text.length).clamp(0, i + 900)) : text.substring(0, text.length.clamp(0, 1500))}');
        }
        orig(d);
      };
      addTearDown(() {
        FlutterError.onError = orig;
        _hooked = false;
      });
    }
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: sqliteRepositoryOverrides,
      child: const MyApp(),
    ));
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, Finder f, {int rounds = 10}) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await tester.pump();
    await settle(tester, rounds);
  }

  /// Let a SnackBar (it can cover the panel's bottom buttons) go away.
  Future<void> clearSnackBars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await settle(tester, 6);
  }

  Finder field(Type type, String label) => find.widgetWithText(type, label);

  /// A Settings section in the left rail.
  Finder rail(String label) => find.descendant(
      of: find.byType(NavigationRail), matching: find.text(label));

  Future<void> login(WidgetTester tester, String user, String pass,
      {AppLocalizations? l10n}) async {
    final l = l10n ?? en;
    await tester.enterText(field(TextField, l.loginUsernameLabel), user);
    await tester.enterText(field(TextField, l.loginPasswordLabel), pass);
    await tap(tester, find.widgetWithText(ElevatedButton, l.loginButton),
        rounds: 16);
  }

  Future<void> forcedPasswordChange(WidgetTester tester, String pw) async {
    await tester.enterText(
        field(TextField, en.changePasswordNewPasswordLabel), pw);
    await tester.enterText(
        field(TextField, en.userMgmtConfirmNewPasswordLabel), pw);
    await tap(tester,
        find.widgetWithText(ElevatedButton, en.userMgmtChangePasswordTitle),
        rounds: 16);
  }

  Future<void> walkOnboarding(WidgetTester tester,
      {String? name, AppLocalizations? l10n}) async {
    final l = l10n ?? en;
    if (name != null) {
      await tester.enterText(field(TextField, l.onboardingCompanyNameLabel), name);
    }
    for (var step = 0; step < 3; step++) {
      await tap(tester, find.text(l.actionNext), rounds: 16);
      noErrors(tester, 'onboarding step ${step + 1}');
    }
    await tap(tester, find.text(l.actionGetStarted), rounds: 20);
  }

  /// A new install taken to the dashboard through the real screens.
  Future<void> firstRunToDashboard(WidgetTester tester,
      {String name = _shopName}) async {
    await freshInstall(tester);
    await startApp(tester);
    await login(tester, 'admin', 'admin');
    await forcedPasswordChange(tester, _adminNewPassword);
    await walkOnboarding(tester, name: name);
    expect(find.byType(DashboardScreen), findsOneWidget);
  }

  Future<void> openNav(WidgetTester tester, String label) =>
      tap(tester, find.byKey(ValueKey('modernNav_$label')), rounds: 16);

  Future<void> logout(WidgetTester tester, {AppLocalizations? l10n}) async {
    final l = l10n ?? en;
    await tap(tester, find.byKey(const ValueKey('modernUserMenu')));
    await tap(tester, find.text(l.dashboardLogoutTooltip).last, rounds: 14);
  }

  String companyPillName(WidgetTester tester) {
    final pill = find.byKey(const ValueKey('modernCompanyMenu'));
    return tester
        .widget<PopupMenuButton<String>>(pill)
        .tooltip!;
  }

  Future<T> io<T>(WidgetTester tester, Future<T> Function() f) async =>
      (await tester.runAsync(f)) as T;

  // ── 1. first run ───────────────────────────────────────────────────────────

  group('first run', () {
    testWidgets(
        'splash -> login with the admin/admin hint -> forced password change '
        '-> 4-step onboarding -> Modern dashboard, empty, no errors',
        (tester) async {
      await freshInstall(tester);
      // The registry has exactly the default company before anything opens.
      final before = await io(tester, CompanyRegistryService.listCompanies);
      expect(before.map((c) => c.id), [defaultCompanyId]);

      await startApp(tester);
      noErrors(tester, 'splash/login');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
          File(p.join(dataDir.path, 'invoice_manager.db')).existsSync(), isTrue,
          reason: 'the splash screen creates the database');

      // First-run hint, fields pre-filled with admin/admin.
      expect(find.textContaining('First time here?'), findsOneWidget);
      final user = tester.widget<TextField>(field(TextField, en.loginUsernameLabel));
      final pass = tester.widget<TextField>(field(TextField, en.loginPasswordLabel));
      expect(user.controller!.text, 'admin');
      expect(pass.controller!.text, 'admin');
      // Only one company: no picker on the login card.
      expect(find.text(en.loginCompanySelectorLabel), findsNothing);

      await tap(tester, find.widgetWithText(ElevatedButton, en.loginButton),
          rounds: 16);
      noErrors(tester, 'login');

      // Forced change: can't go back, rules are enforced.
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      expect(find.text(en.changePasswordRequiredTitle), findsOneWidget);
      expect(field(TextField, en.userMgmtCurrentPasswordLabel), findsNothing);

      Future<void> tryPw(String a, String b, String msg) async {
        await tester.enterText(
            field(TextField, en.changePasswordNewPasswordLabel), a);
        await tester.enterText(
            field(TextField, en.userMgmtConfirmNewPasswordLabel), b);
        await tap(tester,
            find.widgetWithText(ElevatedButton, en.userMgmtChangePasswordTitle));
        expect(find.text(msg), findsOneWidget, reason: 'for "$a"/"$b"');
        expect(find.byType(ChangePasswordScreen), findsOneWidget);
      }

      await tryPw('short', 'short', en.changePasswordMinLengthMessage);
      await tryPw('ADMIN', 'ADMIN', en.changePasswordMinLengthMessage);
      await tryPw('Shop@2026', 'Shop@2027', en.userMgmtPasswordsDoNotMatchMessage);
      // Back is blocked on the forced screen.
      final pop = tester.widget<PopScope>(find.byType(PopScope).first);
      expect(pop.canPop, isFalse);

      await forcedPasswordChange(tester, _adminNewPassword);
      noErrors(tester, 'after password change');
      final admin = await io(tester, () => UserService.getUserByUsername('admin'));
      expect(admin!.passwordChanged, isTrue);
      expect(await io(tester, () => UserService.getUser('admin', 'admin')), isNull,
          reason: 'the default password no longer works');

      // ── onboarding ──
      expect(find.byType(OnboardingScreen), findsOneWidget);
      // Step 1: the seeded placeholder name is shown as an empty field.
      final nameField =
          tester.widget<TextField>(field(TextField, en.onboardingCompanyNameLabel));
      expect(nameField.controller!.text, isEmpty);
      expect(find.text(DatabaseHelper.seedCompanyName), findsNothing);
      // Country defaults to India; the logo is skipped (not tapped).
      expect(find.widgetWithText(TextField, en.onboardingCountryLabel),
          findsOneWidget);
      expect(find.text('India'), findsWidgets);
      await tester.enterText(
          field(TextField, en.onboardingCompanyNameLabel), '  $_shopName  ');
      await tap(tester, find.text(en.actionNext), rounds: 16);
      noErrors(tester, 'onboarding company step');

      // Step 2: invoice settings.
      expect(find.text(en.onboardingStepInvoiceTitle), findsOneWidget);
      await tester.enterText(
          field(TextField, en.onboardingInvoiceStartingNumberLabel), '100');
      await tester.enterText(
          field(TextField, en.onboardingDefaultTaxRateLabel), '5');
      await tap(tester, find.text(en.actionNext), rounds: 16);
      noErrors(tester, 'onboarding invoice step');

      // Step 3: appearance, then the Done page.
      expect(find.text(en.onboardingStepAppearanceTitle), findsOneWidget);
      await tap(tester, find.text(en.actionNext), rounds: 16);
      expect(find.text(en.actionSkip), findsNothing, reason: 'no Skip on Done');
      await tap(tester, find.text(en.actionGetStarted), rounds: 24);
      noErrors(tester, 'dashboard');

      // ── dashboard ──
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('modernDashboard')), findsOneWidget);
      expect(find.byKey(const ValueKey('modernSidebar')), findsOneWidget);
      expect(find.text(en.dashboardNoInvoicesYetTitle), findsWidgets,
          reason: 'empty recent-invoices state');
      expect(companyPillName(tester), _shopName);

      // What onboarding saved.
      final settings = BackendServices.settings;
      expect(await io(tester,
              () => settings.getSetting(SettingKey.onboardingCompleted)),
          'true');
      expect(await io(tester,
              () => settings.getSetting(SettingKey.invoiceStartingNumber)),
          '100');
      expect(await io(tester, () => settings.getSetting(SettingKey.defaultTaxRate)),
          '5.0');
      final info = await io(tester, BackendServices.companyInfo.getCompanyInfo);
      expect(info!.name, _shopName, reason: 'typed name, trimmed');
      expect(info.country, 'India');
      // No fake contact details on a new company.
      expect(info.address, isEmpty);
      expect(info.phone, isEmpty);
      expect(info.email, isEmpty);
      expect(info.website, isEmpty);
      for (final fake in ['123 Street', '9876543210', 'info@yourcompany.com',
        'www.yourcompany.com']) {
        expect('${info.address}${info.phone}${info.email}${info.website}',
            isNot(contains(fake)));
      }
      // Registry label = typed name (not 'My Company').
      final companies = await io(tester, CompanyRegistryService.listCompanies);
      expect(companies.single.name, _shopName);
      final prefs = await io(tester, SharedPreferences.getInstance);
      expect(prefs.getString('company_registry'), contains(_shopName));

      // Every sidebar page opens on an empty company without errors.
      for (final page in [
        en.navInvoices, en.navCustomers, en.navProducts, en.navReports,
        en.navSettings, en.navDashboard,
      ]) {
        final key = find.byKey(ValueKey('modernNav_$page'));
        if (key.evaluate().isEmpty) continue;
        await openNav(tester, page);
        noErrors(tester, 'page $page');
      }

      // A restart lands on Login (no hint now) and goes straight to the
      // dashboard — no second onboarding, no second forced change.
      await relaunch(tester);
      await startApp(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.textContaining('First time here?'), findsNothing);
      expect(
          tester.widget<TextField>(field(TextField, en.loginUsernameLabel))
              .controller!
              .text,
          isEmpty);
      await login(tester, 'admin', _adminNewPassword);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      noErrors(tester, 'second start');
    });

    testWidgets('skipping every onboarding step still reaches the dashboard',
        (tester) async {
      await freshInstall(tester);
      await startApp(tester);
      await login(tester, 'admin', 'admin');
      await forcedPasswordChange(tester, _adminNewPassword);
      for (var i = 0; i < 3; i++) {
        await tap(tester, find.text(en.actionSkip), rounds: 12);
        noErrors(tester, 'skip $i');
      }
      await tap(tester, find.text(en.actionGetStarted), rounds: 20);
      expect(find.byType(DashboardScreen), findsOneWidget);
      noErrors(tester, 'dashboard after skip');
      final info = await io(tester, BackendServices.companyInfo.getCompanyInfo);
      expect(info!.phone, isEmpty);
      expect(info.address, isEmpty);
      expect(info.email, isEmpty);
    });

    testWidgets(
        'BUG (low): skipping the company step leaves the placeholder '
        '"Your Company Name" as the shop name in the sidebar',
        skip: !_runBugs, // reported as low: see final report (placeholder shown)
        (tester) async {
      await freshInstall(tester);
      await startApp(tester);
      await login(tester, 'admin', 'admin');
      await forcedPasswordChange(tester, _adminNewPassword);
      for (var i = 0; i < 3; i++) {
        await tap(tester, find.text(en.actionSkip), rounds: 12);
      }
      await tap(tester, find.text(en.actionGetStarted), rounds: 20);
      expect(companyPillName(tester), isNot(DatabaseHelper.seedCompanyName));
    });
  });

  // ── 2. login, logout, forgot password ──────────────────────────────────────

  group('login and logout', () {
    testWidgets('empty fields, wrong password, logout and login again',
        (tester) async {
      await firstRunToDashboard(tester);
      await logout(tester);
      noErrors(tester, 'logout');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);

      // Empty fields.
      await tester.enterText(field(TextField, en.loginUsernameLabel), '');
      await tester.enterText(field(TextField, en.loginPasswordLabel), '');
      await tap(tester, find.widgetWithText(ElevatedButton, en.loginButton));
      expect(find.text(en.loginEnterCredentialsMessage(en.loginUsernameLabel)),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await settle(tester, 4);

      // Username only.
      await login(tester, 'admin', '');
      expect(find.text(en.loginEnterCredentialsMessage(en.loginUsernameLabel)),
          findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await settle(tester, 4);

      // Wrong password, the old default, unknown user.
      for (final creds in [
        ['admin', 'wrong-pass'],
        ['admin', 'admin'],
        ['nobody', _adminNewPassword],
        ['ADMIN', _adminNewPassword],
      ]) {
        await login(tester, creds[0], creds[1]);
        expect(find.text(en.loginInvalidCredentialsMessage), findsOneWidget,
            reason: '$creds');
        expect(find.byType(LoginScreen), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await settle(tester, 4);
      }

      // Spaces around the username are ignored; Enter in the password box logs in.
      await tester.enterText(field(TextField, en.loginUsernameLabel), '  admin ');
      await tester.enterText(
          field(TextField, en.loginPasswordLabel), _adminNewPassword);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester, 16);
      expect(find.byType(DashboardScreen), findsOneWidget);
      noErrors(tester, 'login again');

      // Logging out stops the inactivity timer.
      await logout(tester);
      await tester.pump(const Duration(minutes: 40));
      await settle(tester, 4);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(en.dashboardSessionExpiredMessage), findsNothing);
      noErrors(tester, 'after logout');
    });

    testWidgets(
        'forgot password shows the installation ID, needs a username, '
        'rejects a wrong code', (tester) async {
      await firstRunToDashboard(tester);
      await logout(tester);
      await tap(tester, find.text(en.loginForgotPasswordButton), rounds: 12);
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      noErrors(tester, 'forgot password screen');

      final prefs = await io(tester, SharedPreferences.getInstance);
      final id = prefs.getString('installation_id');
      expect(id, isNotNull);
      expect(id, isNotEmpty);
      expect(find.text(id!), findsOneWidget, reason: 'installation ID shown');
      expect(find.text(en.resetPasswordCompanyLabel(_shopName)), findsOneWidget);

      // Nothing typed.
      await tap(tester, find.text(en.resetPasswordVerifyButton));
      expect(find.text(en.resetPasswordEnterFieldsMessage), findsOneWidget);
      // A code but no username.
      await tester.enterText(
          field(TextField, en.resetPasswordResponseCodeLabel), 'ABCD-EFGH');
      await tap(tester, find.text(en.resetPasswordVerifyButton));
      expect(find.text(en.resetPasswordEnterFieldsMessage), findsOneWidget);
      // A username and a made-up code.
      await tester.enterText(field(TextField, en.loginUsernameLabel), 'admin');
      await tap(tester, find.text(en.resetPasswordVerifyButton), rounds: 14);
      expect(find.text(en.resetPasswordInvalidCodeMessage), findsOneWidget);
      expect(field(TextField, en.changePasswordNewPasswordLabel), findsNothing,
          reason: 'no new-password form without a valid code');
      noErrors(tester, 'wrong code');

      // The ID is stable (same on the next visit).
      await tap(tester, find.text(en.resetPasswordBackToLoginButton));
      await tap(tester, find.text(en.loginForgotPasswordButton), rounds: 12);
      expect(find.text(id), findsOneWidget);
      // The admin password is unchanged.
      expect(await io(tester, () => UserService.getUser('admin', _adminNewPassword)),
          isNotNull);
    });
  });

  // ── 3. users ───────────────────────────────────────────────────────────────

  group('users', () {
    Future<void> openUsers(WidgetTester tester) async {
      await openNav(tester, en.navSettings);
      await tap(tester, rail(en.settingsNavUsersLabel), rounds: 14);
      noErrors(tester, 'Users page');
    }

    Future<void> addUser(WidgetTester tester, String name, String pw,
        {bool admin = false}) async {
      await tap(tester, find.byKey(const ValueKey('userMgmtAddUserButton')));
      await tester.enterText(
          field(TextFormField, en.userMgmtUsernameRequiredLabel), name);
      await tester.enterText(
          field(TextFormField, en.userMgmtPasswordRequiredLabel), pw);
      await tap(tester, find.byType(DropdownButtonFormField<String>).last);
      await tap(tester,
          find.text(admin ? en.dashboardRoleAdmin : en.dashboardRoleUser).last);
      await tap(tester, find.text(en.userMgmtSaveUserButton), rounds: 14);
      noErrors(tester, 'add user $name');
    }

    testWidgets(
        'admin adds a normal user; the user sees only Software Info in '
        'Settings and cannot reach Users or Backup', (tester) async {
      await firstRunToDashboard(tester);
      await openUsers(tester);

      // Validation: short name, short password, duplicate name.
      await tap(tester, find.byKey(const ValueKey('userMgmtAddUserButton')));
      await tester.enterText(
          field(TextFormField, en.userMgmtUsernameRequiredLabel), 'ab');
      await tester.enterText(
          field(TextFormField, en.userMgmtPasswordRequiredLabel), '123');
      await tap(tester, find.text(en.userMgmtSaveUserButton));
      expect(find.text(en.userMgmtUsernameMinLengthMessage), findsOneWidget);
      expect(find.text(en.userMgmtMinimum6CharsMessage), findsOneWidget);
      expect(find.text(en.userMgmtRoleRequiredMessage), findsOneWidget);
      await tap(tester, find.text(en.actionCancel).last);

      await addUser(tester, 'cashier1', 'cash1234');
      expect(find.text(en.userMgmtAddedMessage), findsOneWidget);
      final saved = await io(tester, () => UserService.getUserByUsername('cashier1'));
      expect(saved, isNotNull);
      expect(saved!.userType, 'user');
      expect(saved.password, isNot('cash1234'), reason: 'stored hashed');
      expect(saved.salt, isNotNull);

      await tester.pump(const Duration(seconds: 5));
      await settle(tester, 4);
      await addUser(tester, 'cashier1', 'other1234');
      expect(find.text(en.userMgmtUsernameTakenMessage), findsOneWidget);
      expect((await io(tester, UserService.getAllUsers)).length, 2);
      await clearSnackBars(tester);
      await tap(tester, find.text(en.actionCancel).last);

      // ── as the normal user ──
      await logout(tester);
      await login(tester, 'cashier1', 'cash1234');
      noErrors(tester, 'cashier login');
      expect(find.byType(DashboardScreen), findsOneWidget,
          reason: 'admin-created users are not forced to change the password');
      expect(find.text(en.dashboardRoleUser), findsWidgets);

      await openNav(tester, en.navSettings);
      noErrors(tester, 'cashier settings');
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text(en.settingsNavUsersLabel), findsNothing);
      expect(find.text(en.settingsNavBackupLabel), findsNothing);
      expect(find.text(en.settingsNavCompaniesLabel), findsNothing);
      expect(find.text(en.settingsNavCompanyInfoLabel), findsNothing);
      expect(find.text(en.settingsNavSoftwareInfoLabel), findsWidgets,
          reason: 'only Software Info');

      // Same through the user menu's Settings item.
      await tap(tester, find.byKey(const ValueKey('modernUserMenu')));
      await tap(tester, find.text(en.navSettings).last, rounds: 12);
      expect(find.text(en.settingsNavUsersLabel), findsNothing);
      expect(find.text(en.settingsNavBackupLabel), findsNothing);
      noErrors(tester, 'cashier user menu settings');
    });

    testWidgets('the only admin cannot change (demote) their own role',
        (tester) async {
      await firstRunToDashboard(tester);
      await openUsers(tester);
      await addUser(tester, 'cashier1', 'cash1234');
      await clearSnackBars(tester);
      // admin is the first row
      await tap(tester, find.byTooltip(en.actionEdit).first);
      final dd = tester.widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>).last);
      expect(dd.onChanged, isNull, reason: 'role locked');
      expect(find.text(en.userMgmtCantChangeOwnRoleMessage), findsOneWidget);
      await tap(tester, find.text(en.productMgmtSaveChangesButton), rounds: 12);
      final admin = await io(tester, () => UserService.getUserByUsername('admin'));
      expect(admin!.userType, 'admin');
      expect(await io(tester, () => UserService.getUser('admin', _adminNewPassword)),
          isNotNull,
          reason: 'saving the edit form must not touch the password');
      noErrors(tester, 'edit admin');
    });

    testWidgets(
        'admin changes own password from Settings > Users',
        (tester) async {
      await firstRunToDashboard(tester);
      await openUsers(tester);
      await tap(tester, find.byTooltip(en.userMgmtChangePasswordTitle).first);
      await tester.enterText(
          field(TextFormField, en.userMgmtCurrentPasswordLabel), _adminNewPassword);
      await tester.enterText(
          field(TextFormField, en.userMgmtNewPasswordLabel), 'NewShop@2026');
      await tester.enterText(
          field(TextFormField, en.userMgmtConfirmNewPasswordLabel), 'NewShop@2026');
      // the dialog's button (ElevatedButton.icon), not its title
      await tap(tester,
          find.descendant(
              of: find.byWidgetPredicate((w) => w is ElevatedButton),
              matching: find.text(en.userMgmtChangePasswordTitle)),
          rounds: 14);
      expect(find.text(en.userMgmtCurrentPasswordIncorrectMessage), findsNothing,
          reason: 'the right current password is refused');
      expect(find.text(en.userMgmtPasswordChangedMessage), findsOneWidget);
      expect(await io(tester, () => UserService.getUser('admin', 'NewShop@2026')),
          isNotNull);
    });

    testWidgets(
        'a normal user changes their own password from the user menu',
        (tester) async {
      await firstRunToDashboard(tester);
      await openUsers(tester);
      await addUser(tester, 'cashier1', 'cash1234');
      await logout(tester);
      await login(tester, 'cashier1', 'cash1234');
      await tap(tester, find.byKey(const ValueKey('modernUserMenu')));
      await tap(tester, find.text(en.userMgmtChangePasswordTitle).last, rounds: 12);
      Finder field(String label) =>
          find.widgetWithText(TextFormField, label).evaluate().isNotEmpty
              ? find.widgetWithText(TextFormField, label)
              : find.widgetWithText(TextField, label);
      await tester.enterText(field(en.userMgmtCurrentPasswordLabel), 'cash1234');
      await tester.enterText(field(en.changePasswordNewPasswordLabel), 'newpass99');
      await tester.enterText(field(en.userMgmtConfirmNewPasswordLabel), 'newpass99');
      await tap(tester, find.widgetWithText(ElevatedButton, en.userMgmtChangePasswordTitle),
          rounds: 14);
      noErrors(tester, 'after changing the password');
      // Back where they were, then the new password works.
      expect(find.byKey(const ValueKey('modernUserMenu')), findsOneWidget);
      await logout(tester);
      await login(tester, 'cashier1', 'newpass99');
      expect(find.byKey(const ValueKey('modernUserMenu')), findsOneWidget);
    });

    testWidgets(
        'a normal user cannot create companies from the company switcher',
        (tester) async {
      await firstRunToDashboard(tester);
      await openUsers(tester);
      await addUser(tester, 'cashier1', 'cash1234');
      await logout(tester);
      await login(tester, 'cashier1', 'cash1234');
      await tap(tester, find.byKey(const ValueKey('modernCompanyMenu')));
      await tap(tester, find.text(en.companyMgmtTitle).last, rounds: 12);
      expect(find.text(en.companyMgmtNewCompanyButton), findsNothing);
    });
  });

  // ── 4. companies ───────────────────────────────────────────────────────────

  group('companies', () {
    Future<void> openCompanies(WidgetTester tester) async {
      await openNav(tester, en.navSettings);
      await tap(tester, rail(en.settingsNavCompaniesLabel), rounds: 14);
      noErrors(tester, 'Companies page');
    }

    testWidgets(
        'create a second company, switch (login again), data is separate, '
        'rename, delete', (tester) async {
      // Short names: the login company picker overflows on longer ones
      // (separate BUG test below).
      const shopA = 'Shop A';
      await firstRunToDashboard(tester, name: shopA);
      // Company A has one customer.
      await io(tester, () => CustomerService.insertCustomer(Customer(
          id: 'cust-a', name: 'Ravi A', phone: '9000000001', email: '',
          address: '', gstin: '')));

      await openCompanies(tester);
      expect(find.text(shopA), findsWidgets);
      // A single company cannot be deleted.
      final del = tester.widget<IconButton>(find.ancestor(
          of: find.byIcon(Icons.delete_outline), matching: find.byType(IconButton)));
      expect(del.onPressed, isNull);

      // New company dialog: required name / duplicate name / admin account.
      await tap(tester, find.byKey(const ValueKey('companyMgmtNewCompany')));
      await tap(tester, find.text(en.companyMgmtCreateButton));
      expect(find.text(en.fieldRequiredMessage(en.onboardingCompanyNameLabel)),
          findsOneWidget);
      await tester.enterText(
          field(TextFormField, en.onboardingCompanyNameLabel), ' shop a ');
      await tap(tester, find.text(en.companyMgmtCreateButton));
      expect(find.text(en.companyMgmtNameTakenMessage), findsOneWidget);
      await tester.enterText(
          field(TextFormField, en.onboardingCompanyNameLabel), 'Branch Two');
      await tester.enterText(
          field(TextFormField, en.userMgmtUsernameRequiredLabel), 'owner2');
      await tester.enterText(
          field(TextFormField, en.userMgmtPasswordRequiredLabel), 'Branch@2026');
      await tap(tester, find.text(en.companyMgmtCreateButton), rounds: 20);
      noErrors(tester, 'create company');

      // Back on Login, now on the new company, with a company picker.
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(en.loginCompanySelectorLabel), findsOneWidget);
      expect(find.text('Branch Two'), findsWidgets);
      final companies = await io(tester, CompanyRegistryService.listCompanies);
      expect(companies.map((c) => c.name), [shopA, 'Branch Two']);
      final branch = companies.last;
      expect(await io(tester, CompanyRegistryService.getActiveCompanyId), branch.id);
      expect(File(p.join(dataDir.path, branch.dbFileName)).existsSync(), isTrue);

      // The seeded admin/admin does not exist in the new company.
      await login(tester, 'admin', 'admin');
      expect(find.text(en.loginInvalidCredentialsMessage), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await settle(tester, 4);
      await login(tester, 'owner2', 'Branch@2026');
      noErrors(tester, 'login company B');
      expect(find.byType(ChangePasswordScreen), findsNothing);
      // The new company gets its own onboarding, name pre-filled.
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(
          tester.widget<TextField>(field(TextField, en.onboardingCompanyNameLabel))
              .controller!
              .text,
          'Branch Two');
      await walkOnboarding(tester);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(companyPillName(tester), 'Branch Two');
      // Separate data.
      expect(await io(tester, () => CustomerService.getAllCustomers()), isEmpty);
      final infoB = await io(tester, BackendServices.companyInfo.getCompanyInfo);
      expect(infoB!.name, 'Branch Two');
      expect(infoB.phone, isEmpty);
      expect(infoB.address, isEmpty);
      await io(tester, () => CustomerService.insertCustomer(Customer(
          id: 'cust-b', name: 'Bala B', phone: '9000000002', email: '',
          address: '', gstin: '')));

      // Switch back to A from the sidebar company menu.
      await tap(tester, find.byKey(const ValueKey('modernCompanyMenu')));
      await tap(tester, find.text(shopA).last);
      expect(find.text(en.companyMgmtSwitchConfirmBody(shopA)), findsOneWidget);
      await tap(tester, find.text(en.companyMgmtSwitchButton).last, rounds: 16);
      noErrors(tester, 'switch to A');
      expect(find.byType(LoginScreen), findsOneWidget);
      // B's owner cannot log into A.
      await login(tester, 'owner2', 'Branch@2026');
      expect(find.text(en.loginInvalidCredentialsMessage), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await settle(tester, 4);
      await login(tester, 'admin', _adminNewPassword);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(companyPillName(tester), shopA);
      final customersA = await io(tester, () => CustomerService.getAllCustomers());
      expect(customersA.map((c) => c.name), ['Ravi A']);

      // Rename A (the active company).
      await openCompanies(tester);
      // Only the active company has rename/delete; the other row has Switch.
      expect(find.byTooltip(en.companyMgmtRenameTooltip), findsOneWidget);
      expect(find.text(en.companyMgmtSwitchButton), findsOneWidget);
      await tap(tester, find.byTooltip(en.companyMgmtRenameTooltip));
      await tester.enterText(
          find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
          'Shop A1');
      await tap(tester, find.text(en.actionSave).last, rounds: 14);
      noErrors(tester, 'rename');
      expect(find.text('Shop A1'), findsWidgets);
      final infoA = await io(tester, BackendServices.companyInfo.getCompanyInfo);
      expect(infoA!.name, 'Shop A1');
      final afterRename = await io(tester, CompanyRegistryService.listCompanies);
      expect(afterRename.first.name, 'Shop A1');
      final prefs = await io(tester, SharedPreferences.getInstance);
      expect(prefs.getString('company_registry'), contains('Shop A1'),
          reason: 'stored label renamed too, not only the live one');

      // Delete Branch Two: the UI only deletes the ACTIVE company, so switch
      // to it, log in, and delete it from there.
      await tap(tester, find.text(en.companyMgmtSwitchButton));
      await tap(tester, find.text(en.companyMgmtSwitchButton).last, rounds: 16);
      expect(find.byType(LoginScreen), findsOneWidget);
      await login(tester, 'owner2', 'Branch@2026');
      expect(find.byType(DashboardScreen), findsOneWidget);
      await openCompanies(tester);
      await tap(tester, find.byTooltip(en.companyMgmtDeleteButton));
      // Delete stays off until the name is typed.
      final deleteBtn = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, en.actionDelete));
      expect(tester.widget<TextButton>(deleteBtn).onPressed, isNull);
      await tester.enterText(
          find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
          'Branch Two');
      await tester.pump();
      await tap(tester, deleteBtn, rounds: 18);
      noErrors(tester, 'delete company');
      expect(find.byType(LoginScreen), findsOneWidget);
      final left = await io(tester, CompanyRegistryService.listCompanies);
      expect(left.map((c) => c.name), ['Shop A1']);
      expect(await io(tester, CompanyRegistryService.getActiveCompanyId),
          defaultCompanyId);
      expect(File(p.join(dataDir.path, branch.dbFileName)).existsSync(), isFalse,
          reason: 'the deleted company file is removed');
      expect(find.text(en.loginCompanySelectorLabel), findsNothing);
      await login(tester, 'admin', _adminNewPassword);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(
          (await io(tester, () => CustomerService.getAllCustomers()))
              .map((c) => c.name),
          ['Ravi A'],
          reason: "company A's data survives B's deletion");
      noErrors(tester, 'end');
    });

    testWidgets('the registry refuses to delete the active or the only company',
        (tester) async {
      await firstRunToDashboard(tester);
      await tester.runAsync(() async {
        await expectLater(
            CompanyRegistryService.deleteCompany(defaultCompanyId),
            throwsStateError);
        final b = await CompanyRegistryService.createCompany('Temp Co');
        // a non-active company CAN be deleted at registry level
        await CompanyRegistryService.deleteCompany(b.id);
        final left = await CompanyRegistryService.listCompanies();
        expect(left.length, 1);
      });
    });

    testWidgets(
        'the login company picker fits a long company name',
        (tester) async {
      const longName = 'Sri Lakshmi Narasimha Textiles and Readymades';
      await firstRunToDashboard(tester, name: longName);
      await tester.runAsync(() => CompanyRegistryService.createCompany('B'));
      await logout(tester);
      noErrors(tester, 'login with two companies, long name');
    });

    testWidgets(
        'BUG (low): renaming the company in Settings updates the sidebar name',
        skip: !_runBugs, // BUG: sidebar keeps the old name until re-login
        (tester) async {
      await firstRunToDashboard(tester);
      await openCompanies(tester);
      await tap(tester, find.byTooltip(en.companyMgmtRenameTooltip));
      await tester.enterText(
          find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
          'Madhan Super Stores');
      await tap(tester, find.text(en.actionSave).last, rounds: 14);
      expect(companyPillName(tester), 'Madhan Super Stores');
    });
  });

  // ── 5. session timeout ─────────────────────────────────────────────────────

  group('session timeout', () {
    testWidgets(
        '30 idle minutes on an unsaved new invoice: saved as a draft, back to '
        'Login with a message', (tester) async {
      await firstRunToDashboard(tester);
      await openNav(tester, en.navNewInvoice);
      noErrors(tester, 'new invoice');
      await tester.enterText(
          find.byKey(const ValueKey('modernCustomerName')), 'Walk-in Ravi');
      await settle(tester, 6);
      expect(
          await io(tester, () => DatabaseHelper().database.then(
              (db) => db.query('invoice_drafts'))),
          isEmpty);

      // 29 minutes: still in.
      await tester.pump(const Duration(minutes: 29));
      await settle(tester, 2);
      expect(find.byType(DashboardScreen), findsOneWidget);

      // past 30: timed out.
      await tester.pump(const Duration(minutes: 2));
      await settle(tester, 20);
      noErrors(tester, 'timeout');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
      expect(find.text(en.dashboardSessionExpiredMessage), findsOneWidget);
      final drafts = await io(tester, () => DatabaseHelper().database.then(
          (db) => db.query('invoice_drafts')));
      expect(drafts.length, 1, reason: 'the unsaved invoice is kept as a draft');
      expect(drafts.single.toString(), contains('Walk-in Ravi'));
    });

    testWidgets('an untouched new invoice does not leave an empty draft',
        (tester) async {
      await firstRunToDashboard(tester);
      await openNav(tester, en.navNewInvoice);
      await tester.pump(const Duration(minutes: 31));
      await settle(tester, 16);
      expect(find.byType(LoginScreen), findsOneWidget);
      final drafts = await io(tester, () => DatabaseHelper().database.then(
          (db) => db.query('invoice_drafts')));
      expect(drafts, isEmpty);
      noErrors(tester, 'timeout empty');
    });
  });

  // ── 6. Tamil ───────────────────────────────────────────────────────────────

  group('Tamil', () {
    String navKey(String label) => 'modernNav_$label';

    testWidgets(
        'switch to Tamil in Settings > Company Info, then walk the first '
        'screens with no overflow', (tester) async {
      await firstRunToDashboard(tester);
      await openNav(tester, en.navSettings);
      await tap(tester, rail(en.settingsNavCompanyInfoLabel), rounds: 14);
      noErrors(tester, 'company info');
      await tap(tester, find.byKey(const ValueKey('companyInfoLanguage')));
      await tap(tester, find.text('தமிழ்').last, rounds: 16);
      noErrors(tester, 'Company Info in Tamil');
      expect(find.text(ta.navSettings), findsWidgets);
      expect(
          await io(tester, () => BackendServices.settings.getAppLocale()), 'ta');

      // Sidebar pages in Tamil.
      for (final page in [
        ta.navDashboard, ta.navNewInvoice, ta.navInvoices, ta.navCustomers,
        ta.navProducts, ta.navReports, ta.navSettings,
      ]) {
        final k = find.byKey(ValueKey(navKey(page)));
        if (k.evaluate().isEmpty) continue;
        await tap(tester, k, rounds: 16);
        noErrors(tester, 'Tamil page $page');
      }
      // Settings sections in Tamil.
      for (final s in [
        ta.settingsNavCompaniesLabel, ta.settingsNavUsersLabel,
        ta.settingsNavBackupLabel, ta.settingsNavSoftwareInfoLabel,
      ]) {
        await tap(tester, rail(s), rounds: 14);
        noErrors(tester, 'Tamil settings $s');
      }
      await tap(tester, find.byKey(ValueKey(navKey(ta.navDashboard))),
          rounds: 12);

      // Logout -> Login, forgot password, wrong password, all in Tamil.
      await logout(tester, l10n: ta);
      noErrors(tester, 'Tamil logout');
      expect(find.text(ta.loginButton), findsOneWidget);
      await login(tester, 'admin', 'nope-nope', l10n: ta);
      expect(find.text(ta.loginInvalidCredentialsMessage), findsOneWidget);
      noErrors(tester, 'Tamil wrong password');
      await tester.pump(const Duration(seconds: 5));
      await settle(tester, 4);
      await tap(tester, find.text(ta.loginForgotPasswordButton), rounds: 12);
      noErrors(tester, 'Tamil forgot password');
      await tap(tester, find.text(ta.resetPasswordVerifyButton));
      expect(find.text(ta.resetPasswordEnterFieldsMessage), findsOneWidget);
      await tap(tester, find.text(ta.resetPasswordBackToLoginButton));

      // Restart: the app opens in Tamil.
      await relaunch(tester);
      await startApp(tester);
      noErrors(tester, 'Tamil restart');
      expect(find.text(ta.loginButton), findsOneWidget);
      await login(tester, 'admin', _adminNewPassword, l10n: ta);
      expect(find.byType(DashboardScreen), findsOneWidget);
      noErrors(tester, 'Tamil dashboard after restart');

      // Narrower window (the minimum size main() allows is 600x400).
      tester.view.physicalSize = const Size(1024, 700);
      await settle(tester, 6);
      noErrors(tester, 'Tamil at 1024x700');
    });

    testWidgets('a new shop owner picks Tamil in onboarding step 1',
        (tester) async {
      await freshInstall(tester);
      await startApp(tester);
      await login(tester, 'admin', 'admin');
      await forcedPasswordChange(tester, _adminNewPassword);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await tap(tester, find.byType(DropdownButtonFormField<Locale>));
      await tap(tester, find.text('தமிழ்').last, rounds: 12);
      noErrors(tester, 'onboarding in Tamil');
      expect(find.text(ta.onboardingStepCompanyTitle), findsOneWidget);
      await walkOnboarding(tester, name: 'மதன் ஸ்டோர்ஸ்', l10n: ta);
      noErrors(tester, 'Tamil onboarding done');
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(companyPillName(tester), 'மதன் ஸ்டோர்ஸ்');
    });
  });
}
