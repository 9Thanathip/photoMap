// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle => 'Customize your experience';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get sectionGeneral => 'General';

  @override
  String get sectionAccount => 'Account';

  @override
  String get sectionAbout => 'About';

  @override
  String get appTheme => 'App Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsVersion => 'Version';

  @override
  String get defaultUserName => 'User';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileAccountStatus => 'Account Status';

  @override
  String get profileVerified => 'Verified';

  @override
  String get profileUnverified => 'Unverified';

  @override
  String get profileVerifiedAccount => 'Verified account';

  @override
  String get profileSignOut => 'Sign Out';

  @override
  String get sectionDangerZone => 'Danger Zone';

  @override
  String get profileManageAccount => 'Manage Account';

  @override
  String get profileManageAccountSubtitle => 'Delete account and other actions';

  @override
  String get signOutConfirmTitle => 'Sign Out';

  @override
  String get signOutConfirmBody => 'Are you sure you want to sign out?';

  @override
  String get deleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountIntro =>
      'Deleting your account is irreversible. Please review what happens before continuing.';

  @override
  String get deleteConsequencePhotos =>
      'All your photos and their map locations will be removed';

  @override
  String get deleteConsequenceAchievements =>
      'Your province achievements and progress will be lost';

  @override
  String get deleteConsequencePermanent =>
      'This action is permanent and cannot be undone';

  @override
  String get deleteAccountAcknowledge =>
      'I understand this will permanently delete my account and all my data.';

  @override
  String get deleteAccountButton => 'Delete My Account';

  @override
  String get deleteConfirmTitle => 'Delete Account?';

  @override
  String get deleteConfirmBody =>
      'This is your final confirmation. Your account and all data will be permanently deleted.';

  @override
  String get deleteConfirmAction => 'Delete';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldFullName => 'Full Name';

  @override
  String get fieldConfirmPassword => 'Confirm Password';

  @override
  String get validationEmailRequired => 'Email is required';

  @override
  String get validationEmailInvalid => 'Enter a valid email';

  @override
  String get validationPasswordRequired => 'Password is required';

  @override
  String get validationNameRequired => 'Name is required';

  @override
  String get validationPasswordMin => 'Minimum 6 characters';

  @override
  String get validationPasswordMismatch => 'Passwords do not match';

  @override
  String get loginWelcomeBack => 'Welcome\nBack';

  @override
  String get loginSubtitle => 'Sign in to continue your journey';

  @override
  String get buttonSignIn => 'Sign In';

  @override
  String get loginNoAccount => 'Don\'t have an account? ';

  @override
  String get buttonRegister => 'Register';

  @override
  String get registerTitle => 'Create\nAccount';

  @override
  String get registerSubtitle => 'Start mapping your memories today';

  @override
  String get buttonCreateAccount => 'Create Account';

  @override
  String get registerHaveAccount => 'Already have an account? ';

  @override
  String get onboard1Title => 'Capture Your\nMoments';

  @override
  String get onboard1Body =>
      'Organize and edit your photos with a beautiful, intuitive gallery experience.';

  @override
  String get onboard2Title => 'Map Your\nJourney';

  @override
  String get onboard2Body =>
      'Pin your photos to locations and explore your memories on an interactive map.';

  @override
  String get onboard3Title => 'Explore\nThailand';

  @override
  String get onboard3Body =>
      'Discover all 77 provinces and unlock achievements as you travel the kingdom.';

  @override
  String get buttonSkip => 'Skip';

  @override
  String get buttonNext => 'Next';

  @override
  String get buttonGetStarted => 'Get Started';

  @override
  String get verifyTitle => 'Verify your\nemail';

  @override
  String get verifyBodyPrefix => 'We sent a verification link to ';

  @override
  String get verifyYourEmail => 'your email';

  @override
  String get verifyBodySuffix =>
      '. Open it, then come back here — this screen updates automatically.';

  @override
  String get verifyContinue => 'I\'ve verified — Continue';

  @override
  String get verifyResend => 'Resend email';

  @override
  String verifyResendCooldown(Object seconds) {
    return 'Resend email (${seconds}s)';
  }

  @override
  String get verifyUseAnotherAccount => 'Use another account';

  @override
  String get verifyNotVerifiedYet =>
      'Not verified yet. Open the link in your email first.';

  @override
  String get verifyEmailSent => 'Verification email sent.';

  @override
  String get authOrDivider => 'or';

  @override
  String get buttonContinueWithGoogle => 'Continue with Google';

  @override
  String get authInvalidEmail => 'Invalid email address.';

  @override
  String get authUserDisabled => 'This account has been disabled.';

  @override
  String get authInvalidCredentials => 'Incorrect email or password.';

  @override
  String get authEmailInUse => 'This email is already registered.';

  @override
  String get authWeakPassword => 'Password is too weak (min 6 characters).';

  @override
  String get authNetworkError => 'Network error. Check your connection.';

  @override
  String get authRequiresRecentLogin => 'Please sign in again to continue.';

  @override
  String get authTooManyRequests => 'Too many attempts. Try again later.';

  @override
  String get authFailed => 'Authentication failed.';

  @override
  String get commonError => 'Error';

  @override
  String get errorPermissionDenied =>
      'Photo permission denied. Please allow access in Settings.';

  @override
  String get errorLoadPhotos => 'Failed to load photos. Please try again.';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonDone => 'Done';

  @override
  String get commonSelect => 'Select';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Apr';

  @override
  String get monthMay => 'May';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Aug';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'Oct';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dec';

  @override
  String get navMap => 'Map';

  @override
  String get navAchievements => 'Achievements';

  @override
  String get deletePhotosTitle => 'Delete Photos';

  @override
  String deletePhotosBody(Object count) {
    return 'Delete $count photos?';
  }

  @override
  String get galleryTitle => 'Gallery';

  @override
  String get tabPhotos => 'Photos';

  @override
  String get tabAlbums => 'Albums';

  @override
  String get selectAll => 'Select All';

  @override
  String get deselectAll => 'Deselect All';

  @override
  String get selectItems => 'Select Items';

  @override
  String selectedCount(Object count) {
    return '$count Selected';
  }

  @override
  String get viewModeTitle => 'View Mode';

  @override
  String get viewModeAll => 'All';

  @override
  String get viewModeYear => 'Year';

  @override
  String get viewModeMonth => 'Month';

  @override
  String get viewModeDay => 'Day';

  @override
  String get viewModeHue => 'Color Gradient';

  @override
  String get viewModeHueSorting => 'Sorting by color…';

  @override
  String get deletePhotoTitle => 'Delete Photo';

  @override
  String get deletePhotoBody => 'Are you sure you want to delete this photo?';

  @override
  String get noPhotosFound => 'No photos found';

  @override
  String get libraryEmpty => 'Your photo library is empty';

  @override
  String get detectingLocations => 'Detecting locations...';

  @override
  String get photosAppearShortly => 'Your photos will appear shortly';

  @override
  String photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get noPhotosHere => 'No photos here';

  @override
  String get noAlbumsFound => 'No albums found';

  @override
  String noAlbumsIn(Object country) {
    return 'No albums in $country';
  }

  @override
  String noPhotosIn(Object country) {
    return 'No photos in $country';
  }

  @override
  String get setLocation => 'Set Location';

  @override
  String get addToAlbums => 'Add to Albums';

  @override
  String locationSetTo(Object province) {
    return 'Location set to $province';
  }

  @override
  String addedTo(Object province) {
    return 'Added to $province';
  }

  @override
  String get searchPlaceHint => 'Search place…';

  @override
  String get searchForPlace => 'Search for a place';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get cannotConnect => 'Cannot connect. Check internet connection.';

  @override
  String settingLocationTo(Object place) {
    return 'Setting location to $place…';
  }

  @override
  String get failedWriteGps => 'Failed to write GPS to photo file';

  @override
  String get exifUnknownCamera => 'Unknown Camera';

  @override
  String get exifStandardLens => 'Standard Lens';

  @override
  String get exifVideoRecording => 'Video Recording';

  @override
  String get exifMainVideo => 'Main Video';

  @override
  String get infoResolution => 'Resolution';

  @override
  String get infoQuality => 'Quality';

  @override
  String get infoIso => 'ISO';

  @override
  String get infoExposure => 'Exposure';

  @override
  String get locationLabel => 'Location';

  @override
  String get openInAppleMaps => 'Open in Apple Maps';

  @override
  String get openInGoogleMaps => 'Open in Google Maps';

  @override
  String get weekdayMon => 'Monday';

  @override
  String get weekdayTue => 'Tuesday';

  @override
  String get weekdayWed => 'Wednesday';

  @override
  String get weekdayThu => 'Thursday';

  @override
  String get weekdayFri => 'Friday';

  @override
  String get weekdaySat => 'Saturday';

  @override
  String get weekdaySun => 'Sunday';

  @override
  String get editorPresets => 'Presets';

  @override
  String get editorAdjust => 'Adjust';

  @override
  String get editorReset => 'Reset Adjustments';

  @override
  String get adjExposure => 'Exposure';

  @override
  String get adjContrast => 'Contrast';

  @override
  String get adjSaturation => 'Saturation';

  @override
  String get adjTemperature => 'Temperature';

  @override
  String get adjTint => 'Tint';

  @override
  String get editorSaved => 'Saved to Photos';

  @override
  String get editorSaveFailed => 'Failed to save photo';

  @override
  String get adjFade => 'Fade';

  @override
  String get adjGrain => 'Grain';

  @override
  String get adjVignette => 'Vignette';

  @override
  String get adjLightLeak => 'Light Leak';

  @override
  String get editorLocal => 'Local';

  @override
  String get adjShadows => 'Shadows';

  @override
  String get adjHighlights => 'Highlights';

  @override
  String get adjWarmth => 'Warmth';

  @override
  String get localMaskRadial => 'Radial';

  @override
  String get localMaskLinear => 'Linear';

  @override
  String get localMaskBrush => 'Brush';

  @override
  String get localAddMaskHint => 'Add a mask to adjust part of the photo';

  @override
  String get localSize => 'Size';

  @override
  String get localFeather => 'Feather';

  @override
  String get localBrushSize => 'Brush Size';

  @override
  String get localShowMask => 'Show Mask';

  @override
  String get localAdd => 'Add';

  @override
  String get localErase => 'Erase';

  @override
  String get localAmount => 'Amount';

  @override
  String get localFlow => 'Flow';

  @override
  String get localInvert => 'Invert';

  @override
  String get editorUndo => 'Undo';

  @override
  String get editorHeal => 'Remove';

  @override
  String get healHint => 'Brush over anything you want gone';

  @override
  String get healWorking => 'Removing…';

  @override
  String healCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots removed',
      one: '1 spot removed',
    );
    return '$_temp0';
  }

  @override
  String get presetOriginal => 'Original';

  @override
  String get presetMoody => 'Moody';

  @override
  String get presetVibrant => 'Vibrant';

  @override
  String get presetVintage => 'Vintage';

  @override
  String get presetPolaroid => 'Polaroid';

  @override
  String get presetBw => 'B&W';

  @override
  String get mapSavedToPhotos => 'Saved to Photos';

  @override
  String get mapSaveFailed => 'Failed to save image';

  @override
  String get statsTopProvinces => 'Most Photographed';

  @override
  String get tripsTitle => 'Trips';

  @override
  String tripsCount(int count) {
    return '$count trips';
  }

  @override
  String tripDays(int days) {
    return '$days days';
  }

  @override
  String tripDaysShort(int days) {
    return '${days}d';
  }

  @override
  String tripDaysNights(int days, int nights) {
    return '$days days, $nights nights';
  }

  @override
  String tripDaysNightsShort(int days, int nights) {
    return '${days}d ${nights}n';
  }

  @override
  String tripStops(int count) {
    return '$count stops';
  }

  @override
  String get tripsEmptyTitle => 'No trips yet';

  @override
  String get tripsEmptySubtitle =>
      'Trips appear automatically from photos taken away from home.';

  @override
  String get shareCardTitle => 'Share Card';

  @override
  String shareCardProvinces(int visited, int total) {
    return '$visited of $total provinces';
  }

  @override
  String shareCardExplored(int percent) {
    return '$percent% explored';
  }

  @override
  String shareCardPhotos(int count) {
    return '$count photos';
  }

  @override
  String get mapNoData => 'No Map Data Found';

  @override
  String get mapNoPhotosByDistrict => 'No photos categorized by district';

  @override
  String get provinceGallerySubtitle =>
      'Photos you take here will appear here.';

  @override
  String get menuViewDistricts => 'View by Districts';

  @override
  String get menuViewDistrictsSub => 'Browse photos by district';

  @override
  String get menuViewGallery => 'View Gallery';

  @override
  String get menuViewGallerySub => 'All photos in this province';

  @override
  String get menuChangeCover => 'Change Cover Photo';

  @override
  String get menuChangeCoverSub => 'Pick which photo appears on the map';

  @override
  String get mapSettingsProvince => 'Province';

  @override
  String get mapSettingsBackground => 'Background';

  @override
  String get mapSettingsBorder => 'Border';

  @override
  String get mapSettingsColor => 'Color';

  @override
  String get mapSettingsWidth => 'Width';

  @override
  String get mapSettingsApply => 'Apply';

  @override
  String get mapSettingsProvinceColor => 'Province Color';

  @override
  String get mapSettingsBackgroundColor => 'Background Color';

  @override
  String get mapSettingsBorderColor => 'Border Color';

  @override
  String get mapBackToPresets => 'Back to presets';

  @override
  String get mapHue => 'Hue';

  @override
  String get mapSaturation => 'Saturation';

  @override
  String get mapBrightness => 'Brightness';

  @override
  String get mapCustomColor => 'Custom Color';

  @override
  String get mapResetColor => 'Reset';

  @override
  String get tooltipBackground => 'Background';

  @override
  String get tooltipCenterMap => 'Center Map';

  @override
  String get tooltipSaveToPhotos => 'Save to Photos';

  @override
  String get tooltipShare => 'Share';

  @override
  String get tooltipColors => 'Colors';

  @override
  String get tooltipCenter => 'Center';

  @override
  String get tooltipShareMap => 'Share Map';

  @override
  String get tooltipDownload => 'Download';

  @override
  String get tooltipDelete => 'Delete';

  @override
  String get countryTitle => 'Country';

  @override
  String get searchCountries => 'Search countries';

  @override
  String get noCountriesAvailable => 'No countries available';

  @override
  String noResultsFor(Object query) {
    return 'No results for \"$query\"';
  }

  @override
  String get coverSetTitle => 'Set Cover Photo';

  @override
  String get coverAdjustHint => 'Move and pinch to adjust';

  @override
  String get coverUsePhoto => 'Use Photo';

  @override
  String get coverArea => 'Cover area';

  @override
  String get coverTapHint => 'Tap a photo to set as cover';

  @override
  String get placesTitle => 'Places';

  @override
  String provincesExplored(Object visited, Object total) {
    return '$visited of $total provinces explored';
  }

  @override
  String provincesProgress(Object visited, Object total) {
    return '$visited / $total provinces';
  }

  @override
  String get thailandExplorer => 'Thailand Explorer';

  @override
  String provincesRemaining(Object count) {
    return '$count provinces remaining';
  }

  @override
  String get noPhotosYet => 'No photos yet — start exploring!';

  @override
  String get viewAll => 'View All';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageThai => 'ไทย';

  @override
  String get setupPreparingAtlas => 'Preparing Your Atlas';

  @override
  String setupIndexingPhotos(Object processed, Object total) {
    return 'Indexing and organizing your photos\n($processed / $total)';
  }

  @override
  String get setupFirstLaunchNote =>
      'This setup only happens on the first launch\nto map your travels safely.';

  @override
  String get frameTitle => 'Frame';

  @override
  String get frameStyleBottomBar => 'Bar';

  @override
  String get frameStyleFullBorder => 'Border';

  @override
  String get frameStyleMinimal => 'Minimal';

  @override
  String get frameSave => 'Save';

  @override
  String get frameShare => 'Share';

  @override
  String get frameSaved => 'Saved to Photos';

  @override
  String get frameSaveFailed => 'Couldn\'t save frame';

  @override
  String get frameTextSize => 'Text';

  @override
  String get frameSize => 'Frame';

  @override
  String get collageTitle => 'Collage';

  @override
  String get collageAddPhotos => 'Add';

  @override
  String get collageColorSort => 'Color gradient';

  @override
  String get achExplorerLabel => 'Explorer';

  @override
  String get achExplorerSubtitle => 'Province Explorer';

  @override
  String get achExplored => 'explored';

  @override
  String get achProvincesVisited => 'provinces visited';

  @override
  String get achLeftToExplore => 'left to explore';

  @override
  String collagePickerHint(int filled, int total) {
    return 'Grid $filled/$total filled';
  }

  @override
  String get collageRows => 'Rows';

  @override
  String get collageCols => 'Cols';

  @override
  String get collageGap => 'Gap';

  @override
  String get collageEmptyHint => 'Tap a cell to add a photo';

  @override
  String get collageFrameHint =>
      'Drag a photo to reframe it · two fingers to zoom and straighten · hold to swap';

  @override
  String get collageResetFraming => 'Reset framing';
}
