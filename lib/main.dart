import 'dart:ffi' show DynamicLibrary;
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoiceo/common/app_config.dart';
import 'package:invoiceo/database/company_registry_service.dart';
import 'package:invoiceo/database/legacy_data_migration.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/providers/locale_provider.dart';
import 'package:invoiceo/providers/repositories.dart';
import 'package:invoiceo/providers/sqlite_repository_overrides.dart';
import 'package:invoiceo/providers/theme_provider.dart';
import 'package:invoiceo/theme/app_theme.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/screens/splash_screen.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/utils/window_title.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  // Set up error handlers BEFORE runApp
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('[PlatformDispatcher] Unhandled error: $error');
      debugPrint('Stack: $stack');
    }
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              kDebugMode ? details.exceptionAsString() : 'Please restart the app.',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  };

  if (Platform.isLinux) {
    // The database runs in its own isolate, so the library choice is made
    // there (see _openSqliteOnLinux).
    databaseFactory = createDatabaseFactoryFfi(ffiInit: _openSqliteOnLinux);
  } else if (!Platform.isAndroid) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  WidgetsFlutterBinding.ensureInitialized();
  registerFallbackNumberSymbols();
  // Invoiceo is built on Invoiso (MIT License). Its notice is listed on the
  // licence page with the other packages.
  LicenseRegistry.addLicense(() async* {
    String? text;
    try {
      text = await rootBundle.loadString('LICENSE');
    } catch (_) {
      // LICENSE not bundled: skip it rather than break the licence page.
    }
    if (text != null) {
      yield LicenseEntryWithLineBreaks(
          ['Invoiceo (based on Invoiso © 2025 ANOOP P)'], text);
    }
  });
  await LegacyDataMigration.runAtStartup(); // copy-only, before the database opens
  await CompanyRegistryService.ensureDefaultCompanyRegistered();
  DatabaseHelper().setActiveFileNameBeforeFirstOpen(
      await CompanyRegistryService.getActiveCompanyDbFileName());
  BackendServices.configure(
    settings: SqliteSettingsRepository(),
    companyInfo: SqliteCompanyInfoRepository(),
    invoices: SqliteInvoiceRepository(),
    payments: SqlitePaymentRepository(),
    installation: SqliteInstallationRepository()
  );

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    // First size about 1280x800, never larger than the screen: a smaller
    // screen opens maximised instead.
    const firstSize = Size(1280, 800);
    var maximize = false;
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      final screen = display.visibleSize ?? display.size;
      maximize =
          screen.width < firstSize.width || screen.height < firstSize.height;
    } catch (_) {
      // Screen size unknown: keep the first size.
    }

    final WindowOptions options = WindowOptions(
      size: maximize ? null : firstSize,
      minimumSize: const Size(600, 400),
      center: true,
      backgroundColor: Colors.white,
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(options, () async {
      if (maximize) {
        await windowManager.maximize();
      } else {
        await windowManager.center();
      }
      await windowManager.show();
      await windowManager.focus();
    });

    await refreshWindowTitle();
  }

  runApp(ProviderScope(
    overrides: sqliteRepositoryOverrides,
    child: const MyApp()
  ));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _loadAppLocale();
  }

  Future<void> _loadThemeMode() async {
    final key = await ref.read(settingsRepositoryProvider).getThemeMode();
    if (!mounted) return;
    ref.read(themeModeProvider.notifier).state = themeModeFromKey(key);
  }

  Future<void> _loadAppLocale() async {
    final key = await ref.read(settingsRepositoryProvider).getAppLocale();
    if (!mounted) return;
    applyAppLocale(ref, localeFromKey(key));
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      title: AppConfig.brandName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        FallbackLocalizationsDelegate<MaterialLocalizations>(GlobalMaterialLocalizations.delegate),
        FallbackLocalizationsDelegate<WidgetsLocalizations>(GlobalWidgetsLocalizations.delegate),
        FallbackLocalizationsDelegate<CupertinoLocalizations>(GlobalCupertinoLocalizations.delegate),
      ],
      home: const SplashScreen(),
    );
  }
}

/// Linux: sqlite3 opens 'libsqlite3.so', which only the -dev package
/// installs. A normal Ubuntu has 'libsqlite3.so.0', so try that next, then a
/// copy shipped next to the app (lib/libsqlite3.so).
void _openSqliteOnLinux() {
  open.overrideFor(OperatingSystem.linux, () {
    final bundled =
        '${File(Platform.resolvedExecutable).parent.path}/lib/libsqlite3.so';
    for (final name in ['libsqlite3.so', 'libsqlite3.so.0', bundled]) {
      try {
        return DynamicLibrary.open(name);
      } catch (_) {}
    }
    return DynamicLibrary.open('libsqlite3.so'); // shows the real error
  });
}
