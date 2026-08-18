import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../theme/tokens.dart';
import 'google_sign_in_button.dart';
import 'google_svg_logo.dart';

/// Native (Android/iOS/desktop) Google sign-in button -- calls
/// GoogleSignIn.instance.authenticate() directly on tap. The result (success or
/// failure) is picked up via AuthController's authenticationEvents listener; [onError]
/// only covers exceptions authenticate() itself throws synchronously.
class GoogleSignInButton extends GoogleSignInButtonBase {
  const GoogleSignInButton({super.key, super.onError});

  Future<void> _onTap() async {
    try {
      await GoogleSignIn.instance.authenticate();
    } catch (e) {
      onError?.call(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: _onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.string(googleGLogoSvg, width: 18, height: 18),
          const SizedBox(width: 10),
          const Text('Continue with Google', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
