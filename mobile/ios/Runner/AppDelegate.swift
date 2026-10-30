import AVFoundation
import Flutter
import Photos
import UIKit

final class WeDoDeepLinkBridge {
  static let shared = WeDoDeepLinkBridge()
  private var initialLink: String?
  private var isDartReady = false
  private weak var channel: FlutterMethodChannel?

  func attachChannel(_ methodChannel: FlutterMethodChannel) {
    self.channel = methodChannel
  }

  func consumeInitialLink() -> String? {
    isDartReady = true
    let link = initialLink
    initialLink = nil
    return link
  }

  func handleIncomingURL(_ url: URL?) {
    guard let raw = url?.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines),
          !raw.isEmpty else { return }
    DispatchQueue.main.async {
      if self.isDartReady, let channel = self.channel {
        channel.invokeMethod("onDeepLink", arguments: raw)
      } else {
        self.initialLink = raw
      }
    }
  }
}

final class WeDoQrScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
  private let session = AVCaptureSession()
  private var previewLayer: AVCaptureVideoPreviewLayer?
  private var finished = false
  private let onResult: (String?) -> Void

  init(onResult: @escaping (String?) -> Void) {
    self.onResult = onResult
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .fullScreen
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black

    guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
          let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
          session.canAddInput(videoInput) else {
      finish(with: nil)
      return
    }
    session.addInput(videoInput)

    let metadataOutput = AVCaptureMetadataOutput()
    guard session.canAddOutput(metadataOutput) else {
      finish(with: nil)
      return
    }
    session.addOutput(metadataOutput)
    metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
    if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
      metadataOutput.metadataObjectTypes = [.qr]
    }

    let preview = AVCaptureVideoPreviewLayer(session: session)
    preview.frame = view.layer.bounds
    preview.videoGravity = .resizeAspectFill
    view.layer.addSublayer(preview)
    previewLayer = preview

    setupOverlay()
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      self?.session.startRunning()
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    previewLayer?.frame = view.layer.bounds
  }

  private func setupOverlay() {
    let topBar = UIView()
    topBar.backgroundColor = UIColor.black.withAlphaComponent(0.55)
    topBar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(topBar)

    let titleLabel = UILabel()
    titleLabel.text = "Quét mã QR bạn bè"
    titleLabel.textColor = .white
    titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    topBar.addSubview(titleLabel)

    let closeButton = UIButton(type: .system)
    closeButton.setTitle("Đóng", for: .normal)
    closeButton.setTitleColor(.white, for: .normal)
    closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    topBar.addSubview(closeButton)

    let reticle = UIView()
    reticle.layer.borderColor = UIColor(red: 0.72, green: 0.50, blue: 1.0, alpha: 1.0).cgColor
    reticle.layer.borderWidth = 3
    reticle.layer.cornerRadius = 24
    reticle.backgroundColor = .clear
    reticle.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(reticle)

    let hintLabel = UILabel()
    hintLabel.text = "Đặt mã QR weDO vào trong khung để mở hồ sơ"
    hintLabel.textColor = .white
    hintLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
    hintLabel.textAlignment = .center
    hintLabel.numberOfLines = 2
    hintLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
    hintLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(hintLabel)

    NSLayoutConstraint.activate([
      topBar.topAnchor.constraint(equalTo: view.topAnchor),
      topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

      titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
      titleLabel.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 20),
      titleLabel.bottomAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -12),

      closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
      closeButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -20),

      reticle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      reticle.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      reticle.widthAnchor.constraint(equalToConstant: 240),
      reticle.heightAnchor.constraint(equalToConstant: 240),

      hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hintLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      hintLabel.heightAnchor.constraint(equalToConstant: 88)
    ])
  }

  @objc private func handleClose() {
    finish(with: nil)
  }

  func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
    guard !finished,
          let readable = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
          readable.type == .qr,
          let value = readable.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty else { return }
    finish(with: value)
  }

  private func finish(with value: String?) {
    guard !finished else { return }
    finished = true
    if session.isRunning {
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        self?.session.stopRunning()
      }
    }
    dismiss(animated: true) { [onResult] in
      onResult(value)
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var savingImage = false
  private var scanningQr = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let url = launchOptions?[.url] as? URL {
      WeDoDeepLinkBridge.shared.handleIncomingURL(url)
    } else if let activityDict = launchOptions?[.userActivityDictionary] as? [AnyHashable: Any] {
      for (_, value) in activityDict {
        if let activity = value as? NSUserActivity,
           activity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = activity.webpageURL {
          WeDoDeepLinkBridge.shared.handleIncomingURL(url)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    WeDoDeepLinkBridge.shared.handleIncomingURL(url)
    return true
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      WeDoDeepLinkBridge.shared.handleIncomingURL(url)
      return true
    }
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(
      name: "wedo/media_gallery", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "saveImage" else { result(FlutterMethodNotImplemented); return }
      guard let self = self else { return }
      guard !self.savingImage else {
        result(FlutterError(code: "save_busy", message: "Save already in progress", details: nil)); return
      }
      guard let arguments = call.arguments as? [String: Any],
            let bytes = arguments["bytes"] as? FlutterStandardTypedData,
            !bytes.data.isEmpty, bytes.data.count <= 10 * 1024 * 1024,
            let mime = arguments["contentType"] as? String,
            let suffix = ["image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"][mime]
      else { result(FlutterError(code: "invalid_file", message: "Unsupported image", details: nil)); return }
      self.savingImage = true
      let finish: (String?) -> Void = { code in
        DispatchQueue.main.async {
          self.savingImage = false
          if let code = code {
            result(FlutterError(code: code, message: "Unable to save image", details: nil))
          } else { result(nil) }
        }
      }
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        guard status == .authorized || status == .limited else {
          switch status {
          case .restricted: finish("permission_restricted")
          case .denied: finish("permission_denied")
          default: finish("permission_unavailable")
          }
          return
        }
        PHPhotoLibrary.shared().performChanges({
          let options = PHAssetResourceCreationOptions()
          options.originalFilename = "weDO-\(UUID().uuidString).\(suffix)"
          PHAssetCreationRequest.forAsset().addResource(with: .photo, data: bytes.data, options: options)
        }) { success, _ in finish(success ? nil : "save_failed") }
      }
    }

    let deepLinkChannel = FlutterMethodChannel(
      name: "wedo/deep_links", binaryMessenger: messenger)
    WeDoDeepLinkBridge.shared.attachChannel(deepLinkChannel)
    deepLinkChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "getInitialLink":
        result(WeDoDeepLinkBridge.shared.consumeInitialLink())
      case "shareText":
        guard let args = call.arguments as? [String: Any],
              let text = (args["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
          result(FlutterError(code: "invalid_args", message: "Text is required", details: nil))
          return
        }
        DispatchQueue.main.async {
          guard let presenter = self.topPresenter() else {
            result(FlutterError(code: "no_presenter", message: "Unable to present share sheet", details: nil))
            return
          }
          let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
          if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
              x: presenter.view.bounds.midX,
              y: presenter.view.bounds.midY,
              width: 1,
              height: 1
            )
          }
          presenter.present(activityVC, animated: true) {
            result(true)
          }
        }
      case "scanQr":
        guard !self.scanningQr else {
          result(FlutterError(code: "scan_busy", message: "Scanner already active", details: nil))
          return
        }
        self.scanningQr = true
        let finishScan: (String?, FlutterError?) -> Void = { value, error in
          DispatchQueue.main.async {
            self.scanningQr = false
            if let error = error {
              result(error)
            } else {
              result(value)
            }
          }
        }
        let presentScanner = {
          DispatchQueue.main.async {
            guard AVCaptureDevice.default(for: .video) != nil else {
              finishScan(nil, FlutterError(code: "camera_unavailable", message: "Camera unavailable", details: nil))
              return
            }
            guard let presenter = self.topPresenter() else {
              finishScan(nil, FlutterError(code: "no_presenter", message: "Unable to open scanner", details: nil))
              return
            }
            let scannerVC = WeDoQrScannerViewController { qrValue in
              finishScan(qrValue, nil)
            }
            presenter.present(scannerVC, animated: true)
          }
        }
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
        case .authorized:
          presentScanner()
        case .notDetermined:
          AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
              presentScanner()
            } else {
              finishScan(
                nil,
                FlutterError(code: "camera_permission_denied", message: "Camera permission denied", details: nil)
              )
            }
          }
        case .denied, .restricted:
          finishScan(
            nil,
            FlutterError(code: "camera_permission_denied", message: "Camera permission denied", details: nil)
          )
        @unknown default:
          finishScan(
            nil,
            FlutterError(code: "camera_permission_denied", message: "Camera permission denied", details: nil)
          )
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func topPresenter() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let keyWindow = scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow })
      ?? scenes.flatMap { $0.windows }.first
    var top = keyWindow?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
