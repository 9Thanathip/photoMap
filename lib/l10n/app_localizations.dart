import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('th'),
  ];

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customize your experience'**
  String get settingsSubtitle;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @sectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get sectionGeneral;

  /// No description provided for @sectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get sectionAccount;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @appTheme.
  ///
  /// In en, this message translates to:
  /// **'App Theme'**
  String get appTheme;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @defaultUserName.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get defaultUserName;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileAccountStatus.
  ///
  /// In en, this message translates to:
  /// **'Account Status'**
  String get profileAccountStatus;

  /// No description provided for @profileVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get profileVerified;

  /// No description provided for @profileUnverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get profileUnverified;

  /// No description provided for @profileVerifiedAccount.
  ///
  /// In en, this message translates to:
  /// **'Verified account'**
  String get profileVerifiedAccount;

  /// No description provided for @profileSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get profileSignOut;

  /// No description provided for @sectionDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get sectionDangerZone;

  /// No description provided for @profileManageAccount.
  ///
  /// In en, this message translates to:
  /// **'Manage Account'**
  String get profileManageAccount;

  /// No description provided for @profileManageAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account and other actions'**
  String get profileManageAccountSubtitle;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirmBody;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountIntro.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account is irreversible. Please review what happens before continuing.'**
  String get deleteAccountIntro;

  /// No description provided for @deleteConsequencePhotos.
  ///
  /// In en, this message translates to:
  /// **'All your photos and their map locations will be removed'**
  String get deleteConsequencePhotos;

  /// No description provided for @deleteConsequenceAchievements.
  ///
  /// In en, this message translates to:
  /// **'Your province achievements and progress will be lost'**
  String get deleteConsequenceAchievements;

  /// No description provided for @deleteConsequencePermanent.
  ///
  /// In en, this message translates to:
  /// **'This action is permanent and cannot be undone'**
  String get deleteConsequencePermanent;

  /// No description provided for @deleteAccountAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I understand this will permanently delete my account and all my data.'**
  String get deleteAccountAcknowledge;

  /// No description provided for @deleteAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Delete My Account'**
  String get deleteAccountButton;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This is your final confirmation. Your account and all data will be permanently deleted.'**
  String get deleteConfirmBody;

  /// No description provided for @deleteConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteConfirmAction;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @fieldFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fieldFullName;

  /// No description provided for @fieldConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get fieldConfirmPassword;

  /// No description provided for @validationEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get validationEmailRequired;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get validationEmailInvalid;

  /// No description provided for @validationPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get validationPasswordRequired;

  /// No description provided for @validationNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get validationNameRequired;

  /// No description provided for @validationPasswordMin.
  ///
  /// In en, this message translates to:
  /// **'Minimum 6 characters'**
  String get validationPasswordMin;

  /// No description provided for @validationPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get validationPasswordMismatch;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome\nBack'**
  String get loginWelcomeBack;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue your journey'**
  String get loginSubtitle;

  /// No description provided for @buttonSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get buttonSignIn;

  /// No description provided for @loginNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get loginNoAccount;

  /// No description provided for @buttonRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get buttonRegister;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create\nAccount'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start mapping your memories today'**
  String get registerSubtitle;

  /// No description provided for @buttonCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get buttonCreateAccount;

  /// No description provided for @registerHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get registerHaveAccount;

  /// No description provided for @onboard1Title.
  ///
  /// In en, this message translates to:
  /// **'Capture Your\nMoments'**
  String get onboard1Title;

  /// No description provided for @onboard1Body.
  ///
  /// In en, this message translates to:
  /// **'Organize and edit your photos with a beautiful, intuitive gallery experience.'**
  String get onboard1Body;

  /// No description provided for @onboard2Title.
  ///
  /// In en, this message translates to:
  /// **'Map Your\nJourney'**
  String get onboard2Title;

  /// No description provided for @onboard2Body.
  ///
  /// In en, this message translates to:
  /// **'Pin your photos to locations and explore your memories on an interactive map.'**
  String get onboard2Body;

  /// No description provided for @onboard3Title.
  ///
  /// In en, this message translates to:
  /// **'Explore\nThailand'**
  String get onboard3Title;

  /// No description provided for @onboard3Body.
  ///
  /// In en, this message translates to:
  /// **'Discover all 77 provinces and unlock achievements as you travel the kingdom.'**
  String get onboard3Body;

  /// No description provided for @buttonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get buttonSkip;

  /// No description provided for @buttonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get buttonNext;

  /// No description provided for @buttonGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get buttonGetStarted;

  /// No description provided for @verifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your\nemail'**
  String get verifyTitle;

  /// No description provided for @verifyBodyPrefix.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to '**
  String get verifyBodyPrefix;

  /// No description provided for @verifyYourEmail.
  ///
  /// In en, this message translates to:
  /// **'your email'**
  String get verifyYourEmail;

  /// No description provided for @verifyBodySuffix.
  ///
  /// In en, this message translates to:
  /// **'. Open it, then come back here — this screen updates automatically.'**
  String get verifyBodySuffix;

  /// No description provided for @verifyContinue.
  ///
  /// In en, this message translates to:
  /// **'I\'ve verified — Continue'**
  String get verifyContinue;

  /// No description provided for @verifyResend.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get verifyResend;

  /// No description provided for @verifyResendCooldown.
  ///
  /// In en, this message translates to:
  /// **'Resend email ({seconds}s)'**
  String verifyResendCooldown(Object seconds);

  /// No description provided for @verifyUseAnotherAccount.
  ///
  /// In en, this message translates to:
  /// **'Use another account'**
  String get verifyUseAnotherAccount;

  /// No description provided for @verifyNotVerifiedYet.
  ///
  /// In en, this message translates to:
  /// **'Not verified yet. Open the link in your email first.'**
  String get verifyNotVerifiedYet;

  /// No description provided for @verifyEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent.'**
  String get verifyEmailSent;

  /// No description provided for @authOrDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOrDivider;

  /// No description provided for @buttonContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get buttonContinueWithGoogle;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address.'**
  String get authInvalidEmail;

  /// No description provided for @authUserDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get authUserDisabled;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get authInvalidCredentials;

  /// No description provided for @authEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered.'**
  String get authEmailInUse;

  /// No description provided for @authWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak (min 6 characters).'**
  String get authWeakPassword;

  /// No description provided for @authNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection.'**
  String get authNetworkError;

  /// No description provided for @authRequiresRecentLogin.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to continue.'**
  String get authRequiresRecentLogin;

  /// No description provided for @authTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get authTooManyRequests;

  /// No description provided for @authFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed.'**
  String get authFailed;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @errorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Photo permission denied. Please allow access in Settings.'**
  String get errorPermissionDenied;

  /// No description provided for @errorLoadPhotos.
  ///
  /// In en, this message translates to:
  /// **'Failed to load photos. Please try again.'**
  String get errorLoadPhotos;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get commonSelect;

  /// No description provided for @monthJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthJan;

  /// No description provided for @monthFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthFeb;

  /// No description provided for @monthMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthMar;

  /// No description provided for @monthApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthApr;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthJun;

  /// No description provided for @monthJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthJul;

  /// No description provided for @monthAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthAug;

  /// No description provided for @monthSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthSep;

  /// No description provided for @monthOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthOct;

  /// No description provided for @monthNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthNov;

  /// No description provided for @monthDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthDec;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// No description provided for @navAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get navAchievements;

  /// No description provided for @deletePhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Photos'**
  String get deletePhotosTitle;

  /// No description provided for @deletePhotosBody.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} photos?'**
  String deletePhotosBody(Object count);

  /// No description provided for @galleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galleryTitle;

  /// No description provided for @tabPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get tabPhotos;

  /// No description provided for @tabAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get tabAlbums;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get deselectAll;

  /// No description provided for @selectItems.
  ///
  /// In en, this message translates to:
  /// **'Select Items'**
  String get selectItems;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Selected'**
  String selectedCount(Object count);

  /// No description provided for @viewModeTitle.
  ///
  /// In en, this message translates to:
  /// **'View Mode'**
  String get viewModeTitle;

  /// No description provided for @viewModeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get viewModeAll;

  /// No description provided for @viewModeYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get viewModeYear;

  /// No description provided for @viewModeMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get viewModeMonth;

  /// No description provided for @viewModeDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get viewModeDay;

  /// No description provided for @deletePhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Photo'**
  String get deletePhotoTitle;

  /// No description provided for @deletePhotoBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this photo?'**
  String get deletePhotoBody;

  /// No description provided for @noPhotosFound.
  ///
  /// In en, this message translates to:
  /// **'No photos found'**
  String get noPhotosFound;

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your photo library is empty'**
  String get libraryEmpty;

  /// No description provided for @detectingLocations.
  ///
  /// In en, this message translates to:
  /// **'Detecting locations...'**
  String get detectingLocations;

  /// No description provided for @photosAppearShortly.
  ///
  /// In en, this message translates to:
  /// **'Your photos will appear shortly'**
  String get photosAppearShortly;

  /// No description provided for @photoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String photoCount(int count);

  /// No description provided for @noPhotosHere.
  ///
  /// In en, this message translates to:
  /// **'No photos here'**
  String get noPhotosHere;

  /// No description provided for @noAlbumsFound.
  ///
  /// In en, this message translates to:
  /// **'No albums found'**
  String get noAlbumsFound;

  /// No description provided for @noAlbumsIn.
  ///
  /// In en, this message translates to:
  /// **'No albums in {country}'**
  String noAlbumsIn(Object country);

  /// No description provided for @noPhotosIn.
  ///
  /// In en, this message translates to:
  /// **'No photos in {country}'**
  String noPhotosIn(Object country);

  /// No description provided for @setLocation.
  ///
  /// In en, this message translates to:
  /// **'Set Location'**
  String get setLocation;

  /// No description provided for @addToAlbums.
  ///
  /// In en, this message translates to:
  /// **'Add to Albums'**
  String get addToAlbums;

  /// No description provided for @locationSetTo.
  ///
  /// In en, this message translates to:
  /// **'Location set to {province}'**
  String locationSetTo(Object province);

  /// No description provided for @addedTo.
  ///
  /// In en, this message translates to:
  /// **'Added to {province}'**
  String addedTo(Object province);

  /// No description provided for @searchPlaceHint.
  ///
  /// In en, this message translates to:
  /// **'Search place…'**
  String get searchPlaceHint;

  /// No description provided for @searchForPlace.
  ///
  /// In en, this message translates to:
  /// **'Search for a place'**
  String get searchForPlace;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @cannotConnect.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect. Check internet connection.'**
  String get cannotConnect;

  /// No description provided for @settingLocationTo.
  ///
  /// In en, this message translates to:
  /// **'Setting location to {place}…'**
  String settingLocationTo(Object place);

  /// No description provided for @failedWriteGps.
  ///
  /// In en, this message translates to:
  /// **'Failed to write GPS to photo file'**
  String get failedWriteGps;

  /// No description provided for @exifUnknownCamera.
  ///
  /// In en, this message translates to:
  /// **'Unknown Camera'**
  String get exifUnknownCamera;

  /// No description provided for @exifStandardLens.
  ///
  /// In en, this message translates to:
  /// **'Standard Lens'**
  String get exifStandardLens;

  /// No description provided for @exifVideoRecording.
  ///
  /// In en, this message translates to:
  /// **'Video Recording'**
  String get exifVideoRecording;

  /// No description provided for @exifMainVideo.
  ///
  /// In en, this message translates to:
  /// **'Main Video'**
  String get exifMainVideo;

  /// No description provided for @infoResolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get infoResolution;

  /// No description provided for @infoQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get infoQuality;

  /// No description provided for @infoIso.
  ///
  /// In en, this message translates to:
  /// **'ISO'**
  String get infoIso;

  /// No description provided for @infoExposure.
  ///
  /// In en, this message translates to:
  /// **'Exposure'**
  String get infoExposure;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @openInAppleMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Apple Maps'**
  String get openInAppleMaps;

  /// No description provided for @openInGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get openInGoogleMaps;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get weekdaySun;

  /// No description provided for @editorPresets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get editorPresets;

  /// No description provided for @editorAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get editorAdjust;

  /// No description provided for @editorReset.
  ///
  /// In en, this message translates to:
  /// **'Reset Adjustments'**
  String get editorReset;

  /// No description provided for @adjExposure.
  ///
  /// In en, this message translates to:
  /// **'Exposure'**
  String get adjExposure;

  /// No description provided for @adjContrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get adjContrast;

  /// No description provided for @adjSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get adjSaturation;

  /// No description provided for @adjTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get adjTemperature;

  /// No description provided for @adjTint.
  ///
  /// In en, this message translates to:
  /// **'Tint'**
  String get adjTint;

  /// No description provided for @editorSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to Photos'**
  String get editorSaved;

  /// No description provided for @editorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save photo'**
  String get editorSaveFailed;

  /// No description provided for @adjFade.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get adjFade;

  /// No description provided for @adjGrain.
  ///
  /// In en, this message translates to:
  /// **'Grain'**
  String get adjGrain;

  /// No description provided for @adjVignette.
  ///
  /// In en, this message translates to:
  /// **'Vignette'**
  String get adjVignette;

  /// No description provided for @adjLightLeak.
  ///
  /// In en, this message translates to:
  /// **'Light Leak'**
  String get adjLightLeak;

  /// No description provided for @presetOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get presetOriginal;

  /// No description provided for @presetMoody.
  ///
  /// In en, this message translates to:
  /// **'Moody'**
  String get presetMoody;

  /// No description provided for @presetVibrant.
  ///
  /// In en, this message translates to:
  /// **'Vibrant'**
  String get presetVibrant;

  /// No description provided for @presetVintage.
  ///
  /// In en, this message translates to:
  /// **'Vintage'**
  String get presetVintage;

  /// No description provided for @presetPolaroid.
  ///
  /// In en, this message translates to:
  /// **'Polaroid'**
  String get presetPolaroid;

  /// No description provided for @presetBw.
  ///
  /// In en, this message translates to:
  /// **'B&W'**
  String get presetBw;

  /// No description provided for @mapSavedToPhotos.
  ///
  /// In en, this message translates to:
  /// **'Saved to Photos'**
  String get mapSavedToPhotos;

  /// No description provided for @mapSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save image'**
  String get mapSaveFailed;

  /// No description provided for @mapNoData.
  ///
  /// In en, this message translates to:
  /// **'No Map Data Found'**
  String get mapNoData;

  /// No description provided for @mapNoPhotosByDistrict.
  ///
  /// In en, this message translates to:
  /// **'No photos categorized by district'**
  String get mapNoPhotosByDistrict;

  /// No description provided for @provinceGallerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Photos you take here will appear here.'**
  String get provinceGallerySubtitle;

  /// No description provided for @menuViewDistricts.
  ///
  /// In en, this message translates to:
  /// **'View by Districts'**
  String get menuViewDistricts;

  /// No description provided for @menuViewDistrictsSub.
  ///
  /// In en, this message translates to:
  /// **'Browse photos by district'**
  String get menuViewDistrictsSub;

  /// No description provided for @menuViewGallery.
  ///
  /// In en, this message translates to:
  /// **'View Gallery'**
  String get menuViewGallery;

  /// No description provided for @menuViewGallerySub.
  ///
  /// In en, this message translates to:
  /// **'All photos in this province'**
  String get menuViewGallerySub;

  /// No description provided for @menuChangeCover.
  ///
  /// In en, this message translates to:
  /// **'Change Cover Photo'**
  String get menuChangeCover;

  /// No description provided for @menuChangeCoverSub.
  ///
  /// In en, this message translates to:
  /// **'Pick which photo appears on the map'**
  String get menuChangeCoverSub;

  /// No description provided for @mapSettingsProvince.
  ///
  /// In en, this message translates to:
  /// **'Province'**
  String get mapSettingsProvince;

  /// No description provided for @mapSettingsBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get mapSettingsBackground;

  /// No description provided for @mapSettingsBorder.
  ///
  /// In en, this message translates to:
  /// **'Border'**
  String get mapSettingsBorder;

  /// No description provided for @mapSettingsColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get mapSettingsColor;

  /// No description provided for @mapSettingsWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get mapSettingsWidth;

  /// No description provided for @mapSettingsApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get mapSettingsApply;

  /// No description provided for @mapSettingsProvinceColor.
  ///
  /// In en, this message translates to:
  /// **'Province Color'**
  String get mapSettingsProvinceColor;

  /// No description provided for @mapSettingsBackgroundColor.
  ///
  /// In en, this message translates to:
  /// **'Background Color'**
  String get mapSettingsBackgroundColor;

  /// No description provided for @mapSettingsBorderColor.
  ///
  /// In en, this message translates to:
  /// **'Border Color'**
  String get mapSettingsBorderColor;

  /// No description provided for @mapBackToPresets.
  ///
  /// In en, this message translates to:
  /// **'Back to presets'**
  String get mapBackToPresets;

  /// No description provided for @mapHue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get mapHue;

  /// No description provided for @mapSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get mapSaturation;

  /// No description provided for @mapBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get mapBrightness;

  /// No description provided for @mapCustomColor.
  ///
  /// In en, this message translates to:
  /// **'Custom Color'**
  String get mapCustomColor;

  /// No description provided for @mapResetColor.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get mapResetColor;

  /// No description provided for @tooltipBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get tooltipBackground;

  /// No description provided for @tooltipCenterMap.
  ///
  /// In en, this message translates to:
  /// **'Center Map'**
  String get tooltipCenterMap;

  /// No description provided for @tooltipSaveToPhotos.
  ///
  /// In en, this message translates to:
  /// **'Save to Photos'**
  String get tooltipSaveToPhotos;

  /// No description provided for @tooltipShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get tooltipShare;

  /// No description provided for @tooltipColors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get tooltipColors;

  /// No description provided for @tooltipCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get tooltipCenter;

  /// No description provided for @tooltipShareMap.
  ///
  /// In en, this message translates to:
  /// **'Share Map'**
  String get tooltipShareMap;

  /// No description provided for @tooltipDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get tooltipDownload;

  /// No description provided for @tooltipDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get tooltipDelete;

  /// No description provided for @countryTitle.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get countryTitle;

  /// No description provided for @searchCountries.
  ///
  /// In en, this message translates to:
  /// **'Search countries'**
  String get searchCountries;

  /// No description provided for @noCountriesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No countries available'**
  String get noCountriesAvailable;

  /// No description provided for @noResultsFor.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String noResultsFor(Object query);

  /// No description provided for @coverSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Cover Photo'**
  String get coverSetTitle;

  /// No description provided for @coverAdjustHint.
  ///
  /// In en, this message translates to:
  /// **'Move and pinch to adjust'**
  String get coverAdjustHint;

  /// No description provided for @coverUsePhoto.
  ///
  /// In en, this message translates to:
  /// **'Use Photo'**
  String get coverUsePhoto;

  /// No description provided for @coverArea.
  ///
  /// In en, this message translates to:
  /// **'Cover area'**
  String get coverArea;

  /// No description provided for @coverTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a photo to set as cover'**
  String get coverTapHint;

  /// No description provided for @placesTitle.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get placesTitle;

  /// No description provided for @provincesExplored.
  ///
  /// In en, this message translates to:
  /// **'{visited} of {total} provinces explored'**
  String provincesExplored(Object visited, Object total);

  /// No description provided for @provincesProgress.
  ///
  /// In en, this message translates to:
  /// **'{visited} / {total} provinces'**
  String provincesProgress(Object visited, Object total);

  /// No description provided for @thailandExplorer.
  ///
  /// In en, this message translates to:
  /// **'Thailand Explorer'**
  String get thailandExplorer;

  /// No description provided for @provincesRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} provinces remaining'**
  String provincesRemaining(Object count);

  /// No description provided for @noPhotosYet.
  ///
  /// In en, this message translates to:
  /// **'No photos yet — start exploring!'**
  String get noPhotosYet;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageThai.
  ///
  /// In en, this message translates to:
  /// **'ไทย'**
  String get languageThai;

  /// No description provided for @setupPreparingAtlas.
  ///
  /// In en, this message translates to:
  /// **'Preparing Your Atlas'**
  String get setupPreparingAtlas;

  /// No description provided for @setupIndexingPhotos.
  ///
  /// In en, this message translates to:
  /// **'Indexing and organizing your photos\n({processed} / {total})'**
  String setupIndexingPhotos(Object processed, Object total);

  /// No description provided for @setupFirstLaunchNote.
  ///
  /// In en, this message translates to:
  /// **'This setup only happens on the first launch\nto map your travels safely.'**
  String get setupFirstLaunchNote;

  /// No description provided for @frameTitle.
  ///
  /// In en, this message translates to:
  /// **'Frame'**
  String get frameTitle;

  /// No description provided for @frameStyleBottomBar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get frameStyleBottomBar;

  /// No description provided for @frameStyleFullBorder.
  ///
  /// In en, this message translates to:
  /// **'Border'**
  String get frameStyleFullBorder;

  /// No description provided for @frameStyleMinimal.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get frameStyleMinimal;

  /// No description provided for @frameSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get frameSave;

  /// No description provided for @frameShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get frameShare;

  /// No description provided for @frameSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to Photos'**
  String get frameSaved;

  /// No description provided for @frameSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save frame'**
  String get frameSaveFailed;

  /// No description provided for @frameTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get frameTextSize;

  /// No description provided for @frameSize.
  ///
  /// In en, this message translates to:
  /// **'Frame'**
  String get frameSize;

  /// No description provided for @collageTitle.
  ///
  /// In en, this message translates to:
  /// **'Collage'**
  String get collageTitle;

  /// No description provided for @collageAddPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get collageAddPhotos;

  /// No description provided for @collageColorSort.
  ///
  /// In en, this message translates to:
  /// **'Color gradient'**
  String get collageColorSort;

  /// No description provided for @achExplorerLabel.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get achExplorerLabel;

  /// No description provided for @achExplorerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Province Explorer'**
  String get achExplorerSubtitle;

  /// No description provided for @achExplored.
  ///
  /// In en, this message translates to:
  /// **'explored'**
  String get achExplored;

  /// No description provided for @achProvincesVisited.
  ///
  /// In en, this message translates to:
  /// **'provinces visited'**
  String get achProvincesVisited;

  /// No description provided for @achLeftToExplore.
  ///
  /// In en, this message translates to:
  /// **'left to explore'**
  String get achLeftToExplore;

  /// No description provided for @collagePickerHint.
  ///
  /// In en, this message translates to:
  /// **'Grid {filled}/{total} filled'**
  String collagePickerHint(int filled, int total);

  /// No description provided for @collageRows.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get collageRows;

  /// No description provided for @collageCols.
  ///
  /// In en, this message translates to:
  /// **'Cols'**
  String get collageCols;

  /// No description provided for @collageGap.
  ///
  /// In en, this message translates to:
  /// **'Gap'**
  String get collageGap;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'th'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'th':
      return AppLocalizationsTh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
