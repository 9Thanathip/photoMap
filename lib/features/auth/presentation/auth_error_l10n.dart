import '../../../l10n/app_localizations.dart';

/// Maps a stable auth error *code* (thrown by the repository and stored in
/// `AuthState.error`) to a localized, user-facing message.
String localizedAuthError(AppLocalizations l10n, String? code) {
  switch (code) {
    case 'authInvalidEmail':
      return l10n.authInvalidEmail;
    case 'authUserDisabled':
      return l10n.authUserDisabled;
    case 'authInvalidCredentials':
      return l10n.authInvalidCredentials;
    case 'authEmailInUse':
      return l10n.authEmailInUse;
    case 'authWeakPassword':
      return l10n.authWeakPassword;
    case 'authNetworkError':
      return l10n.authNetworkError;
    case 'authRequiresRecentLogin':
      return l10n.authRequiresRecentLogin;
    case 'authTooManyRequests':
      return l10n.authTooManyRequests;
    default:
      return l10n.authFailed;
  }
}
