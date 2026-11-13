import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // Applied after launch so it is not overridden by the nib's frame:
    // wide enough for the two-column layout, centred on screen.
    DispatchQueue.main.async {
      self.title = "מחשבון הלוואה"
      self.contentMinSize = NSSize(width: 380, height: 560)
      self.setContentSize(NSSize(width: 1240, height: 860))
      self.center()
    }
  }
}
