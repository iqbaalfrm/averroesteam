import 'package:averroes_core/averroes_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onActionTap,
    this.leadingIcon,
  });

  final String title;
  final String? actionText;
  final VoidCallback? onActionTap;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              if (leadingIcon != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD1FAE5)),
                  ),
                  child: Icon(leadingIcon, size: 16, color: AppColors.emerald),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate,
                  ),
                ),
              ),
            ],
          ),
        ),
        if ((actionText ?? '').isNotEmpty)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              actionText!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.emeraldDark,
              ),
            ),
          ),
      ],
    );
  }
}

class AppEmptyStateCard extends StatelessWidget {
  const AppEmptyStateCard({
    super.key,
    required this.text,
    this.icon = Symbols.inbox,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _AppStateCardBase(
      icon: icon,
      text: text,
      backgroundColor: Colors.white,
      borderColor: const Color(0xFFE2E8F0),
      textColor: AppColors.muted,
      iconColor: AppColors.muted,
    );
  }
}

class AppErrorStateCard extends StatelessWidget {
  const AppErrorStateCard({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Coba lagi',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return _AppStateCardBase(
      icon: Symbols.error,
      text: message,
      backgroundColor: const Color(0xFFFEF2F2),
      borderColor: const Color(0xFFFECACA),
      textColor: const Color(0xFFB91C1C),
      iconColor: const Color(0xFFDC2626),
      action: onRetry == null
          ? null
          : OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB91C1C),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
              ),
              child: Text(retryLabel),
            ),
    );
  }
}

class _AppStateCardBase extends StatelessWidget {
  const _AppStateCardBase({
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.iconColor,
    this.action,
  });

  final IconData icon;
  final String text;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color iconColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 8),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: 10),
            action!,
          ],
        ],
      ),
    );
  }
}

