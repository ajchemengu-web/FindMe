import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridges a Riverpod provider's changes into go_router's `refreshListenable`, so
/// GoRouter re-evaluates its `redirect` callback whenever auth state changes (sign-in,
/// sign-out, initial boot-check resolving).
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref, ProviderListenable listenable) {
    ref.listen(listenable, (_, _) => notifyListeners());
  }
}
