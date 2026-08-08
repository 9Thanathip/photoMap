// ignore_for_file: constant_identifier_names
//
// Central icon set. Names mirror the Material icons they replaced so call sites
// read `AppIcons.<same_name>`. Glyphs point at Heroicons (MIT, shipped as an
// icon font by `heroicons_flutter`): outline for normal chrome, solid for the
// "filled / selected" variants. A handful of photo-editing glyphs have no
// Heroicons equivalent and stay on Material's rounded set (Apache-2.0).
// SF Symbols are deliberately NOT used — Apple's license forbids redistributing
// them.
import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';

abstract final class AppIcons {
  // ── Navigation / chrome ──
  static const IconData add = HeroiconsOutline.plus;
  static const IconData add_rounded = HeroiconsOutline.plus;
  static const IconData add_photo_alternate_outlined = HeroiconsOutline.photo;
  static const IconData arrow_back_ios_new_rounded = HeroiconsOutline.chevronLeft;
  static const IconData arrow_forward_rounded = HeroiconsOutline.arrowRight;
  static const IconData chevron_right_rounded = HeroiconsOutline.chevronRight;
  static const IconData expand_more_rounded = HeroiconsOutline.chevronDown;
  static const IconData keyboard_arrow_down_rounded =
      HeroiconsOutline.chevronDown;
  static const IconData close_rounded = HeroiconsOutline.xMark;
  static const IconData clear_rounded = HeroiconsSolid.xCircle;
  static const IconData search_rounded = HeroiconsOutline.magnifyingGlass;
  static const IconData refresh_rounded = HeroiconsOutline.arrowPath;
  static const IconData tune_rounded = HeroiconsOutline.adjustmentsHorizontal;
  static const IconData filter_list_rounded = HeroiconsOutline.funnel;
  static const IconData grid_view_rounded = HeroiconsOutline.squares2x2;
  static const IconData dashboard_customize_outlined =
      HeroiconsOutline.squaresPlus;

  // ── Bottom-nav tabs ── (solid = selected, outline = idle)
  static const IconData photo_library = HeroiconsSolid.photo;
  static const IconData photo_library_outlined = HeroiconsOutline.photo;
  static const IconData photo_library_rounded = HeroiconsSolid.photo;
  static const IconData map = HeroiconsSolid.map;
  static const IconData map_outlined = HeroiconsOutline.map;
  static const IconData map_rounded = HeroiconsSolid.map;
  static const IconData emoji_events = HeroiconsSolid.trophy;
  static const IconData emoji_events_outlined = HeroiconsOutline.trophy;
  static const IconData emoji_events_rounded = HeroiconsSolid.trophy;
  static const IconData settings = HeroiconsSolid.cog6Tooth;
  static const IconData settings_outlined = HeroiconsOutline.cog6Tooth;
  static const IconData settings_backup_restore_rounded =
      HeroiconsOutline.arrowUturnLeft;

  // ── Status / feedback ──
  static const IconData check_rounded = HeroiconsOutline.check;
  static const IconData check_circle_rounded = HeroiconsSolid.checkCircle;
  static const IconData error_rounded = HeroiconsSolid.exclamationCircle;
  static const IconData error_outline = HeroiconsOutline.exclamationCircle;
  static const IconData error_outline_rounded =
      HeroiconsOutline.exclamationCircle;
  static const IconData warning_amber_rounded =
      HeroiconsOutline.exclamationTriangle;
  static const IconData info_rounded = HeroiconsSolid.informationCircle;
  static const IconData info_outline_rounded =
      HeroiconsOutline.informationCircle;
  static const IconData hourglass_top_rounded = HeroiconsOutline.clock;

  // ── Media / camera ──
  static const IconData camera_alt_rounded = HeroiconsOutline.camera;
  static const IconData videocam_rounded = HeroiconsOutline.videoCamera;
  static const IconData image_outlined = HeroiconsOutline.photo;
  static const IconData broken_image = HeroiconsOutline.photo;
  static const IconData play_arrow_rounded = HeroiconsSolid.play;
  static const IconData play_circle_filled_rounded = HeroiconsSolid.playCircle;
  static const IconData pause_rounded = HeroiconsSolid.pause;
  static const IconData volume_up_rounded = HeroiconsOutline.speakerWave;
  static const IconData volume_off_rounded = HeroiconsOutline.speakerXMark;
  static const IconData filter_frames_rounded = HeroiconsOutline.square2Stack;
  static const IconData ios_share = HeroiconsOutline.arrowUpTray;
  static const IconData ios_share_rounded = HeroiconsOutline.arrowUpTray;

  // ── Location / world ──
  static const IconData location_on_rounded = HeroiconsSolid.mapPin;
  static const IconData location_on_outlined = HeroiconsOutline.mapPin;
  static const IconData map_pin = HeroiconsOutline.mapPin;
  static const IconData public_rounded = HeroiconsOutline.globeAsiaAustralia;
  static const IconData language_outlined = HeroiconsOutline.language;
  // Heroicons has no compass — a paper plane carries the "travel" role here.
  static const IconData explore_outlined = HeroiconsOutline.paperAirplane;
  static const IconData flag_rounded = HeroiconsOutline.flag;
  static const IconData center_focus_strong_outlined =
      HeroiconsOutline.viewfinderCircle;
  static const IconData touch_app_outlined = HeroiconsOutline.cursorArrowRays;

  // ── Account / auth ──
  static const IconData person_outlined = HeroiconsOutline.user;
  static const IconData manage_accounts_outlined = HeroiconsOutline.userCircle;
  static const IconData verified_user_outlined = HeroiconsOutline.shieldCheck;
  static const IconData logout_rounded =
      HeroiconsOutline.arrowRightStartOnRectangle;
  static const IconData lock_outlined = HeroiconsOutline.lockClosed;
  static const IconData lock_outline_rounded = HeroiconsOutline.lockClosed;
  static const IconData email_outlined = HeroiconsOutline.envelope;
  static const IconData mark_email_unread_outlined =
      HeroiconsOutline.envelopeOpen;
  static const IconData visibility_outlined = HeroiconsOutline.eye;
  static const IconData visibility_off_outlined = HeroiconsOutline.eyeSlash;
  static const IconData cloud_outlined = HeroiconsOutline.cloud;
  static const IconData download_rounded = HeroiconsOutline.cloudArrowDown;

  // ── Appearance / theme ──
  static const IconData light_mode_outlined = HeroiconsOutline.sun;
  static const IconData dark_mode_outlined = HeroiconsOutline.moon;
  static const IconData auto_mode_outlined =
      HeroiconsOutline.devicePhoneMobile; // "follow system"
  static const IconData palette_outlined = HeroiconsOutline.swatch;
  static const IconData star_rounded = HeroiconsSolid.star;

  // ── Editor / adjustments ──
  static const IconData exposure_rounded = HeroiconsOutline.sun;
  static const IconData thermostat_rounded = HeroiconsOutline.fire; // warmth
  static const IconData water_drop_outlined = HeroiconsOutline.beaker;
  static const IconData colorize_rounded = HeroiconsOutline.eyeDropper;
  static const IconData flare_rounded = HeroiconsOutline.sparkles;
  // No Heroicons match for these photo-grading glyphs — Material rounded
  // (Apache-2.0) stays.
  static const IconData contrast_rounded = Icons.contrast_rounded;
  static const IconData contrast_material = Icons.contrast_rounded;
  static const IconData invert_colors_rounded = Icons.invert_colors_rounded;
  static const IconData gradient_rounded = Icons.gradient_rounded;
  static const IconData grain_rounded = Icons.grain_rounded;
  static const IconData vignette_rounded = Icons.vignette_rounded;

  // ── Local adjust (masks) ──
  static const IconData mask_radial = HeroiconsOutline.viewfinderCircle;
  static const IconData mask_linear = HeroiconsOutline.bars3;
  static const IconData mask_brush = HeroiconsOutline.paintBrush;
  static const IconData adj_shadows = HeroiconsOutline.moon;
  static const IconData adj_highlights = HeroiconsOutline.sun;
  static const IconData mask_show = HeroiconsOutline.eye;
  static const IconData mask_hide = HeroiconsOutline.eyeSlash;
  static const IconData mask_size = HeroiconsOutline.arrowsPointingOut;
  static const IconData mask_feather = HeroiconsOutline.cloud; // softness
  static const IconData mask_invert = HeroiconsOutline.arrowsRightLeft;

  // ── Misc ──
  static const IconData remove_rounded = HeroiconsOutline.minus;
  static const IconData remove_circle_outline = HeroiconsOutline.minusCircle;
  static const IconData delete_outline = HeroiconsOutline.trash;
  static const IconData delete_outline_rounded = HeroiconsOutline.trash;
  static const IconData north_east_rounded = HeroiconsOutline.arrowUpRight;
  static const IconData north_west_rounded = HeroiconsOutline.arrowUpLeft;
  static const IconData south_east_rounded = HeroiconsOutline.arrowDownRight;
  static const IconData south_west_rounded = HeroiconsOutline.arrowDownLeft;
}
