import 'package:flutter/material.dart';

class AppLogoBadge extends StatelessWidget {
  const AppLogoBadge({
    super.key,
    this.size = 72,
    this.radius = 20,
    this.padding = 14,
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0xFFE2E8F0),
  });

  final double size;
  final double radius;
  final double padding;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
