import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:invoiceo/common/app_config.dart';
import 'package:invoiceo/common/constants.dart';
import 'package:invoiceo/database/company_registry_service.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/models/company_profile.dart';
import 'package:invoiceo/models/user.dart';
import 'package:invoiceo/providers/locale_provider.dart';
import 'package:invoiceo/providers/repositories.dart';
import 'package:invoiceo/providers/theme_provider.dart';
import 'package:invoiceo/screens/auth/forgot_password_screen.dart';
import 'package:invoiceo/screens/auth/change_password_screen.dart';
import 'package:invoiceo/screens/help/help_search_screen.dart';
import 'package:invoiceo/screens/settings/company_management_screen.dart';
import 'package:invoiceo/screens/test_gate_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:invoiceo/providers/app_config_provider.dart';
import 'package:invoiceo/utils/post_auth_navigation.dart';
import 'package:invoiceo/utils/window_title.dart';
import 'package:invoiceo/theme/brand_colors.dart';

// Login Screen
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showDefaultCredsHint = false;
  List<CompanyProfile> _companies = [];
  String? _activeCompanyId;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _checkFirstTimeUser();
  }

  Future<void> _loadCompanies() async {
    final companies = await CompanyRegistryService.listCompanies();
    final activeId = await CompanyRegistryService.getActiveCompanyId();
    if (!mounted) return;
    setState(() {
      _companies = companies;
      _activeCompanyId = activeId;
    });
  }

  /// Nothing has read per-company data yet at the Login screen (see
  /// `CompanyManagementScreen`'s doc comment for the full reasoning), so
  /// switching here is instant — repoint the DB, re-sync the two providers
  /// loaded before this screen even rendered, and start the credential
  /// fields fresh for whichever company is now selected.
  Future<void> _onCompanySelected(String? id) async {
    if (id == null || id == _activeCompanyId) return;
    await CompanyRegistryService.switchToCompany(id);
    final themeKey = await ref.read(settingsRepositoryProvider).getThemeMode();
    final localeKey = await ref.read(settingsRepositoryProvider).getAppLocale();
    await refreshWindowTitle();
    if (!mounted) return;
    ref.read(themeModeProvider.notifier).state = themeModeFromKey(themeKey);
    applyAppLocale(ref, localeFromKey(localeKey));
    _usernameController.clear();
    _passwordController.clear();
    setState(() {
      _activeCompanyId = id;
      _showDefaultCredsHint = false;
    });
    await _checkFirstTimeUser();
  }

  Future<void> _openCompanyManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CompanyManagementScreen()),
    );
    if (!mounted) return;
    _usernameController.clear();
    _passwordController.clear();
    setState(() => _showDefaultCredsHint = false);
    await _loadCompanies();
    await _checkFirstTimeUser();
  }

  // Show the hint only while admin/admin actually still works as a login.
  // Cloud edition has no seeded default account — skip the check entirely.
  Future<void> _checkFirstTimeUser() async {
    if (ref.read(appEditionConfigProvider).isCloud) return;
    final user =
        await ref.read(authRepositoryProvider).getUser('admin', 'admin');
    if (!mounted || user == null) return;
    _usernameController.text = 'admin';
    _passwordController.text = 'admin';
    setState(() => _showDefaultCredsHint = true);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login(AppEditionConfig cfg) async {
    final l10n = AppLocalizations.of(context)!;

    // for cloud the username will be email
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final usernameText =
        cfg.isCloud ? l10n.fieldEmailLabel : l10n.loginUsernameLabel;

    if (username.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loginEnterCredentialsMessage(usernameText))),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    final user = await ref.read(authRepositoryProvider).getUser(username, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if(user == null)
    {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loginInvalidCredentialsMessage)),
      );
      return;
    }

    _afterLoginNavigate(cfg, user);
  }

  Future<void> _afterLoginNavigate(AppEditionConfig cfg, User user) async {
    if (TestBuildConfig.isTestBuild && !await _testGatePasses(cfg, user)) return;

    if(cfg.isCloud)
    {
      if (!mounted) return;
      await navigateAfterAuth(context, ref, user);
    }
    else if (!user.passwordChanged && !cfg.isCloud) {
      // Force password change
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChangePasswordScreen(user: user, forced: true),
        ),
      );
    }
    else{
      if (!mounted) return;
      await navigateAfterAuth(context, ref, user);
    }

  }

  // Test builds only: uses our website's response Date header as a trusted
  // clock — local device time is spoofable and would defeat this gate.
  Future<bool> _testGatePasses(AppEditionConfig cfg, User user) async {
    DateTime serverTime;
    try {
      final resp = await http
          .head(Uri.parse(AppConfig.website))
          .timeout(const Duration(seconds: 5));
      final dateHeader = resp.headers['date'];
      if (dateHeader == null) throw const HttpException('missing Date header');
      serverTime = HttpDate.parse(dateHeader);
    } catch (_) {
      if (!mounted) return false;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TestGateScreen(
            reason: TestGateReason.noInternet,
            onRetry: () => _afterLoginNavigate(cfg, user),
          ),
        ),
      );
      return false;
    }

    final expiry = DateTime.fromMillisecondsSinceEpoch(TestBuildConfig.buildEpochSeconds * 1000)
        .add(const Duration(days: TestBuildConfig.testExpiryDays));
    if (serverTime.isAfter(expiry)) {
      if (!mounted) return false;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TestGateScreen(reason: TestGateReason.expired)),
      );
      return false;
    }
    return true;
  }

  /// The first-run hint with both 'admin' values in bold. The translated
  /// sentence is split where the two values go.
  List<TextSpan> _defaultCredsHintSpans(AppLocalizations l10n) {
    const marker = '\u0000';
    final parts = l10n.loginFirstTimeHint(marker, marker).split(marker);
    final bold = TextStyle(
        fontWeight: FontWeight.bold, color: Colors.orange.shade700);
    return [
      for (var i = 0; i < parts.length; i++) ...[
        TextSpan(text: parts[i]),
        if (i < parts.length - 1) TextSpan(text: 'admin', style: bold),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cfg = ref.watch(appEditionConfigProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Phone: card fills the width (minus side padding) since there's no
    // room to spare. Tablet/desktop: a fixed comfortable width instead of
    // the old `width * 0.25`, which shrank to an unusably narrow card on
    // tablet portrait widths (e.g. ~190px at 768px wide).
    final isPhone = screenWidth < 600;
    final cardWidth = isPhone ? screenWidth - 48 : 420.0;
    final cardPadding = isPhone ? 20.0 : 32.0;
    final logoWidth = (cardWidth * 0.65).clamp(140.0, 230.0);
    return Scaffold(
      backgroundColor: isDark ? null : BrandColors.primarySoft,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                Card(
                  elevation: 8,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: Container(
                    width: cardWidth,
                    padding: EdgeInsets.all(cardPadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          // TODO: swap to a real dark-mode asset once available.
                          isDark
                              ? 'assets/images/logo_dark.png'
                              : 'assets/images/logo.png',
                          width: logoWidth,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                        AppSpacing.hSmall,
                        if (!cfg.isCloud && _showDefaultCredsHint) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: _defaultCredsHintSpans(l10n),
                                    ),
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppSpacing.hLarge,
                        ],
                        if (_companies.length > 1) ...[
                          DropdownButtonFormField<String>(
                            isExpanded: true, // long names shorten, not overflow
                            value: _activeCompanyId,
                            decoration: InputDecoration(
                              labelText: l10n.loginCompanySelectorLabel,
                              prefixIcon: const Icon(Icons.corporate_fare),
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              for (final company in _companies)
                                DropdownMenuItem(
                                  value: company.id,
                                  child: Text(company.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: _onCompanySelected,
                          ),
                          AppSpacing.hMedium,
                        ],
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: cfg.isCloud
                                ? l10n.fieldEmailLabel
                                : l10n.loginUsernameLabel,
                            prefixIcon: const Icon(Icons.person),
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: cfg.isCloud
                              ? TextInputType.emailAddress
                              : TextInputType.text,
                        ),
                        AppSpacing.hMedium,
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          onSubmitted: (_) => _login(cfg),
                          decoration: InputDecoration(
                            labelText: l10n.loginPasswordLabel,
                            prefixIcon: const Icon(Icons.lock),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        AppSpacing.hXlarge,
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () => _login(cfg),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(l10n.loginButton),
                          ),
                        ),
                        AppSpacing.hSmall,
                        if (!cfg.isCloud)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ForgotPasswordScreen()),
                              ),
                              child: Text(l10n.loginForgotPasswordButton),
                            ),
                          ),
                        AppSpacing.hLarge,
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => launchUrl(Uri.parse(AppConfig.website),
                                mode: LaunchMode.externalApplication),
                            child: Text(
                              AppConfig.website,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  decoration: TextDecoration.underline),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppConfig.version,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => showHelpSearchDialog(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.support_agent_outlined,
                                    size: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    l10n.loginNeedHelpLink,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        decoration: TextDecoration.underline),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
          ),
          if (!cfg.isCloud)
            Positioned(
              right: 16,
              bottom: 16,
              child: IconButton(
                tooltip: l10n.loginCompanyGearTooltip,
                icon: const Icon(Icons.settings),
                onPressed: _openCompanyManagement,
              ),
            ),
        ],
      ),
    );
  }
}
