// app_config.dart
class AppConfig
{
  static const kIsCloud = false;
  /// The product name people see (window title, PDF footers, texts).
  static const brandName = "Invoiceo";
  /// Short technical name (backup metadata, file names).
  static const name = "invoiceo";
  static const version = "v1.0.6";
  static const developer = "Madhan Prasath";
  static const supportEmail = "madhanprasat2002r@gmail.com";
  /// Support request form (Google Forms) — Help → Contact Support opens it.
  static const supportForm = "https://docs.google.com/forms/d/e/1FAIpQLSc6HAtInB-gJv9T2vwfLHoy26V2T-jTh83cMCBbuY889UwOuA/viewform";
  static const buyMeCoffee = "https://buymeacoffee.com/madcreations";
  static const website = "https://invoiceo.in/";
  /// Where anonymous usage counts go (Cloudflare Worker, tool/telemetry/).
  /// Empty = nothing is sent. See UsageStatsService.
  static const usageStatsUrl = "https://invoiceo-telemetry.madhanprasat2002r.workers.dev";
  static const license = "MIT";
  static const description = "Invoiceo is a modern invoice and quotation management app for freelancers and small businesses.";
}
