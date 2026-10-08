import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Recognises barcode-scanner input anywhere on a screen, whatever has focus.
///
/// A scanner is a keyboard that "types" a whole code within a few
/// milliseconds and then presses Enter (or Tab). A person cannot press
/// [minChars] keys with less than [maxGap] between them, so that burst is
/// treated as a scan:
///
///  * the burst is kept OUT of whichever text box has focus (the box is put
///    back to what it held before the first character),
///  * [onScan] receives the code, and
///  * the Enter/Tab that ends it is swallowed, so it can neither submit a
///    form nor press a focused button.
///
/// Key auto-repeat (holding a key down) is never counted. Timing uses
/// [Timer]s only, so it also behaves under `fake_async`.
class ScannerCapture {
  ScannerCapture({
    required this.isActive,
    required this.onScan,
    this.minChars = 4,
    this.maxGap = const Duration(milliseconds: 60),
    this.enterGrace = const Duration(milliseconds: 300),
  });

  /// Whether scans should be captured right now (e.g. screen is on top).
  final bool Function() isActive;
  final void Function(String code) onScan;
  final int minChars;
  final Duration maxGap;

  /// How long after a scan an Enter/Tab is still taken as the scanner's own.
  final Duration enterGrace;

  Timer? _gapTimer;
  Timer? _graceTimer;
  String _buffer = '';
  int _chars = 0;
  bool _active = false;
  TextEditingController? _target;
  String? _snapshot;

  void attach() => HardwareKeyboard.instance.addHandler(_onKey);

  void detach() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _gapTimer?.cancel();
    _graceTimer?.cancel();
  }

  bool _onKey(KeyEvent event) {
    if (!isActive()) {
      _resetBurst();
      return false;
    }
    if (event is KeyUpEvent) return false;

    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed || keys.isMetaPressed || keys.isAltPressed) {
      _resetBurst(); // a shortcut such as Ctrl+F, not scanner input
      return false;
    }

    final key = event.logicalKey;
    final isEnter =
        key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;
    final isTab = key == LogicalKeyboardKey.tab;
    if (isEnter || isTab) {
      if (_active) {
        _finish(); // the scanner's terminator: the scan is complete
        return true;
      }
      if (_graceTimer?.isActive ?? false) return true; // arrived after the gap
      _resetBurst();
      return false;
    }

    // Holding a key down repeats it; that is never a scan.
    if (event is KeyRepeatEvent) return _active;

    final ch = event.character;
    if (ch == null || ch.isEmpty || ch.runes.length != 1 || ch.codeUnitAt(0) < 32) {
      return false; // Shift, arrows, F-keys...: neither part of a scan nor a break
    }

    final continuing = _gapTimer?.isActive ?? false;
    if (!continuing) {
      _resetBurst();
      _target = _focusedController();
      _snapshot = _target?.text; // what the box held before this burst
    }
    _buffer += ch;
    _chars++;
    if (_chars >= minChars) _active = true;
    _gapTimer?.cancel();
    _gapTimer = Timer(maxGap, _finish);

    if (_active) {
      _restoreTarget(); // undo the characters that slipped in before we knew
      return true; // and keep the rest out of the box
    }
    return false;
  }

  void _finish() {
    _gapTimer?.cancel();
    final wasScan = _active;
    final code = _buffer.trim();
    if (wasScan) _restoreTarget();
    _resetBurst();
    if (!wasScan) return;
    _graceTimer?.cancel();
    _graceTimer = Timer(enterGrace, () {});
    if (code.isNotEmpty) onScan(code);
  }

  void _restoreTarget() {
    final target = _target;
    final snapshot = _snapshot;
    if (target == null || snapshot == null || target.text == snapshot) return;
    target.value = TextEditingValue(
      text: snapshot,
      selection: TextSelection.collapsed(offset: snapshot.length),
    );
  }

  void _resetBurst() {
    _gapTimer?.cancel();
    _buffer = '';
    _chars = 0;
    _active = false;
    _target = null;
    _snapshot = null;
  }

  /// The controller of the text box that currently has keyboard focus, if any.
  TextEditingController? _focusedController() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return null;
    EditableTextState? state = context.findAncestorStateOfType<EditableTextState>();
    if (state == null && context is StatefulElement && context.state is EditableTextState) {
      state = context.state as EditableTextState;
    }
    return state?.widget.controller;
  }
}
