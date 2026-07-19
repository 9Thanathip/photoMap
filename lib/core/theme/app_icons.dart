// ignore_for_file: constant_identifier_names
//
// Central icon set. Names mirror the Material icons they replaced so call sites
// read `AppIcons.<same_name>`. Glyphs point at CupertinoIcons (iOS look, bundled
// with Flutter, Apache-2.0 — license-safe) wherever a good match exists; a few
// photo-editing glyphs with no Cupertino equivalent fall back to Material's
// rounded set (also Apache-2.0). SF Symbols are deliberately NOT used — Apple's
// license forbids redistributing them.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppIcons {
  // ── Navigation / chrome ──
  static const IconData add = CupertinoIcons.add;
  static const IconData add_rounded = CupertinoIcons.add;
  static const IconData add_photo_alternate_outlined =
      CupertinoIcons.photo_on_rectangle;
  static const IconData arrow_back_ios_new_rounded = CupertinoIcons.back;
  static const IconData arrow_forward_rounded = CupertinoIcons.forward;
  static const IconData chevron_right_rounded = CupertinoIcons.chevron_forward;
  static const IconData expand_more_rounded = CupertinoIcons.chevron_down;
  static const IconData keyboard_arrow_down_rounded =
      CupertinoIcons.chevron_down;
  static const IconData close_rounded = CupertinoIcons.xmark;
  static const IconData clear_rounded = CupertinoIcons.clear;
  static const IconData search_rounded = CupertinoIcons.search;
  static const IconData refresh_rounded = CupertinoIcons.refresh;
  static const IconData tune_rounded = CupertinoIcons.slider_horizontal_3;
  static const IconData filter_list_rounded =
      CupertinoIcons.line_horizontal_3_decrease;
  static const IconData grid_view_rounded = CupertinoIcons.square_grid_2x2;
  static const IconData dashboard_customize_outlined =
      CupertinoIcons.square_grid_2x2;

  // ── Bottom-nav tabs ──
  static const IconData photo_library = CupertinoIcons.photo_on_rectangle;
  static const IconData photo_library_outlined =
      CupertinoIcons.photo_on_rectangle;
  static const IconData photo_library_rounded =
      CupertinoIcons.photo_fill_on_rectangle_fill;
  static const IconData map = CupertinoIcons.map;
  static const IconData map_outlined = CupertinoIcons.map;
  static const IconData map_rounded = CupertinoIcons.map_fill;
  static const IconData emoji_events = CupertinoIcons.rosette;
  static const IconData emoji_events_outlined = CupertinoIcons.rosette;
  static const IconData emoji_events_rounded = CupertinoIcons.rosette;
  static const IconData settings = CupertinoIcons.gear_solid;
  static const IconData settings_outlined = CupertinoIcons.gear;
  static const IconData settings_backup_restore_rounded =
      CupertinoIcons.arrow_counterclockwise;

  // ── Status / feedback ──
  static const IconData check_rounded = CupertinoIcons.check_mark;
  static const IconData check_circle_rounded =
      CupertinoIcons.check_mark_circled_solid;
  static const IconData error_rounded =
      CupertinoIcons.exclamationmark_circle_fill;
  static const IconData error_outline = CupertinoIcons.exclamationmark_circle;
  static const IconData error_outline_rounded =
      CupertinoIcons.exclamationmark_circle;
  static const IconData warning_amber_rounded =
      CupertinoIcons.exclamationmark_triangle;
  static const IconData info_rounded = CupertinoIcons.info_circle_fill;
  static const IconData info_outline_rounded = CupertinoIcons.info_circle;
  static const IconData hourglass_top_rounded = CupertinoIcons.hourglass;

  // ── Media / camera ──
  static const IconData camera_alt_rounded = CupertinoIcons.camera;
  static const IconData videocam_rounded = CupertinoIcons.videocam;
  static const IconData image_outlined = CupertinoIcons.photo;
  static const IconData broken_image = CupertinoIcons.photo;
  static const IconData play_arrow_rounded = CupertinoIcons.play_fill;
  static const IconData play_circle_filled_rounded =
      CupertinoIcons.play_circle_fill;
  static const IconData pause_rounded = CupertinoIcons.pause_fill;
  static const IconData volume_up_rounded = CupertinoIcons.volume_up;
  static const IconData volume_off_rounded = CupertinoIcons.volume_off;
  static const IconData filter_frames_rounded = CupertinoIcons.square_on_square;
  static const IconData ios_share = CupertinoIcons.share;
  static const IconData ios_share_rounded = CupertinoIcons.share;

  // ── Location / world ──
  static const IconData location_on_rounded = CupertinoIcons.location_solid;
  static const IconData location_on_outlined = CupertinoIcons.location;
  static const IconData map_pin = CupertinoIcons.map_pin_ellipse;
  static const IconData public_rounded = CupertinoIcons.globe;
  static const IconData language_outlined = CupertinoIcons.globe;
  static const IconData explore_outlined = CupertinoIcons.compass;
  static const IconData flag_rounded = CupertinoIcons.flag;
  static const IconData center_focus_strong_outlined = CupertinoIcons.viewfinder;
  static const IconData touch_app_outlined = CupertinoIcons.hand_draw;

  // ── Account / auth ──
  static const IconData person_outlined = CupertinoIcons.person;
  static const IconData manage_accounts_outlined =
      CupertinoIcons.person_crop_circle;
  static const IconData verified_user_outlined = CupertinoIcons.checkmark_shield;
  static const IconData logout_rounded = CupertinoIcons.square_arrow_right;
  static const IconData lock_outlined = CupertinoIcons.lock;
  static const IconData lock_outline_rounded = CupertinoIcons.lock;
  static const IconData email_outlined = CupertinoIcons.mail;
  static const IconData mark_email_unread_outlined = CupertinoIcons.envelope_badge;
  static const IconData visibility_outlined = CupertinoIcons.eye;
  static const IconData visibility_off_outlined = CupertinoIcons.eye_slash;
  static const IconData cloud_outlined = CupertinoIcons.cloud;
  static const IconData download_rounded = CupertinoIcons.cloud_download;

  // ── Appearance / theme ──
  static const IconData light_mode_outlined = CupertinoIcons.sun_max;
  static const IconData dark_mode_outlined = CupertinoIcons.moon;
  static const IconData auto_mode_outlined = CupertinoIcons.circle_lefthalf_fill;
  static const IconData palette_outlined = CupertinoIcons.paintbrush;
  static const IconData star_rounded = CupertinoIcons.star_fill;

  // ── Editor / adjustments ──
  static const IconData exposure_rounded = CupertinoIcons.sun_max;
  static const IconData thermostat_rounded = CupertinoIcons.thermometer;
  static const IconData water_drop_outlined = CupertinoIcons.drop;
  static const IconData colorize_rounded = CupertinoIcons.eyedropper;
  static const IconData contrast_rounded = CupertinoIcons.circle_righthalf_fill;
  static const IconData flare_rounded = CupertinoIcons.sparkles;
  // No clean Cupertino match — keep Material's rounded glyph (Apache-2.0).
  static const IconData contrast_material = Icons.contrast_rounded;
  static const IconData invert_colors_rounded = Icons.invert_colors_rounded;
  static const IconData gradient_rounded = Icons.gradient_rounded;
  static const IconData grain_rounded = Icons.grain_rounded;
  static const IconData vignette_rounded = Icons.vignette_rounded;

  // ── Misc ──
  static const IconData remove_rounded = CupertinoIcons.minus;
  static const IconData remove_circle_outline = CupertinoIcons.minus_circle;
  static const IconData delete_outline = CupertinoIcons.delete;
  static const IconData delete_outline_rounded = CupertinoIcons.delete;
  static const IconData north_east_rounded = CupertinoIcons.arrow_up_right;
  static const IconData north_west_rounded = CupertinoIcons.arrow_up_left;
  static const IconData south_east_rounded = CupertinoIcons.arrow_down_right;
  static const IconData south_west_rounded = CupertinoIcons.arrow_down_left;
}
