import Flutter
import UIKit
import ImageIO

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "stamp_korea/photo_import", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        guard call.method == "heicToJpeg" else { result(FlutterMethodNotImplemented); return }
        guard let input = call.arguments as? FlutterStandardTypedData,
              input.data.count <= 20 * 1024 * 1024 else {
          result(FlutterError(code: "INVALID_IMAGE", message: "Invalid photo", details: nil)); return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          let output: Data? = autoreleasepool {
            guard let source = CGImageSourceCreateWithData(input.data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
                  let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
                  width.doubleValue > 0, height.doubleValue > 0,
                  width.doubleValue * height.doubleValue <= 80_000_000 else { return nil }
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
              kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1600,
              kCGImageSourceShouldCacheImmediately: true]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            return UIImage(cgImage: image).jpegData(compressionQuality: 0.9)
          }
          DispatchQueue.main.async {
            if let output = output { result(FlutterStandardTypedData(bytes: output)) }
            else { result(FlutterError(code: "HEIC_CONVERSION", message: "Cannot decode photo", details: nil)) }
          }
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
