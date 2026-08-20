import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/token_store.dart';
import '../../core/models/user.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

/// Surfaced by the sign-in/sign-up screens next to the Google button -- separate from
/// AuthController's own state because a failed Google attempt shouldn't clobber
/// whatever error the plain email/password form was already showing, and vice versa.
final googleSignInErrorProvider = StateProvider<String?>((ref) => null);

/// Ported from findme_app/lib/auth.tsx's AuthProvider. state == null means "checked, no
/// session"; state == AsyncLoading only during the initial boot check (mirrors the
/// original's `loading` flag that gates app/_layout.tsx's redirect).
///
/// Google sign-in is event-driven rather than a simple awaited call (both the web GIS
/// button and native `authenticate()` report their result via
/// GoogleSignIn.instance.authenticationEvents), so this subscribes to that stream once
/// on build() rather than exposing a signInWithGoogle() method for the UI to call
/// directly.
class AuthController extends AsyncNotifier<AppUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AppUser?> build() async {
    final sub = GoogleSignIn.instance.authenticationEvents.listen(
      _handleGoogleEvent,
      onError: (Object _) => ref.read(googleSignInErrorProvider.notifier).state = 'Google sign-in failed.',
    );
    ref.onDispose(sub.cancel);

    final accessToken = await TokenStore.instance.getAccessToken();
    if (accessToken == null) return null;
    return _repo.loadProfile();
  }

  Future<void> _handleGoogleEvent(GoogleSignInAuthenticationEvent event) async {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;

    final idToken = event.user.authentication.idToken;
    if (idToken == null) {
      ref.read(googleSignInErrorProvider.notifier).state = "Google didn't return a sign-in token.";
      return;
    }

    ref.read(googleSignInErrorProvider.notifier).state = null;
    state = const AsyncLoading<AppUser?>().copyWithPrevious(state);
    try {
      final user = await _repo.signInWithGoogle(idToken);
      state = AsyncData(user);
    } catch (e) {
      ref.read(googleSignInErrorProvider.notifier).state = e is ApiException ? e.message : 'Google sign-in failed.';
      state = AsyncData(state.valueOrNull);
    }
  }

  Future<String?> signUp({
    required String email,
    required String username,
    required String phone,
    required String password,
    String? referralCode,
  }) async {
    try {
      final user = await _repo.signUp(SignUpInput(email: email, username: username, phone: phone, password: password, referralCode: referralCode));
      state = AsyncData(user);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong signing up.';
    }
  }

  Future<String?> signIn(String identifier, String password) async {
    try {
      final user = await _repo.signIn(identifier, password);
      state = AsyncData(user);
      return null;
    } catch (_) {
      return 'Invalid email, username, phone, or password.';
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncData(null);
  }

  Future<void> refreshProfile() async {
    final user = await _repo.loadProfile();
    state = AsyncData(user);
  }

  /// Returns an error message on failure, null (and updates state) on success.
  Future<String?> updateProfile({String? displayName, String? username, String? email}) async {
    try {
      final user = await _repo.updateProfile(displayName: displayName, username: username, email: email);
      state = AsyncData(user);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong updating your profile.';
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);
