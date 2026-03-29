import 'package:flutter/material.dart';

/// USF brand greens and shared decoration helpers.
abstract final class UsfTheme {
  static const Color green = Color(0xFF006747);
  static const Color goldAccent = Color(0xFFCFC493);
  static const Color surfaceInput = Color(0xFFE8E8E8);

  /// Dark theme would otherwise paint light-gray input text on [surfaceInput].
  static const TextStyle inputTextStyle = TextStyle(color: Colors.black);

  static InputDecoration inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade700),
      filled: true,
      fillColor: surfaceInput,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
