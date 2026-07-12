/// Aspect ratios offered by the collage builder. [value] is width / height.
enum CollageRatio {
  square(1, 1),
  portrait45(4, 5),
  story(9, 16),
  portrait34(3, 4),
  landscape169(16, 9);

  const CollageRatio(this.w, this.h);

  final int w;
  final int h;

  double get value => w / h;

  /// Short label for the picker chip, e.g. `4:5`.
  String get label => '$w:$h';
}
