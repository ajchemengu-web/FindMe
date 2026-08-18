import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/token_store.dart';
import '../../core/models/user.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

/// Ported from findme_app/lib/auth.tsx's AuthProvider. state == null means "checked, no
/// session"; state == AsyncLoading only during the initial boot check (mirrors the
/// original's `loading` flag that gates app/_layout.tsx's redirect).
class AuthController extends AsyncNotifier<AppUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AppUser?> build() async {
    final accessToken = await TokenStore.instance.getAccessToken();
    if (accessToken == null) return null;
    return _repo.loadProfile();
  }

  Future<String?> signUp({required String email, required String username, required String phone, required String password}) async {
    try {
      final user = await _repo.signUp(SignUpInput(email: email, username: username, phone: phone, password: password));
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
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);
