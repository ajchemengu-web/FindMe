import 'package:flutter/widgets.dart';

/// GoogleSignInPlatform's web implementation imports dart:ui_web, which fails to
/// compile for non-web targets -- so the actual button widget for each platform lives
/// behind this conditional export. Web uses Google's own rendered GIS button (embedding
/// third-party auth UI is required by Google's terms); everything else uses a plain
/// styled button that calls GoogleSignIn.instance.authenticate() directly.
export 'google_sign_in_button_stub.dart' if (dart.library.js_interop) 'google_sign_in_button_web.dart';

/// Shared signature both implementations satisfy: a tappable Google sign-in affordance
/// that reports failures via [onError]. Successful sign-ins are picked up by
/// AuthController's GoogleSignIn.instance.authenticationEvents listener, not a
/// callback here -- both platforms' underlying flows are event-stream-based.
abstract class GoogleSignInButtonBase extends StatelessWidget {
  const GoogleSignInButtonBase({super.key, this.onError});
  final void Function(Object error)? onError;
}
