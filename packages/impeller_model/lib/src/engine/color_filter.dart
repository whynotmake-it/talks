/// `DlColorFilter::modifies_transparent_black`, which decides whether a
/// color-filtered saveLayer floods to its clip.
library;

import 'dart:ui' as ui;

/// ```engine display_list/effects/color_filters/dl_blend_color_filter.cc
///     // These modes all act like kSrc when the dest is all 0s.
///     // So they modify transparent black when the src color is
///     // not transparent.
///     case DlBlendMode::kSrc:
///     case DlBlendMode::kSrcOver:
///     case DlBlendMode::kDstOver:
///     case DlBlendMode::kSrcOut:
///     case DlBlendMode::kDstATop:
///     case DlBlendMode::kXor:
///     case DlBlendMode::kPlus:
///     case DlBlendMode::kScreen:
///     case DlBlendMode::kOverlay:
///     case DlBlendMode::kDarken:
///     case DlBlendMode::kLighten:
///     case DlBlendMode::kColorDodge:
///     case DlBlendMode::kColorBurn:
///     case DlBlendMode::kHardLight:
///     case DlBlendMode::kSoftLight:
///     case DlBlendMode::kDifference:
///     case DlBlendMode::kExclusion:
///     case DlBlendMode::kMultiply:
///     case DlBlendMode::kHue:
///     case DlBlendMode::kSaturation:
///     case DlBlendMode::kColor:
///     case DlBlendMode::kLuminosity:
///       return !color_.isTransparent();
/// ```
const _modesThatModifyTransparentBlack = {
  ui.BlendMode.src,
  ui.BlendMode.srcOver,
  ui.BlendMode.dstOver,
  ui.BlendMode.srcOut,
  ui.BlendMode.dstATop,
  ui.BlendMode.xor,
  ui.BlendMode.plus,
  ui.BlendMode.screen,
  ui.BlendMode.overlay,
  ui.BlendMode.darken,
  ui.BlendMode.lighten,
  ui.BlendMode.colorDodge,
  ui.BlendMode.colorBurn,
  ui.BlendMode.hardLight,
  ui.BlendMode.softLight,
  ui.BlendMode.difference,
  ui.BlendMode.exclusion,
  ui.BlendMode.multiply,
  ui.BlendMode.hue,
  ui.BlendMode.saturation,
  ui.BlendMode.color,
  ui.BlendMode.luminosity,
};

bool blendColorFilterModifiesTransparentBlack(
  ui.BlendMode mode, {
  required bool colorIsTransparent,
}) => !colorIsTransparent && _modesThatModifyTransparentBlack.contains(mode);

/// ```engine display_list/effects/color_filters/dl_matrix_color_filter.cc
///   return (std::isfinite(matrix_[19]) && matrix_[19] > 0);
/// ```
bool matrixColorFilterModifiesTransparentBlack(List<double> matrix) =>
    matrix.length >= 20 && matrix[19].isFinite && matrix[19] > 0;
