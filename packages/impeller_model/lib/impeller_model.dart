/// Estimates the Impeller GPU work of a Flutter screen from a widget test:
/// render passes per frame, memory traffic per device class, and the frames
/// a screen keeps requesting while idle.
///
/// Every engine decision it mirrors is pinned to one Flutter release (see
/// [pinnedFlutterVersion]) and quoted from that engine's source.
library;

export 'package:device_frame/device_frame.dart' show DeviceInfo, Devices;

export 'src/api/estimate_gpu.dart' show GpuReport, estimateGpu;
export 'src/api/frame_demand.dart'
    show
        FrameDemand,
        FrameDemandVerdict,
        FrameSample,
        FrameSource,
        measureFrameDemand;
export 'src/api/frame_estimate.dart'
    show CostCenter, FrameEstimate, estimateFrame;
export 'src/api/gpu_device.dart' show GpuDevice;
export 'src/capture/binding.dart'
    show DrawnFrame, FrameCapture, ImpellerModelBinding;
export 'src/capture/creation_location.dart' show WidgetOrigin;
export 'src/capture/frame_requests.dart' show FrameRequestOrigin;
export 'src/capture/layer_walk.dart' show CapturedLayer;
export 'src/capture/tickers.dart' show TickerInfo, findTickers;
export 'src/engine/canvas.dart' show ModelPass, PassRole, PassTimeline;
export 'src/engine/capabilities.dart'
    show CapabilityProfile, GpuBackend, PixelFormat;
export 'src/engine/labels.dart' show EngineLabels;
export 'src/engine/revision.dart'
    show pinnedEngineRevision, pinnedFlutterVersion;
export 'src/model/traffic.dart' show MemoryTraffic;
