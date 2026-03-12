import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var screenshotChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Screenshot detection channel
    if let controller = window?.rootViewController as? FlutterViewController {
      screenshotChannel = FlutterMethodChannel(
        name: "com.pgpchat/screenshot",
        binaryMessenger: controller.binaryMessenger
      )

      // Listen for screenshot events and notify Flutter
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(screenshotTaken),
        name: UIApplication.userDidTakeScreenshotNotification,
        object: nil
      )
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @objc func screenshotTaken() {
    screenshotChannel?.invokeMethod("onScreenshotDetected", arguments: nil)
  }
}
