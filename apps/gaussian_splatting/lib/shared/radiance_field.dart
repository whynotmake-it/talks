import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;

void main() {
  runApp(const RadianceFieldDemoApp());
}

class RadianceFieldDemoApp extends StatelessWidget {
  const RadianceFieldDemoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radiance Fields Demo (Flutter + three_js)',
      debugShowCheckedModeBanner: false,
      home: const RadianceFieldScreen(),
    );
  }
}

class RadianceFieldScreen extends StatefulWidget {
  const RadianceFieldScreen({super.key});
  @override
  State<RadianceFieldScreen> createState() => _RadianceFieldScreenState();
}

class _RadianceFieldScreenState extends State<RadianceFieldScreen> {
  late three.ThreeJS threeJs;

  // ---- Scene params
  static const int nx = 16, ny = 16, nz = 16;
  static const int camW = 16, camH = 16; // fake sensor rays
  static const double voxelSize = 1.0;
  static const double fieldHalf = (nx * voxelSize) / 2.0; // half-extent
  static const double rayStep = 0.5; // march step in world units
  static const double densityScale = 1.2; // scales sigma
  static const double earlyStopT = 0.01; // early termination if T < this
  bool showAllRays = true;

  // fake camera spherical params
  double yaw = 35 * math.pi / 180.0;
  double pitch = 20 * math.pi / 180.0;
  double camRadius = 26.0;

  // volume data (density/color grid)
  late final List<double> sigmaGrid; // length nx*ny*nz
  late final List<double> colorR, colorG, colorB;

  // Instanced voxels
  late three.InstancedMesh voxelsMesh;
  final three.Object3D _dummy = three.Object3D();

  // Fake camera that casts the rays (renders not from this, but from observer camera)
  late three.PerspectiveCamera fakeCam;
  late three.Object3D? fakeCamVisual;

  // Rays visualization
  late three.LineSegments raysLines;
  late three.BufferGeometry raysGeom;
  late three.LineBasicMaterial raysMat;

  // 2D sensor result (16x16 pixels)
  final List<Color> sensorImage = List<Color>.filled(
    camW * camH,
    Colors.black,
    growable: false,
  );

  // Selected pixel details
  int selectedU = 8, selectedV = 8;
  List<_SampleRecord> selectedRaySamples = [];

  // Flags/UI
  bool showInstancedVoxels = true;
  bool showRayDetail = true;
  bool showTransmittanceCurve = true;
  bool viewDependentColor = false;

  @override
  void initState() {
    super.initState();

    // Build a procedural 3D grid as our radiance field (sigma + rgb per voxel)
    sigmaGrid = List<double>.filled(nx * ny * nz, 0.0, growable: false);
    colorR = List<double>.filled(nx * ny * nz, 0.0, growable: false);
    colorG = List<double>.filled(nx * ny * nz, 0.0, growable: false);
    colorB = List<double>.filled(nx * ny * nz, 0.0, growable: false);
    _populateField();

    threeJs = three.ThreeJS(
      onSetupComplete: () => setState(() {}),
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
  void dispose() {
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
          Positioned.fill(child: threeJs.build()),
          Positioned.fill(child: ui),
        ],
      ),
    );
  }

  // ========================= Setup three_js scene =========================

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

    // Scene & lights
    threeJs.scene = three.Scene();
    threeJs.scene.background = three.Color.fromHex32(0x101418);
    final amb = three.AmbientLight(0xffffff, 0.75);
    final dir = three.DirectionalLight(0xffffff, 0.75);
    dir.position.setValues(30, 50, 20);
    threeJs.scene.add(amb);
    threeJs.scene.add(dir);

    // A ground grid to help orientation
    // final grid = three.GridHelper(60, 30, three.Color(0x444444), three.Color(0x222222));
    // grid.position.y = -fieldHalf - 0.6;
    // threeJs.scene.add(grid);

       // Visual representation of fake camera
    _buildFakeCameraVisual();

    // Fake camera that "casts rays" through the field
    fakeCam = three.PerspectiveCamera(60, 1, 0.1, 200);
    _updateFakeCamTransform();
    threeJs.scene.add(fakeCam);

 

    // Voxel field visualization with instancing
    _buildVoxelInstancing();

    // Rays visualization (thin semi-transparent lines)
    _buildRaysLines();

    // Do first render/march immediately
    _marchAllRays();

    // Animation/update loop - only update when needed
    threeJs.addAnimationEvent((dt) {
      // Only update rays visualization, camera transform is updated via sliders
      _updateRaysLinesGeom();
    });
  }

  // ========================= Field generation & sampling =========================

  void _populateField() {
    // A couple of soft 3D blobs + a slanted "wall" to make occlusion obvious.
    final blobs = <_Blob>[
      _Blob(
        center: three.Vector3(-3, -1.5, 0),
        sigma: 1.1,
        density: 2.0,
        color: const [0.9, 0.2, 0.2],
      ),
      _Blob(
        center: three.Vector3(3.5, 1.5, 2.0),
        sigma: 1.6,
        density: 1.8,
        color: const [0.2, 0.8, 0.3],
      ),
      _Blob(
        center: three.Vector3(0.0, 0.0, -3.5),
        sigma: 1.2,
        density: 2.4,
        color: const [0.2, 0.5, 1.0],
      ),
    ];

    for (int k = 0; k < nz; k++) {
      for (int j = 0; j < ny; j++) {
        for (int i = 0; i < nx; i++) {
          final world = _voxelCenterToWorld(i, j, k);
          double sig = 0.0;
          double r = 0, g = 0, b = 0;

          for (final blob in blobs) {
            final d2 = world.distanceToSquared(blob.center);
            final w = math.exp(-d2 / (2 * blob.sigma * blob.sigma));
            sig += blob.density * w;
            r += blob.color[0] * w;
            g += blob.color[1] * w;
            b += blob.color[2] * w;
          }

          // Slanted "sheet"
          final s = (world.x + world.y * 0.6 - 1.5);
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
  _FieldSample _sampleField(three.Vector3 p, three.Vector3 rayDir) {
    // Map world coords [-fieldHalf, fieldHalf] to grid coords [0, nx), etc.
    final gx = ((p.x + fieldHalf) / voxelSize).clamp(0.0, nx - 1.0001);
    final gy = ((p.y + fieldHalf) / voxelSize).clamp(0.0, ny - 1.0001);
    final gz = ((p.z + fieldHalf) / voxelSize).clamp(0.0, nz - 1.0001);

    final i0 = gx.floor().toInt();
    final j0 = gy.floor().toInt();
    final k0 = gz.floor().toInt();

    final tx = gx - i0;
    final ty = gy - j0;
    final tz = gz - k0;

    double sigma = 0;
    double r = 0, g = 0, b = 0;

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
    if (viewDependentColor) {
      final n = three.Vector3(0, 1, 0); // fake "up" normal to hint the idea
      final ndotv = n.dot(rayDir.clone().negate()).clamp(0, 1);
      final lobe = math.pow(ndotv, 8).toDouble();
      r = (r + 0.7 * lobe).clamp(0.0, 1.0);
      g = (g + 0.7 * lobe).clamp(0.0, 1.0);
      b = (b + 0.7 * lobe).clamp(0.0, 1.0);
    }

    return _FieldSample(sigma * densityScale, r, g, b);
  }

  // ========================= Ray marching & sensor image =========================

  void _marchAllRays() {
    print('DEBUG: _marchAllRays called');
    final origin = fakeCam.position.clone();
    print('DEBUG: Ray marching from origin: (${origin.x}, ${origin.y}, ${origin.z})');
    final bboxMin = three.Vector3(-fieldHalf, -fieldHalf, -fieldHalf);
    final bboxMax = three.Vector3(fieldHalf, fieldHalf, fieldHalf);

    // Update entire 16x16
    for (int v = 0; v < camH; v++) {
      for (int u = 0; u < camW; u++) {
        final dir = _rayDirForPixel(u, v);
        final _RayBoxHit hit = _rayAABB(origin, dir, bboxMin, bboxMax);
        Color c = Colors.black;
        if (hit.hit) {
          final res = _marchOneRay(
            origin,
            dir,
            hit.t0,
            hit.t1,
            collect: (u == selectedU && v == selectedV),
          );
          c = Color.fromARGB(
            0xFF,
            (res.r.clamp(0.0, 1.0) * 255).toInt(),
            (res.g.clamp(0.0, 1.0) * 255).toInt(),
            (res.b.clamp(0.0, 1.0) * 255).toInt(),
          );
          if (u == selectedU && v == selectedV) {
            selectedRaySamples = res.samples; // for the detail panel
          }
        }
        sensorImage[v * camW + u] = c;
      }
    }
    setState(() {});
  }

  _MarchResult _marchOneRay(
    three.Vector3 origin,
    three.Vector3 dir,
    double t0,
    double t1, {
    required bool collect,
  }) {
    double T = 1.0;
    double rAcc = 0, gAcc = 0, bAcc = 0;

    final samples = <_SampleRecord>[];

    double t = t0;
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
          _SampleRecord(
            t: t,
            sigma: sigma,
            alpha: alpha,
            Tbefore: T,
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

      T *= (1.0 - alpha);
      t += rayStep;
    }

    return _MarchResult(rAcc, gAcc, bAcc, samples);
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

  _RayBoxHit _rayAABB(
    three.Vector3 o,
    three.Vector3 d,
    three.Vector3 bmin,
    three.Vector3 bmax,
  ) {
    double tmin = (bmin.x - o.x) / d.x;
    double tmax = (bmax.x - o.x) / d.x;
    if (tmin > tmax) {
      final tmp = tmin;
      tmin = tmax;
      tmax = tmp;
    }

    double tymin = (bmin.y - o.y) / d.y;
    double tymax = (bmax.y - o.y) / d.y;
    if (tymin > tymax) {
      final tmp = tymin;
      tymin = tymax;
      tymax = tmp;
    }
    if ((tmin > tymax) || (tymin > tmax)) return _RayBoxHit(false, 0, 0);

    if (tymin > tmin) tmin = tymin;
    if (tymax < tmax) tmax = tymax;

    double tzmin = (bmin.z - o.z) / d.z;
    double tzmax = (bmax.z - o.z) / d.z;
    if (tzmin > tzmax) {
      final tmp = tzmin;
      tzmin = tzmax;
      tzmax = tmp;
    }
    if ((tmin > tzmax) || (tzmin > tmax)) return _RayBoxHit(false, 0, 0);

    if (tzmin > tmin) tmin = tzmin;
    if (tzmax < tmax) tmax = tzmax;

    if (tmax < 0) return _RayBoxHit(false, 0, 0);
    return _RayBoxHit(true, math.max(0.0, tmin), tmax);
  }

  // ========================= Instanced voxels & rays lines =========================

  void _buildFakeCameraVisual() {
    // Create a visual representation of the fake camera
    final cameraGroup = three.Group();
    
    // Camera body (small cube)
    final bodyGeom = three.BoxGeometry(1.5, 1.0, 2.0);
    final bodyMat = three.MeshStandardMaterial.fromMap({
      "color": 0xff4444,
      "roughness": 0.3,
      "metalness": 0.1,
    });
    final body = three.Mesh(bodyGeom, bodyMat);
    cameraGroup.add(body);
    
    // Camera lens (cylinder pointing forward)
    final lensGeom = three.CylinderGeometry(0.3, 0.3, 1.0);
    final lensMat = three.MeshStandardMaterial.fromMap({
      "color": 0x333333,
      "roughness": 0.1,
      "metalness": 0.8,
    });
    final lens = three.Mesh(lensGeom, lensMat);
    lens.rotation.x = math.pi / 2; // Point forward
    lens.position.z = -1.5; // In front of body
    cameraGroup.add(lens);
    
    // Direction indicator (small arrow/cone)
    final arrowGeom = three.ConeGeometry(0.2, 1.0);
    final arrowMat = three.MeshStandardMaterial.fromMap({
      "color": 0xffff00,
      "roughness": 0.3,
    });
    final arrow = three.Mesh(arrowGeom, arrowMat);
    arrow.rotation.x = math.pi / 2; // Point forward
    arrow.position.z = -2.5; // In front of lens
    cameraGroup.add(arrow);
    
    fakeCamVisual = cameraGroup;
    threeJs.scene.add(fakeCamVisual);
    print('DEBUG: Fake camera visual added to scene');
  }

  void _buildVoxelInstancing() {
    // Create an instanced grid of semi-transparent cubes just for intuition
    final geom = three.BoxGeometry(
      voxelSize * 0.95,
      voxelSize * 0.95,
      voxelSize * 0.95,
    );
    final mat = three.MeshStandardMaterial.fromMap({
      "color": 0x4fc3f7,
      "transparent": true,
      "opacity": 0.12,
      "roughness": 0.9,
      "metalness": 0.0,
    });

    voxelsMesh = three.InstancedMesh(geom, mat, nx * ny * nz);
    int i = 0;
    for (int z = 0; z < nz; z++) {
      for (int y = 0; y < ny; y++) {
        for (int x = 0; x < nx; x++) {
          final p = _voxelCenterToWorld(x, y, z);
          _dummy.position.setFrom(p);
          _dummy.rotation.set(0, 0, 0);
          _dummy.updateMatrix();
          voxelsMesh.setMatrixAt(i++, _dummy.matrix);
        }
      }
    }
    voxelsMesh.instanceMatrix?.needsUpdate = true;
    threeJs.scene.add(voxelsMesh);
  }

  void _buildRaysLines() {
    // We’ll draw line segments from the fake camera to the AABB exit point, one per pixel.
    final nSegments = camW * camH;
    final positions = three.Float32Array(nSegments * 2 * 3);

    raysGeom = three.BufferGeometry();
    final posAttr = three.Float32BufferAttribute(positions, 3, false);
    raysGeom.setAttribute(three.Attribute.position, posAttr);

    raysMat = three.LineBasicMaterial.fromMap({
      "color": 0xffffff,
      "transparent": true,
      "opacity": 0.12,
      "linewidth": 1, // platform dependent
    });

    raysLines = three.LineSegments(raysGeom, raysMat);
    threeJs.scene.add(raysLines);
  }

  void _updateRaysLinesGeom() {
    print('DEBUG: _updateRaysLinesGeom called, showAllRays=$showAllRays');
    if (!showAllRays) {
      print('DEBUG: Hiding rays lines');
      raysLines.visible = false;
      return;
    }
    print('DEBUG: Showing rays lines');
    raysLines.visible = true;

    final posAttr =
        raysGeom.getAttribute(three.Attribute.position)
            as three.Float32BufferAttribute;
    final positions = posAttr.array as Float32List;

    final o = fakeCam.position.clone();
    final bboxMin = three.Vector3(-fieldHalf, -fieldHalf, -fieldHalf);
    final bboxMax = three.Vector3(fieldHalf, fieldHalf, fieldHalf);

    int ptr = 0;
    for (int v = 0; v < camH; v++) {
      for (int u = 0; u < camW; u++) {
        final dir = _rayDirForPixel(u, v);
        final hit = _rayAABB(o, dir, bboxMin, bboxMax);

        three.Vector3 a = o;
        three.Vector3 b = hit.hit
            ? o.clone().add(dir.clone().scale(hit.t1))
            : o.clone().add(dir.clone().scale(10.0)); // short stub if miss

        positions[ptr++] = a.x;
        positions[ptr++] = a.y;
        positions[ptr++] = a.z;
        positions[ptr++] = b.x;
        positions[ptr++] = b.y;
        positions[ptr++] = b.z;
      }
    }
    posAttr.needsUpdate = true;
    print('DEBUG: Ray lines geometry updated, posAttr.needsUpdate set to true');
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
    print('DEBUG: _updateFakeCamTransform called with yaw=$yaw, pitch=$pitch, radius=$camRadius');
    final x = camRadius * math.cos(pitch) * math.cos(yaw);
    final y = camRadius * math.sin(pitch);
    final z = camRadius * math.cos(pitch) * math.sin(yaw);
    print('DEBUG: Computed camera position: ($x, $y, $z)');
    fakeCam.position.setValues(x, y, z);
    fakeCam.lookAt(three.Vector3(0, 0, 0));
    print('DEBUG: Updated fakeCam position');
    
    // Update visual representation
    if (fakeCamVisual != null) {
      print('DEBUG: Updating fakeCamVisual position');
      fakeCamVisual?.position.setFrom(fakeCam.position);
      fakeCamVisual?.lookAt(three.Vector3(0, 0, 0));
      print('DEBUG: Updated fakeCamVisual position');
    } else {
      print('DEBUG: WARNING - fakeCamVisual is null!');
    }
  }

  // ========================= Overlay UI =========================

  Widget _buildOverlayUI(BuildContext context) {
    final sensor = _SensorView(
      image: sensorImage,
      w: camW,
      h: camH,
      onTapPixel: (u, v) {
        selectedU = u;
        selectedV = v;
        // recompute that ray’s detailed samples now
        final origin = fakeCam.position.clone();
        final dir = _rayDirForPixel(u, v);
        final bboxMin = three.Vector3(-fieldHalf, -fieldHalf, -fieldHalf);
        final bboxMax = three.Vector3(fieldHalf, fieldHalf, fieldHalf);
        final hit = _rayAABB(origin, dir, bboxMin, bboxMax);
        if (hit.hit) {
          final res = _marchOneRay(origin, dir, hit.t0, hit.t1, collect: true);
          selectedRaySamples = res.samples;
        } else {
          selectedRaySamples = [];
        }
    print('DEBUG: _marchAllRays completed, calling setState');
    setState(() {});
      },
      selectedU: selectedU,
      selectedV: selectedV,
    );

    final detail = showRayDetail
        ? _RayDetail(
            samples: selectedRaySamples,
            rayStep: rayStep,
            showTransmittance: showTransmittanceCurve,
          )
        : const SizedBox.shrink();

    return IgnorePointer(
      ignoring: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SafeArea(child: SizedBox()),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 12),
              // Left: controls
              _ControlCard(
                title: 'Fake Camera',
                child: Column(
                  children: [
                    _sliderRow(
                      'Yaw',
                      yaw,
                      -math.pi,
                      math.pi,
                      (v) => setState(() {
                        print('DEBUG: Yaw slider changed to $v');
                        yaw = v;
                        print('DEBUG: About to call _updateFakeCamTransform');
                        _updateFakeCamTransform();
                        print('DEBUG: About to call _marchAllRays');
                        _marchAllRays();
                        print('DEBUG: Slider update complete');
                      }),
                    ),
                    _sliderRow(
                      'Pitch',
                      pitch,
                      -math.pi / 2 + 0.05,
                      math.pi / 2 - 0.05,
                      (v) => setState(() {
                        pitch = v;
                        _updateFakeCamTransform();
                        _marchAllRays();
                      }),
                    ),
                    _sliderRow(
                      'Radius',
                      camRadius,
                      10.0,
                      40.0,
                      (v) => setState(() {
                        camRadius = v;
                        _updateFakeCamTransform();
                        _marchAllRays();
                      }),
                    ),
                    const Divider(),
                    CheckboxListTile(
                      value: showAllRays,
                      onChanged: (v) => setState(() => showAllRays = v ?? true),
                      title: const Text('Show 16×16 rays'),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    CheckboxListTile(
                      value: showInstancedVoxels,
                      onChanged: (v) {
                        setState(() {
                          showInstancedVoxels = v ?? true;
                          voxelsMesh.visible = showInstancedVoxels;
                        });
                      },
                      title: const Text('Show voxel cubes'),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    CheckboxListTile(
                      value: viewDependentColor,
                      onChanged: (v) =>
                          setState(() => viewDependentColor = v ?? false),
                      title: const Text('View-dependent color (toy)'),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Middle: sensor view
              _ControlCard(
                title: 'Sensor (16×16)',
                child: sensor,
              ),
              const SizedBox(width: 12),
              // Right: per-ray breakdown
              Expanded(
                child: _ControlCard(
                  title: 'Selected Ray Breakdown',
                  child: detail,
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(value.toStringAsFixed(2), textAlign: TextAlign.right),
        ),
      ],
    );
  }
}

// ========================= Widgets: sensor view & ray detail =========================

class _SensorView extends StatelessWidget {
  final List<Color> image;
  final int w, h;
  final void Function(int u, int v) onTapPixel;
  final int selectedU, selectedV;

  const _SensorView({
    required this.image,
    required this.w,
    required this.h,
    required this.onTapPixel,
    required this.selectedU,
    required this.selectedV,
  });

  @override
  Widget build(BuildContext context) {
    final double cell = 16; // px per cell in UI
    return GestureDetector(
      onTapDown: (d) {
        final box = (context.findRenderObject() as RenderBox);
        final local = box.globalToLocal(d.globalPosition);
        final u = (local.dx / cell).floor().clamp(0, w - 1);
        final v = (local.dy / cell).floor().clamp(0, h - 1);
        onTapPixel(u, v);
      },
      child: CustomPaint(
        size: Size(w * cell, h * cell),
        painter: _SensorPainter(
          image: image,
          w: w,
          h: h,
          selectedU: selectedU,
          selectedV: selectedV,
        ),
      ),
    );
  }
}

class _SensorPainter extends CustomPainter {
  final List<Color> image;
  final int w, h;
  final int selectedU, selectedV;

  _SensorPainter({
    required this.image,
    required this.w,
    required this.h,
    required this.selectedU,
    required this.selectedV,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / w;
    final p = Paint()..style = PaintingStyle.fill;

    for (int v = 0; v < h; v++) {
      for (int u = 0; u < w; u++) {
        p.color = image[v * w + u];
        canvas.drawRect(Rect.fromLTWH(u * cell, v * cell, cell, cell), p);
      }
    }

    // Grid lines
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.white.withOpacity(0.08);
    for (int u = 0; u <= w; u++) {
      canvas.drawLine(Offset(u * cell, 0), Offset(u * cell, size.height), grid);
    }
    for (int v = 0; v <= h; v++) {
      canvas.drawLine(Offset(0, v * cell), Offset(size.width, v * cell), grid);
    }

    // Selected pixel outline
    final sel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white.withOpacity(0.9);
    canvas.drawRect(
      Rect.fromLTWH(selectedU * cell, selectedV * cell, cell, cell),
      sel,
    );
  }

  @override
  bool shouldRepaint(covariant _SensorPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.selectedU != selectedU ||
        oldDelegate.selectedV != selectedV;
    // repaint on changes
  }
}

class _RayDetail extends StatelessWidget {
  final List<_SampleRecord> samples;
  final double rayStep;
  final bool showTransmittance;

  const _RayDetail({
    required this.samples,
    required this.rayStep,
    required this.showTransmittance,
  });

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No hit / outside volume')),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, 260),
          painter: _RayDetailPainter(
            samples: samples,
            showTransmittance: showTransmittance,
          ),
        );
      },
    );
  }
}

class _RayDetailPainter extends CustomPainter {
  final List<_SampleRecord> samples;
  final bool showTransmittance;

  _RayDetailPainter({required this.samples, required this.showTransmittance});

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 10.0;
    final width = size.width - padding * 2;
    final height = size.height - padding * 2;

    // Top row: dots for samples along t (x-axis), opacity by alpha, size by Tbefore
    final rowH = height * 0.45;
    final tMin = samples.first.t;
    final tMax = samples.last.t;
    double xForT(double t) =>
        padding + (t - tMin) / (tMax - tMin + 1e-6) * width;

    // Guides
    final guide = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1.0;
    canvas.drawRect(Rect.fromLTWH(padding, padding, width, rowH), guide);

    for (final s in samples) {
      final x = xForT(s.t);
      final y = padding + rowH / 2;
      final dot = Paint()
        ..style = PaintingStyle.fill
        ..color = s.color.withOpacity((s.alpha).clamp(0.05, 1.0));
      final r = (4.0 + 12.0 * s.Tbefore).clamp(2.0, 10.0);
      canvas.drawCircle(Offset(x, y), r, dot);
    }

    // Bottom row: stacked contributions (w * color)
    final bottomY = padding + rowH + 8;
    final contribH = height - rowH - 8;

    double x = padding;
    for (final s in samples) {
      final w = s.w; // contribution weight
      final barW = (w * width).clamp(
        0.5,
        width,
      ); // visualize by weight proportionally
      final p = Paint()..color = s.color.withOpacity(0.85);
      canvas.drawRect(Rect.fromLTWH(x, bottomY, barW, contribH), p);
      x += barW;
      if (x > padding + width - 1) break;
    }

    if (showTransmittance) {
      // Overdraw T(t) curve over the top row
      final path = Path();
      bool first = true;
      for (final s in samples) {
        final xx = xForT(s.t);
        final yy = padding + rowH * (1 - s.Tbefore);
        if (first) {
          path.moveTo(xx, yy);
          first = false;
        } else {
          path.lineTo(xx, yy);
        }
      }
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.orangeAccent.withOpacity(0.9);
      canvas.drawPath(path, pen);
    }
  }

  @override
  bool shouldRepaint(covariant _RayDetailPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.showTransmittance != showTransmittance;
  }
}

// ========================= Data classes =========================

class _Blob {
  final three.Vector3 center;
  final double sigma; // spatial stddev
  final double density; // scale
  final List<double> color; // r,g,b 0..1
  _Blob({
    required this.center,
    required this.sigma,
    required this.density,
    required this.color,
  });
}

class _FieldSample {
  final double sigma;
  final double r, g, b;
  _FieldSample(this.sigma, this.r, this.g, this.b);
}

class _RayBoxHit {
  final bool hit;
  final double t0, t1;
  _RayBoxHit(this.hit, this.t0, this.t1);
}

class _SampleRecord {
  final double t;
  final double sigma;
  final double alpha;
  final double Tbefore;
  final double w;
  final Color color;
  final three.Vector3 p;
  _SampleRecord({
    required this.t,
    required this.sigma,
    required this.alpha,
    required this.Tbefore,
    required this.w,
    required this.color,
    required this.p,
  });
}

class _MarchResult {
  final double r, g, b;
  final List<_SampleRecord> samples;
  _MarchResult(this.r, this.g, this.b, this.samples);
}

// ========================= UI bits =========================

class _ControlCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ControlCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E2430),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SizedBox(
          width: 400,
          height: 308,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
