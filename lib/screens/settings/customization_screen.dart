import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:invoiceo/common/constants.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/theme/brand_colors.dart';

class CustomizationScreen extends StatefulWidget {
  final int? highlightIndex;
  const CustomizationScreen({super.key, this.highlightIndex});

  @override
  State<CustomizationScreen> createState() => _CustomizationScreenState();
}

class _CustomizationScreenState extends State<CustomizationScreen> {
  int? _highlightIndex;

  @override
  void initState() {
    super.initState();
    _highlightIndex = widget.highlightIndex;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context)!;

    final options = [
      _CustomOption(
        icon: Icons.picture_as_pdf_rounded,
        title: l10n.customizationPdfTemplateTitle,
        description: l10n.customizationPdfTemplateDescription,
      ),
      _CustomOption(
        icon: Icons.tune_rounded,
        title: l10n.customizationCustomFieldsTitle,
        description: l10n.customizationCustomFieldsDescription,
      ),
      _CustomOption(
        icon: Icons.branding_watermark_rounded,
        title: l10n.customizationWhiteLabelTitle,
        description: l10n.customizationWhiteLabelDescription,
      ),
      _CustomOption(
        icon: Icons.category_rounded,
        title: l10n.customizationIndustryBuildTitle,
        description: l10n.customizationIndustryBuildDescription,
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : BrandColors.page,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.customizationEyebrowLabel,
              style: TextStyle(
                fontSize: AppFontSize.xsmall,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.customizationHeadline,
              style: TextStyle(
                fontSize: AppFontSize.xlarge,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.customizationSubtitle,
              style: TextStyle(
                  fontSize: AppFontSize.small,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            LayoutBuilder(builder: (context, constraints) {
              // As many 380px columns as fit (like the old grid), but each row
              // is as tall as its tallest card, so longer text never spills.
              const gap = 16.0;
              final columns = (constraints.maxWidth / (380 + gap))
                  .ceil()
                  .clamp(1, options.length);
              final cardWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Column(
                children: [
                  for (var start = 0;
                      start < options.length;
                      start += columns) ...[
                    if (start > 0) const SizedBox(height: gap),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = start;
                              i < start + columns && i < options.length;
                              i++) ...[
                            if (i > start) const SizedBox(width: gap),
                            SizedBox(
                              width: cardWidth,
                              child: _optionCard(
                                  context, options[i], i, l10n, primaryColor),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              );
            }),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: Colors.amber.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.customizationDisclaimerMessage,
                      style: TextStyle(
                          fontSize: AppFontSize.xsmall,
                          color: Colors.amber.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _formUrl = 'https://invoiceo.in/customization.html#request';

  Widget _pill(String text,
          {required Color background, required Color foreground}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: AppFontSize.xsmall,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      );

  Widget _optionCard(BuildContext context, _CustomOption opt, int index,
      AppLocalizations l10n, Color primaryColor) {
    final isHighlighted = _highlightIndex == index;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      elevation: isHighlighted ? 4 : 0,
      shadowColor: isHighlighted
          ? primaryColor.withValues(alpha: 0.3)
          : Colors.transparent,
      color: isHighlighted
          ? primaryColor.withValues(alpha: 0.04)
          : Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        side: BorderSide(
          color: isHighlighted
              ? primaryColor
              : Theme.of(context).colorScheme.outlineVariant,
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(
                        alpha: isHighlighted ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(AppBorderRadius.small),
                  ),
                  child: Icon(opt.icon, size: 20, color: primaryColor),
                ),
                const SizedBox(width: 8),
                // The tags wrap onto a second line rather than overflow.
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (isHighlighted)
                        _pill(l10n.customizationRecommendedBadge,
                            background: primaryColor, foreground: Colors.white),
                      _pill(l10n.customizationQuotedBadge,
                          background: primaryColor.withValues(alpha: 0.08),
                          foreground: primaryColor),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              opt.title,
              style: TextStyle(
                fontSize: AppFontSize.medium,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              opt.description,
              style: TextStyle(
                  fontSize: AppFontSize.xsmall, color: muted, height: 1.5),
            ),
            const Spacer(),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () async {
                  if (_highlightIndex != null) {
                    setState(() => _highlightIndex = null);
                  }
                  final uri = Uri.parse(_formUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text(l10n.customizationFormOpenErrorMessage)),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    l10n.customizationRequestButton,
                    style: const TextStyle(
                        fontSize: AppFontSize.xsmall,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomOption {
  final IconData icon;
  final String title;
  final String description;

  const _CustomOption({
    required this.icon,
    required this.title,
    required this.description,
  });
}
