import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web_gsi;

import 'google_sign_in_button.dart';

/// Web Google sign-in button -- Google's own rendered GIS widget (required by Google's
/// terms; a custom-styled button can't be substituted on web). Tapping it is handled
/// entirely by Google's SDK; the result lands on
/// GoogleSignIn.instance.authenticationEvents, which AuthController listens to.
class GoogleSignInButton extends GoogleSignInButtonBase {
  const GoogleSignInButton({super.key, super.onError});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: web_gsi.renderButton(
        configuration: web_gsi.GSIButtonConfiguration(
          theme: web_gsi.GSIButtonTheme.filledBlack,
          text: web_gsi.GSIButtonText.continueWith,
          shape: web_gsi.GSIButtonShape.rectangular,
          size: web_gsi.GSIButtonSize.large,
          minimumWidth: 360,
        ),
      ),
    );
  }
}
