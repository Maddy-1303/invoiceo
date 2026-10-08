// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appTitle => 'Invoiceo';

  @override
  String get actionSave => 'சேமிக்கவும்';

  @override
  String get actionCancel => 'ரத்து செய்யவும்';

  @override
  String get actionSkip => 'தவிர்க்கவும்';

  @override
  String get actionNext => 'அடுத்து';

  @override
  String get actionBack => 'பின்செல்';

  @override
  String get actionGetStarted => 'தொடங்கவும்';

  @override
  String get commonLanguage => 'மொழி';

  @override
  String get commonBeta => 'பீட்டா';

  @override
  String get commonSystemDefault => 'கணினி இயல்புநிலை';

  @override
  String get commonTheme => 'தோற்றம்';

  @override
  String get themeLight => 'ஒளி';

  @override
  String get themeDark => 'இருள்';

  @override
  String get themeSystem => 'கணினி';

  @override
  String get onboardingStepCompanyTitle => 'நிறுவனம்';

  @override
  String get onboardingStepCompanySubtitle =>
      'உங்கள் வணிகத்தைப் பற்றிக் கூறவும்';

  @override
  String get onboardingStepInvoiceTitle => 'விலைப்பட்டியல் அமைப்புகள்';

  @override
  String get onboardingStepInvoiceSubtitle =>
      'உங்கள் விலைப்பட்டியல்கள் செயல்படும் விதத்தை அமைக்கவும்';

  @override
  String get onboardingStepAppearanceTitle => 'விலைப்பட்டியல் தோற்றம்';

  @override
  String get onboardingStepAppearanceSubtitle =>
      'தாள் அளவையும் வடிவமைப்பையும் தேர்ந்தெடுக்கவும்';

  @override
  String get onboardingStepDoneTitle => 'அனைத்தும் தயார்';

  @override
  String get onboardingCompanyNameLabel => 'நிறுவனப் பெயர்';

  @override
  String get onboardingCountryLabel => 'நாடு';

  @override
  String get onboardingLogoLabel => 'நிறுவன லோகோ';

  @override
  String get onboardingCurrencyLabel => 'நாணயம்';

  @override
  String get onboardingDateFormatLabel => 'தேதி வடிவம்';

  @override
  String get onboardingInvoiceStartingNumberLabel =>
      'விலைப்பட்டியல் தொடக்க எண்';

  @override
  String get onboardingLeadingZerosLabel => 'முன்னணிப் பூஜ்ஜியங்கள்';

  @override
  String get onboardingLeadingZerosSubtitle =>
      'விலைப்பட்டியல் எண்களை 8 இலக்கங்களாக்க முன்னால் பூஜ்ஜியம் சேர்க்கவும் (எ.கா. 00000007)';

  @override
  String get onboardingDefaultTaxRateLabel => 'இயல்புநிலை வரி விகிதம் (%)';

  @override
  String get onboardingPageSizeLabel => 'தாள் அளவு';

  @override
  String get onboardingTemplateLabel => 'விலைப்பட்டியல் வடிவமைப்பு';

  @override
  String get onboardingDoneHeadline => 'அனைத்தும் தயார்!';

  @override
  String get onboardingDoneBody =>
      'உங்கள் நிறுவனம், விலைப்பட்டியல் மற்றும் வடிவமைப்பு விவரங்கள் சேமிக்கப்பட்டன. இவற்றில் எதையும் பின்னர் அமைப்புகளிலிருந்து மாற்றிக்கொள்ளலாம்.';

  @override
  String get splashInitErrorTitle => 'தொடக்கப் பிழை';

  @override
  String splashInitErrorMessage(String error) {
    return 'தரவுத்தளத்தைத் தொடங்க முடியவில்லை.\n\n$error';
  }

  @override
  String get actionRetry => 'மீண்டும் முயலவும்';

  @override
  String get splashInitializingMessage => 'செயலி தொடங்கப்படுகிறது...';

  @override
  String get testGateNoInternetTitle =>
      'சரிபார்க்க சோதனை நிறுவிக்கு இணைய இணைப்பு தேவை.';

  @override
  String get testGateExpiredTitle =>
      'இந்தச் சோதனைப் பதிப்பு காலாவதியாகிவிட்டது.';

  @override
  String get testGateNoInternetSubtitle =>
      'இணையத்துடன் இணைந்து மீண்டும் முயலவும்.';

  @override
  String testGateExpiredSubtitle(String email) {
    return 'ஆதரவுக் குழுவைத் தொடர்புகொள்ளவும்: $email';
  }

  @override
  String get dashboardSessionExpiredMessage =>
      'செயல்பாடு இல்லாததால் அமர்வு காலாவதியானது.';

  @override
  String get dashboardUnknownTabLabel => 'அறியப்படாத தாவல்';

  @override
  String dashboardInvoiceLayoutTooltip(String layout) {
    return 'விலைப்பட்டியல் தளவமைப்பு: $layout — விவரங்களுக்குக் கிளிக் செய்யவும்';
  }

  @override
  String get dashboardLayoutNew => 'புதியது';

  @override
  String get dashboardLayoutClassic => 'கிளாசிக்';

  @override
  String get dashboardInvoiceLayoutDialogTitle => 'விலைப்பட்டியல் தளவமைப்பு';

  @override
  String dashboardInvoiceLayoutDialogBody(String layout) {
    return 'தற்போதைய \"புதிய விலைப்பட்டியல்\" தளவமைப்பு: $layout. இதை அமைப்புகள் > அணுகல்தன்மை பகுதியில் மாற்றலாம். குறிப்பு: திருத்தும்போது மாற்றினால், இந்தப் படிவத்தில் சேமிக்கப்படாத மாற்றங்கள் நீக்கப்படும்.';
  }

  @override
  String get actionClose => 'மூடவும்';

  @override
  String get dashboardOpenSettingsAction => 'அமைப்புகளைத் திறக்கவும்';

  @override
  String get dashboardCollapseSidebarTooltip => 'பக்கப்பட்டியைச் சுருக்கவும்';

  @override
  String get dashboardExpandSidebarTooltip => 'பக்கப்பட்டியை விரிவாக்கவும்';

  @override
  String get navDashboard => 'முகப்புப் பலகை';

  @override
  String get navNewInvoice => 'புதிய விலைப்பட்டியல்';

  @override
  String get navInvoices => 'விலைப்பட்டியல்கள்';

  @override
  String get navQuotations => 'விலைப்புள்ளிகள்';

  @override
  String get navReceipts => 'ரசீதுகள்';

  @override
  String get navCustomers => 'வாடிக்கையாளர்கள்';

  @override
  String get navProducts => 'பொருட்கள்';

  @override
  String get navReports => 'அறிக்கைகள்';

  @override
  String get navSettings => 'அமைப்புகள்';

  @override
  String get modernNavSectionSales => 'விற்பனை';

  @override
  String get modernNavSectionCatalog => 'பட்டியல்';

  @override
  String get modernNavSectionBusiness => 'வணிகம்';

  @override
  String get modernTopBarSearchHint => 'எதையும் தேடுங்கள்... (Ctrl+K)';

  @override
  String get modernHelpSupport => 'உதவி & ஆதரவு';

  @override
  String get modernCreateNewTooltip => 'புதியது உருவாக்கு';

  @override
  String modernDashGreetingMorning(String name) {
    return 'காலை வணக்கம், $name';
  }

  @override
  String modernDashGreetingAfternoon(String name) {
    return 'மதிய வணக்கம், $name';
  }

  @override
  String modernDashGreetingEvening(String name) {
    return 'மாலை வணக்கம், $name';
  }

  @override
  String get modernDashSubtitle =>
      'இன்று உங்கள் வணிகத்தில் என்ன நடக்கிறது என்பது இதோ.';

  @override
  String get modernDashSalesOverview => 'விற்பனை மேலோட்டம்';

  @override
  String get modernDashRecentInvoices => 'சமீபத்திய விலைப்பட்டியல்கள்';

  @override
  String get modernDashLowStockProducts => 'குறைந்த இருப்பு பொருட்கள்';

  @override
  String get modernDashVsLastMonth => 'கடந்த மாதத்துடன்';

  @override
  String get modernDashVsPreviousPeriod => 'முந்தைய காலத்துடன்';

  @override
  String modernDashLowStockCount(int count) {
    return '$count குறைந்த இருப்பு';
  }

  @override
  String get modernDashLast12Months => 'கடந்த 12 மாதங்கள்';

  @override
  String get modernDashThisMonth => 'இந்த மாதம்';

  @override
  String get modernDashLastMonth => 'கடந்த மாதம்';

  @override
  String get modernDashInvoiceNo => 'விலைப்பட்டியல் எண்';

  @override
  String get modernDashAddCustomer => 'வாடிக்கையாளரைச் சேர்';

  @override
  String get modernDashAddProduct => 'பொருளைச் சேர்';

  @override
  String get modernDashViewReports => 'அறிக்கைகளைப் பார்';

  @override
  String get modernDashUpdateStock => 'இருப்பைப் புதுப்பி';

  @override
  String get modernDashNewStockLabel => 'புதிய இருப்பு';

  @override
  String get modernDashNoLowStock => 'இருப்பு குறைந்த பொருட்கள் இல்லை.';

  @override
  String get modernDashNoData => 'இந்தக் காலத்திற்குத் தரவு இல்லை';

  @override
  String get mInvSubtitle =>
      'வாடிக்கையாளர், பொருட்கள் மற்றும் பில்லிங் விவரங்களைச் சேர்க்கவும்.';

  @override
  String get mInvCustomerSearchHint =>
      'வாடிக்கையாளரைத் தேடுங்கள் அல்லது நேரடி வாடிக்கையாளர் பெயரைத் தட்டச்சு செய்யுங்கள்...';

  @override
  String get mInvAddNew => 'புதியது சேர்';

  @override
  String get mInvNewCustomerTitle => 'புதிய வாடிக்கையாளர்';

  @override
  String get mInvEditCustomerTitle => 'வாடிக்கையாளரைத் திருத்து';

  @override
  String get mInvSaveToCustomerList => 'வாடிக்கையாளர் பட்டியலில் சேமி';

  @override
  String get mInvUpdateCustomer => 'வாடிக்கையாளரைப் புதுப்பி';

  @override
  String get mInvItems => 'பொருட்கள்';

  @override
  String get mInvClearAll => 'அனைத்தையும் நீக்கு';

  @override
  String get mInvClearAllConfirm =>
      'இந்த ஆவணத்திலிருந்து எல்லா பொருட்களையும் நீக்கவா?';

  @override
  String get mInvAddAnotherItem => 'மற்றொரு பொருளைச் சேர்';

  @override
  String mInvDetailsTitle(String type) {
    return '$type விவரங்கள்';
  }

  @override
  String get mInvAdvancedOptions => 'மேம்பட்ட விருப்பங்கள்';

  @override
  String get mInvChargesAdjustments => 'கட்டணங்கள் & சரிசெய்தல்கள்';

  @override
  String get mInvStatusAddCustomer => 'வாடிக்கையாளரைச் சேர்க்கவும்';

  @override
  String get mInvStatusAddCustomerSub =>
      'வாடிக்கையாளரைத் தேடுங்கள் அல்லது நேரடி வாடிக்கையாளர் பெயரைத் தட்டச்சு செய்யுங்கள்.';

  @override
  String get mInvStatusAddItems => 'பொருட்களைச் சேர்க்கவும்';

  @override
  String get mInvStatusAddItemsSub =>
      'மேலே ஒரு பொருளைத் தேடுங்கள், பார்கோடை ஸ்கேன் செய்யுங்கள் அல்லது தனிப்பயன் பொருளைச் சேர்க்கவும்.';

  @override
  String mInvStatusReady(String type) {
    return '$type உருவாக்கத் தயார்';
  }

  @override
  String mInvStatusReadyUpdate(String type) {
    return '$type புதுப்பிக்கத் தயார்';
  }

  @override
  String get mInvStatusReadySub =>
      'மேலும் பொருட்களைச் சேர்க்கவும் அல்லது விவரங்களைச் சரிபார்த்து உருவாக்கவும்.';

  @override
  String get mInvSaveDraft => 'வரைவாகச் சேமி';

  @override
  String get mInvDraftSaved => 'வரைவு சேமிக்கப்பட்டது';

  @override
  String get mInvNothingToSave =>
      'வரைவைச் சேமிக்கும் முன் ஒரு வாடிக்கையாளர் அல்லது பொருளைச் சேர்க்கவும்.';

  @override
  String get mInvSavePrint => 'சேமித்து அச்சிடு';

  @override
  String get mInvUpdatePrint => 'புதுப்பித்து அச்சிடு';

  @override
  String get mInvPrintThermal => 'தெர்மல் ரசீதை அச்சிடு';

  @override
  String get mInvPrintA4 => 'A4 PDF அச்சிடு';

  @override
  String get mInvPreviewFirst => 'அச்சிடும் முன் முன்னோட்டம்';

  @override
  String mInvCreateType(String type) {
    return '$type உருவாக்கு';
  }

  @override
  String mInvUpdateType(String type) {
    return '$type புதுப்பி';
  }

  @override
  String get mInvCreateAndNew => 'உருவாக்கிப் புதியதைத் தொடங்கு';

  @override
  String get mInvCreateAndPreview => 'உருவாக்கி முன்னோட்டமிடு';

  @override
  String get mInvPdfNumberTitle => 'PDF-இல் உள்ள எண்';

  @override
  String get mInvPdfNumberInfo =>
      'எண்கள் தானாக வரிசையாக வழங்கப்படும். PDF-இல் வேறு எண்ணை அச்சிட, \"PDF-இல் விலைப்பட்டியல் எண்ணை மறை\" என்பதை இயக்கி அச்சிட வேண்டிய எண்ணைத் தட்டச்சு செய்யுங்கள்.';

  @override
  String get mInvDrafts => 'வரைவுகள்';

  @override
  String get mInvContinueDraft => 'தொடர்';

  @override
  String get mInvDeleteDraftConfirm => 'இந்த வரைவை நீக்கவா?';

  @override
  String mInvDraftSavedOn(String date) {
    return '$date அன்று சேமிக்கப்பட்டது';
  }

  @override
  String get mListSubtitleInvoice =>
      'உங்கள் அனைத்து விலைப்பட்டியல்களையும் நிர்வகிக்கவும், தேடவும், கண்காணிக்கவும்';

  @override
  String get mListSubtitleQuotation =>
      'உங்கள் அனைத்து மதிப்பீடுகளையும் நிர்வகிக்கவும், தேடவும், கண்காணிக்கவும்';

  @override
  String get mListSubtitleReceipt =>
      'உங்கள் அனைத்து ரசீதுகளையும் நிர்வகிக்கவும், தேடவும், கண்காணிக்கவும்';

  @override
  String mListAllOfType(String items) {
    return 'அனைத்து $items';
  }

  @override
  String mListPctOfTotal(int pct) {
    return 'மொத்தத்தில் $pct%';
  }

  @override
  String get mListMoreFilters => 'மேலும் வடிப்பான்கள்';

  @override
  String get mListAllDates => 'அனைத்து தேதிகளும்';

  @override
  String get mListToday => 'இன்று';

  @override
  String get mListNoDrafts => 'சேமித்த வரைவுகள் இல்லை';

  @override
  String mSuccessSubtitle(String type) {
    return '$type சேமிக்கப்பட்டு பயன்படுத்தத் தயாராக உள்ளது.';
  }

  @override
  String mSuccessIdLabel(String type) {
    return '$type எண்';
  }

  @override
  String mSuccessOpenType(String type) {
    return '$type-ஐத் திற';
  }

  @override
  String get mSuccessViewBeforePrint => 'அச்சிடும் முன் பார்க்க';

  @override
  String get mSuccessSaveToDevice => 'சாதனத்தில் சேமி';

  @override
  String mSuccessPrintType(String type) {
    return '$type அச்சிடு';
  }

  @override
  String get mSuccessSendToPrinter => 'அச்சுப்பொறிக்கு அனுப்பு';

  @override
  String mSuccessCreateNew(String type) {
    return 'புதிய $type உருவாக்கு';
  }

  @override
  String mSuccessGoToList(String list) {
    return '$listக்குச் செல்';
  }

  @override
  String get mSuccessCopy => 'நகலெடு';

  @override
  String get mSuccessCopied => 'நகலெடுக்கப்பட்டது';

  @override
  String get mCustTypeLabel => 'வாடிக்கையாளர் வகை';

  @override
  String get mCustAllTypes => 'அனைத்து வகைகளும்';

  @override
  String get mCustIndividual => 'தனிநபர்';

  @override
  String get mCustBusiness => 'வணிகம்';

  @override
  String get mCustColNameBusiness => 'பெயர் / வணிகம்';

  @override
  String get mCustColContact => 'தொடர்பு';

  @override
  String get mCustColType => 'வகை';

  @override
  String get mCustOutstandingCurrency => 'நிலுவை நாணயம்';

  @override
  String get mCustReceivePayment => 'பணம் பெறு';

  @override
  String mCustDeleteSelectedTitle(int count) {
    return 'தேர்ந்தெடுத்த வாடிக்கையாளர்களை நீக்கவா ($count)?';
  }

  @override
  String get mCustDeleteSelectedBody =>
      'ஏற்கனவே உள்ள விலைப்பட்டியல்கள் பாதிக்கப்படாது. இதைத் திரும்பப் பெற முடியாது.';

  @override
  String mCustDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count வாடிக்கையாளர்கள் நீக்கப்பட்டனர்',
      one: '1 வாடிக்கையாளர் நீக்கப்பட்டார்',
    );
    return '$_temp0';
  }

  @override
  String get navServices => 'சேவைகள்';

  @override
  String get mProdSubtitle =>
      'உங்கள் பொருட்கள், இருப்பு மற்றும் விலைகளை நிர்வகிக்கவும்';

  @override
  String get mSvcTitle => 'சேவை மேலாண்மை';

  @override
  String get mSvcSubtitle => 'உங்கள் சேவைகள் மற்றும் விலைகளை நிர்வகிக்கவும்';

  @override
  String get mSvcNewService => 'புதிய சேவை';

  @override
  String get mProdTotalProducts => 'மொத்த பொருட்கள்';

  @override
  String get mProdAllProductsSub => 'அனைத்து பொருட்களும்';

  @override
  String get mProdInStock => 'இருப்பில் உள்ளது';

  @override
  String get mProdInStockSub => 'கிடைக்கும் பொருட்கள்';

  @override
  String get mProdLowStockSub => 'கவனம் தேவைப்படும் பொருட்கள்';

  @override
  String get mProdOutOfStockSub => 'கிடைக்கவில்லை';

  @override
  String get mSvcTotal => 'மொத்த சேவைகள்';

  @override
  String get mSvcAllSub => 'அனைத்து சேவைகளும்';

  @override
  String get mSvcWithTax => 'வரியுடன்';

  @override
  String get mSvcWithTaxSub => '0%-க்கு மேல் வரி';

  @override
  String get mSvcTaxFree => 'வரி இல்லாதவை';

  @override
  String get mSvcTaxFreeSub => '0% வரி';

  @override
  String get mSvcNoSac => 'SAC இல்லாதவை';

  @override
  String get mSvcNoSacSub => 'SAC குறியீடு இல்லை';

  @override
  String get mProdColSellingPrice => 'விற்பனை விலை';

  @override
  String mProdCopyName(String name) {
    return '$name (நகல்)';
  }

  @override
  String get mProdDuplicated => 'நகல் சேமிக்கப்பட்டது — இப்போது மாற்றலாம்';

  @override
  String mProdDeleteSelectedTitle(int count) {
    return 'தேர்ந்தெடுத்தவற்றை நீக்கவா ($count)?';
  }

  @override
  String get mProdDeleteSelectedBody =>
      'ஏற்கனவே உருவாக்கிய விலைப்பட்டியல்கள் பாதிக்கப்படாது. இதைத் திரும்பப் பெற முடியாது.';

  @override
  String mProdDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count உருப்படிகள் நீக்கப்பட்டன',
      one: '1 உருப்படி நீக்கப்பட்டது',
    );
    return '$_temp0';
  }

  @override
  String get mSvcSearchHint =>
      'சேவைகளைப் பெயர், மாற்றுப் பெயர், SAC, SKU மூலம் தேடுங்கள்…';

  @override
  String get mSvcDeleteAllTitle => 'அனைத்து சேவைகளையும் நீக்கு';

  @override
  String mSvcDeleteAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count சேவைகள் நிரந்தரமாக நீக்கப்படும். ஏற்கனவே உள்ள விலைப்பட்டியல்கள் பாதிக்கப்படாது. இதைத் திரும்பப் பெற முடியாது.',
      one:
          '1 சேவை நிரந்தரமாக நீக்கப்படும். ஏற்கனவே உள்ள விலைப்பட்டியல்கள் பாதிக்கப்படாது. இதைத் திரும்பப் பெற முடியாது.',
    );
    return '$_temp0';
  }

  @override
  String mSvcShowingRange(int from, int to, int total) {
    return '$total சேவைகளில் $from முதல் $to வரை காட்டப்படுகிறது';
  }

  @override
  String get mSvcNoServicesFound => 'சேவைகள் எதுவும் இல்லை';

  @override
  String get mSvcAddFirstService => 'தொடங்க உங்கள் முதல் சேவையைச் சேர்க்கவும்';

  @override
  String get mSvcNoneToDelete => 'நீக்க சேவைகள் இல்லை.';

  @override
  String get mSvcAllDeleted => 'அனைத்து சேவைகளும் நீக்கப்பட்டன.';

  @override
  String mSvcDeleteAllError(String error) {
    return 'சேவைகளை நீக்குவதில் பிழை: $error';
  }

  @override
  String get mSvcSaveButton => 'சேவையைச் சேமி';

  @override
  String get mSvcAdded => 'சேவை வெற்றிகரமாகச் சேர்க்கப்பட்டது!';

  @override
  String get mSvcImportCsvTitle => 'CSV-இலிருந்து சேவைகளை இறக்குமதி செய்';

  @override
  String mSvcImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count சேவைகள் வெற்றிகரமாக இறக்குமதி செய்யப்பட்டன!',
      one: '1 சேவை வெற்றிகரமாக இறக்குமதி செய்யப்பட்டது!',
    );
    return '$_temp0';
  }

  @override
  String mSvcExportPdfChoice(int pageSize, int allCount) {
    return 'தற்போதைய பக்கத்தை ($pageSize சேவைகள்) அல்லது அனைத்து $allCount சேவைகளையும் ஏற்றுமதி செய்யவா?';
  }

  @override
  String get mSvcAllServicesLabel => 'அனைத்து சேவைகளும்';

  @override
  String get dashboardRoleAdmin => 'நிர்வாகி';

  @override
  String get dashboardRoleUser => 'பயனர்';

  @override
  String get dashboardSupportTooltip => 'ஆதரவு';

  @override
  String get buyMeCoffeeLabel => 'எனக்கு ஒரு காபி வாங்கித் தாருங்கள்';

  @override
  String get dashboardLogoutTooltip => 'வெளியேறு';

  @override
  String get dashboardTestBuildBadge => 'சோதனைப் பதிப்பு';

  @override
  String get dashboardTestBadgeShort => 'சோதனை';

  @override
  String get dashboardKeyboardShortcutsTitle => 'விசைப்பலகை குறுக்குவழிகள்';

  @override
  String get dashboardShortcutsBannerTitle =>
      'புதியது: விசைப்பலகை குறுக்குவழிகள்';

  @override
  String get dashboardShortcutsBannerSubtitle =>
      'புதிய விலைப்பட்டியலுக்கு Ctrl+Q, சேமிக்க Ctrl+S, மேலும் பல.';

  @override
  String get dashboardViewAllAction => 'அனைத்தையும் பார்க்கவும்';

  @override
  String get dashboardLayoutBannerTitle =>
      'புதியது: பல முகப்புப் பலகை தளவமைப்புகள்';

  @override
  String get dashboardLayoutBannerSubtitle =>
      'மேல் வலது மூலையில் உள்ள கட்ட ஐகானைப் பயன்படுத்தி இயல்புநிலை, கிளாசிக், பென்டோ, எளிய ஃபீட் ஆகியவற்றுக்கு இடையே மாறவும்.';

  @override
  String get actionGotIt => 'புரிந்தது';

  @override
  String get dashboardThemeBannerTitle => 'புதியது: இருள் தோற்றம்';

  @override
  String get dashboardThemeBannerSubtitle =>
      'இன்னும் மெருகேற்றி வருகிறோம் — அமைப்புகள் > நிறுவனத் தகவல் பகுதியில் இதை இயக்கி, எது சரியில்லை என்று எங்களுக்குத் தெரிவியுங்கள்.';

  @override
  String dashboardSupportBannerTitle(String count) {
    return 'நீங்கள் $count விலைப்பட்டியல்களை உருவாக்கியுள்ளீர்கள்!';
  }

  @override
  String get dashboardSupportBannerReviewSubtitle =>
      'Invoiceo பிடித்திருக்கிறதா? ஒரு சிறு மதிப்புரை பெரிதும் உதவும்.';

  @override
  String get dashboardSupportBannerSupportSubtitle =>
      'Invoiceo உங்கள் அன்றாடப் பணிகளின் ஒரு பகுதியாகிவிட்டது போல் தெரிகிறது. இது உதவியாக இருந்தால், உங்களுக்குத் தோன்றும்போது இந்தத் திட்டத்தை ஆதரிப்பதைப் பரிசீலிக்கவும்.';

  @override
  String get dashboardReviewAction => 'மதிப்புரை';

  @override
  String get dashboardSupportAction => 'ஆதரவளிக்கவும்';

  @override
  String get dashboardOverviewTitle => 'முகப்புப் பலகை கண்ணோட்டம்';

  @override
  String get actionRefresh => 'புதுப்பிக்கவும்';

  @override
  String get helpSearchTooltip => 'உதவி மற்றும் அமைப்புகளில் தேடவும்';

  @override
  String dashboardOutOfStockCountLabel(int count) {
    return '$count இருப்பில் இல்லை';
  }

  @override
  String get dashboardRevenueCollectedLabel => 'வசூலான வருவாய்';

  @override
  String get dashboardOutstandingLabel => 'நிலுவை';

  @override
  String dashboardOverdueCountLabel(int count) {
    return '$count தாமதம்';
  }

  @override
  String get dashboardRecentInvoicesTitle => 'சமீபத்திய ஆவணங்கள்';

  @override
  String get dashboardLastFiveInvoicesLabel => 'கடைசி 5 ஆவணங்கள்';

  @override
  String get dashboardColDocumentNo => 'ஆவண எண்';

  @override
  String get dashboardColType => 'வகை';

  @override
  String get dashboardNoInvoicesYetTitle => 'இன்னும் விலைப்பட்டியல்கள் இல்லை';

  @override
  String get dashboardNoInvoicesYetSubtitle =>
      'இங்கே காண, உங்கள் முதல் விலைப்பட்டியலை உருவாக்கவும்';

  @override
  String get actionView => 'பார்க்கவும்';

  @override
  String get actionEdit => 'திருத்தவும்';

  @override
  String get actionDuplicate => 'நகலெடுக்கவும்';

  @override
  String get actionPdfPreview => 'PDF முன்னோட்டம்';

  @override
  String get actionDownloadPdf => 'PDF பதிவிறக்கவும்';

  @override
  String get actionPrint => 'அச்சிடவும்';

  @override
  String get actionPayment => 'பணம் செலுத்துதல்';

  @override
  String get actionDelete => 'நீக்கவும்';

  @override
  String get actionRecordPayment => 'பணம் செலுத்துதலைப் பதிவு செய்யவும்';

  @override
  String dashboardDueDateLabel(String date) {
    return 'செலுத்த வேண்டிய தேதி: $date';
  }

  @override
  String get labelInvoice => 'விலைப்பட்டியல்';

  @override
  String get labelQuotation => 'விலைப்புள்ளி';

  @override
  String get labelReceipt => 'ரசீது';

  @override
  String dashboardWelcomeBackMessage(String username) {
    return 'மீண்டும் வருக, $username';
  }

  @override
  String get dashboardBusinessGlanceSubtitle => 'உங்கள் வணிகம் ஒரே பார்வையில்';

  @override
  String get dashboardDueSoonTitle => 'விரைவில் செலுத்த வேண்டியவை';

  @override
  String dashboardInvoiceCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count விலைப்பட்டியல்கள்',
      one: '1 விலைப்பட்டியல்',
    );
    return '$_temp0';
  }

  @override
  String get dashboardTodayTomorrowLabel => 'இன்று & நாளை';

  @override
  String get dashboardDueTodayBadge => 'இன்று செலுத்த வேண்டும்';

  @override
  String get dashboardDueTomorrowBadge => 'நாளை செலுத்த வேண்டும்';

  @override
  String get dashboardOverdueSectionTitle => 'தாமதமானவை';

  @override
  String get dashboardOldestFirstLabel => 'பழையவை முதலில்';

  @override
  String dashboardDaysOverdueLabel(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days நாட்கள் தாமதம்',
      one: '1 நாள் தாமதம்',
    );
    return '$_temp0';
  }

  @override
  String get dashboardNewStockQuantityLabel => 'புதிய இருப்பு அளவு';

  @override
  String get actionUpdate => 'புதுப்பிக்கவும்';

  @override
  String get labelService => 'சேவை';

  @override
  String get labelProduct => 'பொருள்';

  @override
  String dashboardStockLabel(String count) {
    return 'இருப்பு: $count';
  }

  @override
  String get actionUpdateStock => 'இருப்பைப் புதுப்பிக்கவும்';

  @override
  String get paymentStatusPaid => 'செலுத்தப்பட்டது';

  @override
  String get paymentStatusPartial => 'பகுதியளவு';

  @override
  String get paymentStatusUnpaid => 'செலுத்தவில்லை';

  @override
  String get dashboardDuplicateInvoiceTitle => 'விலைப்பட்டியலை நகலெடுக்கவும்';

  @override
  String dashboardDuplicateInvoiceBody(String number, String customerName) {
    return 'விலைப்பட்டியல் #$number\n($customerName) என்பதன் நகலை இவ்வாறு உருவாக்கவும்:';
  }

  @override
  String get dashboardDeleteInvoiceTitle => 'விலைப்பட்டியலை நீக்கவும்';

  @override
  String dashboardDeleteInvoiceBody(String number) {
    return 'விலைப்பட்டியல் #$number-ஐ நீக்க விரும்புகிறீர்களா? இந்தச் செயலைத் திரும்பப் பெற முடியாது.';
  }

  @override
  String get dashboardLayoutTooltip => 'முகப்புப் பலகை தளவமைப்பு';

  @override
  String get dashboardLayoutDefaultTitle => 'இயல்புநிலை';

  @override
  String get dashboardLayoutDefaultSubtitle => 'அசல் தளவமைப்பு';

  @override
  String get dashboardLayoutClassicSubtitle =>
      'வரைபடங்கள் + முக்கிய அளவீட்டுக் கட்டம்';

  @override
  String get dashboardLayoutBentoTitle => 'பென்டோ';

  @override
  String get dashboardLayoutBentoSubtitle => 'முதன்மை வரைபடம் + அட்டைக் கட்டம்';

  @override
  String get dashboardLayoutSimpleTitle => 'எளிய ஃபீட்';

  @override
  String get dashboardLayoutSimpleSubtitle => 'எளிமையான பட்டியல் காட்சி';

  @override
  String get dashboardTotalInvoicesLabel => 'மொத்த விலைப்பட்டியல்கள்';

  @override
  String get dashboardRevenueLast6MonthsTitle => 'வருவாய் — கடந்த 6 மாதங்கள்';

  @override
  String get dashboardNoPaymentDataYetLabel =>
      'பணம் செலுத்துதல் தரவு இன்னும் இல்லை';

  @override
  String get dashboardFinancialOverviewTitle => 'நிதிநிலை மேலோட்டம்';

  @override
  String get dashboardCollectedLabel => 'வசூலிக்கப்பட்டது';

  @override
  String dashboardInvoiceCountOverdueLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'காலக்கெடு கடந்த $count விலைப்பட்டியல்கள்',
      one: 'காலக்கெடு கடந்த 1 விலைப்பட்டியல்',
    );
    return '$_temp0';
  }

  @override
  String dashboardLastNLabel(int n) {
    return 'கடைசி $n';
  }

  @override
  String get labelCustomer => 'வாடிக்கையாளர்';

  @override
  String get labelAmount => 'தொகை';

  @override
  String get dashboardZeroLeftLabel => '0 மீதம்';

  @override
  String get labelStock => 'இருப்பு';

  @override
  String get actionPay => 'செலுத்தவும்';

  @override
  String get dashboardQuickActionsTitle => 'விரைவுச் செயல்கள்';

  @override
  String get dashboardPdfActionsTooltip => 'PDF செயல்கள்';

  @override
  String get dashboardActionsTooltip => 'செயல்கள்';

  @override
  String get dashboardTopCustomersTitle => 'சிறந்த வாடிக்கையாளர்கள்';

  @override
  String get dashboardTopProductsTitle => 'சிறந்த பொருட்கள்';

  @override
  String dashboardUnitsLabel(String qty) {
    return '$qty அலகுகள்';
  }

  @override
  String get dashboardBetaBadge => 'BETA';

  @override
  String get dashboardOutOfStockSectionTitle => 'இருப்பில் இல்லை';

  @override
  String dashboardItemCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count உருப்படிகள்',
      one: '1 உருப்படி',
    );
    return '$_temp0';
  }

  @override
  String get dashboardTapToRestockLabel => 'இருப்பைச் சேர்க்கத் தட்டவும்';

  @override
  String get createInvoiceUnsavedChangesTitle => 'சேமிக்கப்படாத மாற்றங்கள்';

  @override
  String get createInvoiceUnsavedChangesMessage =>
      'இந்த விலைப்பட்டியலில் சேமிக்கப்படாத மாற்றங்கள் உள்ளன. வெளியேறும் முன் அவற்றைச் சேமிக்கவா?';

  @override
  String get createInvoiceKeepEditingButton => 'திருத்துவதைத் தொடரவும்';

  @override
  String get actionDiscard => 'கைவிடவும்';

  @override
  String createInvoiceErrorLoadingDataMessage(String e) {
    return 'தரவை ஏற்றுவதில் பிழை: $e';
  }

  @override
  String get createInvoiceInsufficientStockTitle => 'போதுமான இருப்பு இல்லை';

  @override
  String createInvoiceInsufficientStockMessage(String stock, String qty) {
    return 'இருப்பில் $stock அலகு(கள்) மட்டுமே உள்ளன. இருப்பினும் $qty சேர்க்கவா?';
  }

  @override
  String get createInvoiceAddAnywayButton => 'இருப்பினும் சேர்க்கவும்';

  @override
  String get createInvoiceOutOfStockTitle => 'இருப்பில் இல்லை';

  @override
  String createInvoiceOutOfStockMessage(String name) {
    return '$name இருப்பில் இல்லை. இருப்பினும் சேர்க்கவா?';
  }

  @override
  String get createInvoiceUnlimitedStockLabel => 'வரம்பற்ற இருப்பு';

  @override
  String createInvoiceAvailableStockLabel(String stock) {
    return 'கிடைக்கும் இருப்பு: $stock';
  }

  @override
  String get fieldDiscountLabel => 'தள்ளுபடி';

  @override
  String get fieldUnitPriceOverrideLabel => 'அலகு விலை (மாற்றுவதற்கு)';

  @override
  String get fieldExtraCostLabel => 'கூடுதல் கட்டணம் (விருப்பத்திற்குரியது)';

  @override
  String get fieldInsertAtPositionLabel => 'செருக வேண்டிய இடம்';

  @override
  String get actionAdd => 'சேர்க்கவும்';

  @override
  String get createInvoiceProductAlreadyAddedMessage =>
      'இந்தப் பொருள் ஏற்கனவே சேர்க்கப்பட்டுள்ளது';

  @override
  String get createInvoiceCustomerNameRequiredMessage =>
      'வாடிக்கையாளர் பெயரை உள்ளிடவும்';

  @override
  String get createInvoiceAtLeastOneItemRequiredMessage =>
      'குறைந்தது ஒரு உருப்படியைச் சேர்க்கவும்';

  @override
  String createInvoiceCreatedSuccessMessage(String invoiceTypeLabel) {
    return '$invoiceTypeLabel வெற்றிகரமாக உருவாக்கப்பட்டது!';
  }

  @override
  String createInvoiceErrorCreatingMessage(String e) {
    return 'விலைப்பட்டியலை உருவாக்குவதில் பிழை: $e';
  }

  @override
  String get createInvoiceEditItemTitle => 'உருப்படியைத் திருத்தவும்';

  @override
  String get createInvoiceCustomItemTitle => 'தனிப்பயன் உருப்படி';

  @override
  String get fieldItemNameLabel => 'உருப்படியின் பெயர்';

  @override
  String get fieldAliasForPdfLabel => 'மாற்றுப் பெயர் (PDF-க்கு)';

  @override
  String get fieldUnitPriceLabel => 'அலகு விலை';

  @override
  String get fieldRateLabel => 'விலை';

  @override
  String get fieldTaxRateLabel => 'வரி விகிதம் (%)';

  @override
  String get fieldPriceIncludesTaxLabel => 'விலையில் வரி அடங்கும்';

  @override
  String get createInvoicePhoneAlreadyInUseTitle =>
      'தொலைபேசி எண் ஏற்கனவே பயன்பாட்டில் உள்ளது';

  @override
  String createInvoicePhoneAlreadyInUseMessage(String ownerName) {
    return 'இந்தத் தொலைபேசி எண் \"$ownerName\" என்பவருக்கு உரியது.\n\nவேறொருவருக்கு ஏற்கனவே உள்ள தொலைபேசி எண்ணுடன் இந்த வாடிக்கையாளரைச் சேமிக்க முடியாது.';
  }

  @override
  String get actionOk => 'சரி';

  @override
  String get createInvoiceCustomerNameRequiredBeforeSavingMessage =>
      'சேமிக்கும் முன் வாடிக்கையாளர் பெயரை உள்ளிடவும்';

  @override
  String get createInvoicePhoneChangedTitle => 'தொலைபேசி எண் மாற்றப்பட்டது';

  @override
  String createInvoicePhoneChangedMessage(String name) {
    return '\"$name\" என்பவரின் தொலைபேசி எண் மாற்றப்பட்டுள்ளது.\n\nஏற்கனவே உள்ள பதிவைப் புதுப்பிக்கவா, அல்லது இந்த விவரங்களைப் புதிய வாடிக்கையாளராகச் சேமிக்கவா?';
  }

  @override
  String get createInvoiceSaveAsNewButton => 'புதிதாகச் சேமிக்கவும்';

  @override
  String get createInvoiceUpdateExistingButton => 'உள்ளதைப் புதுப்பிக்கவும்';

  @override
  String createInvoiceCustomerUpdatedMessage(String name) {
    return 'வாடிக்கையாளர் பட்டியலில் $name புதுப்பிக்கப்பட்டது';
  }

  @override
  String get createInvoiceCustomerAlreadyExistsTitle =>
      'வாடிக்கையாளர் ஏற்கனவே உள்ளார்';

  @override
  String createInvoiceCustomerAlreadyExistsMessage(String name) {
    return 'இந்தத் தொலைபேசி எண்ணுடன் \"$name\" என்ற பதிவு ஏற்கனவே சேமிக்கப்பட்டுள்ளது.\n\nஏற்கனவே உள்ள விவரங்களைப் பயன்படுத்தவா, அல்லது தற்போதைய தகவலுடன் அந்தப் பதிவைப் புதுப்பிக்கவா?';
  }

  @override
  String get createInvoiceUseExistingButton => 'உள்ளதைப் பயன்படுத்தவும்';

  @override
  String createInvoiceUsingExistingCustomerMessage(String name) {
    return 'ஏற்கனவே உள்ள வாடிக்கையாளர் பதிவு \"$name\" பயன்படுத்தப்படுகிறது';
  }

  @override
  String createInvoiceCustomerSavedMessage(String name) {
    return 'வாடிக்கையாளர் பட்டியலில் $name சேமிக்கப்பட்டது';
  }

  @override
  String get createInvoiceCustomerRecordGoneMessage =>
      'வாடிக்கையாளர் பதிவு இனி இல்லை';

  @override
  String get createInvoiceCustomerRefreshedMessage =>
      'வாடிக்கையாளர் விவரங்கள் புதுப்பிக்கப்பட்டன';

  @override
  String get fieldLabelLabel => 'தலைப்பு';

  @override
  String get hintLabelExample => 'எ.கா. போக்குவரத்துக் கட்டணம்';

  @override
  String get tooltipRemove => 'நீக்கவும்';

  @override
  String get createInvoiceAddRowButton => 'வரிசையைச் சேர்க்கவும்';

  @override
  String get fieldDiscountPerUnitLabel => 'அலகுக்கான தள்ளுபடி';

  @override
  String get createInvoiceDiscountPerUnitFormulaOn =>
      '(விலை − தள்ளுபடி) × அளவு';

  @override
  String get createInvoiceDiscountPerUnitFormulaOff =>
      '(விலை × அளவு) − தள்ளுபடி';

  @override
  String get createInvoicePrevBalanceShortLabel => 'முந்தைய மீதி';

  @override
  String get createInvoicePreviousBalanceDueLabel => 'முந்தைய நிலுவைத் தொகை';

  @override
  String get createInvoiceDueShortLabel => 'நிலுவை';

  @override
  String get createInvoiceTotalDueLabel => 'மொத்த நிலுவை';

  @override
  String createInvoiceUpdatedSuccessMessage(String invoiceTypeLabel) {
    return '$invoiceTypeLabel வெற்றிகரமாகப் புதுப்பிக்கப்பட்டது!';
  }

  @override
  String createInvoiceTotalBelowPaidMessage(String paid) {
    return 'புதிய மொத்தம், ஏற்கனவே செலுத்தப்பட்ட $paid தொகையை விடக் குறைவாக உள்ளது. முதலில் “பணம் செலுத்துதலைப் பதிவுசெய்யவும்” பகுதியில் உள்ள பதிவுகளை நீக்கவும், அல்லது மொத்தத்தை அந்தத் தொகைக்குச் சமமாகவோ அதற்கு மேலாகவோ வைக்கவும்.';
  }

  @override
  String createInvoiceErrorUpdatingMessage(String e) {
    return 'விலைப்பட்டியலைப் புதுப்பிப்பதில் பிழை: $e';
  }

  @override
  String createInvoiceCreatedHeadline(String invoiceTypeLabel) {
    return '$invoiceTypeLabel வெற்றிகரமாக உருவாக்கப்பட்டது!';
  }

  @override
  String createInvoiceIdLabel(String invoiceTypeLabel, String invoiceNumber) {
    return '$invoiceTypeLabel எண்: $invoiceNumber';
  }

  @override
  String get createInvoiceViewDetailsLabel => 'விவரங்களைப் பார்க்கவும்';

  @override
  String get createInvoicePreviewPdfLabel => 'PDF முன்னோட்டம்';

  @override
  String get createInvoicePreviewPdfTooltip =>
      'PDF முன்னோட்டம் (குறுக்குவழி: Ctrl+o)';

  @override
  String get createInvoicePrintPdfLabel => 'PDF அச்சிடவும்';

  @override
  String get createInvoicePrintPdfTooltip =>
      'PDF அச்சிடவும் (குறுக்குவழி: Ctrl+p)';

  @override
  String get actionDismiss => 'மூடவும்';

  @override
  String get createInvoiceCreateNewInvoiceButton =>
      'புதிய விலைப்பட்டியலை உருவாக்கவும் (குறுக்குவழி: Ctrl+q)';

  @override
  String createInvoiceAppBarTitle(String invoiceTypeLabel) {
    return 'புதிய $invoiceTypeLabel உருவாக்கவும்';
  }

  @override
  String get commonLoadingDataMessage => 'தரவு ஏற்றப்படுகிறது...';

  @override
  String get createInvoiceAddItemBeforeCreatingMessage =>
      'விலைப்பட்டியலை உருவாக்கும் முன் குறைந்தது ஒரு உருப்படியைச் சேர்க்கவும்.';

  @override
  String createInvoiceCreatedTitleShort(String invoiceTypeLabel) {
    return '$invoiceTypeLabel உருவாக்கப்பட்டது';
  }

  @override
  String createInvoiceEditTitle(String invoiceTypeLabel) {
    return '$invoiceTypeLabel திருத்தவும்';
  }

  @override
  String createInvoiceDuplicateAsTitle(String invoiceTypeLabel) {
    return '$invoiceTypeLabel ஆக நகலெடுக்கவும்';
  }

  @override
  String get createInvoiceNewShortLabel => 'புதியது';

  @override
  String get createInvoiceNewInvoiceShortcutLabel =>
      'புதிய விலைப்பட்டியல் (குறுக்குவழி: Ctrl+q)';

  @override
  String get createInvoiceSavingEllipsisLabel => 'சேமிக்கப்படுகிறது...';

  @override
  String get createInvoiceSaveCustomerLabel => 'வாடிக்கையாளரைச் சேமிக்கவும்';

  @override
  String get createInvoiceSelectExistingCustomerButton =>
      'பட்டியலிலிருந்து தேர்ந்தெடுக்கவும்';

  @override
  String get createInvoiceRefreshCustomerTooltip =>
      'சேமித்த வாடிக்கையாளரிடமிருந்து புதுப்பிக்கவும்';

  @override
  String get createInvoiceClearCustomerTooltip =>
      'வாடிக்கையாளர் தேர்வை அழிக்கவும்';

  @override
  String get fieldCustomerNameRequiredLabel => 'வாடிக்கையாளர் பெயர் *';

  @override
  String get fieldBusinessNameLabel => 'வணிகப் பெயர்';

  @override
  String get fieldPhoneLabel => 'தொலைபேசி';

  @override
  String get fieldGstinVatLabel => 'GSTIN / VAT';

  @override
  String get fieldEmailLabel => 'மின்னஞ்சல்';

  @override
  String get fieldAddressLabel => 'முகவரி';

  @override
  String get tooltipEditInLargerView => 'பெரிய காட்சியில் திருத்தவும்';

  @override
  String get createInvoiceChooseCustomerTitle =>
      'வாடிக்கையாளரைத் தேர்ந்தெடுக்கவும்';

  @override
  String get createInvoiceSearchCustomerLabel => 'வாடிக்கையாளரைத் தேடவும்';

  @override
  String get createInvoiceNoCustomersFoundMessage =>
      'வாடிக்கையாளர்கள் யாரும் கிடைக்கவில்லை';

  @override
  String createInvoiceDetailsHeading(String invoiceTypeLabel) {
    return '$invoiceTypeLabel விவரங்கள்';
  }

  @override
  String get createInvoiceTypeFieldLabel => 'விலைப்பட்டியல் வகை';

  @override
  String get createInvoiceTypeLockedHelperText =>
      'உருவாக்கிய பிறகு வகையை மாற்ற முடியாது';

  @override
  String get createInvoiceOrderDateLabel => 'ஆர்டர் தேதி';

  @override
  String get createInvoiceOrderTimeLabel => 'ஆர்டர் நேரம்';

  @override
  String get createInvoiceDueDateLabel => 'செலுத்த வேண்டிய தேதி';

  @override
  String get createInvoiceGstTitleLabel => 'GST தலைப்பு';

  @override
  String get createInvoiceTaxTitleLabel => 'வரித் தலைப்பு';

  @override
  String get gstTitleTaxInvoiceLabel => 'வரி விலைப்பட்டியல்';

  @override
  String get gstTitleBillOfSupplyLabel => 'விநியோகப் பில்';

  @override
  String get gstTitleInvoiceCumBillLabel => 'விலைப்பட்டியல்-கம்-விநியோகப் பில்';

  @override
  String get gstTitleCashBillLabel => 'ரொக்கப் பில்';

  @override
  String get gstTitleCreditNoteLabel => 'வரவுக் குறிப்பு';

  @override
  String get gstTitleDebitNoteLabel => 'பற்றுக் குறிப்பு';

  @override
  String get gstTitleRevisedInvoiceLabel => 'திருத்தப்பட்ட விலைப்பட்டியல்';

  @override
  String get createInvoiceSearchProductLabel =>
      'பொருள் அல்லது சேவையைத் தேடிச் சேர்க்கவும் (Ctrl+F)';

  @override
  String get createInvoiceCustomItemButton => 'தனிப்பயன் உருப்படி (Ctrl+M)';

  @override
  String get createInvoiceNoProductsFoundMessage =>
      'பொருட்கள் எதுவும் கிடைக்கவில்லை';

  @override
  String createInvoiceItemAlreadyInProductListMessage(String name) {
    return '\"$name\" ஏற்கனவே பொருள் பட்டியலில் உள்ளது';
  }

  @override
  String createInvoiceProductSavedMessage(String name) {
    return 'பொருள் பட்டியலில் $name சேமிக்கப்பட்டது';
  }

  @override
  String get createInvoiceSaveToProductListTooltip =>
      'பொருள் பட்டியலில் சேமிக்கவும்';

  @override
  String get tooltipEditItem => 'உருப்படியைத் திருத்தவும்';

  @override
  String get tooltipRemoveItem => 'உருப்படியை நீக்கவும்';

  @override
  String get createInvoiceNoItemsAddedMessage =>
      'இதுவரை உருப்படிகள் எதுவும் சேர்க்கப்படவில்லை';

  @override
  String get createInvoiceSearchHintMessage =>
      'கீழே தேடவும் அல்லது Ctrl+F அழுத்தவும்';

  @override
  String get createInvoiceDiscountFieldLabel => 'விலைப்பட்டியல் தள்ளுபடி';

  @override
  String get discountTypeAmountShortLabel => 'தொகை';

  @override
  String get createInvoiceNotesOptionalLabel =>
      'குறிப்புகள் (விருப்பத்திற்குரியது)';

  @override
  String get createInvoiceNotesHint =>
      'பணம் செலுத்தும் விதிமுறைகள், நன்றிக் குறிப்பு…';

  @override
  String get createInvoiceNotesTitle => 'குறிப்புகள்';

  @override
  String get createInvoiceHideNumberInPdfLabel =>
      'PDF-இல் விலைப்பட்டியல் எண்ணை மறைக்கவும்';

  @override
  String get createInvoiceCustomNumberLabel => 'தனிப்பயன் எண் (விருப்பம்)';

  @override
  String get createInvoiceCustomNumberHint =>
      'எ.கா. QUO-2026-014 — PDF-இல் இதுவே காட்டப்படும்';

  @override
  String get createInvoiceEnableTaxLabel => 'வரியை இயக்கவும்';

  @override
  String get createInvoiceGlobalRateTooltip => 'அனைத்துக்கும் ஒரே விகிதம்';

  @override
  String get createInvoicePerItemRateTooltip =>
      'ஒவ்வொரு உருப்படிக்கும் தனி விகிதம்';

  @override
  String get createInvoiceDefaultTaxRateLabel => 'இயல்புநிலை வரி விகிதம்';

  @override
  String get createInvoiceTaxRateFromProductMessage =>
      'ஒவ்வொரு பொருளின் வரி விகிதம்';

  @override
  String get createInvoiceInterStateLabel =>
      'மாநிலங்களுக்கிடையேயான விற்பனை (IGST)';

  @override
  String get createInvoicePaymentUpiAccountLabel => 'பணம் பெறும் UPI கணக்கு';

  @override
  String get commonNoneLabel => 'எதுவுமில்லை';

  @override
  String get createInvoiceBankAccountLabel => 'வங்கிக் கணக்கு';

  @override
  String get fieldSubtotalLabel => 'துணை மொத்தம்';

  @override
  String get createInvoiceDiscountColonLabel => 'தள்ளுபடி:';

  @override
  String get fieldTaxLabel => 'வரி';

  @override
  String get createInvoiceExtraCostFallbackLabel => 'கூடுதல் கட்டணம்';

  @override
  String createInvoiceDiscountPercentLabel(String toStringAsFixed) {
    return 'விலைப்பட்டியல் தள்ளுபடி ($toStringAsFixed%):';
  }

  @override
  String get createInvoiceInvoiceDiscountColonLabel =>
      'விலைப்பட்டியல் தள்ளுபடி:';

  @override
  String get fieldTotalLabel => 'மொத்தம்';

  @override
  String get createInvoicePreviewLabel => 'முன்னோட்டம்';

  @override
  String get createInvoicePreviewTooltip => 'முன்னோட்டம் (குறுக்குவழி: Ctrl+o)';

  @override
  String get createInvoiceDownloadLabel => 'பதிவிறக்கவும்';

  @override
  String get createInvoicePrintTooltip => 'அச்சிடவும் (குறுக்குவழி: Ctrl+p)';

  @override
  String get fieldUnitOverrideLabel => 'அலகு (மாற்றியமைக்க)';

  @override
  String get commonCustomEllipsisLabel => 'தனிப்பயன்…';

  @override
  String get fieldCustomUnitLabel => 'தனிப்பயன் அலகு';

  @override
  String get invoiceMgmtMoveToTrashTitle => 'குப்பைத் தொட்டிக்கு நகர்த்தவும்';

  @override
  String invoiceMgmtMoveToTrashBody(String number) {
    return 'விலைப்பட்டியல் #$number-ஐக் குப்பைத் தொட்டிக்கு நகர்த்தவா?';
  }

  @override
  String get invoiceMgmtMovedToTrashMessage =>
      'விலைப்பட்டியல் குப்பைத் தொட்டிக்கு நகர்த்தப்பட்டது.';

  @override
  String invoiceMgmtFailedToLoadMessage(String error) {
    return 'விலைப்பட்டியல்களை ஏற்ற முடியவில்லை: $error';
  }

  @override
  String invoiceMgmtExportToCsvTitle(String type) {
    return '$type CSV ஏற்றுமதி';
  }

  @override
  String get invoiceMgmtExportAllRecordsLabel =>
      'அனைத்துப் பதிவுகளையும் ஏற்றுமதி செய்யவும்';

  @override
  String get invoiceMgmtFilterByDateRangeLabel =>
      'அல்லது தேதி வரம்பின்படி வடிகட்டவும்:';

  @override
  String get invoiceMgmtFromDateLabel => 'தொடக்கத் தேதி';

  @override
  String get invoiceMgmtToDateLabel => 'முடிவுத் தேதி';

  @override
  String get invoiceMgmtDateRangeInvalidMessage =>
      'முடிவுத் தேதி தொடக்கத் தேதிக்குப் பிறகு இருக்க வேண்டும்.';

  @override
  String get actionExport => 'ஏற்றுமதி';

  @override
  String invoiceMgmtExportedRecordsMessage(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count பதிவுகள் ஏற்றுமதி செய்யப்பட்டன: $path',
      one: '1 பதிவு ஏற்றுமதி செய்யப்பட்டது: $path',
    );
    return '$_temp0';
  }

  @override
  String invoiceMgmtExportFailedMessage(String error) {
    return 'ஏற்றுமதி தோல்வியடைந்தது: $error';
  }

  @override
  String invoiceMgmtBulkMoveToTrashBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count விலைப்பட்டியல்களைக் குப்பைத் தொட்டிக்கு நகர்த்தவா?',
      one: '1 விலைப்பட்டியலைக் குப்பைத் தொட்டிக்கு நகர்த்தவா?',
    );
    return '$_temp0';
  }

  @override
  String invoiceMgmtBulkMovedToTrashMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count விலைப்பட்டியல்கள் குப்பைத் தொட்டிக்கு நகர்த்தப்பட்டன.',
      one: '1 விலைப்பட்டியல் குப்பைத் தொட்டிக்கு நகர்த்தப்பட்டது.',
    );
    return '$_temp0';
  }

  @override
  String invoiceMgmtBulkDeleteFailedMessage(String error) {
    return 'மொத்த நீக்கம் தோல்வியடைந்தது: $error';
  }

  @override
  String invoiceMgmtBulkExportedCsvMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count விலைப்பட்டியல்கள் CSV-ஆக ஏற்றுமதி செய்யப்பட்டன',
      one: '1 விலைப்பட்டியல் CSV-ஆக ஏற்றுமதி செய்யப்பட்டது',
    );
    return '$_temp0';
  }

  @override
  String invoiceMgmtCsvExportFailedMessage(String error) {
    return 'CSV ஏற்றுமதி தோல்வியடைந்தது: $error';
  }

  @override
  String get invoiceMgmtDownloadPdfsTitle => 'PDF-களைப் பதிவிறக்கவும்';

  @override
  String invoiceMgmtSavePdfsPromptMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PDF-களை எவ்வாறு சேமிக்க விரும்புகிறீர்கள்?',
      one: '1 PDF-ஐ எவ்வாறு சேமிக்க விரும்புகிறீர்கள்?',
    );
    return '$_temp0';
  }

  @override
  String get invoiceMgmtSaveToFolderLabel => 'கோப்புறையில் சேமிக்கவும்';

  @override
  String get invoiceMgmtSaveAsZipLabel => 'ZIP-ஆகச் சேமிக்கவும்';

  @override
  String get invoiceMgmtChooseFolderDialogTitle =>
      'PDF-களைச் சேமிக்கக் கோப்புறையைத் தேர்ந்தெடுக்கவும்';

  @override
  String get invoiceMgmtSaveZipDialogTitle => 'ZIP கோப்பைச் சேமிக்கவும்';

  @override
  String get invoiceMgmtCreatingZipLabel => 'ZIP உருவாக்கப்படுகிறது';

  @override
  String get invoiceMgmtGeneratingPdfsLabel => 'PDF-கள் உருவாக்கப்படுகின்றன';

  @override
  String invoiceMgmtProcessingPdfsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PDF-கள் செயலாக்கப்படுகின்றன...',
      one: '1 PDF செயலாக்கப்படுகிறது...',
    );
    return '$_temp0';
  }

  @override
  String invoiceMgmtSavedToMessage(String path) {
    return 'சேமிக்கப்பட்ட இடம்: $path';
  }

  @override
  String invoiceMgmtPdfExportFailedMessage(String error) {
    return 'PDF ஏற்றுமதி தோல்வியடைந்தது: $error';
  }

  @override
  String get invoiceMgmtDownloadByFilterTitle =>
      'வடிகட்டி மூலம் PDF-களைப் பதிவிறக்கவும்';

  @override
  String get invoiceMgmtByDateLabel => 'தேதியின்படி';

  @override
  String get invoiceMgmtByInvoiceNumberLabel => 'விலைப்பட்டியல் எண்ணின்படி';

  @override
  String get invoiceMgmtFromInvoiceNumberLabel => 'விலைப்பட்டியல் # முதல்';

  @override
  String get invoiceMgmtToInvoiceNumberLabel => 'விலைப்பட்டியல் # வரை';

  @override
  String get invoiceMgmtCheckCountLabel => 'எண்ணிக்கையைச் சரிபார்க்கவும்';

  @override
  String invoiceMgmtInvoicesExceedLimitMessage(int count, int limit) {
    return '$count விலைப்பட்டியல்கள் — $limit வரம்பை மீறுகிறது';
  }

  @override
  String invoiceMgmtInvoicesMatchMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count விலைப்பட்டியல்கள் பொருந்துகின்றன',
      one: '1 விலைப்பட்டியல் பொருந்துகிறது',
    );
    return '$_temp0';
  }

  @override
  String invoiceMgmtMaxPdfsPerDownloadMessage(int limit) {
    return 'ஒரு பதிவிறக்கத்தில் அதிகபட்சம் $limit PDF-கள். வடிகட்டியைச் சுருக்கவும்.';
  }

  @override
  String get invoiceMgmtNoInvoicesForFilterMessage =>
      'தேர்ந்தெடுக்கப்பட்ட வடிகட்டிக்கு விலைப்பட்டியல்கள் எதுவும் கிடைக்கவில்லை.';

  @override
  String invoiceMgmtFilterExceedsLimitMessage(int count, int limit) {
    return 'வடிகட்டியில் $count விலைப்பட்டியல்கள் உள்ளன — அதிகபட்சம் $limit.';
  }

  @override
  String get invoiceMgmtFilterInvoicesTitle => 'விலைப்பட்டியல்களை வடிகட்டவும்';

  @override
  String get invoiceMgmtHideFullyPaidLabel =>
      'முழுமையாகச் செலுத்தப்பட்ட விலைப்பட்டியல்களை மறைக்கவும்';

  @override
  String get invoiceMgmtHideDeclinedLabel =>
      'நிராகரிக்கப்பட்ட விலைப்பட்டியல்களை மறைக்கவும்';

  @override
  String get invoiceMgmtPaymentStatusLabel => 'பணம் செலுத்துதல் நிலை';

  @override
  String get invoiceMgmtDueDateLabel => 'செலுத்த வேண்டிய தேதி';

  @override
  String get invoiceMgmtInvoiceDateRangeLabel => 'விலைப்பட்டியல் தேதி வரம்பு';

  @override
  String get invoiceMgmtInvoiceNumberRangeLabel => 'விலைப்பட்டியல் எண் வரம்பு';

  @override
  String get invoiceMgmtFromHashLabel => '# முதல்';

  @override
  String get invoiceMgmtToHashLabel => '# வரை';

  @override
  String get actionReset => 'மீட்டமைக்கவும்';

  @override
  String get actionApply => 'பயன்படுத்தவும்';

  @override
  String get invoiceMgmtSortByTitle => 'இதன்படி வரிசைப்படுத்தவும்';

  @override
  String get invoiceMgmtSearchHintMessage =>
      'விலைப்பட்டியல் ஐடி அல்லது வாடிக்கையாளர் பெயரால் தேடவும்…';

  @override
  String get invoiceMgmtFilterLabel => 'வடிகட்டி';

  @override
  String get invoiceMgmtSortLabel => 'வரிசைப்படுத்தல்';

  @override
  String invoiceMgmtTotalPageStatusLabel(int total, int page, int totalPages) {
    return 'மொத்தம்: $total   ·   பக்கம் $page/$totalPages';
  }

  @override
  String invoiceMgmtSelectedCountLabel(int count) {
    return '$count தேர்ந்தெடுக்கப்பட்டது';
  }

  @override
  String get invoiceMgmtDeselectLabel => 'தேர்வை நீக்கவும்';

  @override
  String get invoiceMgmtSelectPageLabel => 'பக்கத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get invoiceMgmtMarkPaidLabel => 'செலுத்தப்பட்டதாகக் குறிக்கவும்';

  @override
  String get invoiceMgmtCsvLabel => 'CSV';

  @override
  String get invoiceMgmtPdfsLabel => 'PDF-கள்';

  @override
  String get invoiceMgmtTrashLabel => 'குப்பைத் தொட்டி';

  @override
  String get actionApplyPayment => 'பணம் செலுத்துதலைப் பதிவு செய்யவும்';

  @override
  String get invoiceMgmtMoreActionsTooltip => 'மேலும் செயல்கள்';

  @override
  String get invoiceMgmtColSlNo => 'வ.எண்.';

  @override
  String get invoiceMgmtColInvoiceCustomer => 'விலைப்பட்டியல் / வாடிக்கையாளர்';

  @override
  String get invoiceMgmtColTitle => 'தலைப்பு';

  @override
  String get invoiceMgmtColDate => 'தேதி';

  @override
  String get invoiceMgmtColItems => 'உருப்படிகள்';

  @override
  String get invoiceMgmtColStatus => 'நிலை';

  @override
  String get invoiceMgmtColOutstanding => 'நிலுவை';

  @override
  String get invoiceMgmtColActions => 'செயல்கள்';

  @override
  String get invoiceMgmtRowsPerPageLabel => 'ஒரு பக்கத்திற்கு வரிசைகள்:';

  @override
  String get actionPrevious => 'முந்தையது';

  @override
  String invoiceMgmtPageOfLabel(int page, int totalPages) {
    return 'பக்கம் $page / $totalPages';
  }

  @override
  String invoiceMgmtNoResultsForQueryMessage(String query) {
    return '\"$query\"-க்கு முடிவுகள் எதுவும் இல்லை';
  }

  @override
  String invoiceMgmtNoFilteredTypeFoundMessage(String type) {
    return '$type எதுவும் கிடைக்கவில்லை';
  }

  @override
  String invoiceMgmtCreateFirstTypeMessage(String type) {
    return 'உங்கள் முதல் $type-ஐ உருவாக்கவும்; அது இங்கே தோன்றும்';
  }

  @override
  String get invoiceMgmtTryAdjustingFiltersMessage =>
      'தேடல் அல்லது வடிகட்டிகளை மாற்றி முயலவும்';

  @override
  String get invoiceMgmtDownloadByRangeTooltip =>
      'தேதி அல்லது விலைப்பட்டியல் வரம்பின்படி PDF-களைப் பதிவிறக்கவும்';

  @override
  String get invoiceMgmtExportAllCsvTooltip =>
      'அனைத்தையும் CSV-ஆக ஏற்றுமதி செய்யவும்';

  @override
  String get invoiceMgmtDownloadByRangeMenuLabel =>
      'வரம்பின்படி PDF-களைப் பதிவிறக்கவும்';

  @override
  String invoiceMgmtManagementTitle(String type) {
    return '$type மேலாண்மை';
  }

  @override
  String invoiceMgmtNewDocumentButton(String type) {
    return 'புதிய $type';
  }

  @override
  String get invoiceMgmtConvertToInvoiceAction => 'விலைப்பட்டியலாக மாற்றவும்';

  @override
  String get invoiceMgmtConvertAgainTitle => 'மீண்டும் மாற்றவா?';

  @override
  String invoiceMgmtConvertAgainBody(String number) {
    return 'விலைப்புள்ளி $number ஏற்கனவே விலைப்பட்டியலாக மாற்றப்பட்டுள்ளது. இதிலிருந்து மற்றொரு விலைப்பட்டியலை உருவாக்கவா?';
  }

  @override
  String get invoiceMgmtMarkAsSent => 'அனுப்பப்பட்டதாகக் குறிக்கவும்';

  @override
  String get invoiceMgmtMarkAsAccepted => 'ஏற்கப்பட்டதாகக் குறிக்கவும்';

  @override
  String get invoiceMgmtMarkAsDeclined => 'நிராகரிக்கப்பட்டதாகக் குறிக்கவும்';

  @override
  String get quotationStatusDraft => 'வரைவு';

  @override
  String get quotationStatusSent => 'அனுப்பப்பட்டது';

  @override
  String get quotationStatusAccepted => 'ஏற்கப்பட்டது';

  @override
  String get quotationStatusDeclined => 'நிராகரிக்கப்பட்டது';

  @override
  String get quotationStatusConverted => 'மாற்றப்பட்டது';

  @override
  String get invoiceMgmtDeclineInvoiceTitle => 'விலைப்பட்டியலை நிராகரிக்கவா?';

  @override
  String invoiceMgmtDeclineInvoiceBody(String number) {
    return 'இது விலைப்பட்டியல் #$number-ஐ நிராகரிக்கப்பட்டதாகக் குறித்து, அதன் உருப்படிகளை இருப்புக்குத் திருப்பும். இதைத் திரும்பப் பெற முடியாது.';
  }

  @override
  String invoiceMgmtDeclineHasPaymentsMessage(String number) {
    return 'விலைப்பட்டியல் #$number-இல் பணம் செலுத்திய பதிவுகள் உள்ளன. நிராகரிக்கும் முன் “பணம் செலுத்துதலைப் பதிவு செய்யவும்” பகுதியில் அவற்றை நீக்கவும்.';
  }

  @override
  String get invoiceMgmtDeclinedSuccessMessage =>
      'விலைப்பட்டியல் நிராகரிக்கப்பட்டது, இருப்பு மீட்டெடுக்கப்பட்டது.';

  @override
  String get invoiceStatusDeclinedBadge => 'நிராகரிக்கப்பட்டது';

  @override
  String get createInvoiceConvertTitle => 'விலைப்பட்டியலாக மாற்றவும்';

  @override
  String createInvoiceConvertedSuccessMessage(String invoiceNumber) {
    return 'விலைப்பட்டியல் #$invoiceNumber-ஆக மாற்றப்பட்டது';
  }

  @override
  String get createInvoiceTrashQuotationAction =>
      'விலைப்புள்ளியைக் குப்பைத் தொட்டிக்கு நகர்த்தவும்';

  @override
  String get createInvoiceQuotationTrashedMessage =>
      'விலைப்புள்ளி குப்பைத் தொட்டிக்கு நகர்த்தப்பட்டது';

  @override
  String get invoiceMgmtOverdueBadge => 'தாமதமானது';

  @override
  String get invoiceMgmtTodayBadge => 'இன்று';

  @override
  String get invoiceMgmtTrashIsEmptyLabel => 'குப்பைத் தொட்டி காலியாக உள்ளது';

  @override
  String get actionRestore => 'மீட்டெடுக்கவும்';

  @override
  String get invoiceMgmtPermanentlyDeleteTitle => 'நிரந்தரமாக நீக்கவும்';

  @override
  String invoiceMgmtPermanentlyDeleteBody(String number) {
    return 'விலைப்பட்டியல் #$number-ஐ நிரந்தரமாக நீக்கவா? இதைத் திரும்பப் பெற முடியாது.';
  }

  @override
  String get invoiceMgmtInvoiceRestoredMessage =>
      'விலைப்பட்டியல் மீட்டெடுக்கப்பட்டது.';

  @override
  String get invoiceMgmtAnyDateLabel => 'ஏதேனும்';

  @override
  String get invoiceMgmtStatusAllLabel => 'அனைத்தும்';

  @override
  String get invoiceMgmtDueAllLabel => 'அனைத்து நிலுவைகள்';

  @override
  String get invoiceMgmtDueTodayLabel => 'இன்று நிலுவை';

  @override
  String get invoiceMgmtDueWeekLabel => 'இந்த வாரம் நிலுவை';

  @override
  String get invoiceMgmtDueMonthLabel => 'இந்த மாதம் நிலுவை';

  @override
  String get invoiceMgmtSortRecentlyAdded => 'சமீபத்தில் சேர்க்கப்பட்டவை';

  @override
  String get invoiceMgmtSortOldestAdded => 'முதலில் சேர்க்கப்பட்டவை';

  @override
  String get invoiceMgmtSortDateNewest =>
      'விலைப்பட்டியல் தேதி (புதியது முதலில்)';

  @override
  String get invoiceMgmtSortDateOldest =>
      'விலைப்பட்டியல் தேதி (பழையது முதலில்)';

  @override
  String get invoiceMgmtSortCustomerAZ => 'வாடிக்கையாளர் பெயர் (A–Z)';

  @override
  String get invoiceMgmtSortCustomerZA => 'வாடிக்கையாளர் பெயர் (Z–A)';

  @override
  String get invoiceMgmtMarkAsPaidTitle => 'செலுத்தப்பட்டதாகக் குறிக்கவும்';

  @override
  String invoiceMgmtMarkAsPaidBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count விலைப்பட்டியல்களை முழுமையாகச் செலுத்தப்பட்டதாகக் குறிக்கவா?',
      one: '1 விலைப்பட்டியலை முழுமையாகச் செலுத்தப்பட்டதாகக் குறிக்கவா?',
    );
    return '$_temp0';
  }

  @override
  String invoiceMgmtAlreadyPaidNoteMessage(int count) {
    return '\n($count ஏற்கனவே செலுத்தப்பட்டவை — தவிர்க்கப்படும்)';
  }

  @override
  String get invoiceMgmtAllAlreadyPaidMessage =>
      'தேர்ந்தெடுக்கப்பட்ட அனைத்து விலைப்பட்டியல்களும் ஏற்கனவே முழுமையாகச் செலுத்தப்பட்டுவிட்டன.';

  @override
  String invoiceMgmtMarkedAsPaidMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count விலைப்பட்டியல்கள் செலுத்தப்பட்டதாகக் குறிக்கப்பட்டன.',
      one: '1 விலைப்பட்டியல் செலுத்தப்பட்டதாகக் குறிக்கப்பட்டது.',
    );
    return '$_temp0';
  }

  @override
  String invoiceMgmtMarkAsPaidFailedMessage(String error) {
    return 'செலுத்தப்பட்டதாகக் குறிக்க முடியவில்லை: $error';
  }

  @override
  String get fieldNameLabel => 'பெயர்';

  @override
  String get customerMgmtEditCustomerTitle => 'வாடிக்கையாளரைத் திருத்தவும்';

  @override
  String get customerMgmtViewCustomerTitle => 'வாடிக்கையாளரைப் பார்க்கவும்';

  @override
  String fieldTaxVatNumberLabel(String taxWord) {
    return '$taxWord / VAT எண்';
  }

  @override
  String get customerMgmtUpdatedMessage =>
      'வாடிக்கையாளர் விவரங்கள் வெற்றிகரமாகப் புதுப்பிக்கப்பட்டன!';

  @override
  String fieldRequiredMessage(String field) {
    return '$field உள்ளிடவும்';
  }

  @override
  String get customerMgmtConfirmDeleteTitle => 'நீக்குவதை உறுதிப்படுத்தவும்';

  @override
  String customerMgmtDeleteConfirmBody(String name) {
    return '\"$name\" என்பதை நிச்சயமாக நீக்க விரும்புகிறீர்களா?';
  }

  @override
  String get customerMgmtDeletedMessage =>
      'வாடிக்கையாளர் வெற்றிகரமாக நீக்கப்பட்டார்!';

  @override
  String get customerMgmtSaveSampleCsvDialogTitle =>
      'மாதிரி CSV-ஐச் சேமிக்கவும்';

  @override
  String get customerMgmtSampleSavedMessage =>
      'மாதிரி CSV வெற்றிகரமாகச் சேமிக்கப்பட்டது!';

  @override
  String customerMgmtErrorSavingSampleMessage(String error) {
    return 'மாதிரியைச் சேமிப்பதில் பிழை: $error';
  }

  @override
  String get customerMgmtImportCsvDialogTitle =>
      'CSV-இலிருந்து வாடிக்கையாளர்களை இறக்குமதி செய்யவும்';

  @override
  String get customerMgmtCsvFormatInstructionMessage =>
      'உங்கள் CSV கோப்பு பின்வரும் நெடுவரிசைத் தலைப்புகளை அவற்றின் சரியான எழுத்துக்கூட்டலுடன் பயன்படுத்த வேண்டும் (எந்த வரிசையிலும் இருக்கலாம்):';

  @override
  String get customerMgmtCsvColColumnHeader => 'நெடுவரிசை';

  @override
  String get customerMgmtCsvColRequiredHeader => 'கட்டாயம்';

  @override
  String get customerMgmtCsvColDescriptionHeader => 'விளக்கம்';

  @override
  String get commonYesLabel => 'ஆம்';

  @override
  String get commonNoLabel => 'இல்லை';

  @override
  String get customerMgmtCsvDescName => 'வாடிக்கையாளரின் முழுப் பெயர்';

  @override
  String get customerMgmtCsvDescEmail => 'மின்னஞ்சல் முகவரி';

  @override
  String get customerMgmtCsvDescPhone => 'தொலைபேசி எண்';

  @override
  String get customerMgmtCsvDescAddress => 'முழு முகவரி';

  @override
  String get customerMgmtCsvDescBusinessName => 'நிறுவனம் / வணிகத்தின் பெயர்';

  @override
  String get customerMgmtCsvDescTaxNumber => 'வரி / VAT / GSTIN எண்';

  @override
  String customerMgmtCsvMaxRowsNote(int max) {
    return 'ஒரு இறக்குமதிக்கு அதிகபட்சம் $max வரிசைகள்.';
  }

  @override
  String get customerMgmtCsvDuplicatesNote =>
      'மின்னஞ்சல் அல்லது தொலைபேசி எண் மூலம் நகல்கள் கண்டறியப்படும். ஒவ்வொன்றையும் மேலெழுதவா அல்லது தவிர்க்கவா என்று கேட்கப்படும்.';

  @override
  String get customerMgmtCsvMissingNameNote =>
      'பெயர் இல்லாத வரிசைகள் தவிர்க்கப்பட்டு, இறுதியில் தெரிவிக்கப்படும்.';

  @override
  String get customerMgmtCsvEncodingNote =>
      'UTF-8 குறியாக்கம் பரிந்துரைக்கப்படுகிறது. Excel BOM தானாகவே கையாளப்படும்.';

  @override
  String get customerMgmtDownloadSampleCsvButton =>
      'மாதிரி CSV-ஐப் பதிவிறக்கவும்';

  @override
  String get customerMgmtChooseFileButton => 'கோப்பைத் தேர்ந்தெடுக்கவும்';

  @override
  String get customerMgmtSelectCsvDialogTitle =>
      'வாடிக்கையாளர் CSV-ஐத் தேர்ந்தெடுக்கவும்';

  @override
  String get customerMgmtCsvEmptyMessage => 'CSV கோப்பு காலியாக உள்ளது.';

  @override
  String get customerMgmtCsvMissingNameColumnMessage =>
      'CSV-இல் தேவையான நெடுவரிசை இல்லை: \"name\"';

  @override
  String customerMgmtUnknownColumnMessage(String col, String expected) {
    return 'அறியப்படாத நெடுவரிசை \"$col\". எதிர்பார்க்கப்படுபவை: $expected';
  }

  @override
  String customerMgmtCsvTooManyRowsMessage(int count, int max) {
    return 'CSV-இல் $count வரிசைகள் உள்ளன. அதிகபட்சம் $max வரிசைகள் மட்டுமே அனுமதிக்கப்படும். கோப்பைப் பல பகுதிகளாகப் பிரிக்கவும்.';
  }

  @override
  String get customerMgmtImportingTitle =>
      'வாடிக்கையாளர்கள் இறக்குமதி செய்யப்படுகின்றனர்';

  @override
  String customerMgmtValidatingRowsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'நகல்கள் கண்டறியப்பட்டு $count வரிசைகள் சரிபார்க்கப்படுகின்றன...',
      one: 'நகல்கள் கண்டறியப்பட்டு 1 வரிசை சரிபார்க்கப்படுகிறது...',
    );
    return '$_temp0';
  }

  @override
  String customerMgmtRowMissingNameMessage(int n) {
    return 'வரிசை $n: பெயர் இல்லை — தவிர்க்கப்பட்டது';
  }

  @override
  String customerMgmtCsvReadErrorMessage(String error) {
    return 'CSV-ஐப் படிப்பதில் பிழை: $error';
  }

  @override
  String get customerMgmtImportPreviewTitle => 'இறக்குமதி முன்னோட்டம்';

  @override
  String customerMgmtNewCountChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count புதியவை',
      one: '1 புதியது',
    );
    return '$_temp0';
  }

  @override
  String customerMgmtDuplicatesCountChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count நகல்கள்',
      one: '1 நகல்',
    );
    return '$_temp0';
  }

  @override
  String customerMgmtErrorsCountChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count பிழைகள்',
      one: '1 பிழை',
    );
    return '$_temp0';
  }

  @override
  String get customerMgmtDuplicatesMatchedLabel =>
      'நகல்கள் (மின்னஞ்சல் அல்லது தொலைபேசி எண் மூலம் பொருந்தியவை):';

  @override
  String get customerMgmtOverwriteAllButton => 'அனைத்தையும் மேலெழுதவும்';

  @override
  String get customerMgmtSkipAllButton => 'அனைத்தையும் தவிர்க்கவும்';

  @override
  String get customerMgmtOverwriteLabel => 'மேலெழுதவும்';

  @override
  String get customerMgmtSkippedRowsLabel =>
      'தவிர்க்கப்பட்ட வரிசைகள் (பிழைகள்):';

  @override
  String customerMgmtErrorBulletLabel(String error) {
    return '• $error';
  }

  @override
  String customerMgmtWillImportMessage(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total வாடிக்கையாளர்கள் இறக்குமதி செய்யப்படுவார்கள்.',
      one: '1 வாடிக்கையாளர் இறக்குமதி செய்யப்படுவார்.',
    );
    return '$_temp0';
  }

  @override
  String customerMgmtImportCountButton(int total) {
    return '$total இறக்குமதி செய்யவும்';
  }

  @override
  String get customerMgmtDeleteAllTitle =>
      'அனைத்து வாடிக்கையாளர்களையும் நீக்கவும்';

  @override
  String get customerMgmtNoCustomersToDeleteMessage =>
      'நீக்குவதற்கு வாடிக்கையாளர்கள் இல்லை.';

  @override
  String customerMgmtDeleteAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'இது அனைத்து $count வாடிக்கையாளர்களையும் நிரந்தரமாக நீக்கும். ஏற்கனவே உள்ள விலைப்பட்டியல்கள் பாதிக்கப்படாது. இந்தச் செயலைத் திரும்பப்பெற முடியாது.',
      one:
          'இது 1 வாடிக்கையாளரை நிரந்தரமாக நீக்கும். ஏற்கனவே உள்ள விலைப்பட்டியல்கள் பாதிக்கப்படாது. இந்தச் செயலைத் திரும்பப்பெற முடியாது.',
    );
    return '$_temp0';
  }

  @override
  String get customerMgmtDeleteAllButton => 'அனைத்தையும் நீக்கவும்';

  @override
  String get customerMgmtAllDeletedMessage =>
      'அனைத்து வாடிக்கையாளர்களும் நீக்கப்பட்டனர்.';

  @override
  String customerMgmtDeleteAllErrorMessage(String error) {
    return 'வாடிக்கையாளர்களை நீக்குவதில் பிழை: $error';
  }

  @override
  String get customerMgmtSaveCsvDialogTitle =>
      'வாடிக்கையாளர் CSV-ஐச் சேமிக்கவும்';

  @override
  String get customerMgmtCsvExportedMessage =>
      'CSV வெற்றிகரமாக ஏற்றுமதி செய்யப்பட்டது!';

  @override
  String customerMgmtCsvExportErrorMessage(String error) {
    return 'CSV-ஐ ஏற்றுமதி செய்வதில் பிழை: $error';
  }

  @override
  String get customerMgmtSavePdfDialogTitle =>
      'வாடிக்கையாளர் PDF-ஐச் சேமிக்கவும்';

  @override
  String get customerMgmtPdfExportedMessage =>
      'PDF வெற்றிகரமாக ஏற்றுமதி செய்யப்பட்டது!';

  @override
  String customerMgmtPdfExportErrorMessage(String error) {
    return 'PDF-ஐ ஏற்றுமதி செய்வதில் பிழை: $error';
  }

  @override
  String get customerMgmtTotalCustomersLabel => 'மொத்த வாடிக்கையாளர்கள்';

  @override
  String get customerMgmtAllCustomersSubtitle => 'அனைத்து வாடிக்கையாளர்கள்';

  @override
  String get customerMgmtBusinessesLabel => 'வணிகங்கள்';

  @override
  String get customerMgmtRegisteredBusinessesSubtitle =>
      'பதிவு செய்யப்பட்ட வணிகங்கள்';

  @override
  String get customerMgmtIndividualsLabel => 'தனிநபர்கள்';

  @override
  String get customerMgmtIndividualCustomersSubtitle =>
      'தனிநபர் வாடிக்கையாளர்கள்';

  @override
  String customerMgmtTaxRegisteredLabel(String taxWord) {
    return '$taxWord பதிவு பெற்றவர்கள்';
  }

  @override
  String customerMgmtWithTaxNumberSubtitle(String taxWord) {
    return '$taxWord எண்ணுடன்';
  }

  @override
  String customerMgmtWithoutTaxLabel(String taxWord) {
    return '$taxWord இல்லாதவர்கள்';
  }

  @override
  String get customerMgmtTitle => 'வாடிக்கையாளர் மேலாண்மை';

  @override
  String get customerMgmtSubtitle =>
      'உங்கள் வாடிக்கையாளர்களையும் தொடர்பு விவரங்களையும் நிர்வகிக்கவும்';

  @override
  String get actionImport => 'இறக்குமதி';

  @override
  String get customerMgmtExportPdfMenuLabel => 'PDF ஏற்றுமதி';

  @override
  String get customerMgmtNewCustomerButton => 'புதிய வாடிக்கையாளர்';

  @override
  String get customerMgmtSortNameAZ => 'பெயர் A-Z';

  @override
  String get customerMgmtSortNameZA => 'பெயர் Z-A';

  @override
  String get customerMgmtSortIdOldest => 'ID (பழையது முதலில்)';

  @override
  String get customerMgmtSortIdNewest => 'ID (புதியது முதலில்)';

  @override
  String get customerMgmtSortOutstandingHighLow => 'நிலுவை (அதிகம்-குறைவு)';

  @override
  String get customerMgmtSortOutstandingLowHigh => 'நிலுவை (குறைவு-அதிகம்)';

  @override
  String get customerMgmtWithOutstandingLabel => 'நிலுவையுடன்';

  @override
  String customerMgmtSearchHint(String taxWord) {
    return 'பெயர், வணிகம், தொலைபேசி, $taxWord, மின்னஞ்சல் மூலம் வாடிக்கையாளர்களைத் தேடவும்…';
  }

  @override
  String customerMgmtAllTaxStatusesLabel(String taxWord) {
    return 'அனைத்து $taxWord நிலைகளும்';
  }

  @override
  String customerMgmtTaxRegisteredLowerLabel(String taxWord) {
    return '$taxWord பதிவு பெற்றவர்';
  }

  @override
  String customerMgmtSortWithLabel(String label) {
    return 'வரிசைப்படுத்தல்: $label';
  }

  @override
  String get customerMgmtColumnsLabel => 'நெடுவரிசைகள்';

  @override
  String customerMgmtTaxVatNoColumnLabel(String taxWord) {
    return '$taxWord / VAT எண்';
  }

  @override
  String get customerMgmtHideStatCardsTooltip =>
      'புள்ளிவிவர அட்டைகளை மறைக்கவும்';

  @override
  String get customerMgmtShowStatCardsTooltip =>
      'புள்ளிவிவர அட்டைகளைக் காட்டவும்';

  @override
  String customerMgmtTabChipLabel(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get customerMgmtColSlNo => 'வ.எண்.';

  @override
  String get customerMgmtColNameBusiness => 'பெயர் / வணிகம்';

  @override
  String get customerMgmtColPhone => 'தொலைபேசி';

  @override
  String get customerMgmtColEmail => 'மின்னஞ்சல்';

  @override
  String customerMgmtColTaxVatNo(String taxWord) {
    return '$taxWord / VAT எண்';
  }

  @override
  String get customerMgmtColAddress => 'முகவரி';

  @override
  String get customerMgmtColActions => 'செயல்கள்';

  @override
  String get customerMgmtViewStatementTooltip =>
      'கணக்கு அறிக்கையைப் பார்க்கவும் (அறிக்கைகளில்)';

  @override
  String customerMgmtShowingRangeLabel(int from, int to, int total) {
    return '$total வாடிக்கையாளர்களில் $from முதல் $to வரை காட்டப்படுகிறது';
  }

  @override
  String get customerMgmtRowsPerPageLabel => 'ஒரு பக்கத்திற்கு வரிசைகள்';

  @override
  String customerMgmtOfTotalPagesLabel(int totalPages) {
    return '/ $totalPages';
  }

  @override
  String get customerMgmtAddAnotherLabel =>
      'சேமித்த பின் மேலும் ஒன்றைச் சேர்க்கவும்';

  @override
  String get customerMgmtSaveCustomerButton => 'வாடிக்கையாளரைச் சேமிக்கவும்';

  @override
  String get customerMgmtAddFirstCustomerSubtitle =>
      'தொடங்க உங்கள் முதல் வாடிக்கையாளரைச் சேர்க்கவும்';

  @override
  String get customerMgmtTryAdjustingSearchSubtitle =>
      'உங்கள் தேடலை மாற்றி முயற்சிக்கவும்';

  @override
  String customerMgmtLoadErrorMessage(String error) {
    return 'வாடிக்கையாளர்களை ஏற்றுவதில் பிழை: $error';
  }

  @override
  String get customerMgmtAddedMessage =>
      'வாடிக்கையாளர் வெற்றிகரமாகச் சேர்க்கப்பட்டார்!';

  @override
  String customerMgmtSaveErrorMessage(String error) {
    return 'வாடிக்கையாளரைச் சேமிப்பதில் பிழை: $error';
  }

  @override
  String customerMgmtImportedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count வாடிக்கையாளர்கள் வெற்றிகரமாக இறக்குமதி செய்யப்பட்டனர்!',
      one: '1 வாடிக்கையாளர் வெற்றிகரமாக இறக்குமதி செய்யப்பட்டார்!',
    );
    return '$_temp0';
  }

  @override
  String customerMgmtImportErrorMessage(String error) {
    return 'இறக்குமதிப் பிழை: $error';
  }

  @override
  String get taxWordGst => 'GST';

  @override
  String get taxWordTax => 'வரி';

  @override
  String get commonMoreLabel => 'மேலும்';

  @override
  String get productMgmtSellingAtLossTitle => 'நட்டத்தில் விற்பனை';

  @override
  String productMgmtSellingAtLossMessage(String purchase, String sale) {
    return 'கொள்முதல் விலை ($purchase) விற்பனை விலையை ($sale) விட அதிகம். இருந்தாலும் சேமிக்கவா?';
  }

  @override
  String get actionSaveAnyway => 'இருப்பினும் சேமிக்கவும்';

  @override
  String get productMgmtAdvancedInformationLabel => 'மேம்பட்ட தகவல்';

  @override
  String get productMgmtStorageLocationLabel => 'சேமிப்பு இடம்';

  @override
  String get productMgmtContainerNumberLabel => 'கொள்கலன் எண்';

  @override
  String get productMgmtBatchNumberLabel => 'தொகுதி எண்';

  @override
  String get productMgmtExpiryDateLabel => 'காலாவதி தேதி';

  @override
  String get productMgmtManufactureDateLabel => 'உற்பத்தி தேதி';

  @override
  String get productMgmtManufactureNameLabel => 'உற்பத்தியாளர் பெயர்';

  @override
  String get productMgmtSupplierNameLabel => 'விநியோகஸ்தர் பெயர்';

  @override
  String get productMgmtSkuCodeLabel => 'SKU குறியீடு';

  @override
  String get productMgmtNotesLabel => 'குறிப்புகள்';

  @override
  String get fieldEnterValidPriceMessage => 'சரியான விலையை உள்ளிடவும்';

  @override
  String get fieldEnterValidStockMessage => 'சரியான இருப்பை உள்ளிடவும்';

  @override
  String get fieldTaxRangeMessage => 'வரி 0-100 வரம்பிற்குள் இருக்க வேண்டும்';

  @override
  String get productMgmtImportProductsCsvTitle =>
      'CSV-இலிருந்து பொருட்களை இறக்குமதி செய்யவும்';

  @override
  String get productMgmtCsvDescName => 'பொருளின் பெயர்';

  @override
  String get productMgmtCsvDescPrice => 'அலகு விலை (எண்)';

  @override
  String get productMgmtCsvDescHsnCode => 'HSN / SAC குறியீடு';

  @override
  String get productMgmtCsvDescDescription => 'சுருக்கமான விளக்கம்';

  @override
  String get productMgmtCsvDescTaxRate => 'வரி % (0–100), இயல்புநிலை 0';

  @override
  String get productMgmtCsvDescStock => 'இருப்பு அளவு, இயல்புநிலை 0';

  @override
  String get productMgmtCsvDescType =>
      '\"product\" அல்லது \"service\", இயல்புநிலை product';

  @override
  String get productMgmtCsvDescDefaultDiscount =>
      'நிலையான தள்ளுபடித் தொகை (நாணய மதிப்பில்), இயல்புநிலை 0';

  @override
  String get productMgmtCsvDescPurchasePrice =>
      'கொள்முதல் விலை (எண்), இயல்புநிலை 0';

  @override
  String get productMgmtCsvDescAliasName => 'PDF-களுக்கான உள்ளூர் மொழிப் பெயர்';

  @override
  String get productMgmtCsvDescUnit =>
      'அளவீட்டு அலகு (எ.கா. kg, bag, pcs), இயல்புநிலை pcs';

  @override
  String get productMgmtCsvDescUnlimitedStock =>
      'வரம்பற்ற இருப்புக்கு 1/true, இயல்புநிலை 0';

  @override
  String get productMgmtCsvDescPriceIncludesTax =>
      'விலையில் வரி ஏற்கனவே சேர்க்கப்பட்டிருந்தால் 1/true, இயல்புநிலை 0';

  @override
  String get productMgmtCsvDescStorageLocation =>
      'சேமிப்பு இடம் (கிடங்கு/அடுக்கு)';

  @override
  String get productMgmtCsvDescContainerNumber => 'கொள்கலன்/பெட்டி எண்';

  @override
  String get productMgmtCsvDescBatchNumber => 'தொகுதி/லாட் எண்';

  @override
  String get productMgmtCsvDescExpiryDate => 'காலாவதி தேதி';

  @override
  String get productMgmtCsvDescManufactureDate => 'உற்பத்தி தேதி';

  @override
  String get productMgmtCsvDescManufactureName => 'உற்பத்தியாளர் பெயர்';

  @override
  String get productMgmtCsvDescSupplierName => 'விநியோகஸ்தர் பெயர்';

  @override
  String get productMgmtCsvDescSkuCode => 'SKU குறியீடு';

  @override
  String get productMgmtCsvDescNotes => 'விருப்பப்படி எழுதும் குறிப்புகள்';

  @override
  String get productMgmtCsvDuplicateNote =>
      'பொருளின் பெயரைக் கொண்டு நகல்கள் கண்டறியப்படும் (பெரிய/சிறிய எழுத்து வேறுபாடு பொருட்டல்ல). ஒவ்வொன்றையும் மேலெழுதவா அல்லது தவிர்க்கவா என்று கேட்கப்படும்.';

  @override
  String get productMgmtCsvMissingRequiredNote =>
      'பெயர் அல்லது விலை இல்லாத வரிசைகள் தவிர்க்கப்பட்டு தெரிவிக்கப்படும்.';

  @override
  String get productMgmtSelectCsvDialogTitle =>
      'பொருள் CSV கோப்பைத் தேர்ந்தெடுக்கவும்';

  @override
  String get productMgmtCsvMissingPriceColumnMessage =>
      'தேவையான நெடுவரிசை CSV-இல் இல்லை: \"price\"';

  @override
  String productMgmtRowInvalidPriceMessage(int n, String price) {
    return 'வரிசை $n: தவறான விலை \"$price\" — தவிர்க்கப்பட்டது';
  }

  @override
  String get productMgmtImportingTitle =>
      'பொருட்கள் இறக்குமதி செய்யப்படுகின்றன';

  @override
  String get productMgmtDuplicatesMatchedByNameLabel =>
      'நகல்கள் (பெயர் மூலம் பொருந்தியவை):';

  @override
  String productMgmtWillImportMessage(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total பொருட்கள் இறக்குமதி செய்யப்படும்.',
      one: '1 பொருள் இறக்குமதி செய்யப்படும்.',
    );
    return '$_temp0';
  }

  @override
  String get productMgmtNoProductsToDeleteMessage =>
      'நீக்குவதற்குப் பொருட்கள் இல்லை.';

  @override
  String get productMgmtDeleteAllTitle => 'அனைத்துப் பொருட்களையும் நீக்கவும்';

  @override
  String productMgmtDeleteAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'இது அனைத்து $count பொருட்களையும் நிரந்தரமாக நீக்கும். ஏற்கனவே உள்ள விலைப்பட்டியல்கள் பாதிக்கப்படாது. இதைத் திரும்பப் பெற முடியாது.',
      one:
          'இது 1 பொருளையும் நிரந்தரமாக நீக்கும். ஏற்கனவே உள்ள விலைப்பட்டியல்கள் பாதிக்கப்படாது. இதைத் திரும்பப் பெற முடியாது.',
    );
    return '$_temp0';
  }

  @override
  String get productMgmtAllDeletedMessage =>
      'அனைத்துப் பொருட்களும் நீக்கப்பட்டன.';

  @override
  String productMgmtDeleteAllErrorMessage(String error) {
    return 'பொருட்களை நீக்குவதில் பிழை: $error';
  }

  @override
  String get productMgmtSaveProductsCsvDialogTitle =>
      'பொருட்கள் CSV கோப்பைச் சேமிக்கவும்';

  @override
  String get productMgmtExportToPdfTitle => 'PDF-க்கு ஏற்றுமதி செய்யவும்';

  @override
  String productMgmtExportPdfChoiceMessage(int pageSize, int allCount) {
    return 'தற்போதைய பக்கத்தை ($pageSize பொருட்கள்) அல்லது அனைத்து $allCount பொருட்களையும் ஏற்றுமதி செய்யவா?';
  }

  @override
  String get productMgmtCurrentPageLabel => 'தற்போதைய பக்கம்';

  @override
  String get productMgmtAllProductsLabel => 'அனைத்துப் பொருட்கள்';

  @override
  String get productMgmtSaveProductsPdfDialogTitle =>
      'பொருட்கள் PDF கோப்பைச் சேமிக்கவும்';

  @override
  String get productMgmtTitle => 'பொருள் மேலாண்மை';

  @override
  String get productMgmtSubtitle =>
      'உங்கள் பொருட்கள் மற்றும் சேவைகளை நிர்வகிக்கவும்';

  @override
  String get productMgmtNewProductButton => 'புதிய பொருள்';

  @override
  String get productMgmtSearchHint =>
      'பெயர், மாற்றுப் பெயர், HSN/SAC, SKU மூலம் பொருட்களைத் தேடவும்…';

  @override
  String get productMgmtFilterByStockStatusTooltip =>
      'இருப்பு நிலை மூலம் வடிகட்டவும்';

  @override
  String get productMgmtAllStockLevelsLabel => 'அனைத்து இருப்பு நிலைகள்';

  @override
  String get productMgmtLowStockLabel => 'குறைந்த இருப்பு';

  @override
  String get productMgmtLowStockTabLabel => 'குறைந்த இருப்பு';

  @override
  String get productMgmtOutOfStockLabel => 'இருப்பு இல்லை';

  @override
  String get productMgmtOutOfStockTabLabel => 'இருப்பு இல்லை';

  @override
  String get productMgmtExpiredLabel => 'காலாவதியானது';

  @override
  String get productMgmtSortPriceLowHigh => 'விலை: குறைவு-அதிகம்';

  @override
  String get productMgmtSortPriceHighLow => 'விலை: அதிகம்-குறைவு';

  @override
  String get productMgmtSortStockLowHigh => 'இருப்பு: குறைவு-அதிகம்';

  @override
  String get productMgmtSortStockHighLow => 'இருப்பு: அதிகம்-குறைவு';

  @override
  String get productMgmtServicesTabLabel => 'சேவைகள்';

  @override
  String get productMgmtColSlNo => 'வ.எண்.';

  @override
  String get productMgmtColNameAlias => 'பெயர் / மாற்றுப் பெயர்';

  @override
  String get productMgmtColHsnSac => 'HSN / SAC';

  @override
  String get productMgmtColPrice => 'விலை';

  @override
  String get productMgmtColPurchase => 'கொள்முதல்';

  @override
  String get productMgmtColStock => 'இருப்பு';

  @override
  String get productMgmtColTaxPercent => 'வரி %';

  @override
  String get productMgmtColExpiryDate => 'காலாவதி தேதி';

  @override
  String get productMgmtCustomizeColumnsLabel =>
      'பொருள் நெடுவரிசைகளைத் தனிப்பயனாக்கவும்';

  @override
  String get productMgmtShowColumnsLabel => 'நெடுவரிசைகளைக் காட்டவும்';

  @override
  String productMgmtShowColumnsMaxHint(int max) {
    return '$max நெடுவரிசைகள் வரை காட்டலாம்';
  }

  @override
  String productMgmtShowingRangeLabel(int from, int to, int total) {
    return '$total பொருட்களில் $from முதல் $to வரை காட்டப்படுகிறது';
  }

  @override
  String get productMgmtAddFirstProductSubtitle =>
      'தொடங்க உங்கள் முதல் பொருளைச் சேர்க்கவும்';

  @override
  String get productMgmtColumnsBannerTitle =>
      'புதியது: பொருள் புலங்களைத் தனிப்பயனாக்கவும்';

  @override
  String get productMgmtColumnsBannerSubtitle =>
      'எளிமையான பட்டியலுக்கு எந்தப் புலங்கள் காட்டப்பட வேண்டும் என்பதைத் தேர்வு செய்யவும். அமைப்புகள் > பொருள் விவரங்களைத் தனிப்பயனாக்கவும்.';

  @override
  String get productMgmtConfigureAction => 'அமைக்கவும்';

  @override
  String productMgmtAddNewItemTitle(String type) {
    return 'புதிய $type சேர்க்கவும்';
  }

  @override
  String get productMgmtEnterProductDetailsSubtitle =>
      'பொருள் விவரங்களை உள்ளிடவும்';

  @override
  String get productMgmtSaveProductButton => 'பொருளைச் சேமிக்கவும்';

  @override
  String get productMgmtAliasNameLabel =>
      'மாற்றுப் பெயர் (விலைப்பட்டியல் PDF-க்கு)';

  @override
  String get productMgmtAliasHelperText =>
      'விருப்பத் தேர்வாக உள்ளிடும் உள்ளூர் மொழிப் பெயர். PDF விலைப்பட்டியல்களில் மட்டுமே பயன்படுத்தப்படும்.';

  @override
  String get productMgmtDescriptionLabel => 'விளக்கம்';

  @override
  String get productMgmtHsnSacLabel => 'HSN/SAC';

  @override
  String get productMgmtSalePriceLabel => 'விற்பனை விலை';

  @override
  String get productMgmtPurchasePriceLabel => 'கொள்முதல் விலை';

  @override
  String get productMgmtDefaultDiscountLabel => 'இயல்புநிலை தள்ளுபடி';

  @override
  String get productMgmtTaxPercentLabel => 'வரி (%)';

  @override
  String get productMgmtPerItemTaxModeOnlyLabel =>
      'உருப்படி வாரி வரி முறையில் மட்டும்';

  @override
  String get productMgmtSectionGeneral => 'பொது';

  @override
  String get productMgmtSectionPricing => 'விலை நிர்ணயம்';

  @override
  String get productMgmtSectionInventory => 'இருப்பு';

  @override
  String get productMgmtUnlimitedStockLabel => 'வரம்பற்ற இருப்பு';

  @override
  String get productMgmtTrackInfiniteStockSubtitle =>
      'இந்தப் பொருளுக்கு வரம்பற்ற இருப்பைக் கண்காணிக்கவும்';

  @override
  String get productMgmtTipEnableCustomFieldsMessage =>
      'உதவிக்குறிப்பு: கூடுதல் விவரங்களைச் சேர்க்க நெடுவரிசைகளில் தனிப்பயன் புலங்களை இயக்கவும்.';

  @override
  String get productMgmtEditProductTitle => 'பொருளைத் திருத்தவும்';

  @override
  String get productMgmtViewProductTitle => 'பொருளைப் பார்க்கவும்';

  @override
  String get productMgmtUpdateProductDetailsSubtitle =>
      'பொருள் விவரங்களைப் புதுப்பிக்கவும்';

  @override
  String get productMgmtProductDetailsSubtitle => 'பொருள் விவரங்கள்';

  @override
  String get productMgmtUpdatedMessage =>
      'பொருள்/சேவை வெற்றிகரமாகப் புதுப்பிக்கப்பட்டது!';

  @override
  String get productMgmtDeleteProductButton => 'பொருளை நீக்கவும்';

  @override
  String get productMgmtSaveChangesButton => 'மாற்றங்களைச் சேமிக்கவும்';

  @override
  String get fieldUnitLabel => 'அலகு';

  @override
  String get productMgmtAddedMessage => 'பொருள் வெற்றிகரமாகச் சேர்க்கப்பட்டது!';

  @override
  String productMgmtAddErrorMessage(String error) {
    return 'பொருளைச் சேர்ப்பதில் பிழை: $error';
  }

  @override
  String productMgmtLoadErrorMessage(String error) {
    return 'பொருட்களை ஏற்றுவதில் பிழை: $error';
  }

  @override
  String get productMgmtDeletedMessage => 'பொருள் வெற்றிகரமாக நீக்கப்பட்டது!';

  @override
  String productMgmtImportedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count பொருட்கள் வெற்றிகரமாக இறக்குமதி செய்யப்பட்டன!',
      one: '1 பொருள் வெற்றிகரமாக இறக்குமதி செய்யப்பட்டது!',
    );
    return '$_temp0';
  }

  @override
  String get productMgmtTotalItemsSubtitle => 'மொத்த உருப்படிகள்';

  @override
  String get productMgmtTangibleProductsSubtitle => 'பௌதிகப் பொருட்கள்';

  @override
  String get productMgmtNonTangibleServicesSubtitle => 'பௌதிகமற்ற சேவைகள்';

  @override
  String get productMgmtNeedAttentionSubtitle => 'கவனம் தேவை';

  @override
  String get productMgmtProductNameLabel => 'பொருளின் பெயர்';

  @override
  String get productMgmtPriceLabel => 'விலை';

  @override
  String get actionClear => 'அழிக்கவும்';

  @override
  String get reportsAboutConversionRateTitle => 'மாற்று விகிதம் பற்றி';

  @override
  String reportsAgedReceivablesTitle(int count) {
    return 'காலவாரி பெறத்தக்கவை ($count)';
  }

  @override
  String get reportsAllCurrenciesLabel => 'அனைத்து நாணயங்கள்';

  @override
  String get reportsArAgingSummaryTitle => 'பெறத்தக்கவை காலவாரி சுருக்கம்';

  @override
  String get reportsAvgInvoiceValueLabel => 'சராசரி விலைப்பட்டியல் மதிப்பு';

  @override
  String get reportsBalanceColumnLabel => 'மீதித் தொகை';

  @override
  String get reportsBilledLabel => 'பில் தொகை';

  @override
  String get reportsBucket0to30Label => '0–30 நாட்கள்';

  @override
  String get reportsBucket31to60Label => '31–60 நாட்கள்';

  @override
  String get reportsBucket61to90Label => '61–90 நாட்கள்';

  @override
  String get reportsBucket90PlusLabel => '90+ நாட்கள்';

  @override
  String get reportsBucketLabel => 'காலப் பிரிவு';

  @override
  String get reportsClosingLabel => 'இறுதி மீதி';

  @override
  String get reportsCogsColumnLabel => 'விற்ற பொருட்களின் செலவு (COGS)';

  @override
  String get reportsConversionRateExplanationBody =>
      'மாற்று விகிதம் = உருவாக்கிய விலைப்பட்டியல்கள் ÷ வழங்கிய விலைப்புள்ளிகள் × 100.\n100%-க்கு மேல் விகிதம் இருந்தால், தேர்ந்தெடுத்த காலத்தில் விலைப்புள்ளிகளை விட அதிக விலைப்பட்டியல்கள் உருவாக்கப்பட்டன என்று பொருள் (முன் விலைப்புள்ளி இல்லாமல் நேரடியாக விலைப்பட்டியல் உருவாக்கும்போது இது வழக்கமானது).\n\nகுறிப்பு: இது காலகட்ட அளவிலான விகிதம்; தனிப்பட்ட விலைப்புள்ளி-விலைப்பட்டியல் மாற்றத்தைக் கண்காணிப்பது அல்ல.';

  @override
  String get reportsConversionRateLabel => 'மாற்று விகிதம்';

  @override
  String get reportsCreditColumnLabel => 'வரவு';

  @override
  String get reportsCurrencySectionLabel => 'நாணயம்';

  @override
  String get reportsCurrentBucketLabel => 'நடப்பு';

  @override
  String reportsCurrentSelectedCurrencyLabel(String currency) {
    return 'தற்போது தேர்ந்தெடுத்த நாணயம் ($currency)';
  }

  @override
  String get reportsCustomRangeLabel => 'தனிப்பயன் வரம்பு';

  @override
  String get reportsDailySalesProfitTitle => 'தினசரி விற்பனை மற்றும் லாபம்';

  @override
  String reportsDaysCountLabel(int d) {
    return '$d நாட்கள்';
  }

  @override
  String get reportsDaysOverdueLabel => 'தாமத நாட்கள்';

  @override
  String get reportsDebitColumnLabel => 'பற்று';

  @override
  String get reportsDiscountGivenColumnLabel => 'வழங்கிய தள்ளுபடி';

  @override
  String get reportsExportCsvLabel => 'CSV ஏற்றுமதி';

  @override
  String reportsFilteredToDateLabel(String date) {
    return '$date தேதிக்கு வடிகட்டப்பட்டது';
  }

  @override
  String reportsInvoiceCountInPeriodLabel(int count, String scope) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'காலத்தில் $countString விலைப்பட்டியல்கள் · $scope',
      one: 'காலத்தில் 1 விலைப்பட்டியல் · $scope',
    );
    return '$_temp0';
  }

  @override
  String get reportsInvoiceIdLabel => 'விலைப்பட்டியல் ஐடி';

  @override
  String get reportsInvoicedLabel => 'விலைப்பட்டியல் தொகை';

  @override
  String get reportsInvoicesColumnLabel => 'விலைப்பட்டியல்கள்';

  @override
  String get reportsInvoicesInPeriodLabel => 'காலத்தில் உள்ள விலைப்பட்டியல்கள்';

  @override
  String reportsLabelWithCountLabel(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get reportsMarginColumnLabel => 'லாப வரம்பு';

  @override
  String get reportsMaxRangeOneYearMessage =>
      'அதிகபட்ச வரம்பு 1 ஆண்டு. முடிவுத் தேதி சரிசெய்யப்பட்டது.';

  @override
  String get reportsMaxRangeThirtyOneDaysMessage =>
      'அதிகபட்ச வரம்பு 31 நாட்கள். முடிவுத் தேதி சரிசெய்யப்பட்டது.';

  @override
  String reportsMissingCostBannerMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'இந்தக் காலத்தில் விற்கப்பட்ட $count உருப்படிகளுக்குக் கொள்முதல் விலை அமைக்கப்படவில்லை — பொருளில் கொள்முதல் விலையைச் சேர்க்கும் வரை அந்த உருப்படிகளுக்கான லாபம்/லாப வரம்பு குறைவாகக் காட்டப்படும்.',
      one:
          'இந்தக் காலத்தில் விற்கப்பட்ட 1 உருப்படிக்குக் கொள்முதல் விலை அமைக்கப்படவில்லை — பொருளில் கொள்முதல் விலையைச் சேர்க்கும் வரை அந்த உருப்படிக்கான லாபம்/லாப வரம்பு குறைவாகக் காட்டப்படும்.',
    );
    return '$_temp0';
  }

  @override
  String get reportsMonthYearLabel => 'மாதம் & ஆண்டு';

  @override
  String get reportsMonthlyRevenueTrendTitle => 'மாதாந்திர வருவாய்ப் போக்கு';

  @override
  String get reportsMonthlyBreakdownTitle => 'மாதவாரி விவரம்';

  @override
  String get reportsMonthColumnLabel => 'மாதம்';

  @override
  String get reportsTotalRowLabel => 'மொத்தம்';

  @override
  String get reportsNavDailyReportLabel => 'தினசரி அறிக்கை';

  @override
  String get reportsNavInventoryLabel => 'இருப்பு';

  @override
  String get reportsNavInvoiceStatusLabel => 'விலைப்பட்டியல் நிலை';

  @override
  String get reportsNavReceivablesLabel => 'நிலுவைகள்';

  @override
  String get reportsNavRevenueLabel => 'வருவாய்';

  @override
  String get reportsNavTaxLabel => 'வரி';

  @override
  String get reportsInventoryBlockedValueLabel => 'இருப்பில் முடங்கிய மதிப்பு';

  @override
  String get reportsInventoryPotentialSaleValueLabel =>
      'எதிர்பார்க்கப்படும் விற்பனை மதிப்பு';

  @override
  String get reportsInventoryLockedProfitLabel => 'இருப்பில் முடங்கிய லாபம்';

  @override
  String get reportsInventoryTotalUnitsLabel => 'மொத்த அலகுகள்';

  @override
  String get reportsInventoryProductCountLabel => 'கண்காணிக்கப்படும் பொருட்கள்';

  @override
  String get reportsInventoryBreakdownTitle => 'பொருள் வாரியான விவரம்';

  @override
  String get reportsNoInventoryDataMessage => 'இருப்புத் தரவு இல்லை';

  @override
  String get reportsInventoryProductColumnLabel => 'பொருள்';

  @override
  String get reportsInventoryStockColumnLabel => 'இருப்பு';

  @override
  String get reportsInventoryPurchasePriceColumnLabel => 'கொள்முதல் விலை';

  @override
  String get reportsInventoryStockValueColumnLabel => 'இருப்பு மதிப்பு';

  @override
  String get reportsInventorySaleValueColumnLabel => 'விற்பனை மதிப்பு';

  @override
  String reportsInventoryExcludedBannerMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count உருப்படிகள் இருப்பு மதிப்பில் சேர்க்கப்படவில்லை — அவை சேவைகள் அல்லது வரம்பற்ற இருப்பு இயக்கப்பட்டவை.',
      one:
          '1 உருப்படி இருப்பு மதிப்பில் சேர்க்கப்படவில்லை — அது ஒரு சேவை அல்லது அதில் வரம்பற்ற இருப்பு இயக்கப்பட்டுள்ளது.',
    );
    return '$_temp0';
  }

  @override
  String get reportsNoCustomerDataMessage =>
      'இந்தக் காலத்தில் வாடிக்கையாளர் தரவு இல்லை';

  @override
  String get reportsNoCustomersMatchSearchMessage =>
      'இந்தத் தேடலுக்குப் பொருந்தும் வாடிக்கையாளர்கள் இல்லை';

  @override
  String get reportsNoCustomersWithInvoicesMessage =>
      'விலைப்பட்டியல்கள் உள்ள வாடிக்கையாளர்கள் இல்லை';

  @override
  String get reportsNoDueDateLabel => 'செலுத்த வேண்டிய தேதி இல்லை';

  @override
  String get reportsNoInvoiceDataMessage =>
      'இந்தக் காலத்தில் விலைப்பட்டியல் தரவு இல்லை';

  @override
  String get reportsNoInvoicesInPeriodMessage =>
      'இந்தக் காலத்தில் விலைப்பட்டியல்கள் இல்லை';

  @override
  String get reportsNoInvoicesMatchFilterMessage =>
      'இந்த வடிகட்டிக்குப் பொருந்தும் விலைப்பட்டியல்கள் இல்லை';

  @override
  String get reportsNoOutstandingInvoicesMessage =>
      'நிலுவையில் உள்ள விலைப்பட்டியல்கள் இல்லை';

  @override
  String get reportsNoProductDataMessage =>
      'இந்தக் காலத்தில் பொருள் தரவு இல்லை';

  @override
  String get reportsNoSalesInPeriodMessage => 'இந்தக் காலத்தில் விற்பனை இல்லை';

  @override
  String get reportsNoStatementActivityMessage =>
      'இந்த வாடிக்கையாளருக்குக் கணக்குப் பரிவர்த்தனைகள் இல்லை';

  @override
  String get reportsNoTaxableItemsMessage =>
      'இந்தக் காலத்தில் வரிக்குட்பட்ட உருப்படிகள் இல்லை';

  @override
  String get reportsNoTransactionsMessage =>
      'இந்தக் காலத்தில் பரிவர்த்தனைகள் இல்லை';

  @override
  String get reportsOpeningLabel => 'தொடக்க மீதி';

  @override
  String get reportsOverviewLabel => 'மேலோட்டம்';

  @override
  String get reportsPaymentStatusBreakdownTitle =>
      'பணம் செலுத்துதல் நிலை விவரம்';

  @override
  String get reportsPeriodSectionLabel => 'காலம்';

  @override
  String get reportsPresetLast30DaysLabel => 'கடந்த 30 நாட்கள்';

  @override
  String get reportsPresetLast3MonthsLabel => 'கடந்த 3 மாதங்கள்';

  @override
  String get reportsPresetLast6MonthsLabel => 'கடந்த 6 மாதங்கள்';

  @override
  String get reportsPresetLastFYLabel => 'கடந்த நிதியாண்டு';

  @override
  String get reportsPresetThisFYLabel => 'இந்த நிதியாண்டு';

  @override
  String get reportsPresetThisYearLabel => 'இந்த ஆண்டு';

  @override
  String get reportsProductServiceColumnLabel => 'பொருள் / சேவை';

  @override
  String get reportsProfitLabel => 'லாபம்';

  @override
  String get reportsQuotationsIssuedLabel => 'வழங்கிய விலைப்புள்ளிகள்';

  @override
  String get reportsRankByProfitLabel => 'தரவரிசை: லாபம்';

  @override
  String get reportsRankByRevenueLabel => 'தரவரிசை: வருவாய்';

  @override
  String get reportsReferenceColumnLabel => 'குறிப்பு எண்';

  @override
  String get reportsSalesColumnLabel => 'விற்பனை';

  @override
  String get reportsSaveCsvReportTitle => 'CSV அறிக்கையைச் சேமிக்கவும்';

  @override
  String get reportsSavePdfReportTitle => 'PDF அறிக்கையைச் சேமிக்கவும்';

  @override
  String reportsSavedAtMessage(String path) {
    return 'சேமிக்கப்பட்டது: $path';
  }

  @override
  String get reportsSelectCustomerTitle => 'வாடிக்கையாளரைத் தேர்ந்தெடுக்கவும்';

  @override
  String get reportsSelectDailyRangeMaxDaysHelpText =>
      'தேதி அல்லது தேதி வரம்பைத் தேர்ந்தெடுக்கவும் (அதிகபட்சம் 31 நாட்கள்)';

  @override
  String get reportsSelectDateRangeMaxYearHelpText =>
      'தேதி வரம்பைத் தேர்ந்தெடுக்கவும் (அதிகபட்சம் 1 ஆண்டு)';

  @override
  String get reportsShareLabel => 'பகிரவும்';

  @override
  String reportsShowingInvoicesDatedLabel(String range) {
    return '$range தேதியிட்ட விலைப்பட்டியல்கள் காட்டப்படுகின்றன';
  }

  @override
  String reportsShowingRangeLabel(int start, int end, int total) {
    return '$total இல் $start – $end';
  }

  @override
  String get reportsSlColumnLabel => 'வ.எண்';

  @override
  String get reportsStatementsLabel => 'கணக்கு அறிக்கைகள்';

  @override
  String get reportsTaxCollectedByRateTitle => 'விகிதப்படி வரி';

  @override
  String get reportsTaxCollectedLabel => 'வரி';

  @override
  String get reportsTaxableAmountLabel => 'வரிக்குட்பட்ட தொகை';

  @override
  String get reportsGrossAmountLabel => 'மொத்தத் தொகை';

  @override
  String get reportsTaxAccrualNote =>
      'இந்தக் காலத்தில் தேதியிடப்பட்ட விலைப்பட்டியல்கள் மற்றும் ரசீதுகளுக்கு விதிக்கப்பட்ட வரி — பணம் செலுத்தப்படுவதற்கு முன்பே, தேதி அடிப்படையில் கணக்கிடப்படுகிறது.';

  @override
  String get reportsTaxRateBucketsLabel => 'வரி விகிதப் பிரிவுகள்';

  @override
  String get reportsTodayLabel => 'இன்று';

  @override
  String reportsTopCustomersByRevenueTitle(int count) {
    return 'வருவாய் அடிப்படையில் முதல் $count வாடிக்கையாளர்கள்';
  }

  @override
  String reportsTopProductsByMetricTitle(int count, String metric) {
    return '$metric அடிப்படையில் முதல் $count பொருட்கள் / சேவைகள்';
  }

  @override
  String get reportsTotalBilledLabel => 'மொத்த பில் தொகை';

  @override
  String get reportsTotalCollectedLabel => 'மொத்த வசூல்';

  @override
  String reportsTotalInvoicesCountLabel(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'மொத்தம் $countString விலைப்பட்டியல்கள்',
      one: 'மொத்தம் 1 விலைப்பட்டியல்',
    );
    return '$_temp0';
  }

  @override
  String get reportsTotalInvoicesLabel => 'மொத்த விலைப்பட்டியல்கள்';

  @override
  String get reportsRealizedProfitLabel => 'வசூலான லாபம்';

  @override
  String get reportsTotalProfitLabel => 'மொத்த லாபம்';

  @override
  String get reportsTotalTaxCollectedLabel => 'விதிக்கப்பட்ட மொத்த வரி';

  @override
  String get reportsTypeColumnLabel => 'வகை';

  @override
  String get reportsUnitsSoldColumnLabel => 'விற்ற அலகுகள்';

  @override
  String userMgmtLoadErrorMessage(String error) {
    return 'பயனர்களை ஏற்றுவதில் பிழை: $error';
  }

  @override
  String get userMgmtAddedMessage => 'பயனர் வெற்றிகரமாகச் சேர்க்கப்பட்டார்';

  @override
  String get userMgmtUpdatedMessage =>
      'பயனர் வெற்றிகரமாகப் புதுப்பிக்கப்பட்டார்';

  @override
  String userMgmtSaveErrorMessage(String error) {
    return 'பயனரைச் சேமிப்பதில் பிழை: $error';
  }

  @override
  String get userMgmtChangePasswordTitle => 'கடவுச்சொல்லை மாற்றவும்';

  @override
  String userMgmtUserColonLabel(String username) {
    return 'பயனர்: $username';
  }

  @override
  String get userMgmtCurrentPasswordLabel => 'தற்போதைய கடவுச்சொல்';

  @override
  String get userMgmtCurrentPasswordRequiredMessage =>
      'தற்போதைய கடவுச்சொல் அவசியம்';

  @override
  String get userMgmtNewPasswordLabel => 'புதிய கடவுச்சொல்';

  @override
  String get userMgmtNewPasswordRequiredMessage => 'புதிய கடவுச்சொல் அவசியம்';

  @override
  String get userMgmtPasswordMinLengthMessage =>
      'கடவுச்சொல் குறைந்தது 6 எழுத்துகளாவது இருக்க வேண்டும்';

  @override
  String get userMgmtConfirmNewPasswordLabel =>
      'புதிய கடவுச்சொல்லை உறுதிப்படுத்தவும்';

  @override
  String get userMgmtConfirmPasswordRequiredMessage =>
      'உங்கள் கடவுச்சொல்லை உறுதிப்படுத்தவும்';

  @override
  String get userMgmtPasswordsDoNotMatchMessage =>
      'கடவுச்சொற்கள் பொருந்தவில்லை';

  @override
  String get userMgmtPasswordChangedMessage =>
      'கடவுச்சொல் வெற்றிகரமாக மாற்றப்பட்டது';

  @override
  String get userMgmtCurrentPasswordIncorrectMessage =>
      'தற்போதைய கடவுச்சொல் தவறானது';

  @override
  String get userMgmtDeleteUserTitle => 'பயனரை நீக்கவும்';

  @override
  String get userMgmtDeleteUserConfirmLabel =>
      'இந்தப் பயனரை உறுதியாக நீக்க விரும்புகிறீர்களா:';

  @override
  String get userMgmtActionCannotBeUndoneMessage =>
      'இந்தச் செயலைத் திரும்பப் பெற முடியாது.';

  @override
  String get userMgmtDeletedMessage => 'பயனர் வெற்றிகரமாக நீக்கப்பட்டார்';

  @override
  String get userMgmtCantDeleteOwnAccountMessage =>
      'உங்கள் சொந்தக் கணக்கை நீக்க முடியாது';

  @override
  String get userMgmtCantDemoteLastAdminMessage =>
      'ஒரே நிர்வாகியின் பங்கை மாற்ற முடியாது';

  @override
  String get userMgmtCantChangeOwnRoleMessage =>
      'உங்கள் சொந்தப் பங்கை மாற்ற முடியாது';

  @override
  String get userMgmtUsernameTakenMessage =>
      'அந்தப் பயனர்பெயர் ஏற்கெனவே பயன்பாட்டில் உள்ளது';

  @override
  String get userMgmtDeleteSelectedTitle => 'தேர்ந்தெடுத்த பயனர்களை நீக்கவா?';

  @override
  String userMgmtBulkDeleteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'இது $count பயனர்களை நிரந்தரமாக நீக்கும். இந்தச் செயலைத் திரும்பப் பெற முடியாது.',
      one:
          'இது 1 பயனரை நிரந்தரமாக நீக்கும். இந்தச் செயலைத் திரும்பப் பெற முடியாது.',
    );
    return '$_temp0';
  }

  @override
  String get userMgmtOwnAccountSkippedMessage =>
      'தேர்வில் உங்கள் சொந்தக் கணக்கும் உள்ளது, அது தவிர்க்கப்படும்.';

  @override
  String userMgmtBulkDeletedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count பயனர்கள் நீக்கப்பட்டனர்',
      one: '1 பயனர் நீக்கப்பட்டார்',
    );
    return '$_temp0';
  }

  @override
  String userMgmtBulkDeleteErrorMessage(String error) {
    return 'பயனர்களை நீக்குவதில் பிழை: $error';
  }

  @override
  String get userMgmtTitle => 'பயனர் மேலாண்மை';

  @override
  String get userMgmtSubtitle =>
      'பயன்பாட்டுப் பயனர்களையும் அணுகல் அனுமதிகளையும் நிர்வகிக்கவும்';

  @override
  String get userMgmtAddUserButton => 'பயனரைச் சேர்க்கவும்';

  @override
  String get userMgmtSearchHint =>
      'பெயர் அல்லது பங்கு மூலம் பயனர்களைத் தேடவும்…';

  @override
  String get userMgmtFilterByRoleTooltip => 'பங்கு வாரியாக வடிகட்டவும்';

  @override
  String get userMgmtAllRolesLabel => 'அனைத்துப் பங்குகள்';

  @override
  String get userMgmtAllLabel => 'அனைத்தும்';

  @override
  String userMgmtRoleColonLabel(String role) {
    return 'பங்கு: $role';
  }

  @override
  String get userMgmtColUser => 'பயனர்';

  @override
  String get userMgmtColRole => 'பங்கு';

  @override
  String get userMgmtYouBadgeLabel => 'நீங்கள்';

  @override
  String get userMgmtDeleteSelectedMenuLabel => 'தேர்ந்தெடுத்தவற்றை நீக்கவும்';

  @override
  String get userMgmtBulkActionsTooltip => 'மொத்தச் செயல்கள்';

  @override
  String get userMgmtBulkActionsLabel => 'மொத்தச் செயல்கள்';

  @override
  String userMgmtShowingRangeLabel(int from, int to, int total) {
    return '$total பயனர்களில் $from முதல் $to வரை காட்டப்படுகிறது';
  }

  @override
  String get userMgmtNoUsersFoundMessage => 'பயனர்கள் யாரும் இல்லை';

  @override
  String get userMgmtAddNewUserTitle => 'புதிய பயனரைச் சேர்க்கவும்';

  @override
  String get userMgmtEditUserTitle => 'பயனரைத் திருத்தவும்';

  @override
  String get userMgmtUsernameRequiredLabel => 'பயனர்பெயர் *';

  @override
  String get userMgmtEnterUsernameHint => 'பயனர்பெயரை உள்ளிடவும்';

  @override
  String get userMgmtUsernameRequiredMessage => 'பயனர்பெயர் அவசியம்';

  @override
  String get userMgmtUsernameMinLengthMessage =>
      'பயனர்பெயர் குறைந்தது 3 எழுத்துகளாக இருக்க வேண்டும்';

  @override
  String get userMgmtPasswordRequiredLabel => 'கடவுச்சொல் *';

  @override
  String get userMgmtEnterPasswordHint => 'கடவுச்சொல்லை உள்ளிடவும்';

  @override
  String get userMgmtPasswordRequiredMessage => 'கடவுச்சொல் அவசியம்';

  @override
  String get userMgmtMinimum6CharsMessage => 'குறைந்தது 6 எழுத்துகள்';

  @override
  String get userMgmtRoleRequiredLabel => 'பங்கு *';

  @override
  String get userMgmtRoleRequiredMessage => 'பங்கு அவசியம்';

  @override
  String get userMgmtSaveUserButton => 'பயனரைச் சேமிக்கவும்';

  @override
  String get userMgmtThisIsYourAccountMessage => 'இது உங்கள் கணக்கு';

  @override
  String get invoiceSettingsAppBarTitle => 'விலைப்பட்டியல் அமைப்புகள்';

  @override
  String get invoiceSettingsSavedMessage =>
      'விலைப்பட்டியல் அமைப்புகள் வெற்றிகரமாகச் சேமிக்கப்பட்டன!';

  @override
  String get invoiceSettingsSignatureTooLargeMessage =>
      'கையொப்பப் படம் 2 MB-க்குக் குறைவாக இருக்க வேண்டும்.';

  @override
  String get invoiceSettingsWatermarkTooLargeMessage =>
      'வாட்டர்மார்க் படம் 2 MB-க்குக் குறைவாக இருக்க வேண்டும்.';

  @override
  String get invoiceSettingsSectionGeneral => 'பொது';

  @override
  String get invoiceSettingsSectionBranding => 'நிறுவன அடையாளம்';

  @override
  String get invoiceSettingsSectionTax => 'வரி & GST';

  @override
  String get invoiceSettingsSectionItems => 'விலைப்பட்டியல் உருப்படிகள்';

  @override
  String get invoiceSettingsSectionCustomer => 'வாடிக்கையாளர் விவரங்கள்';

  @override
  String get invoiceSettingsSectionColumns => 'விலைப்பட்டியல் நெடுவரிசைகள்';

  @override
  String get invoiceSettingsColumnsSectionHint =>
      'விலைப்பட்டியல் PDF உருப்படி அட்டவணையில் எந்த நெடுவரிசைகள் தோன்ற வேண்டும் என்பதைத் தேர்ந்தெடுக்கவும். உருப்படிப் பெயர், விலை மற்றும் மொத்தம் எப்போதும் காட்டப்படும்.';

  @override
  String get invoiceSettingsShowSlNoLabel => 'வ.எண். நெடுவரிசை';

  @override
  String get invoiceSettingsShowSlNoSubtitle =>
      'A4/Letter விலைப்பட்டியல்களில் வரிசை எண் நெடுவரிசையை அச்சிடவும்';

  @override
  String get invoiceSettingsColumnHsnLabel => 'HSN/SAC நெடுவரிசை';

  @override
  String get invoiceSettingsColumnHsnSubtitle =>
      'HSN/SAC குறியீடு நெடுவரிசையை அச்சிடவும் (\"GST புலங்களைக் காட்டவும்\" அமைப்புடன் இணைந்தது)';

  @override
  String get invoiceSettingsColumnTaxLabel => 'வரி நெடுவரிசையைக் காட்டவும்';

  @override
  String get invoiceSettingsColumnTaxSubtitle =>
      'ஒவ்வொரு உருப்படிக்கும் வரி % மற்றும் தொகையைக் காட்டவும் (பொது வரி மற்றும் உருப்படி வாரி வரி இரண்டிற்கும்)';

  @override
  String get invoiceSettingsSplitCgstSgstLabel =>
      'CGST / SGST எனப் பிரிக்கவும்';

  @override
  String get invoiceSettingsSplitCgstSgstSubtitle =>
      'வரியை CGST/SGST ஆகவோ, மாநிலங்களுக்கிடையேயான விற்பனைக்கு IGST ஆகவோ பிரிக்கவும் (இந்திய GST)';

  @override
  String get invoiceSettingsColumnRequiredSubtitle => 'எப்போதும் காட்டப்படும்';

  @override
  String get invoiceSettingsColumnItemNameLabel => 'உருப்படிப் பெயர் நெடுவரிசை';

  @override
  String get invoiceSettingsColumnPriceLabel => 'விலை நெடுவரிசை';

  @override
  String get invoiceSettingsColumnTotalLabel => 'மொத்தம் நெடுவரிசை';

  @override
  String get invoiceSettingsCustomerSectionHint =>
      'விலைப்பட்டியல் PDF மற்றும் தெர்மல் ரசீதுகளில் எந்த வாடிக்கையாளர் விவரங்கள் அச்சாக வேண்டும் என்பதைத் தேர்ந்தெடுக்கவும். ஒரு புலம் இயக்கப்பட்டிருந்து, வாடிக்கையாளருக்கு அதற்கான மதிப்பு இருந்தால் மட்டுமே காட்டப்படும். வாடிக்கையாளர் பெயர் எப்போதும் காட்டப்படும்.';

  @override
  String get invoiceSettingsShowCustomerBusinessNameLabel =>
      'வணிகப் பெயரைக் காட்டவும்';

  @override
  String get invoiceSettingsShowCustomerBusinessNameSubtitle =>
      'வாடிக்கையாளரின் பெயருக்குக் கீழே அவரது வணிகப் பெயரை அச்சிடவும்';

  @override
  String get invoiceSettingsShowCustomerAddressLabel => 'முகவரியைக் காட்டவும்';

  @override
  String get invoiceSettingsShowCustomerAddressSubtitle =>
      'பில் பெறுபவர் பகுதியில் வாடிக்கையாளரின் முகவரியை அச்சிடவும்';

  @override
  String get invoiceSettingsShowCustomerPhoneLabel => 'தொலைபேசியைக் காட்டவும்';

  @override
  String get invoiceSettingsShowCustomerPhoneSubtitle =>
      'வாடிக்கையாளரின் தொலைபேசி எண்ணை அச்சிடவும்';

  @override
  String get invoiceSettingsShowCustomerEmailLabel => 'மின்னஞ்சலைக் காட்டவும்';

  @override
  String get invoiceSettingsShowCustomerEmailSubtitle =>
      'வாடிக்கையாளரின் மின்னஞ்சல் முகவரியை அச்சிடவும் (தெர்மல் ரசீதுகளில் காட்டப்படாது)';

  @override
  String get invoiceSettingsShowCustomerGstinLabel =>
      'GSTIN / வரி அடையாள எண்ணைக் காட்டவும்';

  @override
  String get invoiceSettingsShowCustomerGstinSubtitle =>
      'வாடிக்கையாளரின் GSTIN / வரி அடையாள எண்ணை அச்சிடவும் (GST புலங்கள் இயக்கத்தில் இருக்க வேண்டும்)';

  @override
  String get invoiceSettingsShowTimeInPdfLabel => 'PDF-இல் நேரத்தைக் காட்டவும்';

  @override
  String get invoiceSettingsShowTimeInPdfSubtitle =>
      'PDF மற்றும் தெர்மல் ரசீதுகளில் தேதிக்கு அருகில் விலைப்பட்டியல் உருவாக்கப்பட்ட நேரத்தையும் சேர்க்கவும்';

  @override
  String get invoiceSettingsTimeFormatLabel => 'நேர வடிவம்';

  @override
  String get invoiceSettingsTimeFormat24 => '24 மணி நேரம் (14:30)';

  @override
  String get invoiceSettingsTimeFormat12 => '12 மணி நேரம் (2:30 PM)';

  @override
  String get invoiceSettingsPrefixLabel => 'விலைப்பட்டியல் முன்னொட்டு';

  @override
  String get invoiceSettingsStartingNumberHelper =>
      'முதல் விலைப்பட்டியல் இந்த எண்ணிலிருந்து தொடங்கும்';

  @override
  String get invoiceSettingsStartingNumberLockedMessage =>
      'விலைப்பட்டியல்கள் இருக்கும்போது விலைப்பட்டியல் தொடக்க எண்ணை மாற்ற முடியாது. அனைத்து விலைப்பட்டியல்கள்/விலைப்புள்ளிகளையும் (குப்பைத் தொட்டி உட்பட) நிரந்தரமாக நீக்கிவிட்டு மீண்டும் முயலவும்.';

  @override
  String get invoiceSettingsQuantityColumnLabel => 'அளவு நெடுவரிசைத் தலைப்பு';

  @override
  String get invoiceSettingsQuantityColumnHint =>
      'எ.கா. சொற்கள், மணிநேரம், அலகுகள்';

  @override
  String get invoiceSettingsQuantityColumnHelper =>
      'இயல்புநிலை \"அளவு\" என்பதைப் பயன்படுத்த காலியாக விடவும்';

  @override
  String get invoiceSettingsAdditionalInfoLabel => 'கூடுதல் தகவல்';

  @override
  String get invoiceSettingsThankYouNoteLabel => 'நன்றிக் குறிப்பு';

  @override
  String get invoiceSettingsHideInvoiceNumberLabel =>
      'விலைப்பட்டியல் எண்ணை இயல்பாக மறைக்கவும்';

  @override
  String get invoiceSettingsHideInvoiceNumberSubtitle =>
      'புதிய விலைப்பட்டியல்களை உருவாக்கும்போது \"PDF-இல் விலைப்பட்டியல் எண்ணை மறைக்கவும்\" என்பதை இயல்பாக இயக்கவும்.';

  @override
  String get invoiceSettingsTaxRateHint => 'எ.கா. 18';

  @override
  String get invoiceSettingsTaxRateHelper =>
      'புதிய விலைப்பட்டியல்களுக்குப் பொருந்தும்';

  @override
  String get invoiceSettingsTaxEnabledLabel => 'வரியை இயல்பாக இயக்கவும்';

  @override
  String get invoiceSettingsTaxEnabledSubtitle =>
      'புதிய விலைப்பட்டியல்களை உருவாக்கும்போது வரி சுவிட்சை இயல்பாக இயக்கவும்.';

  @override
  String get invoiceSettingsTaxModeLabel => 'இயல்புநிலை வரி விகித முறை';

  @override
  String get invoiceSettingsAppliesNewInvoicesOnly =>
      'புதிய விலைப்பட்டியல்களுக்கு மட்டுமே பொருந்தும்';

  @override
  String get invoiceSettingsTaxModeGlobal => 'பொது';

  @override
  String get invoiceSettingsTaxModePerItem => 'உருப்படி வாரி';

  @override
  String get invoiceSettingsShowGstFieldsLabel => 'GST புலங்களைக் காட்டவும்';

  @override
  String get invoiceSettingsShowGstFieldsSubtitle =>
      'விலைப்பட்டியல்கள், PDF மற்றும் CSV ஏற்றுமதிகளில் GSTIN புலங்களை (HSN/SAC) காட்டவும்';

  @override
  String get invoiceSettingsShowCgstSgstLabel => 'CGST/SGST/IGST-ஐக் காட்டவும்';

  @override
  String get invoiceSettingsShowCgstSgstSubtitle =>
      'வரியை CGST + SGST ஆகவோ, மாநிலங்களுக்கிடையேயான விலைப்பட்டியல்களுக்கு IGST ஆகவோ பிரிக்கவும் (இந்தியா மட்டும்).';

  @override
  String get invoiceSettingsDefaultGstTitleLabel =>
      'இயல்புநிலை GST விலைப்பட்டியல் தலைப்பு';

  @override
  String get invoiceSettingsDefaultTaxTitleLabel =>
      'இயல்புநிலை TAX விலைப்பட்டியல் தலைப்பு';

  @override
  String get invoiceSettingsGstTitleHelperGst =>
      'புதிய விலைப்பட்டியல்களில் முன்கூட்டியே தேர்ந்தெடுக்கப்படும் — எ.கா. GST கூட்டு வரித் திட்ட வணிகர்களுக்கு \"Bill of Supply\"';

  @override
  String get invoiceSettingsGstTitleHelperGeneric =>
      'புதிய விலைப்பட்டியல்களில் முன்கூட்டியே தேர்ந்தெடுக்கப்படும்';

  @override
  String get invoiceSettingsShowRoundOffLabel =>
      'முழுத்தொகையாக்கலைக் காட்டவும்';

  @override
  String get invoiceSettingsShowRoundOffSubtitle =>
      'விலைப்பட்டியல் PDF-களில் முழுத்தொகையாக்கல் வரிசை, நிகரத் தொகை (அருகிலுள்ள முழு எண்ணாக), தொகை எழுத்துகளில் ஆகியவற்றைக் காட்டவும்.';

  @override
  String get invoiceSettingsShowAliasNameLabel =>
      'PDF-இல் மாற்றுப் பெயரைக் காட்டவும்';

  @override
  String get invoiceSettingsShowAliasNameSubtitle =>
      'PDF-களில் பொருளின் உண்மையான பெயருக்குப் பதிலாக, அதன் உள்ளூர் மொழி மாற்றுப் பெயரை (அமைக்கப்பட்டிருந்தால்) அச்சிடவும்';

  @override
  String get invoiceSettingsShowDescriptionLabel =>
      'பொருள் விளக்கத்தைக் காட்டவும்';

  @override
  String get invoiceSettingsShowDescriptionSubtitle =>
      'A4 PDF-களில் ஒவ்வொரு உருப்படியின் விளக்கத்தையும் அதன் கீழ் ஒரு வரியாக அச்சிடவும் (தெர்மல் ரசீதுகளில் அல்ல)';

  @override
  String get invoiceSettingsDescriptionNewLineLabel => 'விளக்கம் புதிய வரியில்';

  @override
  String get invoiceSettingsDescriptionNewLineSubtitle =>
      'விளக்கத்தை உருப்படிப் பெயருக்குக் கீழுள்ள வரியாக அல்லாமல், உருப்படிக்குக் கீழ் முழு அகல வரியாக அச்சிடவும்';

  @override
  String get invoiceSettingsAllowFractionalQtyLabel =>
      'பின்ன அளவுகளை அனுமதிக்கவும்';

  @override
  String get invoiceSettingsAllowFractionalQtySubtitle =>
      'தசம அளவுகளை இயக்கவும் (எ.கா. 1.5 மணி, 0.5 கிலோ)';

  @override
  String get invoiceSettingsShowQuantityLabel => 'அளவு புலத்தைக் காட்டவும்';

  @override
  String get invoiceSettingsShowQuantitySubtitle =>
      'சேவை அடிப்படையிலான பில்லிங்கிற்கு அளவை மறைக்கவும்; விலை நெடுவரிசை \"விகிதம்\" ஆக மாறும்';

  @override
  String get invoiceSettingsShowDiscountLabel =>
      'தள்ளுபடி நெடுவரிசையைக் காட்டவும்';

  @override
  String get invoiceSettingsShowDiscountSubtitle =>
      'உருப்படி அளவிலான தள்ளுபடிகளைப் பயன்படுத்தாத வாடிக்கையாளர்களுக்குத் தள்ளுபடி நெடுவரிசையை மறைக்கவும்';

  @override
  String get invoiceSettingsShowTypeTagLabel =>
      'பொருள்/சேவை குறிச்சொல்லைக் காட்டவும்';

  @override
  String get invoiceSettingsShowTypeTagSubtitle =>
      'ஒவ்வொரு விலைப்பட்டியல் உருப்படியிலும் பொருள்/சேவை குறிச்சொல்லைக் காட்டவும் அல்லது மறைக்கவும்';

  @override
  String get invoiceSettingsAllowDuplicateItemsLabel =>
      'விலைப்பட்டியலில் நகல் உருப்படிகளை அனுமதிக்கவும்';

  @override
  String get invoiceSettingsAllowDuplicateItemsSubtitle =>
      'ஒரே பொருளை ஒரு விலைப்பட்டியலில் ஒன்றுக்கு மேற்பட்ட முறை சேர்க்க அனுமதிக்கவும்';

  @override
  String get invoiceSettingsShowPrevBalanceLabel =>
      'முந்தைய நிலுவையைக் காட்டவும்';

  @override
  String get invoiceSettingsShowPrevBalanceSubtitle =>
      'விலைப்பட்டியல் PDF-களில் கணக்கிடப்பட்ட முந்தைய நிலுவைத் தொகையைக் காட்டவும்';

  @override
  String get invoiceSettingsLogoPositionLabel => 'நிறுவன லோகோ இடம்';

  @override
  String get invoiceSettingsLogoSizeLabel => 'நிறுவன லோகோ அளவு';

  @override
  String get commonLeftLabel => 'இடது';

  @override
  String get commonRightLabel => 'வலது';

  @override
  String get invoiceSettingsSignatureImageLabel => 'கையொப்பப் படம்';

  @override
  String get invoiceSettingsSignatureImageSubtitle =>
      'விலைப்பட்டியல்களில் அங்கீகரிக்கப்பட்ட கையொப்பமாக அச்சிடப்படும்';

  @override
  String get invoiceSettingsImageFormatHint =>
      'PNG, JPG அல்லது JPEG — அதிகபட்சம் 2 MB';

  @override
  String get invoiceSettingsChangeSignatureButton => 'கையொப்பத்தை மாற்றவும்';

  @override
  String get invoiceSettingsUploadSignatureButton =>
      'கையொப்பத்தைப் பதிவேற்றவும்';

  @override
  String get invoiceSettingsSignatureSizeLabel => 'கையொப்ப அளவு';

  @override
  String get invoiceSettingsSignaturePositionLabel => 'கையொப்ப இடம்';

  @override
  String get invoiceSettingsWatermarkImageLabel => 'வாட்டர்மார்க் படம்';

  @override
  String get invoiceSettingsWatermarkImageSubtitle =>
      'விலைப்பட்டியல் PDF-களில் காட்டப்படும் (தெர்மல் ரசீதுகளில் அச்சிடப்படாது)';

  @override
  String get invoiceSettingsChangeWatermarkButton =>
      'வாட்டர்மார்க்கை மாற்றவும்';

  @override
  String get invoiceSettingsUploadWatermarkButton =>
      'வாட்டர்மார்க்கைப் பதிவேற்றவும்';

  @override
  String get invoiceSettingsWatermarkPlacementLabel => 'வாட்டர்மார்க் இடம்';

  @override
  String get invoiceSettingsWatermarkPlacementItemsTable => 'உருப்படி அட்டவணை';

  @override
  String get invoiceSettingsWatermarkPlacementFullPage => 'முழுப் பக்கம்';

  @override
  String invoiceSettingsOpacityLabel(int value) {
    return 'ஒளிபுகாத்தன்மை: $value%';
  }

  @override
  String invoiceSettingsPercentValueLabel(int value) {
    return '$value%';
  }

  @override
  String get invoiceSettingsPromoTitle =>
      'உங்கள் விலைப்பட்டியல்களில் கூடுதல் புலங்கள் தேவையா?';

  @override
  String get invoiceSettingsPromoBody =>
      'PO எண், திட்டக் குறியீடு, துறை அல்லது எந்தவொரு தனிப்பயன் புலத்தையும் சேர்க்கவும்.';

  @override
  String get invoiceSettingsPromoButton => 'விருப்பங்களைப் பார்க்கவும்';

  @override
  String get pdfSettingsTitle => 'PDF அமைப்புகள்';

  @override
  String get pdfSettingsSubtitle =>
      'விலைப்பட்டியல், விலைப்புள்ளி மற்றும் ரசீது PDF வடிவமைப்புகளைத் தனிப்பயனாக்கவும்';

  @override
  String get pdfSettingsResetToDefaultButton => 'இயல்புநிலைக்கு மீட்டமைக்கவும்';

  @override
  String get pdfSettingsSaveSettingsButton => 'அமைப்புகளைச் சேமிக்கவும்';

  @override
  String get pdfSettingsTemplatesLabel => 'வடிவமைப்புகள்';

  @override
  String pdfSettingsNoTemplatesForPageSizeMessage(String pageSize) {
    return '$pageSize-க்கு வடிவமைப்புகள் இல்லை';
  }

  @override
  String get pdfSettingsSavedSnackbar => 'PDF அமைப்புகள் சேமிக்கப்பட்டன';

  @override
  String get commonActiveLabel => 'செயலில்';

  @override
  String get commonUnavailableLabel => 'கிடைக்கவில்லை';

  @override
  String get pdfSettingsDisplayOptionsLabel => 'காட்சி விருப்பங்கள்';

  @override
  String get pdfSettingsShowTotalQtyRowLabel =>
      'மொத்த அளவு வரிசையைக் காட்டவும்';

  @override
  String get pdfSettingsOrientationLabel => 'திசையமைவு';

  @override
  String get pdfSettingsOrientationPortrait => 'செங்குத்து';

  @override
  String get pdfSettingsOrientationLandscape => 'கிடைமட்டம்';

  @override
  String get pdfSettingsMetadataColumnsLabel =>
      'பொருள் கூடுதல் விவர நெடுவரிசைகள்';

  @override
  String get pdfSettingsMetadataColumnsHint =>
      'பொருள் கூடுதல் விவரங்களை உருப்படி அட்டவணையில் தனி நெடுவரிசைகளாக அச்சிடவும்.';

  @override
  String get pdfSettingsMetadataColumnsWarning =>
      'கூடுதல் விவர நெடுவரிசைகள் எந்த A4 வடிவமைப்பிலும் அச்சாகும் (A5/A6 அல்லது தெர்மல் ரசீதுகளில் அல்ல). ஒவ்வொன்றும் மற்றவற்றின் அகலத்தைக் குறைக்கும் — அட்டவணை நெருக்கடியாகத் தெரிந்தால், சிலவற்றை முடக்கவும் அல்லது மேலே Grid Classic-ஐக் கிடைமட்டமாக மாற்றவும். மதிப்புகள் உருப்படி சேர்க்கப்படும்போதே பதிவாகும்; பின்னர் பொருளைத் திருத்தினாலும் முந்தைய விலைப்பட்டியல்கள் மாறாது.';

  @override
  String get pdfSettingsItemLayoutLabel => 'உருப்படி அமைப்பு';

  @override
  String get pdfSettingsItemLayoutTableLabel => 'அட்டவணை';

  @override
  String get pdfSettingsItemLayoutDetailedLabel => 'விரிவானது';

  @override
  String get pdfSettingsItemLayoutHelpText =>
      'அட்டவணை: ஒரு உருப்படிக்கு ஒரு வரி (வ.எண்/பெயர்/அளவு/விலை/மொத்தம்). விரிவானது: பெயர் தனி வரியில், அதன் கீழ் அளவு/விலை/மொத்தம்.';

  @override
  String get pdfSettingsCompanyNameSizeLabel => 'நிறுவனப் பெயர் எழுத்துரு அளவு';

  @override
  String get pdfSettingsFontSizeLabel => 'PDF எழுத்துரு அளவு';

  @override
  String get pdfSettingsSectionSizesLabel => 'பிரிவு எழுத்துரு அளவுகள்';

  @override
  String get pdfSettingsDocTitleSizeLabel => 'ஆவணத் தலைப்பு அளவு';

  @override
  String get pdfSettingsTableHeaderSizeLabel => 'அட்டவணைத் தலைப்பு அளவு';

  @override
  String get pdfSettingsTableItemsSizeLabel => 'அட்டவணை உருப்படிகளின் அளவு';

  @override
  String get pdfSettingsTotalsSizeLabel => 'மொத்தங்களின் அளவு';

  @override
  String get pdfFontSizeSameAsOverallLabel => 'ஒட்டுமொத்த அளவு போலவே';

  @override
  String get pdfSettingsThemeColorLabel => 'தோற்ற நிறம்';

  @override
  String get pdfSettingsHexErrorText => '#RRGGBB வடிவில் உள்ளிடவும்';

  @override
  String get pdfSettingsPickColorTooltip => 'நிறத் தேர்வியைத் திறக்கவும்';

  @override
  String get pdfSettingsPickThemeColorDialogTitle =>
      'தோற்ற நிறத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get pdfSettingsPreviewDisclaimer =>
      'முன்னோட்டம், இறுதி PDF-இலிருந்து சற்று மாறுபடலாம்.';

  @override
  String get pdfSettingsCustomTemplatePromoTitle =>
      'தனிப்பயன் வடிவமைப்பு வேண்டுமா?';

  @override
  String get pdfSettingsCustomTemplatePromoBody =>
      'உங்கள் பிராண்டுக்கு ஏற்ற வடிவமைப்பைப் பெறுங்கள் — நிறங்கள், எழுத்துருக்கள் மற்றும் தளவமைப்பு.';

  @override
  String get pdfSettingsCustomizationOptionsButton =>
      'தனிப்பயனாக்க விருப்பங்கள்';

  @override
  String get pdfTemplateClassicName => 'கிளாசிக்';

  @override
  String get pdfTemplateClassicDescription =>
      'சுத்தமான கட்டமைப்புடன் கூடிய பாரம்பரியத் தளவமைப்பு';

  @override
  String get pdfTemplateModernName => 'மாடர்ன்';

  @override
  String get pdfTemplateModernDescription =>
      'தடித்த தலைப்புப் பகுதியுடன் கூடிய நவீன பாணி';

  @override
  String get pdfTemplateMinimalName => 'மினிமல்';

  @override
  String get pdfTemplateMinimalDescription =>
      'எளிமையானது, கவனச்சிதறல் இல்லாதது';

  @override
  String get pdfTemplateExecutiveName => 'எக்சிகியூட்டிவ்';

  @override
  String get pdfTemplateExecutiveDescription =>
      'கட்டமைக்கப்பட்ட பில்லிங் பகுதிகளுடன் கூடிய உயர்தர வணிகத் தளவமைப்பு';

  @override
  String get pdfTemplateCompactName => 'காம்பாக்ட்';

  @override
  String get pdfTemplateCompactDescription =>
      'இடத்தைச் சேமிக்கும் ரசீதுத் தளவமைப்பு, A6 அச்சிடலுக்கு மிகவும் ஏற்றது';

  @override
  String get pdfTemplateThermalName => 'தெர்மல்';

  @override
  String get pdfTemplateThermalDescription =>
      '80mm மற்றும் 58mm தெர்மல் அச்சுப்பொறிகளுக்கான குறுகிய ரசீதுத் தளவமைப்பு';

  @override
  String get pdfTemplateGridClassicName => 'கிரிட் கிளாசிக்';

  @override
  String get pdfTemplateGridClassicDescription =>
      'A4, A5, A6 அளவுகளுக்கான, எல்லைக்கோடுகளுடன் கூடிய பழைய பாணி அட்டவணை பில்';

  @override
  String get companyInfoAppBarTitle => 'நிறுவனத் தகவல்';

  @override
  String get companyInfoUploadLogoLabel => 'லோகோவைப் பதிவேற்றவும்';

  @override
  String get companyInfoClickToBrowseLabel => 'உலாவக் கிளிக் செய்யவும்';

  @override
  String get companyInfoRemoveLogoButton => 'லோகோவை அகற்றவும்';

  @override
  String get companyInfoShowOnPdfLabel => 'PDF-இல் காட்டவும்';

  @override
  String get companyInfoLogoRequirementsHint =>
      'அதிகபட்சம் 1080×1080 px · 2 MB\nPNG அல்லது JPG மட்டும்';

  @override
  String get companyInfoLogoSectionLabel => 'நிறுவன லோகோ';

  @override
  String get companyInfoDetailsSectionLabel => 'நிறுவன விவரங்கள்';

  @override
  String get companyInfoBusinessTypeSectionLabel => 'வணிக வகை';

  @override
  String get companyInfoPaymentSettingsSectionLabel =>
      'பணம் செலுத்துதல் அமைப்புகள்';

  @override
  String get companyInfoUpiAccountsSectionLabel => 'UPI கணக்குகள்';

  @override
  String get companyInfoBankAccountsSectionLabel => 'வங்கிக் கணக்குகள்';

  @override
  String get fieldGstinLabel => 'GSTIN';

  @override
  String get fieldTaxVatNoLabel => 'வரி/VAT எண்';

  @override
  String get fieldPanLabel => 'PAN';

  @override
  String get fieldTinLabel => 'TIN';

  @override
  String get fieldVatRegNoLabel => 'VAT பதிவு எண்';

  @override
  String get companyInfoFssaiCodeLabel => 'FSSAI குறியீடு';

  @override
  String get companyInfoPhoneHelperText =>
      'பல எண்கள்: காற்புள்ளியால் பிரிக்கவும்';

  @override
  String get fieldWebsiteLabel => 'இணையதளம்';

  @override
  String get companyInfoBusinessTypeTitle => 'வணிக வகை';

  @override
  String get companyInfoBusinessTypeSubtitle =>
      'பொருள் பட்டியல் மற்றும் விலைப்பட்டியல்களில் கிடைக்கும் உருப்படி வகை விருப்பங்களைத் தீர்மானிக்கிறது';

  @override
  String get labelBoth => 'இரண்டும்';

  @override
  String get companyInfoSetAsDefaultTooltip => 'இயல்பாக அமைக்கவும்';

  @override
  String get companyInfoUpiIdLabel => 'UPI ID';

  @override
  String get companyInfoAddUpiAccountButton => 'UPI கணக்கைச் சேர்க்கவும்';

  @override
  String get companyInfoShowQrToggleTitle =>
      'விலைப்பட்டியல்களில் QR குறியீட்டைக் காட்டவும்';

  @override
  String get companyInfoShowQrToggleSubtitle =>
      'உருவாக்கப்படும் PDF-களில் ஸ்கேன் செய்யக்கூடிய UPI கட்டண QR குறியீடுகளைச் சேர்க்கிறது';

  @override
  String get companyInfoShowBankDetailsToggleTitle =>
      'விலைப்பட்டியல்களில் வங்கி விவரங்களைக் காட்டவும்';

  @override
  String get companyInfoShowBankDetailsToggleSubtitle =>
      'உருவாக்கப்படும் PDF-களில் வங்கிக் கணக்கு விவரங்களை அச்சிடுகிறது';

  @override
  String get fieldBankNameLabel => 'வங்கியின் பெயர்';

  @override
  String get fieldAccountNumberLabel => 'கணக்கு எண்';

  @override
  String get fieldIfscCodeLabel => 'IFSC குறியீடு';

  @override
  String get fieldIbanLabel => 'IBAN';

  @override
  String get companyInfoAddBankAccountButton => 'வங்கிக் கணக்கைச் சேர்க்கவும்';

  @override
  String get companyInfoEditBankAccountTitle => 'வங்கிக் கணக்கைத் திருத்தவும்';

  @override
  String get fieldBankAccountNameLabel => 'கணக்கின் பெயர்';

  @override
  String get tooltipShowOnInvoicePdf => 'விலைப்பட்டியல் PDF-இல் காட்டவும்';

  @override
  String get companyInfoSavedSuccessMessage =>
      'நிறுவனத் தகவல் வெற்றிகரமாகச் சேமிக்கப்பட்டது';

  @override
  String get companyInfoImageTooLargeMessage =>
      'படக் கோப்பு 2 MB-ஐ விடக் குறைவாக இருக்க வேண்டும்.';

  @override
  String get companyInfoInvalidImageMessage => 'தவறான படக் கோப்பு.';

  @override
  String get companyInfoImageDimensionsMessage =>
      'படம் 1080x1080 பிக்சல்களுக்கு மிகாமல் இருக்க வேண்டும்.';

  @override
  String get companyInfoHintExampleBankName => 'எ.கா. HDFC Bank';

  @override
  String get companyInfoHintExampleAccountLabel => 'எ.கா. முதன்மைக் கணக்கு';

  @override
  String get actionConfirm => 'உறுதிப்படுத்தவும்';

  @override
  String get actionShare => 'பகிரவும்';

  @override
  String get appInfoTitle => 'மென்பொருள் தகவல்';

  @override
  String get appInfoAppDetailsTitle => 'செயலி விவரங்கள்';

  @override
  String get appInfoAppNameLabel => 'செயலியின் பெயர்';

  @override
  String get appInfoVersionLabel => 'பதிப்பு';

  @override
  String get appInfoLicenseLabel => 'உரிமம்';

  @override
  String get appInfoDeveloperTitle => 'உருவாக்குநர்';

  @override
  String get appInfoDeveloperLabel => 'உருவாக்குநர்';

  @override
  String get appInfoSupportEmailLabel => 'ஆதரவு மின்னஞ்சல்';

  @override
  String appInfoFooterCopyright(int year, String developer, String license) {
    return '© $year $developer  |  $license உரிமத்தின் கீழ் வெளியிடப்பட்டது';
  }

  @override
  String get appInfoCheckingLabel => 'சரிபார்க்கப்படுகிறது...';

  @override
  String get appInfoUpdateAvailableLabel => 'புதுப்பிப்பு கிடைக்கிறது';

  @override
  String get appInfoUpToDateLabel => 'புதுப்பித்த நிலையில் உள்ளது';

  @override
  String get appInfoCheckFailedLabel => 'சரிபார்க்க முடியவில்லை';

  @override
  String get appInfoUpdatesTitle => 'புதுப்பிப்புகள்';

  @override
  String get appInfoCurrentVersionLabel => 'தற்போதைய பதிப்பு';

  @override
  String get appInfoLatestVersionLabel => 'சமீபத்திய பதிப்பு';

  @override
  String get appInfoCheckNowButton => 'இப்போது சரிபார்க்கவும்';

  @override
  String get backupManagementTitle => 'காப்புப்பிரதி மேலாண்மை';

  @override
  String get backupCreateDbButton => 'தரவுத்தளக் காப்புப்பிரதியை உருவாக்கவும்';

  @override
  String get backupExportJsonButton => 'JSON-ஐ ஏற்றுமதி செய்யவும்';

  @override
  String get backupImportButton => 'காப்புப்பிரதியை இறக்குமதி செய்யவும்';

  @override
  String get backupNoBackupsFoundMessage => 'காப்புப்பிரதிகள் எதுவும் இல்லை';

  @override
  String backupSizeLabel(String size) {
    return 'அளவு: $size';
  }

  @override
  String backupCreatedLabel(String date) {
    return 'உருவாக்கப்பட்டது: $date';
  }

  @override
  String backupLoadErrorMessage(String error) {
    return 'காப்புப்பிரதிகளை ஏற்ற முடியவில்லை: $error';
  }

  @override
  String get backupCreatedSuccessMessage =>
      'காப்புப்பிரதி வெற்றிகரமாக உருவாக்கப்பட்டது!';

  @override
  String backupCreateErrorMessage(String error) {
    return 'காப்புப்பிரதியை உருவாக்க முடியவில்லை: $error';
  }

  @override
  String get backupRestoreConfirmTitle => 'காப்புப்பிரதியை மீட்டெடுக்கவும்';

  @override
  String get backupRestoreConfirmBody =>
      'இது தற்போதைய எல்லாத் தரவையும் காப்புப்பிரதியில் உள்ள தரவால் மாற்றிவிடும். தொடர விரும்புகிறீர்களா?';

  @override
  String backupRestoreErrorMessage(String error) {
    return 'காப்புப்பிரதியை மீட்டெடுக்க முடியவில்லை: $error';
  }

  @override
  String get backupDeleteConfirmTitle => 'காப்புப்பிரதியை நீக்கவும்';

  @override
  String get backupDeleteConfirmBody =>
      'இந்தக் காப்புப்பிரதியை நீக்க விரும்புகிறீர்களா?';

  @override
  String get backupDeletedSuccessMessage =>
      'காப்புப்பிரதி வெற்றிகரமாக நீக்கப்பட்டது!';

  @override
  String get backupDeleteFailedMessage => 'காப்புப்பிரதியை நீக்க முடியவில்லை';

  @override
  String backupDeleteErrorMessage(String error) {
    return 'காப்புப்பிரதியை நீக்க முடியவில்லை: $error';
  }

  @override
  String get backupSavedToDownloadsMessage =>
      'காப்புப்பிரதி Downloads கோப்புறையில் சேமிக்கப்பட்டது.';

  @override
  String backupDownloadErrorMessage(String error) {
    return 'காப்புப்பிரதியைப் பதிவிறக்க முடியவில்லை: $error';
  }

  @override
  String backupShareErrorMessage(String error) {
    return 'காப்புப்பிரதியைப் பகிர முடியவில்லை: $error';
  }

  @override
  String backupImportErrorMessage(String error) {
    return 'காப்புப்பிரதியை இறக்குமதி செய்ய முடியவில்லை: $error';
  }

  @override
  String get backupRestoreSuccessTitle => 'மீட்டெடுப்பு வெற்றிகரமாக முடிந்தது';

  @override
  String get backupRestoreSuccessBody =>
      'தரவுத்தளம் வெற்றிகரமாக மீட்டெடுக்கப்பட்டது.\n\nமாற்றங்கள் நடைமுறைக்கு வர செயலியை மறுதொடக்கம் செய்ய வேண்டும். தயவுசெய்து செயலியை மூடி மீண்டும் திறக்கவும்.';

  @override
  String get backupCloseLaterButton => 'பின்னர் மூடவும்';

  @override
  String get backupCloseAppNowButton => 'செயலியை இப்போது மூடவும்';

  @override
  String get commonSuccessTitle => 'வெற்றி';

  @override
  String get commonErrorTitle => 'பிழை';

  @override
  String get productColumnsScreenTitle => 'பொருள் விவரங்களைத் தனிப்பயனாக்கவும்';

  @override
  String get productColumnsSavedMessage =>
      'பொருள் நெடுவரிசைகள் சேமிக்கப்பட்டன.';

  @override
  String get productColumnsIntroText =>
      'பொருளைச் சேர்க்கும்/திருத்தும் படிவங்கள், பொருள் பட்டியல் மற்றும் விலைப்பட்டியல் உருப்படிகளில் எந்தப் புலங்கள் தோன்ற வேண்டும் என்பதைத் தேர்ந்தெடுக்கவும். பெயர் மற்றும் விலை எப்போதும் கட்டாயம்.';

  @override
  String get productColumnsNameLabel => 'பெயர்';

  @override
  String get productColumnsPriceLabel => 'விலை';

  @override
  String get productColumnsAlwaysRequiredSubtitle =>
      'எப்போதும் காட்டப்படும் — கட்டாயம்.';

  @override
  String get productColumnsStockLabel => 'இருப்பு';

  @override
  String get productColumnsStockSubtitle =>
      'இருப்பைக் கண்காணிக்கவில்லை என்றால் இதை முடக்கவும் — பொருட்கள் இயல்பாக வரம்பற்ற இருப்புடன் இருக்கும்.';

  @override
  String get productColumnsProductFieldsSectionTitle => 'பொருள் புலங்கள்';

  @override
  String get productColumnsAliasNameLabel => 'மாற்றுப் பெயர்';

  @override
  String get productColumnsAliasNameSubtitle =>
      'PDF/அச்சில் காட்டப்படும் உள்ளூர் மொழிப் பெயர்.';

  @override
  String get productColumnsTaxRateLabel => 'வரி விகிதம்';

  @override
  String get productColumnsTaxRateSubtitle =>
      'ஒவ்வொரு பொருளுக்கும் தனி வரி சதவீதம்.';

  @override
  String get productColumnsHsnSacLabel => 'HSN/SAC';

  @override
  String get productColumnsHsnSacSubtitle =>
      'HSN அல்லது SAC குறியீட்டுப் புலம்.';

  @override
  String get productColumnsDescriptionLabel => 'விளக்கம்';

  @override
  String get productColumnsDescriptionSubtitle =>
      'பொருளுக்கான விளக்கம், விரும்பியவாறு எழுதலாம்.';

  @override
  String get productColumnsPurchasePriceLabel => 'கொள்முதல் விலை';

  @override
  String get productColumnsPurchasePriceSubtitle =>
      'அடக்க விலை — லாபத்தைக் கண்காணிக்கப் பயன்படும்.';

  @override
  String get productColumnsDefaultDiscountLabel => 'இயல்புநிலைத் தள்ளுபடி';

  @override
  String get productColumnsDefaultDiscountSubtitle =>
      'இந்தப் பொருளை விலைப்பட்டியலில் சேர்க்கும்போது முன்கூட்டியே நிரப்பப்படும் தள்ளுபடி.';

  @override
  String get productColumnsUnitLabel => 'அலகு';

  @override
  String get productColumnsUnitSubtitle =>
      'அளவீட்டு அலகு (எண்ணிக்கை, கிலோ, மணி...).';

  @override
  String get productColumnsProductServiceTypeLabel => 'பொருள்/சேவை வகை';

  @override
  String get productColumnsProductServiceTypeSubtitle =>
      'பொருள் அல்லது சேவையைத் தேர்ந்தெடுக்கும் பிரிவுத் தேர்வி.';

  @override
  String get productColumnsMetadataLabel => 'பொருளின் கூடுதல் விவரங்கள்';

  @override
  String get productColumnsMetadataSubtitle =>
      'சேமிப்பு இடம், கன்டெய்னர்/பேட்ச் எண், காலாவதி தேதி, தயாரிப்பு தேதி, தயாரிப்பாளர், விநியோகஸ்தர், SKU, குறிப்புகள்.';

  @override
  String get productColumnsMetaStorageLocationLabel => 'சேமிப்பு இடம்';

  @override
  String get productColumnsMetaContainerNumberLabel => 'கன்டெய்னர் எண்';

  @override
  String get productColumnsMetaBatchNumberLabel => 'பேட்ச் எண்';

  @override
  String get productColumnsMetaExpiryDateLabel => 'காலாவதி தேதி';

  @override
  String get productColumnsMetaManufactureDateLabel => 'தயாரிப்பு தேதி';

  @override
  String get productColumnsMetaManufactureNameLabel => 'தயாரிப்பாளர் பெயர்';

  @override
  String get productColumnsMetaSupplierNameLabel => 'விநியோகஸ்தர் பெயர்';

  @override
  String get productColumnsMetaSkuCodeLabel => 'SKU குறியீடு';

  @override
  String get productColumnsMetaNotesLabel => 'குறிப்புகள்';

  @override
  String get productColumnsExtraCostLabel => 'கூடுதல் கட்டணம்';

  @override
  String get productColumnsExtraCostSubtitle =>
      'விலைப்பட்டியல் உருப்படிக்கு விருப்பப்படி சேர்க்கக்கூடிய நிலையான கூடுதல் கட்டணம்.';

  @override
  String get settingsOptionsComingSoonMessage => 'விருப்பங்கள் விரைவில்...';

  @override
  String get settingsNavCompanyInfoLabel => 'நிறுவன விவரங்கள்';

  @override
  String get settingsNavCompaniesLabel => 'நிறுவனங்கள்';

  @override
  String get settingsNavTeamLabel => 'குழு';

  @override
  String get settingsNavBackupLabel => 'காப்புப்பிரதி';

  @override
  String get settingsNavUsersLabel => 'பயனர்கள்';

  @override
  String get settingsNavProductDetailsLabel => 'பொருள் விவரங்கள்';

  @override
  String get settingsNavCustomizeLabel => 'தனிப்பயனாக்கம்';

  @override
  String get settingsNavAccessibilityLabel => 'அணுகல்தன்மை';

  @override
  String get settingsNavSoftwareInfoLabel => 'மென்பொருள் தகவல்';

  @override
  String get companyMgmtTitle => 'நிறுவனங்களை நிர்வகிக்கவும்';

  @override
  String get companyMgmtActiveBadge => 'செயலில்';

  @override
  String get companyMgmtSwitchButton => 'மாற்றவும்';

  @override
  String get companyMgmtSwitchConfirmTitle => 'நிறுவனத்தை மாற்றவா?';

  @override
  String companyMgmtSwitchConfirmBody(String name) {
    return '\"$name\" நிறுவனத்திற்கு மாற, Invoiceo மறுதொடக்கம் செய்யப்படும்.';
  }

  @override
  String get companyMgmtNewCompanyButton => '+ புதிய நிறுவனம்';

  @override
  String get companyMgmtNewCompanyTitle => 'புதிய நிறுவனம்';

  @override
  String get companyMgmtAdminAccountSectionLabel => 'நிர்வாகி கணக்கு';

  @override
  String get companyMgmtCreateButton => 'உருவாக்கவும்';

  @override
  String get companyMgmtDeleteButton => 'இந்த நிறுவனத்தை நீக்கவும்';

  @override
  String companyMgmtDeleteConfirmTitle(String name) {
    return '\"$name\" நிறுவனத்தை நீக்கவா?';
  }

  @override
  String get companyMgmtDeleteConfirmBody =>
      'இது இந்த நிறுவனத்தின் அனைத்துத் தரவையும் நிரந்தரமாக நீக்கும்; இந்தச் செயலைத் திரும்பப் பெற முடியாது. உறுதிப்படுத்த நிறுவனத்தின் பெயரை உள்ளிடவும்.';

  @override
  String get companyMgmtRenameTooltip => 'பெயரை மாற்றவும்';

  @override
  String get companyMgmtRenameTitle => 'நிறுவனத்தின் பெயரை மாற்றவும்';

  @override
  String get companyMgmtNameTakenMessage =>
      'இந்தப் பெயரில் ஒரு நிறுவனம் ஏற்கனவே உள்ளது';

  @override
  String companyMgmtSwitchErrorMessage(String error) {
    return 'நிறுவனத்தை மாற்ற முடியவில்லை: $error';
  }

  @override
  String get companyMgmtSwitchRestartTitle => 'நிறுவனம் மாற்றப்பட்டது';

  @override
  String get companyMgmtSwitchRestartBody =>
      'நிறுவன மாற்றத்தை முடிக்க Invoiceo-வை மறுதொடக்கம் செய்ய வேண்டும். செயலியை மூடி மீண்டும் திறக்கவும்.';

  @override
  String get companyMgmtCreateRestartTitle => 'நிறுவனம் உருவாக்கப்பட்டது';

  @override
  String get companyMgmtCreateRestartBody =>
      'உங்கள் புதிய நிறுவனம் தயார். தொடர, செயலியை மூடி மீண்டும் திறக்கவும்.';

  @override
  String get companyMgmtDeletedMessage => 'நிறுவனம் நீக்கப்பட்டது';

  @override
  String get companyMgmtDeleteRestartTitle => 'நிறுவனம் நீக்கப்பட்டது';

  @override
  String get companyMgmtDeleteRestartBody =>
      'நிறுவனம் நீக்கப்பட்டது; Invoiceo மற்றொரு நிறுவனத்திற்கு மாறியது. தொடர, செயலியை மூடி மீண்டும் திறக்கவும்.';

  @override
  String get companyMgmtOnlyCompanyTooltip =>
      'இதை நீக்க, உங்களிடம் குறைந்தது இன்னொரு நிறுவனம் இருக்க வேண்டும்';

  @override
  String get loginCompanyGearTooltip => 'நிறுவனங்களை நிர்வகிக்கவும்';

  @override
  String get loginCompanySelectorLabel => 'நிறுவனம்';

  @override
  String get customizationEyebrowLabel => 'தனிப்பயனாக்கம்';

  @override
  String get customizationHeadline =>
      'உங்கள் வணிகத்திற்கு ஏற்றவாறு பிரத்யேகமாக உருவாக்கப்பட்டது';

  @override
  String get customizationSubtitle =>
      'தேவையானதைத் தேர்ந்தெடுத்துக் கோரிக்கையை அனுப்பவும். எந்த வேலையும் தொடங்கும் முன் விலைப்புள்ளியுடன் பதில் அளிப்போம்.';

  @override
  String get customizationRecommendedBadge => 'பரிந்துரைக்கப்படுகிறது';

  @override
  String get customizationQuotedBadge => 'கோரிக்கைக்கேற்ப விலை';

  @override
  String get customizationRequestButton => 'கோரவும்';

  @override
  String get customizationFormOpenErrorMessage =>
      'படிவத்தைத் திறக்க முடியவில்லை. உங்கள் உலாவியில் invoiceo.in/customization.html முகவரியைத் திறக்கவும்.';

  @override
  String get customizationDisclaimerMessage =>
      'ஒவ்வொரு கோரிக்கைக்கும் தனியாக விலைப்புள்ளி வழங்கப்படும். விலையும் கால அளவும் முதலில் தெரிவிக்கப்படும்; நீங்கள் ஏற்றுக்கொண்ட பிறகே பணம் கேட்கப்படும்.';

  @override
  String get customizationPdfTemplateTitle => 'தனிப்பயன் PDF வடிவமைப்பு';

  @override
  String get customizationPdfTemplateDescription =>
      'உங்கள் பிராண்டுக்கு ஏற்ற விலைப்பட்டியல் வடிவமைப்பைப் பெறவும் — உங்கள் நிறங்கள், எழுத்துருக்கள், லோகோ இடம் மற்றும் தளவமைப்பு.';

  @override
  String get customizationCustomFieldsTitle => 'தனிப்பயன் புலங்கள்';

  @override
  String get customizationCustomFieldsDescription =>
      'உங்கள் விலைப்பட்டியல்களில் கூடுதல் புலங்கள் தேவையா? (PO எண், திட்டக் குறியீடு, துறை போன்றவை) நாங்கள் சேர்த்துத் தருகிறோம்.';

  @override
  String get customizationWhiteLabelTitle =>
      'வெள்ளை லேபிள் / பிராண்டிங் நீக்கம்';

  @override
  String get customizationWhiteLabelDescription =>
      'செயலி மற்றும் PDF வெளியீடுகளிலிருந்து Invoiceo பிராண்டிங் முழுவதையும் நீக்கி, உங்கள் சொந்த நிறுவன அடையாளத்தைப் பயன்படுத்தவும்.';

  @override
  String get customizationIndustryBuildTitle => 'துறை சார்ந்த பதிப்பு';

  @override
  String get customizationIndustryBuildDescription =>
      'உங்கள் துறைக்கேற்ற பதிப்பு தேவையா? (கட்டுமானம், ஆலோசனை, சில்லறை வணிகம் போன்றவை) உங்கள் தேவைகளுக்கு ஏற்ப செயல்முறையை மாற்றியமைப்போம்.';

  @override
  String get accessibilityCreateInvoiceLayoutSectionTitle =>
      'விலைப்பட்டியல் உருவாக்கப் பக்கத்தின் புதிய தளவமைப்பு';

  @override
  String get accessibilityNewLayoutLabel => 'புதிய தளவமைப்பு';

  @override
  String get accessibilityLayoutDescription =>
      'எந்த \"புதிய விலைப்பட்டியல்\" திரை வடிவமைப்பைப் பயன்படுத்த வேண்டும் என்பதைத் தேர்ந்தெடுக்கவும்.';

  @override
  String get accessibilityShortcutsSubtitle =>
      'மவுஸைத் தொடாமலே விலைப்பட்டியல் உருவாக்கத்தை விரைவுபடுத்தவும்.';

  @override
  String paymentDialogInvoiceRefLabel(String number, String customer) {
    return '#$number — $customer';
  }

  @override
  String get paymentDialogInvoiceTotalLabel => 'விலைப்பட்டியல் மொத்தம்';

  @override
  String get paymentDialogAmountPaidLabel => 'செலுத்திய தொகை';

  @override
  String get paymentDialogHistoryTitle => 'பணம் செலுத்துதல் வரலாறு';

  @override
  String get paymentDialogNoPaymentsMessage =>
      'இதுவரை பணம் செலுத்துதல் எதுவும் பதிவு செய்யப்படவில்லை';

  @override
  String get paymentDialogFullyPaidExclaimMessage =>
      'விலைப்பட்டியல் முழுமையாகச் செலுத்தப்பட்டது!';

  @override
  String get paymentDialogFullyPaidBannerLabel =>
      'விலைப்பட்டியல் முழுமையாகச் செலுத்தப்பட்டது';

  @override
  String paymentDialogRecordedMessage(String symbol, String amount) {
    return 'பணம் செலுத்துதல் பதிவு செய்யப்பட்டது. நிலுவை: $symbol $amount';
  }

  @override
  String paymentDialogRecordFailedMessage(String error) {
    return 'பணம் செலுத்துதலைப் பதிவு செய்ய முடியவில்லை: $error';
  }

  @override
  String get paymentDialogDeleteTitle => 'பணம் செலுத்துதலை நீக்கவும்';

  @override
  String paymentDialogDeleteConfirmBody(String receiptNumber) {
    return '$receiptNumber ரசீதை நீக்கவா?\n\nஇந்தச் செயலைத் திரும்பப் பெற முடியாது.';
  }

  @override
  String get paymentDialogNewPaymentTitle => 'புதிய பணம் செலுத்துதல்';

  @override
  String paymentDialogAmountFieldLabel(String symbol) {
    return 'தொகை ($symbol)';
  }

  @override
  String paymentDialogMaxHelperText(String symbol, String amount) {
    return 'அதிகபட்சம்: $symbol $amount';
  }

  @override
  String get paymentDialogInvalidAmountError => 'சரியான தொகையை உள்ளிடவும்';

  @override
  String get paymentDialogExceedsOutstandingError =>
      'நிலுவைத் தொகையை விட அதிகம்';

  @override
  String get paymentDialogMethodFieldLabel => 'செலுத்தும் முறை';

  @override
  String get paymentDialogSelectMethodHint => 'முறையைத் தேர்ந்தெடுக்கவும்';

  @override
  String get paymentDialogTaxCoveredLabel => 'உள்ளடங்கிய வரி';

  @override
  String get paymentDialogAutoCalculatedHelper => 'தானாகக் கணக்கிடப்பட்டது';

  @override
  String get paymentDialogNotesFieldLabel =>
      'குறிப்பு எண் / குறிப்புகள் (விருப்பத்தேர்வு)';

  @override
  String get paymentDialogNotesHint => 'எ.கா. காசோலை எண், பரிவர்த்தனை ID...';

  @override
  String get paymentDialogReceiptColLabel => 'ரசீது #';

  @override
  String get paymentDialogMethodColLabel => 'முறை';

  @override
  String get paymentDialogDownloadReceiptTooltip => 'ரசீதைப் பதிவிறக்கவும்';

  @override
  String get paymentDialogDeletePaymentTooltip => 'பணம் செலுத்துதலை நீக்கவும்';

  @override
  String get paymentMethodCash => 'ரொக்கம்';

  @override
  String get paymentMethodBankTransfer => 'வங்கிப் பரிமாற்றம்';

  @override
  String get paymentMethodCheck => 'காசோலை';

  @override
  String get paymentMethodOnline => 'ஆன்லைன்';

  @override
  String get paymentMethodOther => 'மற்றவை';

  @override
  String get customerInfoButtonTooltip => 'தொடர்பு விவரங்களைப் பார்க்கவும்';

  @override
  String get customerInfoButtonNoContactMessage =>
      'தொடர்பு விவரங்கள் கிடைக்கவில்லை.';

  @override
  String get updateDialogTitle => 'புதுப்பிப்பு கிடைக்கிறது';

  @override
  String get updateDialogBodyMessage =>
      'Invoiceo-வின் புதிய பதிப்பு கிடைக்கிறது. சமீபத்திய பதிப்பைப் பெற, பதிவிறக்கப் பக்கத்தைப் பார்வையிடவும்.';

  @override
  String get pageSizeA4Label => 'நிலையான A4';

  @override
  String get pageSizeA5Label => 'நிலையான A5';

  @override
  String get pageSizeA6Label => 'நிலையான A6';

  @override
  String get pageSizeThermal80Label => 'தெர்மல் தாள் 80mm';

  @override
  String get pageSizeThermal58Label => 'தெர்மல் தாள் 58mm';

  @override
  String get dateFormatDdmmyyyyLabel => 'DD/MM/YYYY  (எ.கா. 15/04/2026)';

  @override
  String get dateFormatMmddyyyyLabel => 'MM/DD/YYYY  (எ.கா. 04/15/2026)';

  @override
  String get dateFormatDdMmmyyyyLabel => 'DD MMM YYYY  (எ.கா. 15 Apr 2026)';

  @override
  String get dateFormatYyyymmddLabel => 'YYYY-MM-DD  (எ.கா. 2026-04-15)';

  @override
  String get sizeXSmallLabel => 'மிகச் சிறியது';

  @override
  String get sizeSmallLabel => 'சிறியது';

  @override
  String get sizeMediumLabel => 'நடுத்தரம்';

  @override
  String get sizeLargeLabel => 'பெரியது';

  @override
  String get sizeXLargeLabel => 'மிகப் பெரியது';

  @override
  String get shortcutNewInvoiceDescription =>
      'புதிய விலைப்பட்டியல் (முகப்புப் பலகையிலிருந்து) / படிவத்தை மீட்டமைக்கவும் (விலைப்பட்டியல் உருவாக்கத் திரையில்)';

  @override
  String get shortcutSaveInvoiceDescription =>
      'விலைப்பட்டியலைச் சேமிக்கவும் / உருவாக்கவும்';

  @override
  String get shortcutAddProductDescription =>
      'விலைப்பட்டியலில் பொருளைச் சேர்க்கவும்';

  @override
  String get shortcutAddCustomItemDescription =>
      'தனிப்பயன் (தற்காலிக) உருப்படியைச் சேர்க்கவும்';

  @override
  String get shortcutPreviewPdfDescription => 'PDF விலைப்பட்டியல் முன்னோட்டம்';

  @override
  String get shortcutPrintPdfDescription =>
      'PDF விலைப்பட்டியலை உருவாக்கவும் / அச்சிடவும்';

  @override
  String get invoiceSettingsMetadataColumnsGridClassicNote =>
      'குறிப்பு: கூடுதல் விவர நெடுவரிசைகள் A4 PDF வடிவமைப்புகளில் மட்டுமே அச்சாகும் (A5/A6 அல்லது தெர்மல் ரசீதுகளில் அல்ல).';

  @override
  String get invoiceSettingsCustomFieldsPageSupportNote =>
      'தனிப்பயன் புலங்கள் தெர்மல் ரசீதுகளைத் தவிர அனைத்து PDF வடிவமைப்புகளிலும் அச்சாகும்.';

  @override
  String get mItemsColQty => 'அளவு';

  @override
  String get createInvoiceQuantityLabel => 'அளவு';

  @override
  String createInvoiceDefaultPriceHelper(String price) {
    return 'இயல்புநிலை: $price';
  }

  @override
  String get createInvoiceExtraCostHelper =>
      'இந்தப் பொருளின் மொத்தத்துடன் கூடுதலாகச் சேர்க்கப்படும் நிலையான கட்டணம்';

  @override
  String get createInvoiceMustBeAboveZeroError =>
      '0-ஐ விட அதிகமாக இருக்க வேண்டும்';

  @override
  String get createInvoiceNoCustomFieldsFilledMessage =>
      'தனிப்பயன் புலங்கள் எதுவும் இன்னும் நிரப்பப்படவில்லை.';

  @override
  String get createInvoiceChargesMinusHint =>
      'கழிவுகளுக்கு கழித்தல் குறியை (-) பயன்படுத்தவும் (எ.கா. வாங்குபவர் செலுத்திய சரக்குக் கட்டணம்).';

  @override
  String get createInvoiceItemDescriptionLabel =>
      'விளக்கம் (விருப்பத்திற்குரியது)';

  @override
  String get createInvoiceItemDescriptionHint =>
      'பொருளின் பெயரின் கீழ் அச்சிடப்படும் கூடுதல் விவரம்';

  @override
  String get createInvoicePaidInFullBadge => 'முழுமையாகச் செலுத்தப்பட்டது';

  @override
  String get createInvoiceAmountDueLabel => 'நிலுவைத் தொகை';

  @override
  String createInvoiceSaveWalkInPrompt(String name) {
    return '\"$name\" என்பவரை எதிர்காலப் பயன்பாட்டிற்காக உங்கள் வாடிக்கையாளர் பட்டியலில் சேமிக்கவா?';
  }

  @override
  String createInvoiceExpiredOnLabel(String date) {
    return 'காலாவதியானது $date';
  }

  @override
  String createInvoiceExpiresOnLabel(String date) {
    return 'காலாவதி $date';
  }

  @override
  String get createInvoiceHideDetailsPanelTooltip => 'விவரப் பலகத்தை மறை';

  @override
  String get createInvoiceShowDetailsPanelTooltip => 'விவரப் பலகத்தைக் காட்டு';

  @override
  String get createInvoiceItemNotFoundMessage => 'பொருள் கிடைக்கவில்லை';

  @override
  String get createInvoiceSearchAboveHintMessage =>
      'மேலே தேடவும் அல்லது Ctrl+F அழுத்தவும்';

  @override
  String get createInvoiceTaxSettingsLabel => 'வரி அமைப்புகள்';

  @override
  String get createInvoiceCreateShortcutsTip =>
      'Ctrl+S: உருவாக்கு    Ctrl+P அல்லது F11: உருவாக்கி அச்சிடு';

  @override
  String get createInvoiceUpdateShortcutsTip =>
      'Ctrl+S: புதுப்பி    Ctrl+P அல்லது F11: புதுப்பித்து அச்சிடு';

  @override
  String get createInvoiceProcessingLabel => 'செயலாக்கப்படுகிறது...';

  @override
  String get invoiceMgmtFilterByCustomerTitle =>
      'வாடிக்கையாளர் வாரியாக வடிகட்டவும்';

  @override
  String get invoiceMgmtSearchCustomersHint => 'வாடிக்கையாளர்களைத் தேடவும்…';

  @override
  String get invoiceMgmtCustomerNotSavedLabel =>
      'வாடிக்கையாளராகச் சேமிக்கப்படவில்லை';

  @override
  String get invoiceMgmtUnknownCustomerName => 'தெரியாதவர்';

  @override
  String get appInfoBasedOnInvoiso =>
      'Invoiso அடிப்படையில் உருவாக்கப்பட்டது © 2025 ANOOP P · MIT உரிமம்';

  @override
  String get appInfoViewLicensesButton => 'உரிமங்களைக் காண்க';

  @override
  String get loginUsernameLabel => 'பயனர்பெயர்';

  @override
  String get loginPasswordLabel => 'கடவுச்சொல்';

  @override
  String get loginButton => 'உள்நுழைவு';

  @override
  String get loginForgotPasswordButton => 'கடவுச்சொல் மறந்துவிட்டதா?';

  @override
  String get loginInvalidCredentialsMessage =>
      'பயனர்பெயர் அல்லது கடவுச்சொல் தவறானது.';

  @override
  String loginEnterCredentialsMessage(String field) {
    return '$field மற்றும் கடவுச்சொல்லை உள்ளிடவும்';
  }

  @override
  String loginFirstTimeHint(String username, String password) {
    return 'முதல் முறையா? பயனர்பெயர் $username, கடவுச்சொல் $password கொண்டு உள்நுழைந்து, கேட்கப்படும்போது உங்கள் சொந்தக் கடவுச்சொல்லை அமைக்கவும்.';
  }

  @override
  String get loginNeedHelpLink => 'உதவி வேண்டுமா? ஆதரவைத் தொடர்புகொள்ளவும்';

  @override
  String get resetPasswordTitle => 'கடவுச்சொல்லை மீட்டமைக்கவும்';

  @override
  String get resetPasswordInstructions =>
      'பதில் குறியீட்டைப் பெற, கீழே உள்ள நிறுவல் ID-யையும் உங்கள் பயனர்பெயரையும் ஆதரவுக் குழுவுக்கு அனுப்பவும். அந்தக் குறியீடு அந்தப் பயனர்பெயருக்கு மட்டுமே வேலை செய்யும்.';

  @override
  String get resetPasswordLoadingLabel => 'ஏற்றுகிறது...';

  @override
  String get resetPasswordCopyIdTooltip => 'நிறுவல் ID-யை நகலெடுக்கவும்';

  @override
  String get resetPasswordIdCopiedMessage =>
      'நிறுவல் ID கிளிப்போர்டுக்கு நகலெடுக்கப்பட்டது.';

  @override
  String get resetPasswordEnterFieldsMessage =>
      'பயனர்பெயர் மற்றும் பதில் குறியீட்டை உள்ளிடவும்.';

  @override
  String get resetPasswordStillLoadingMessage =>
      'சற்று காத்திருக்கவும், நிறுவல் விவரங்கள் இன்னும் ஏற்றப்படுகின்றன.';

  @override
  String get resetPasswordInvalidCodeMessage =>
      'குறியீடு தவறானது அல்லது காலாவதியானது. ஆதரவுக் குழுவுக்கு அனுப்பிய அதே பயனர்பெயரை உள்ளிட்டுள்ளீர்களா எனச் சரிபார்க்கவும்.';

  @override
  String get resetPasswordVerifiedMessage =>
      'வெற்றிகரமாகச் சரிபார்க்கப்பட்டது. உங்கள் புதிய கடவுச்சொல்லை உள்ளிடவும்.';

  @override
  String resetPasswordCompanyLabel(String company) {
    return 'இதற்கான உள்நுழைவு மீட்டமைக்கப்படுகிறது: $company';
  }

  @override
  String get resetPasswordResponseCodeLabel => 'பதில் குறியீடு';

  @override
  String get resetPasswordVerifyButton => 'சரிபார்க்கவும்';

  @override
  String get resetPasswordSetButton => 'புதிய கடவுச்சொல்லை அமைக்கவும்';

  @override
  String get resetPasswordBackToLoginButton => 'உள்நுழைவுக்குத் திரும்பு';

  @override
  String get resetPasswordSuccessMessage =>
      'கடவுச்சொல் வெற்றிகரமாக மீட்டமைக்கப்பட்டது. உள்நுழையவும்.';

  @override
  String get resetPasswordFailedMessage =>
      'கடவுச்சொல்லை மீட்டமைக்க முடியவில்லை. மீண்டும் முயலவும்.';

  @override
  String get changePasswordMinLengthMessage =>
      'புதிய கடவுச்சொல் குறைந்தது 8 எழுத்துகள் இருக்க வேண்டும்.';

  @override
  String get changePasswordSameAsUsernameMessage =>
      'கடவுச்சொல் உங்கள் பயனர்பெயராக இருக்கக்கூடாது.';

  @override
  String get changePasswordFailedMessage =>
      'கடவுச்சொல்லை மாற்ற முடியவில்லை. மீண்டும் முயலவும்.';

  @override
  String get changePasswordRequiredTitle => 'கடவுச்சொல்லை மாற்ற வேண்டும்';

  @override
  String get changePasswordRequiredSubtitle =>
      'தொடர்வதற்கு முன் புதிய கடவுச்சொல்லை அமைக்க வேண்டும்.';

  @override
  String get changePasswordRememberWarning =>
      'இந்தக் கடவுச்சொல்லை நினைவில் கொள்ளுங்கள்.';

  @override
  String get changePasswordNewPasswordLabel =>
      'புதிய கடவுச்சொல் (குறைந்தது 8 எழுத்துகள்)';

  @override
  String get accessibilityScreenLayoutTitle => 'திரை தளவமைப்பு';

  @override
  String get accessibilityStandardLayoutLabel => 'ஸ்டாண்டர்ட் தளவமைப்பு';

  @override
  String get accessibilityModernLayoutLabel => 'மாடர்ன் தளவமைப்பு';

  @override
  String get accessibilityScreenLayoutDescription =>
      'மாடர்ன்: புதிய, எளிமையான திரைகள் (பரிந்துரைக்கப்படுகிறது). ஸ்டாண்டர்ட்: பழைய வழக்கமான திரைகள்.';

  @override
  String get accessibilityStandardLabel => 'ஸ்டாண்டர்ட்';

  @override
  String get helpContactSupportButton => 'ஆதரவைத் தொடர்புகொள்ளவும்';

  @override
  String get helpArticlesEnglishNote =>
      'உதவிக் கட்டுரைகள் ஆங்கிலத்தில் உள்ளன. ஆங்கிலச் சொற்களில் தேடவும்.';

  @override
  String get helpNoResultsLabel => 'பொருந்தும் முடிவுகள் இல்லை';

  @override
  String helpResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count முடிவுகள்',
      one: '1 முடிவு',
    );
    return '$_temp0';
  }

  @override
  String get helpEmptyPrompt =>
      'தேட தட்டச்சு செய்யவும், அல்லது உலாவ ஒரு வகையைத் தேர்ந்தெடுக்கவும்';

  @override
  String get helpNoMatchPrompt => 'நீங்கள் தேடுவது கிடைக்கவில்லையா?';

  @override
  String get helpSelectQuestionPrompt =>
      'பதிலைப் பார்க்க ஒரு கேள்வியைத் தேர்ந்தெடுக்கவும்';

  @override
  String get helpSearchHint =>
      'ஆங்கிலத்தில் கேள்வி கேளுங்கள், எ.கா. \"forgot password\"';

  @override
  String get helpCategoryFaq => 'கேள்வி-பதில்';

  @override
  String custPaymentAmountExceedsMessage(String number) {
    return '$number-க்கான தொகை அதன் நிலுவையை விட அதிகமாக உள்ளது.';
  }

  @override
  String get custPaymentEnterAmountMessage =>
      'குறைந்தது ஒரு விலைப்பட்டியலுக்குத் தொகையை உள்ளிடவும்.';

  @override
  String custPaymentAppliedMessage(int count, String symbol, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$symbol $amount $count விலைப்பட்டியல்களுக்குப் பிரித்துப் பதிவு செய்யப்பட்டது.',
      one: '$symbol $amount 1 விலைப்பட்டியலுக்குப் பதிவு செய்யப்பட்டது.',
    );
    return '$_temp0';
  }

  @override
  String custPaymentFailedMessage(String error) {
    return 'பணத்தைப் பதிவு செய்ய முடியவில்லை: $error';
  }

  @override
  String get custPaymentNoOpenInvoicesMessage =>
      'இந்த வாடிக்கையாளருக்கு நிலுவையில் உள்ள விலைப்பட்டியல்கள் எதுவும் இல்லை.';

  @override
  String get custPaymentTotalOutstandingLabel => 'மொத்த நிலுவை';

  @override
  String get custPaymentTotalAllocatedLabel => 'மொத்தம் ஒதுக்கப்பட்டது';

  @override
  String custPaymentAmountReceivedLabel(String symbol) {
    return 'பெறப்பட்ட தொகை ($symbol)';
  }

  @override
  String get custPaymentAutoAllocateHelper =>
      'சிறிய நிலுவையுள்ள விலைப்பட்டியலுக்கு முதலில் தானாக ஒதுக்கும்';

  @override
  String get custPaymentAutoAllocateButton => 'தானாக ஒதுக்கவும்';

  @override
  String custPaymentOpenInvoicesLabel(int count) {
    return 'நிலுவையில் உள்ள விலைப்பட்டியல்கள் (பழையது முதலில்) — $count';
  }

  @override
  String get custPaymentApplyingLabel => 'பதிவு செய்கிறது...';

  @override
  String get invoiceSettingsCustomFieldSampleValue => 'மாதிரி மதிப்பு';

  @override
  String get invoiceSettingsCustomFieldsPreviewEmpty =>
      'முன்னோட்டத்தைப் பார்க்க ஒரு புலத்தைச் சேர்க்கவும்.';

  @override
  String get invoiceSettingsCustomFieldsIntro =>
      'புலங்களை இங்கே ஒருமுறை வரையறுக்கவும் (எ.கா. வாகன எண், டெலிவரி குறிப்பு), பிறகு ஒவ்வொரு விலைப்பட்டியலிலும் அவற்றின் மதிப்புகளை நிரப்பவும். இவை வாடிக்கையாளருடன் இணைக்கப்படவில்லை.';

  @override
  String get invoiceSettingsTapToViewFullSize =>
      'முழு அளவில் பார்க்கத் தட்டவும்';

  @override
  String get invoiceSettingsEnableCustomFieldsLabel =>
      'தனிப்பயன் புலங்களை இயக்கவும்';

  @override
  String get invoiceSettingsEnableCustomFieldsSubtitle =>
      'விலைப்பட்டியல் உருவாக்கும் திரையில் தனிப்பயன் புலங்கள் பகுதியைக் காட்டவும்';

  @override
  String get invoiceSettingsMoveUpTooltip => 'மேலே நகர்த்தவும்';

  @override
  String get invoiceSettingsMoveDownTooltip => 'கீழே நகர்த்தவும்';

  @override
  String get invoiceSettingsCustomFieldLabel => 'புலத்தின் பெயர்';

  @override
  String get invoiceSettingsDeleteFieldTooltip => 'புலத்தை நீக்கவும்';

  @override
  String get invoiceSettingsNewCustomFieldLabel => 'புதிய புலத்தின் பெயர்';

  @override
  String get invoiceSettingsNewCustomFieldHint => 'எ.கா. வாகன எண்';

  @override
  String get thermalPrinterTitle => 'தெர்மல் அச்சுப்பொறி';

  @override
  String get thermalPrinterNoneSavedMessage =>
      'அச்சுப்பொறி எதுவும் சேமிக்கப்படவில்லை. அடுத்த முறை தெர்மல் ரசீதை அச்சிடும்போது ஒன்றைத் தேர்ந்தெடுக்கக் கேட்கப்படும்.';

  @override
  String thermalPrinterSavedLabel(String name) {
    return 'சேமித்த அச்சுப்பொறி: $name';
  }

  @override
  String get thermalPrinterForgetButton => 'மறந்துவிடு';

  @override
  String get thermalPrinterAutoPrintTitle =>
      'சேமித்த அச்சுப்பொறிக்கு நேரடியாக அச்சிடவும்';

  @override
  String get thermalPrinterAutoPrintSubtitle =>
      'ஒவ்வொரு முறையும் கேட்கப்பட வேண்டுமெனில் அணைக்கவும்';

  @override
  String get thermalPrinterImageModeNote =>
      'தமிழ் அல்லது ஆங்கிலம் அல்லாத பிற எழுத்துகள் உள்ள ரசீதுகள் படமாக அச்சிடப்படும்:';

  @override
  String get thermalPrinterTextSizeLabel => 'ரசீது எழுத்து அளவு';

  @override
  String get thermalPrinterTextSizeNormal => 'இயல்பு';

  @override
  String get thermalPrinterTextSizeLargeDefault => 'பெரியது (இயல்புநிலை)';

  @override
  String get thermalPrinterTextSizeXLarge => 'மிகப் பெரியது';

  @override
  String get thermalPrinterWidthLabel => 'அச்சு அகலம்';

  @override
  String get thermalPrinterWidthHelper =>
      'வலது ஓரம் வெட்டப்பட்டால், குறைந்த அகலத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get thermalPrinterWidthAuto =>
      'தானியங்கி (80 mm: 576 புள்ளிகள், 58 mm: 384 புள்ளிகள்)';

  @override
  String thermalPrinterWidthDots(String dots) {
    return '$dots புள்ளிகள்';
  }

  @override
  String get thermalPrinterAppliesNowNote =>
      'உடனே பொருந்தும்; PDF அமைப்புகளைச் சேமிக்கத் தேவையில்லை.';

  @override
  String get userMgmtStatTotalUsers => 'மொத்த பயனர்கள்';

  @override
  String get userMgmtStatAllUsers => 'அனைத்து பயனர்களும்';

  @override
  String get userMgmtStatAdminUsers => 'நிர்வாகப் பயனர்கள்';

  @override
  String get userMgmtStatFullAccess => 'முழு அணுகல்';

  @override
  String get userMgmtStatRegularUsers => 'சாதாரண பயனர்கள்';

  @override
  String get userMgmtStatStandardAccess => 'வழக்கமான அணுகல்';

  @override
  String get autoPrintAfterCreateTitle => 'உருவாக்கியதும் தானாக அச்சிடு';

  @override
  String get autoPrintAfterCreateSubtitle =>
      'விலைப்பட்டியலை உருவாக்கும்போது (பொத்தான் அல்லது Ctrl+S) அதுவும் அச்சிடப்படும். Ctrl+P அல்லது F11 எப்போதும் உருவாக்கி அச்சிடும். வெப்ப ரசீது சேமித்த அச்சுப்பொறிக்கு நேரடியாகச் செல்லும்; மற்ற வார்ப்புருக்கள் அச்சு உரையாடலைத் திறக்கும். Modern வடிவமைப்பில் மட்டும் (அமைப்புகள் > அணுகல்தன்மையில் தேர்வு செய்யவும்).';

  @override
  String get shortcutSearchDescription =>
      'உதவி மற்றும் அமைப்புகளில் தேடு (Modern வடிவமைப்பு; Mac-இல் Cmd + K)';

  @override
  String get shortcutCreatedNewInvoiceDescription =>
      'உருவாக்கிய பின்: புதிய விலைப்பட்டியலைத் தொடங்கு';

  @override
  String get shortcutCreatedNewReceiptDescription =>
      'உருவாக்கிய பின்: புதிய ரசீதைத் தொடங்கு';

  @override
  String get shortcutCreateAndPrintDescription =>
      'உருவாக்கி அச்சிடு (Ctrl + P போலவே)';

  @override
  String get pdfPreviewErrorMessage =>
      'முன்னோட்டத்தைக் காட்ட முடியவில்லை. அதற்குப் பதிலாக அச்சிடு அல்லது பதிவிறக்கு என்பதைப் பயன்படுத்தவும்.';

  @override
  String get pdfSettingsSampleCompanyName => 'உங்கள் நிறுவனம்';

  @override
  String get pdfSettingsSampleCustomerName => 'மாதிரி வாடிக்கையாளர்';

  @override
  String pdfSettingsSampleItemName(int number) {
    return 'மாதிரிப் பொருள் $number';
  }

  @override
  String get companyInfoNameRequiredMessage =>
      'உங்கள் நிறுவனத்தின் பெயரை உள்ளிடவும்.';

  @override
  String get createInvoiceNegativeLineMessage =>
      'ஒரு வரியின் மொத்தம் பூஜ்ஜியத்திற்குக் கீழே இருக்க முடியாது. தள்ளுபடியைச் சரிபார்க்கவும்.';

  @override
  String get invoiceMgmtAlreadyConvertedTitle => 'ஏற்கனவே மாற்றப்பட்டது';

  @override
  String invoiceMgmtAlreadyConvertedBody(String number) {
    return 'விலைப்புள்ளி $number ஏற்கனவே விலைப்பட்டியலாக மாற்றப்பட்டது. இதுபோல் இன்னொரு விலைப்பட்டியல் செய்ய, நகலெடு என்பதைப் பயன்படுத்தவும்.';
  }
}
