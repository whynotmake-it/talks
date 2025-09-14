import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gaussian_splatting/shared/radiance_field_data.dart';
import 'package:gaussian_splatting/shared/radiance_field_ui.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_transform_controls/three_js_transform_controls.dart';
import 'package:wnma_talk/wnma_talk.dart';

class RadianceFieldScreen extends StatefulWidget {
  const RadianceFieldScreen({
    required this.showVoxels,
    required this.showSensor,
    required this.showRaySamples,
    required this.showSamplePoints,
    required this.showUI,
    this.yaw = 35 * math.pi / 180.0,
    this.pitch = 20 * math.pi / 180.0,
    this.camRadius = 26,
    this.showAllRays = true,
    this.showInstancedVoxels = true,
    this.viewDependentColor = false,
    this.onYawChanged,
    this.onPitchChanged,
    this.onCamRadiusChanged,
    this.onShowAllRaysChanged,
    this.onShowInstancedVoxelsChanged,
    this.onViewDependentColorChanged,
    super.key,
  });

  final bool showVoxels;
  final bool showSensor;
  final bool showRaySamples;
  final bool showSamplePoints;
  final bool showUI;
  final double yaw;
  final double pitch;
  final double camRadius;
  final bool showAllRays;
  final bool showInstancedVoxels;
  final bool viewDependentColor;
  final ValueChanged<double>? onYawChanged;
  final ValueChanged<double>? onPitchChanged;
  final ValueChanged<double>? onCamRadiusChanged;
  final ValueChanged<bool>? onShowAllRaysChanged;
  final ValueChanged<bool>? onShowInstancedVoxelsChanged;
  final ValueChanged<bool>? onViewDependentColorChanged;

  @override
  State<RadianceFieldScreen> createState() => _RadianceFieldScreenState();
}

class _RadianceFieldScreenState extends State<RadianceFieldScreen> {
  late three.ThreeJS threeJs;
  late ArcballControls orbit;

  // ---- Scene params
  static const int nx = 24;
  static const int ny = 24;
  static const int nz = 24;
  static const int camW = 24;
  static const int camH = 24; // fake sensor rays
  static const double voxelSize = 1;
  static const double fieldHalf = (nx * voxelSize) / 2.0; // half-extent
  static const double rayStep = 1; // march step in world units
  static const double densityScale = 1.2; // scales sigma
  static const double earlyStopT = 0; // early termination if T < this

  // volume data (density/color grid)
  late final List<double> sigmaGrid; // length nx*ny*nz
  late final List<double> colorR, colorG, colorB;

  // Instanced voxels
  late three.Mesh voxelsMesh;

  // Fake camera that casts the rays (renders not from this, but
  // from observer camera)
  late three.PerspectiveCamera fakeCam;
  late three.Object3D? fakeCamVisual;

  // Rays visualization
  late three.LineSegments raysLines;
  late three.BufferGeometry raysGeom;
  late three.LineBasicMaterial raysMat;

  // Selected ray highlighting
  late three.LineSegments selectedRayLine;
  late three.BufferGeometry selectedRayGeom;
  late three.LineBasicMaterial selectedRayMat;

  // Sample points visualization
  late three.Points samplePoints;
  late three.BufferGeometry samplePointsGeom;
  late three.PointsMaterial samplePointsMat;

  // 2D sensor result (16x16 pixels)
  List<Color> sensorImage = List<Color>.filled(
    camW * camH,
    Colors.black,
  );

  // Selected pixel details
  int selectedU = 8, selectedV = 8;
  List<SampleRecord> selectedRaySamples = [];

  // All ray samples (2D array: [pixel][sample])
  List<List<SampleRecord>> allRaySamples = [];

  // Flags/UI
  bool showRayDetail = true;
  bool showTransmittanceCurve = true;

  @override
  void initState() {
    super.initState();

    // Build a procedural 3D grid as our radiance field (sigma + rgb per voxel)
    sigmaGrid = List<double>.filled(nx * ny * nz, 0);
    colorR = List<double>.filled(nx * ny * nz, 0);
    colorG = List<double>.filled(nx * ny * nz, 0);
    colorB = List<double>.filled(nx * ny * nz, 0);
    _populateField();

    // Initialize allRaySamples array
    allRaySamples = List.generate(camW * camH, (_) => <SampleRecord>[]);

    threeJs = three.ThreeJS(
      onSetupComplete: () {
        if (mounted) {
          setState(() {});
        }
      },
      setup: _setup,
      // Render settings: enable transparency multisample
      settings: three.Settings(
        renderOptions: {
          "samples": 4,
        },
      ),
    );
  }

  @override
  void didUpdateWidget(RadianceFieldScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only update if ThreeJS is ready
    if (threeJs.renderer != null) {
      if (oldWidget.yaw != widget.yaw ||
          oldWidget.pitch != widget.pitch ||
          oldWidget.camRadius != widget.camRadius ||
          oldWidget.showAllRays != widget.showAllRays ||
          oldWidget.viewDependentColor != widget.viewDependentColor) {
        _updateVisualization();
      }

      if (oldWidget.showInstancedVoxels != widget.showInstancedVoxels) {
        voxelsMesh.visible = widget.showInstancedVoxels;
      }

      if (oldWidget.showSamplePoints != widget.showSamplePoints) {
        _updateSamplePoints();
      }
    }
  }

  @override
  void dispose() {
    orbit.clearListeners();
    threeJs.dispose();
    three.loading.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = _buildOverlayUI(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Builder(
              builder: (context) {
                try {
                  return threeJs.build();
                } catch (e) {
                  // Handle EGL errors gracefully
                  return ColoredBox(
                    color: Colors.black,
                    child: const Center(
                      child: Text(
                        'Rendering Error\nReloading...',
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          // Position UI to leave center area free for orbit controls
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ui,
            ),
          ),
        ],
      ),
    );
  }

  // ========================= Setup three_js scene =========================

  // Helper method to get theme-aware colors
  int _getThemeColor(
    BuildContext context, {
    Color? lightColor,
    Color? darkColor,
    Color? fallback,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color color;
    if (isDark && darkColor != null) {
      color = darkColor;
    } else if (!isDark && lightColor != null) {
      color = lightColor;
    } else if (fallback != null) {
      color = fallback;
    } else {
      // Use theme colors as intelligent defaults
      color = isDark
          ? theme.colorScheme.onSurface.withOpacity(0.8)
          : theme.colorScheme.onSurface.withOpacity(0.6);
    }
    return color.value;
  }

  Future<void> _setup() async {
    // Observer camera (the one we use to render the 3D scene)
    threeJs.camera = three.PerspectiveCamera(
      60,
      threeJs.width / threeJs.height,
      0.1,
      500,
    );
    threeJs.camera.position.setValues(40, 30, 40);
    threeJs.camera.lookAt(three.Vector3(0, 0, 0));

    // Setup orbit controls for viewport navigation
    orbit = ArcballControls(threeJs.camera, threeJs.globalKey);
    orbit.update();
    orbit.addEventListener('change', (event) {
      threeJs.render();
    });

    // Scene & lights
    threeJs.scene = three.Scene();
    // ignore: lines_longer_than_80_chars
    final bgColor =
        FlutterDeckTheme.of(context).slideTheme.color ?? Colors.black;
    threeJs.scene.background = three.Color.fromHex32(bgColor.toARGB32());
    final amb = three.AmbientLight(
      _getThemeColor(
        context,
        lightColor: Colors.white,
        darkColor: Colors.white,
      ),
      0.75,
    );

    threeJs.scene.add(amb);

    // Visual representation of fake camera
    _buildFakeCameraVisual();

    // Fake camera that "casts rays" through the field
    fakeCam = three.PerspectiveCamera(60, 1, 0.1, 200);
    threeJs.scene.add(fakeCam);

    // Voxel field visualization with instancing
    _buildVoxelInstancing();

    // Rays visualization (thin semi-transparent lines)
    _buildRaysLines();

    // Selected ray and sample points visualization
    _buildSelectedRayVisualization();

    // Update cam pos
    _updateFakeCamTransform();

    // Do first render/march immediately
    _updateVisualization();

    // Initialize the selected ray visualization with default selection
    final origin = fakeCam.position.clone();
    final direction = _rayDirForPixel(selectedU, selectedV);
    final bboxMin = three.Vector3(-fieldHalf, -fieldHalf, -fieldHalf);
    final bboxMax = three.Vector3(fieldHalf, fieldHalf, fieldHalf);
    final hit = _rayAABB(origin, direction, bboxMin, bboxMax);
    if (hit.hit) {
      final res = _marchOneRay(
        origin,
        direction,
        hit.t0,
        hit.t1,
        collect: true,
      );
      selectedRaySamples = res.samples;

      // Also store in allRaySamples
      final pixelIndex = selectedV * camW + selectedU;
      allRaySamples[pixelIndex] = res.samples;
    }
  }

  // ========================= Field generation & sampling =========================

  void _populateField() {
    // A couple of soft 3D blobs + a slanted "wall" to make occlusion obvious.
    final blobs = <Blob>[
      Blob(
        center: three.Vector3(-3.5, -1.5, -2),
        sigma: 1.1,
        density: 2,
        color: const [1, 0, 0],
      ),
      Blob(
        center: three.Vector3(3.5, 1.5, 2),
        sigma: 1.6,
        density: 1.8,
        color: const [0, 1, 0],
      ),
    ];

    for (var k = 0; k < nz; k++) {
      for (var j = 0; j < ny; j++) {
        for (var i = 0; i < nx; i++) {
          final world = _voxelCenterToWorld(i, j, k);
          var sig = 0.0;
          double r = 0;
          double g = 0;
          double b = 0;

          for (final blob in blobs) {
            final d2 = world.distanceToSquared(blob.center);
            final w = math.exp(-d2 / (2 * blob.sigma * blob.sigma));
            sig += blob.density * w;
            r += blob.color[0] * w;
            g += blob.color[1] * w;
            b += blob.color[2] * w;
          }

          // Slanted "sheet"
          final s = world.x + world.y * 0.6 - 1.5;
          final slab = math.exp(-(s * s) / (2 * 0.7 * 0.7));
          sig += 1.8 * slab;
          r += 0.85 * slab;
          g += 0.85 * slab;
          b += 0.85 * slab;

          final idx = _idx(i, j, k);
          sigmaGrid[idx] = sig.clamp(0.0, 8.0);
          colorR[idx] = (r / 2.0).clamp(0.0, 1.0);
          colorG[idx] = (g / 2.0).clamp(0.0, 1.0);
          colorB[idx] = (b / 2.0).clamp(0.0, 1.0);
        }
      }
    }
  }

  // Trilinear sampling of density and color at a world position p (within the field bbox).
  FieldSample _sampleField(three.Vector3 p, three.Vector3 rayDir) {
    // Map world coords [-fieldHalf, fieldHalf] to grid coords [0, nx), etc.
    final gx = ((p.x + fieldHalf) / voxelSize).clamp(0.0, nx - 1.0001);
    final gy = ((p.y + fieldHalf) / voxelSize).clamp(0.0, ny - 1.0001);
    final gz = ((p.z + fieldHalf) / voxelSize).clamp(0.0, nz - 1.0001);

    final i0 = gx.floor();
    final j0 = gy.floor();
    final k0 = gz.floor();

    final tx = gx - i0;
    final ty = gy - j0;
    final tz = gz - k0;

    double sigma = 0;
    double r = 0;
    double g = 0;
    double b = 0;

    double accum(
      double v000,
      double v100,
      double v010,
      double v110,
      double v001,
      double v101,
      double v011,
      double v111,
    ) {
      final c00 = v000 * (1 - tx) + v100 * tx;
      final c10 = v010 * (1 - tx) + v110 * tx;
      final c01 = v001 * (1 - tx) + v101 * tx;
      final c11 = v011 * (1 - tx) + v111 * tx;
      final c0 = c00 * (1 - ty) + c10 * ty;
      final c1 = c01 * (1 - ty) + c11 * ty;
      return c0 * (1 - tz) + c1 * tz;
    }

    double getSigma(int ii, int jj, int kk) => sigmaGrid[_idx(ii, jj, kk)];
    double getR(int ii, int jj, int kk) => colorR[_idx(ii, jj, kk)];
    double getG(int ii, int jj, int kk) => colorG[_idx(ii, jj, kk)];
    double getB(int ii, int jj, int kk) => colorB[_idx(ii, jj, kk)];

    final i1 = (i0 + 1).clamp(0, nx - 1);
    final j1 = (j0 + 1).clamp(0, ny - 1);
    final k1 = (k0 + 1).clamp(0, nz - 1);

    sigma = accum(
      getSigma(i0, j0, k0),
      getSigma(i1, j0, k0),
      getSigma(i0, j1, k0),
      getSigma(i1, j1, k0),
      getSigma(i0, j0, k1),
      getSigma(i1, j0, k1),
      getSigma(i0, j1, k1),
      getSigma(i1, j1, k1),
    );

    r = accum(
      getR(i0, j0, k0),
      getR(i1, j0, k0),
      getR(i0, j1, k0),
      getR(i1, j1, k0),
      getR(i0, j0, k1),
      getR(i1, j0, k1),
      getR(i0, j1, k1),
      getR(i1, j1, k1),
    );
    g = accum(
      getG(i0, j0, k0),
      getG(i1, j0, k0),
      getG(i0, j1, k0),
      getG(i1, j1, k0),
      getG(i0, j0, k1),
      getG(i1, j0, k1),
      getG(i0, j1, k1),
      getG(i1, j1, k1),
    );
    b = accum(
      getB(i0, j0, k0),
      getB(i1, j0, k0),
      getB(i0, j1, k0),
      getB(i1, j1, k0),
      getB(i0, j0, k1),
      getB(i1, j0, k1),
      getB(i0, j1, k1),
      getB(i1, j1, k1),
    );

    // Optional view-dependent tint (very simple spec-like lobe)
    if (widget.viewDependentColor) {
      final n = three.Vector3(0, 1, 0); // fake "up" normal to hint the idea
      final ndotv = n.dot(rayDir.clone().negate()).clamp(0, 1);
      final lobe = math.pow(ndotv, 8).toDouble();
      r = (r + 0.7 * lobe).clamp(0.0, 1.0);
      g = (g + 0.7 * lobe).clamp(0.0, 1.0);
      b = (b + 0.7 * lobe).clamp(0.0, 1.0);
    }

    return FieldSample(sigma * densityScale, r, g, b);
  }

  // ========================= Ray marching & sensor image =================

  void _marchAllRays() {
    final origin = fakeCam.position.clone();
    final bboxMin = three.Vector3(-fieldHalf, -fieldHalf, -fieldHalf);
    final bboxMax = three.Vector3(fieldHalf, fieldHalf, fieldHalf);

    // Create a new sensor image list to force SensorView to repaint
    final newSensorImage = List<Color>.filled(camW * camH, Colors.black);

    // Update entire 16x16
    for (var v = 0; v < camH; v++) {
      for (var u = 0; u < camW; u++) {
        final dir = _rayDirForPixel(u, v);
        final hit = _rayAABB(origin, dir, bboxMin, bboxMax);
        var c = Colors.black;
        if (hit.hit) {
          final res = _marchOneRay(
            origin,
            dir,
            hit.t0,
            hit.t1,
            collect: true,
          );
          c = Color.fromARGB(
            0xFF,
            (res.r.clamp(0.0, 1.0) * 255).toInt(),
            (res.g.clamp(0.0, 1.0) * 255).toInt(),
            (res.b.clamp(0.0, 1.0) * 255).toInt(),
          );

          // Store samples for all rays
          final pixelIndex = v * camW + u;
          allRaySamples[pixelIndex] = res.samples;

          if (u == selectedU && v == selectedV) {
            selectedRaySamples = res.samples; // for the detail panel
          }
        } else {
          // Clear samples for rays that don't hit
          final pixelIndex = v * camW + u;
          allRaySamples[pixelIndex] = [];
        }
        newSensorImage[v * camW + u] = c;
      }
    }

    // Replace the sensor image with the new one
    sensorImage = newSensorImage;
    setState(() {});
  }

  MarchResult _marchOneRay(
    three.Vector3 origin,
    three.Vector3 dir,
    double t0,
    double t1, {
    required bool collect,
  }) {
    double T = 1;
    double rAcc = 0;
    double gAcc = 0;
    double bAcc = 0;

    final samples = <SampleRecord>[];

    var t = t0;
    while (t < t1 && T > earlyStopT) {
      final p = origin.clone().add(dir.clone().scale(t));
      final fs = _sampleField(p, dir);
      final sigma = fs.sigma;
      final alpha = 1.0 - math.exp(-sigma * rayStep);

      final w = T * alpha;
      rAcc += w * fs.r;
      gAcc += w * fs.g;
      bAcc += w * fs.b;

      if (collect) {
        samples.add(
          SampleRecord(
            t: t,
            sigma: sigma,
            alpha: alpha,
            tBefore: T,
            w: w,
            color: Color.fromARGB(
              255,
              (fs.r * 255).toInt(),
              (fs.g * 255).toInt(),
              (fs.b * 255).toInt(),
            ),
            p: p,
          ),
        );
      }

      T *= 1.0 - alpha;
      t += rayStep;
    }

    return MarchResult(rAcc, gAcc, bAcc, samples);
  }

  three.Vector3 _rayDirForPixel(int u, int v) {
    // map pixel center to NDC
    final ndcX = ((u + 0.5) / camW) * 2.0 - 1.0;
    final ndcY = -(((v + 0.5) / camH) * 2.0 - 1.0);

    final ndc = three.Vector3(ndcX, ndcY, -1);
    // unproject to world
    final world = ndc.clone()..unproject(fakeCam);
    final dir = world.sub(fakeCam.position).normalize();
    return dir;
  }

  RayBoxHit _rayAABB(
    three.Vector3 o,
    three.Vector3 d,
    three.Vector3 bmin,
    three.Vector3 bmax,
  ) {
    var tmin = (bmin.x - o.x) / d.x;
    var tmax = (bmax.x - o.x) / d.x;
    if (tmin > tmax) {
      final tmp = tmin;
      tmin = tmax;
      tmax = tmp;
    }

    var tymin = (bmin.y - o.y) / d.y;
    var tymax = (bmax.y - o.y) / d.y;
    if (tymin > tymax) {
      final tmp = tymin;
      tymin = tymax;
      tymax = tmp;
    }
    if ((tmin > tymax) || (tymin > tmax)) return RayBoxHit(false, 0, 0);

    if (tymin > tmin) tmin = tymin;
    if (tymax < tmax) tmax = tymax;

    var tzmin = (bmin.z - o.z) / d.z;
    var tzmax = (bmax.z - o.z) / d.z;
    if (tzmin > tzmax) {
      final tmp = tzmin;
      tzmin = tzmax;
      tzmax = tmp;
    }
    if ((tmin > tzmax) || (tzmin > tmax)) return RayBoxHit(false, 0, 0);

    if (tzmin > tmin) tmin = tzmin;
    if (tzmax < tmax) tmax = tzmax;

    if (tmax < 0) return RayBoxHit(false, 0, 0);
    return RayBoxHit(true, math.max(0, tmin), tmax);
  }

  // ========================= Instanced voxels & rays lines =========================

  void _buildFakeCameraVisual() {
    // Create a visual representation of the fake camera
    final cameraGroup = three.Group();

    // Camera body (small cube)
    final bodyGeom = three.BoxGeometry(1.5, 1, 2);
    final bodyMat = three.MeshStandardMaterial.fromMap({
      "color": _getThemeColor(
        context,
        lightColor: Colors.red.shade400,
        darkColor: Colors.red.shade300,
      ),
      "roughness": 0.3,
      "metalness": 0.1,
    });
    final body = three.Mesh(bodyGeom, bodyMat);
    cameraGroup.add(body);

    // Camera lens (cylinder pointing forward)
    final lensGeom = three.CylinderGeometry(0.3, 0.3);
    final lensMat = three.MeshStandardMaterial.fromMap({
      "color": _getThemeColor(
        context,
        lightColor: Colors.grey.shade700,
        darkColor: Colors.grey.shade300,
      ),
      "roughness": 0.1,
      "metalness": 0.8,
    });
    final lens = three.Mesh(lensGeom, lensMat);
    lens.rotation.x = math.pi / 2; // Point forward
    lens.position.z = 1.5; // In front of body
    cameraGroup.add(lens);

    fakeCamVisual = cameraGroup;
    threeJs.scene.add(fakeCamVisual);
  }

  void _buildVoxelInstancing() {
    final geom = three.BoxGeometry(
      nx * voxelSize,
      ny * voxelSize,
      nz * voxelSize,
    );

    // Convert Flutter Color → 0xRRGGBB
    final themeColor = _getThemeColor(
      context,
      lightColor: Colors.blue.shade600,
      darkColor: Colors.blue.shade400,
    );
    final colorHex = themeColor & 0xFFFFFF;

    final mat = three.MeshBasicMaterial.fromMap({
      "color": colorHex,
      "wireframe": true, // draw edges only
      "transparent": true,
      "opacity": 0.7, // tweak to taste
      "depthWrite": false, // avoids dark “stacking”
    });

    voxelsMesh = three.Mesh(geom, mat);

    voxelsMesh.position.setValues(0, 0, 0);
    voxelsMesh.visible = widget.showInstancedVoxels;
    threeJs.scene.add(voxelsMesh);
  }

  void _buildRaysLines() {
    // We’ll draw line segments from the fake camera to the AABB exit point, one per pixel.
    final nSegments = camW * camH;
    final positions = three.Float32Array(nSegments * 2 * 3);

    raysGeom = three.BufferGeometry();
    final posAttr = three.Float32BufferAttribute(positions, 3);
    raysGeom.setAttribute(three.Attribute.position, posAttr);

    raysMat = three.LineBasicMaterial.fromMap({
      "color": _getThemeColor(
        context,
        lightColor: Colors.grey.shade600,
        darkColor: Colors.grey.shade400,
      ),
      "transparent": true,
      "opacity": 0.15,
      "linewidth": 1, // platform dependent
    });

    raysLines = three.LineSegments(raysGeom, raysMat);
    threeJs.scene.add(raysLines);
  }

  void _buildSelectedRayVisualization() {
    // Selected ray line (highlighted)
    final selectedRayPositions = three.Float32Array(
      2 * 3,
    ); // Start and end point
    selectedRayGeom = three.BufferGeometry();
    final selectedRayPosAttr = three.Float32BufferAttribute(
      selectedRayPositions,
      3,
    );
    selectedRayGeom.setAttribute(three.Attribute.position, selectedRayPosAttr);

    selectedRayMat = three.LineBasicMaterial.fromMap({
      "color": _getThemeColor(
        context,
        lightColor: Colors.orange.shade600,
        darkColor: Colors.orange.shade400,
      ),
      "transparent": false,
      "linewidth": 3, // Thicker line
    });

    selectedRayLine = three.LineSegments(selectedRayGeom, selectedRayMat);
    threeJs.scene.add(selectedRayLine);

    // Sample points (dots along all rays)
    final maxSamplePointsPerRay = 50; // Estimate max samples per ray
    final maxTotalSamplePoints =
        camW * camH * maxSamplePointsPerRay; // Total for all rays
    final samplePositions = three.Float32Array(maxTotalSamplePoints * 3);
    final sampleColors = three.Float32Array(
      maxTotalSamplePoints * 4,
    ); // RGBA colors

    samplePointsGeom = three.BufferGeometry();
    final samplePosAttr = three.Float32BufferAttribute(samplePositions, 3);
    final sampleColorAttr = three.Float32BufferAttribute(sampleColors, 4);

    samplePointsGeom.setAttribute(three.Attribute.position, samplePosAttr);
    samplePointsGeom.setAttribute(three.Attribute.color, sampleColorAttr);

    samplePointsMat = three.PointsMaterial.fromMap({
      "vertexColors": true, // Use per-vertex colors
      "sizeAttenuation": false, // Keep consistent size regardless of distance
      "size": 8.0, // Smaller point size for many points
      "transparent": true, // Enable transparency
    });

    samplePoints = three.Points(samplePointsGeom, samplePointsMat);
    samplePoints.visible = widget.showSamplePoints;
    threeJs.scene.add(samplePoints);
  }

  void _updateRaysLinesGeom() {
    if (!widget.showAllRays) {
      raysLines.visible = false;
      return;
    }
    raysLines.visible = true;

    final posAttr =
        raysGeom.getAttribute(three.Attribute.position)
            as three.Float32BufferAttribute;
    final positions = posAttr.array;

    final o = fakeCam.position.clone();
    const rayLength = 100; // Extend all rays far beyond viewport

    var ptr = 0;
    for (var v = 0; v < camH; v++) {
      for (var u = 0; u < camW; u++) {
        final dir = _rayDirForPixel(u, v);

        // All rays are "infinite" - extend far in their direction
        final start = o;
        final end = o.clone().add(dir.clone().scale(rayLength));

        positions[ptr++] = start.x;
        positions[ptr++] = start.y;
        positions[ptr++] = start.z;
        positions[ptr++] = end.x;
        positions[ptr++] = end.y;
        positions[ptr++] = end.z;
      }
    }
    posAttr.needsUpdate = true;
  }

  void _updateSelectedRayVisualization() {
    // Update the selected ray line
    final selectedRayPosAttr =
        selectedRayGeom.getAttribute(three.Attribute.position)
            as three.Float32BufferAttribute;
    final selectedRayPositions = selectedRayPosAttr.array;

    final origin = fakeCam.position.clone();
    final dir = _rayDirForPixel(selectedU, selectedV);
    const rayLength = 100; // Same infinite length as regular rays

    // Selected ray is also "infinite" - extends far in its direction
    final endPoint = origin.clone().add(dir.clone().scale(rayLength));

    // Set ray line positions
    selectedRayPositions[0] = origin.x;
    selectedRayPositions[1] = origin.y;
    selectedRayPositions[2] = origin.z;
    selectedRayPositions[3] = endPoint.x;
    selectedRayPositions[4] = endPoint.y;
    selectedRayPositions[5] = endPoint.z;

    selectedRayPosAttr.needsUpdate = true;
    selectedRayLine.visible = true;

    // Update the sample points
    _updateSamplePoints();
  }

  void _updateSamplePoints() {
    // CLEAN EARLY QUIT - Check widget flag first
    if (!widget.showSamplePoints) {
      samplePoints.visible = false;
      return;
    }

    final samplePosAttr =
        samplePointsGeom.getAttribute(three.Attribute.position)
            as three.Float32BufferAttribute;
    final sampleColorAttr =
        samplePointsGeom.getAttribute(three.Attribute.color)
            as three.Float32BufferAttribute;

    final positions = samplePosAttr.array;
    final colors = sampleColorAttr.array;

    // Check if we have any samples at all
    final hasAnySamples = allRaySamples.any(
      (raySamples) => raySamples.isNotEmpty,
    );

    if (!hasAnySamples) {
      samplePoints.visible = false;
      return;
    }

    samplePoints.visible = true;

    var pointIndex = 0;

    // Iterate through all rays and their samples
    for (var rayIndex = 0; rayIndex < allRaySamples.length; rayIndex++) {
      final raySamples = allRaySamples[rayIndex];

      for (
        var sampleIndex = 0;
        sampleIndex < raySamples.length;
        sampleIndex++
      ) {
        if (pointIndex >= positions.length ~/ 3) break; // Safety check

        final sample = raySamples[sampleIndex];
        final pos = sample.p;

        // Position
        positions[pointIndex * 3 + 0] = pos.x;
        positions[pointIndex * 3 + 1] = pos.y;
        positions[pointIndex * 3 + 2] = pos.z;

        // Color with proper alpha transparency
        final color = sample.color;
        final alpha =
            sample.alpha * 0.6; // Reduce alpha since we have many more points
        colors[pointIndex * 4 + 0] = color.red / 255.0; // R
        colors[pointIndex * 4 + 1] = color.green / 255.0; // G
        colors[pointIndex * 4 + 2] = color.blue / 255.0; // B
        colors[pointIndex * 4 + 3] = alpha; // A

        pointIndex++;
      }
    }

    // Hide unused points by setting them at origin with zero alpha
    for (var i = pointIndex; i < positions.length ~/ 3; i++) {
      positions[i * 3 + 0] = 0;
      positions[i * 3 + 1] = 0;
      positions[i * 3 + 2] = 0;
      colors[i * 4 + 0] = 0;
      colors[i * 4 + 1] = 0;
      colors[i * 4 + 2] = 0;
      colors[i * 4 + 3] = 0; // Fully transparent
    }

    samplePosAttr.needsUpdate = true;
    sampleColorAttr.needsUpdate = true;
  }

  // ========================= Centralized update function =========================

  void _updateVisualization() {
    _updateFakeCamTransform();
    _marchAllRays();
    _updateRaysLinesGeom();
    _updateSelectedRayVisualization();
  }

  // ========================= Helpers & transforms =========================

  int _idx(int i, int j, int k) => (k * ny + j) * nx + i;

  three.Vector3 _voxelCenterToWorld(int i, int j, int k) {
    final x = (i + 0.5) * voxelSize - fieldHalf;
    final y = (j + 0.5) * voxelSize - fieldHalf;
    final z = (k + 0.5) * voxelSize - fieldHalf;
    return three.Vector3(x, y, z);
  }

  void _updateFakeCamTransform() {
    final x = widget.camRadius * math.cos(widget.pitch) * math.cos(widget.yaw);
    final y = widget.camRadius * math.sin(widget.pitch);
    final z = widget.camRadius * math.cos(widget.pitch) * math.sin(widget.yaw);
    fakeCam.position.setValues(x, y, z);
    fakeCam..lookAt(three.Vector3(0, 0, 0))
    ..updateMatrixWorld(true);

    // Update visual representation
    if (fakeCamVisual != null) {
      fakeCamVisual?.position.setFrom(fakeCam.position);
      fakeCamVisual?.lookAt(three.Vector3(0, 0, 0));
    }
  }

  // ========================= Overlay UI =========================

  Widget _buildOverlayUI(BuildContext context) {
    final detail = showRayDetail
        ? RayDetail(
            samples: selectedRaySamples,
            rayStep: rayStep,
            showTransmittance: showTransmittanceCurve,
          )
        : const SizedBox.shrink();

    return Stack(
      children: [
        Align(
          alignment: Alignment.bottomCenter,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 16,
            children: [
              AnimatedOpacity(
                duration: kThemeAnimationDuration,
                opacity: widget.showSensor ? 1.0 : 0.0,
                child: ControlCard(
                  title: 'Sensor (16×16)',
                  child: SensorView(
                    image: sensorImage,
                    w: camW,
                    h: camH,
                    onTapPixel: (u, v) {
                      selectedU = u;
                      selectedV = v;
                      // recompute that ray's detailed samples now
                      final origin = fakeCam.position.clone();
                      final dir = _rayDirForPixel(u, v);
                      final bboxMin = three.Vector3(
                        -fieldHalf,
                        -fieldHalf,
                        -fieldHalf,
                      );
                      final bboxMax = three.Vector3(
                        fieldHalf,
                        fieldHalf,
                        fieldHalf,
                      );
                      final hit = _rayAABB(origin, dir, bboxMin, bboxMax);
                      if (hit.hit) {
                        final res = _marchOneRay(
                          origin,
                          dir,
                          hit.t0,
                          hit.t1,
                          collect: true,
                        );
                        selectedRaySamples = res.samples;
                      } else {
                        selectedRaySamples = [];
                      }

                      // Update the 3D visualization of the selected ray
                      _updateSelectedRayVisualization();

                      setState(() {});
                    },
                    selectedU: selectedU,
                    selectedV: selectedV,
                  ),
                ),
              ),
              Expanded(
                child: AnimatedOpacity(
                  duration: kThemeAnimationDuration,
                  opacity: widget.showRaySamples ? 1.0 : 0.0,
                  child: ControlCard(
                    title: 'Selected Ray Breakdown',
                    width: double.infinity,
                    child: detail,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
