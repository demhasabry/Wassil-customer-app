import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum AppLogoVariant { wordmark, pin }

enum AppLogoColor { blue, white }

/// Real Wassil brand mark, replacing the old placeholder colored box.
///
/// Per the design handoff: splash and sign-in use [AppLogoVariant.wordmark];
/// every other place a mark is needed uses [AppLogoVariant.pin]. Pick
/// [AppLogoColor.white] on a dark/brand-colored background, [AppLogoColor.blue]
/// on a light one — the source SVGs are pre-colored per variant, not tinted
/// at runtime, since the brand file only ships blue/white lockups.
class AppLogo extends StatelessWidget {
  final AppLogoVariant variant;
  final AppLogoColor color;
  final double? width;
  final double? height;

  const AppLogo({
    super.key,
    this.variant = AppLogoVariant.wordmark,
    this.color = AppLogoColor.blue,
    this.width,
    this.height,
  });

  String get _assetPath {
    final variantName = variant == AppLogoVariant.wordmark ? 'wordmark' : 'pin';
    final colorName = color == AppLogoColor.blue ? 'blue' : 'white';
    return 'assets/logo/$variantName-$colorName.svg';
  }

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(_assetPath, width: width, height: height);
  }
}
