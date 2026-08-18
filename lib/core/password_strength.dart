/// Ported 1:1 from findme_app/lib/passwordStrength.ts. Client-side UX only -- the real
/// enforcement is server-side (see findme_backend_fastapi's validate_password_strength).
const _commonPasswords = {
  'password', 'password1', 'password123', '12345678', '123456789', '1234567890',
  'qwerty123', 'qwertyuiop', 'letmein11', 'letmein123', 'iloveyou1', 'admin1234',
  'welcome11', 'welcome123', 'changeme1', 'findme1234', 'trustno1', 'sunshine1',
  'football1', 'baseball1', 'dragon123', 'monkey123', 'master123', 'abc123456',
};

const _labels = ['Very weak', 'Weak', 'Fair', 'Strong', 'Very strong'];

class PasswordStrengthResult {
  final int score; // 0-4
  final String label;
  final List<String> issues;
  final bool meetsMinimum;

  PasswordStrengthResult({required this.score, required this.label, required this.issues, required this.meetsMinimum});
}

PasswordStrengthResult checkPasswordStrength(String password) {
  final hasLower = RegExp(r'[a-z]').hasMatch(password);
  final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
  final hasDigit = RegExp(r'[0-9]').hasMatch(password);
  final hasSymbol = RegExp(r'[^a-zA-Z0-9]').hasMatch(password);
  final classCount = [hasLower, hasUpper, hasDigit, hasSymbol].where((b) => b).length;
  final isCommon = _commonPasswords.contains(password.toLowerCase());

  final issues = <String>[];
  if (password.length < 10) issues.add('Use at least 10 characters.');
  if (!hasLower) issues.add('Add a lowercase letter.');
  if (!hasUpper) issues.add('Add an uppercase letter.');
  if (!hasDigit) issues.add('Add a number.');
  if (!hasSymbol) issues.add('Add a symbol (e.g. ! ? # -).');
  if (isCommon) issues.add('This password is too common -- pick something less guessable.');

  var score = 0;
  if (password.length >= 10 && classCount >= 2) score = 1;
  if (password.length >= 10 && classCount >= 3) score = 2;
  if (password.length >= 12 && classCount >= 3) score = 3;
  if (password.length >= 14 && classCount == 4) score = 4;
  if (isCommon) score = 0;

  final meetsMinimum = password.length >= 10 && classCount >= 3 && !isCommon;

  return PasswordStrengthResult(score: score, label: _labels[score], issues: issues, meetsMinimum: meetsMinimum);
}
