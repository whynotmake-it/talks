import 'dart:math' as math;
import 'dart:ui' as ui;

import '../capture/recorded_op.dart';

/// Gaussian blur math, ported from
/// impeller/entity/contents/filters/gaussian_blur_filter_contents.cc.

const double kMaxSigma = 500.0; // gaussian_blur_filter_contents.cc:28

/// `Sigma::operator Radius` — impeller/geometry/sigma.h.
/// radius = (sigma - 0.5) * 1.732 for sigma > 0.5, else 0.
double calculateBlurRadius(double sigma) =>
    sigma > 0.5 ? (sigma - 0.5) * 1.73205080757 : 0.0;

/// `GaussianBlurFilterContents::ScaleSigma` — gaussian_blur_filter_contents.cc:1005.
double scaleSigma(double sigma) {
  final clamped = math.min(sigma, kMaxSigma);
  const a = 3.4e-06;
  const b = -3.4e-3;
  const c = 1.0;
  final scalar = c + b * clamped + a * clamped * clamped;
  return clamped * scalar;
}

/// `GaussianBlurFilterContents::CalculateScale` — :751.
/// Downsample factor chosen by scaled sigma (physical pixels).
double calculateBlurScale(double scaledSigma) {
  if (scaledSigma <= 4) {
    return 1.0;
  }
  final rawResult = 4.0 / scaledSigma;
  var exponent = (math.log(rawResult) / math.ln2).roundToDouble();
  // Don't scale below 1/16.
  exponent = math.max(-4.0, exponent);
  final rounded = math.pow(2.0, exponent).toDouble();
  var result = rounded;
  // Extend the 1/8th downsample range based on kernel size (:762-774).
  if (rounded < 0.125) {
    final roundedPlus = math.pow(2.0, exponent + 1).toDouble();
    final blurRadius = calculateBlurRadius(scaledSigma);
    final kernelSizePlus = (scaleBlurRadius(blurRadius, roundedPlus) * 2) + 1;
    const kEighthDownsampleKernelWidthMax = 41;
    result = kernelSizePlus <= kEighthDownsampleKernelWidthMax
        ? roundedPlus
        : rounded;
  }
  return result;
}

/// `ScaleBlurRadius` — :625.
int scaleBlurRadius(double radius, double scalar) => (radius * scalar).round();

/// The GPU sub-passes a single image filter invocation costs.
/// Gaussian blur: downsample + Y + X passes (each its own command buffer,
/// :867-877). All three at the same (downsampled) size.
/// Other filter kinds: one subpass (texture/matrix/compose approximations).
class FilterPassEstimate {
  FilterPassEstimate({
    required this.label,
    required this.size,
    required this.kind,
  });
  final String label;
  final ui.Size size;
  final String kind;

  Map<String, Object?> toJson() => {
    'label': label,
    'size': [size.width, size.height],
    'kind': kind,
  };
}

List<FilterPassEstimate> estimateFilterPasses(
  FilterDesc filter,
  ui.Size inputSize,
  ui.Size basisScale,
) {
  if (filter.kind == 'blur') {
    // scaled_sigma = basis ⊗ ScaleSigma(sigma), clamped to kMaxSigma —
    // per-axis (gaussian_blur_filter_contents.cc:106-111).
    final sx = math.min(
      scaleSigma(filter.sigmaX) * basisScale.width,
      kMaxSigma,
    );
    final sy = math.min(
      scaleSigma(filter.sigmaY) * basisScale.height,
      kMaxSigma,
    );
    final desiredScalar = math.min(
      calculateBlurScale(sx),
      calculateBlurScale(sy),
    );
    // Downsample size: source size * effective scalar, aligned to the
    // divisor (CalculateDownsamplePassArgs, :285-340).
    final divisor = 1.0 / desiredScalar;
    final w = (inputSize.width / divisor).ceil() * divisor * desiredScalar;
    final h = (inputSize.height / divisor).ceil() * divisor * desiredScalar;
    final size = ui.Size(
      w.isFinite ? w : inputSize.width * desiredScalar,
      h.isFinite ? h : inputSize.height * desiredScalar,
    );
    return [
      FilterPassEstimate(
        label: 'Gaussian blur downsample',
        size: size,
        kind: 'blur-down',
      ),
      FilterPassEstimate(label: 'Gaussian blur Y', size: size, kind: 'blur-y'),
      FilterPassEstimate(label: 'Gaussian blur X', size: size, kind: 'blur-x'),
    ];
  }
  if (filter.kind == 'matrix') {
    // Matrix image filters apply via texture contents — no subpass.
    return const [];
  }
  return [
    FilterPassEstimate(
      label: 'Image filter (${filter.kind})',
      size: inputSize,
      kind: 'filter',
    ),
  ];
}
