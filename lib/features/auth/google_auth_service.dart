import 'package:google_sign_in/google_sign_in.dart';

/// Web (or other platform-specific) OAuth Client ID from Google Cloud Console -> APIs
/// & Services -> Credentials. Pass at build/run time:
///   --dart-define=GOOGLE_CLIENT_ID=xxxxxxxx.apps.googleusercontent.com
/// Google sign-in silently has nothing to authenticate against until this is set --
/// the button still renders, but completing a sign-in will fail.
const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

/// Must be awaited exactly once before any other GoogleSignIn call -- see
/// GoogleSignIn.instance.initialize()'s doc comment. Called from main() before
/// runApp().
Future<void> initGoogleSignIn() async {
  await GoogleSignIn.instance.initialize(clientId: googleClientId.isNotEmpty ? googleClientId : null);
}
