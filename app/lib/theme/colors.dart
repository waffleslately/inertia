import 'package:flutter/material.dart';

class AppColors {
  // Deep Dark Base
  static const Color background = Color(0xFF0A0E17);
  static const Color surface = Color(0xFF121826);
  static const Color card = Color(0xFF182235);
  static const Color border = Color(0xFF1F2E45);
  static const Color divider = Color(0xFF26354D);

  // Electric Blue & Cyan Accents
  static const Color electricCyan = Color(0xFF00E5FF);
  static const Color electricBlue = Color(0xFF3B82F6);
  static const Color deepAccent = Color(0xFF00B0FF);
  static const Color cyanGlow = Color(0x4D00E5FF);
  static const Color blueGlow = Color(0x4D3B82F6);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Status & Crowd Levels
  static const Color crowdLow = Color(0xFF10B981);     // Green
  static const Color crowdMedium = Color(0xFFF59E0B);  // Amber
  static const Color crowdHigh = Color(0xFFEF4444);    // Red
  static const Color crowdLowBg = Color(0x2610B981);
  static const Color crowdMediumBg = Color(0x26F59E0B);
  static const Color crowdHighBg = Color(0x26EF4444);

  // Gradients
  static const LinearGradient electricGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF161F30), Color(0xFF101724)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
