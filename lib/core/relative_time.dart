import 'package:intl/intl.dart';

/// Ported 1:1 from findme_app/lib/relativeTime.ts.
String relativeTime(DateTime then) {
  final diff = DateTime.now().difference(then);
  final diffS = diff.inSeconds < 0 ? 0 : diff.inSeconds;

  if (diffS < 60) return 'just now';
  final diffM = diffS ~/ 60;
  if (diffM < 60) return '${diffM}m ago';
  final diffH = diffM ~/ 60;
  if (diffH < 24) return '${diffH}h ago';
  final diffD = diffH ~/ 24;
  if (diffD < 7) return '${diffD}d ago';
  return DateFormat.yMd().format(then);
}
