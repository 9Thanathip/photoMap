# Camera brand logos

Drop white, transparent-background PNG logos here, named by brand key:

    sony.png  canon.png  nikon.png  fujifilm.png  apple.png
    panasonic.png  leica.png  olympus.png  ricoh.png  ...

(Keys are defined in `lib/features/gallery/presentation/widgets/frame/camera_logo.dart`.)

Then register the folder in `pubspec.yaml` under `flutter: assets:`:

    - assets/camera_logos/

Until a brand's PNG exists, the frame falls back to a plain text wordmark
(e.g. `SONY`), so the feature works with zero logos.

> Note: brand logos are trademarks — ship only assets you have the right to use.
