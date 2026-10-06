import Cocoa
import FlutterMacOS

/// A fixed 400x800 pt window, so validation traces render at a known size
/// (800x1600 px on a 2x display), matching test/predict_test.dart.
class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.styleMask.remove(.resizable)
    self.setContentSize(NSSize(width: 400, height: 800))

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
