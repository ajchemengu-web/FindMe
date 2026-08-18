/// Ported 1:1 from findme_app/lib/phone.ts's normalizePhone(). Deliberately not full
/// E.164 validation -- just strips characters that carry no information so two
/// different typings of the same number match. See findme_backend_fastapi README's
/// known gaps for what a real implementation would add.
String normalizePhone(String input) => input.replaceAll(RegExp(r'[\s\-()]'), '');
