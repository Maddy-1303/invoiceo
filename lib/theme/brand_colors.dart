import 'package:flutter/material.dart';

/// The "Clean light" palette: white sidebar and headers on a soft grey page,
/// slate text, and the logo blue for actions, with the logo teal as the second
/// colour. Change a colour here and the
/// whole app follows. Success / error / warning colours (green, red, orange)
/// are deliberately not part of it because they carry meaning.
class BrandColors {
  BrandColors._();

  /// Main action colour: buttons, active items, selected chips.
  static const primary = Color(0xFF1F6FEB);

  /// For text and icons on white and for pressed states.
  static const primaryDark = Color(0xFF1558C0);

  /// Pale fills behind teal text or icons.
  static const primarySoft = Color(0xFFF1F6FE);
  static const primaryTint = Color(0xFFD9E7FD);
  static const primaryBorder = Color(0xFFB4D0FA);

  /// Second colour: links, info, "sent" style statuses.
  static const accent = Color(0xFF0D9488);
  static const accentDark = Color(0xFF0F766E);

  /// Page background behind the white cards.
  static const page = Color(0xFFF4F6F8);

  /// Sidebar and header surfaces.
  static const surface = Color(0xFFFFFFFF);

  /// Main text and headings.
  static const ink = Color(0xFF1F2937);

  /// Sidebar items and secondary text.
  static const slate = Color(0xFF475569);

  /// Hairlines between sections.
  static const line = Color(0xFFE2E8F0);

  /// Table header row.
  static const tableHeader = Color(0xFFEEF2F6);

  /// Selected item in the sidebar and in lists.
  static const selected = Color(0xFFE6EFFD);

  /// Dark mode.
  static const primaryOnDark = Color(0xFF6AA6FF);
  static const darkBar = Color(0xFF1E1E1E);
}
