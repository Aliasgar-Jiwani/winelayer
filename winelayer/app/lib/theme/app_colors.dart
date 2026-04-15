import 'package:flutter/material.dart';

/// WineLayer curated color palette — dark theme with purple/blue accents.
class AppColors {
  AppColors._();

  // ─── Primary Accent ──────────────────────────────────────────────
  static const Color primary = Color(0xFF8B5CF6);       // Vivid purple
  static const Color primaryLight = Color(0xFFA78BFA);   // Lighter purple
  static const Color primaryDark = Color(0xFF6D28D9);    // Deep purple

  // ─── Secondary Accent ────────────────────────────────────────────
  static const Color secondary = Color(0xFF06B6D4);      // Cyan
  static const Color secondaryLight = Color(0xFF22D3EE);  // Light cyan
  static const Color secondaryDark = Color(0xFF0891B2);   // Dark cyan

  // ─── Backgrounds ─────────────────────────────────────────────────
  static const Color bgDarkest = Color(0xFF0A0A0F);      // App background
  static const Color bgDark = Color(0xFF12121A);          // Card background
  static const Color bgMedium = Color(0xFF1A1A2E);        // Elevated surface
  static const Color bgLight = Color(0xFF242438);          // Sidebar / panels

  // ─── Glass Effect Colors ─────────────────────────────────────────
  static const Color glassBg = Color(0x1AFFFFFF);         // ~10% white
  static const Color glassBorder = Color(0x33FFFFFF);     // ~20% white
  static const Color glassHighlight = Color(0x0DFFFFFF);  // ~5% white

  // ─── Text ────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF1F5F9);    // Near white
  static const Color textSecondary = Color(0xFF94A3B8);   // Muted gray-blue
  static const Color textTertiary = Color(0xFF64748B);    // Dimmed
  static const Color textAccent = Color(0xFFA78BFA);      // Purple text

  // ─── Status Colors ───────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);         // Emerald green
  static const Color warning = Color(0xFFF59E0B);         // Amber
  static const Color error = Color(0xFFEF4444);           // Red
  static const Color info = Color(0xFF3B82F6);            // Blue

  // ─── Gradients ───────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sidebarGradient = LinearGradient(
    colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const RadialGradient glowGradient = RadialGradient(
    colors: [Color(0x338B5CF6), Color(0x00000000)],
    radius: 1.5,
  );
}
