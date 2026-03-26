import SwiftUI
import AVFoundation
import Photos
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    var livePhotoEnabled: Bool = true
    var onImagePicked: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.coordinator = context.coordinator
        vc.livePhotoEnabled = livePhotoEnabled
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.livePhotoEnabled = livePhotoEnabled
    }

    final class Coordinator: NSObject {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func didCaptureStillImage(_ image: UIImage) {
            parent.onImagePicked(image)
        }

        func didFinishFlow() {
            parent.dismiss()
        }

        func didCancel() {
            parent.dismiss()
        }
    }
}

final class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var coordinator: CameraPicker.Coordinator?
    var livePhotoEnabled: Bool = true

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!

    private let captureButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let liveBadgeLabel = UILabel()

    private var currentPhotoData: Data?
    private var currentLivePhotoMovieURL: URL?
    private var livePhotoCaptureInProgress = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        checkCameraPermissionAndSetup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupUI() {
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 5
        captureButton.layer.borderColor = UIColor.systemGray4.cgColor
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        liveBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        liveBadgeLabel.text = "LIVE"
        liveBadgeLabel.textColor = .white
        liveBadgeLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.85)
        liveBadgeLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        liveBadgeLabel.textAlignment = .center
        liveBadgeLabel.layer.cornerRadius = 8
        liveBadgeLabel.layer.masksToBounds = true
        liveBadgeLabel.isHidden = true

        view.addSubview(captureButton)
        view.addSubview(closeButton)
        view.addSubview(liveBadgeLabel)

        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70),

            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),

            liveBadgeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            liveBadgeLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            liveBadgeLabel.widthAnchor.constraint(equalToConstant: 54),
            liveBadgeLabel.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func checkCameraPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            checkMicrophonePermissionThenSetup()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.checkMicrophonePermissionThenSetup()
                    } else {
                        self.coordinator?.didCancel()
                    }
                }
            }
        default:
            coordinator?.didCancel()
        }
    }

    private func checkMicrophonePermissionThenSetup() {
        guard livePhotoEnabled else {
            setupCamera()
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async {
                    self.setupCamera()
                }
            }
        default:
            setupCamera()
        }
    }

    private func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: backCamera),
              session.canAddInput(videoInput) else {
            session.commitConfiguration()
            coordinator?.didCancel()
            return
        }

        session.addInput(videoInput)

        if livePhotoEnabled,
           let mic = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            coordinator?.didCancel()
            return
        }

        session.addOutput(photoOutput)

        if photoOutput.isLivePhotoCaptureSupported {
            photoOutput.isLivePhotoCaptureEnabled = livePhotoEnabled
        }

        session.commitConfiguration()

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)

        liveBadgeLabel.isHidden = !(livePhotoEnabled && photoOutput.isLivePhotoCaptureSupported)

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    @objc private func capturePhoto() {
        guard !livePhotoCaptureInProgress else { return }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off

        if #available(iOS 18.0, *) {
            if photoOutput.isShutterSoundSuppressionSupported {
                settings.isShutterSoundSuppressionEnabled = true
            }
        }

        if livePhotoEnabled && photoOutput.isLivePhotoCaptureSupported && photoOutput.isLivePhotoCaptureEnabled {
            let movieURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")

            try? FileManager.default.removeItem(at: movieURL)
            settings.livePhotoMovieFileURL = movieURL
            currentLivePhotoMovieURL = movieURL
            livePhotoCaptureInProgress = true
        } else {
            currentLivePhotoMovieURL = nil
            livePhotoCaptureInProgress = false
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    @objc private func closeTapped() {
        stopSession()
        coordinator?.didCancel()
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        if resolvedSettings.livePhotoMovieDimensions.width > 0 {
            DispatchQueue.main.async {
                self.liveBadgeLabel.alpha = 1.0
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            print("Still photo processing error: \(error.localizedDescription)")
            currentPhotoData = nil
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            currentPhotoData = nil
            return
        }

        currentPhotoData = data
        coordinator?.didCaptureStillImage(image)
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL,
                     resolvedSettings: AVCaptureResolvedPhotoSettings) {
        DispatchQueue.main.async {
            self.liveBadgeLabel.alpha = 0.6
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
                     duration: CMTime,
                     photoDisplayTime: CMTime,
                     resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        if let error = error {
            print("Live Photo movie processing error: \(error.localizedDescription)")
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        if let error = error {
            print("Capture finished with error: \(error.localizedDescription)")
        }

        cleanupTemporaryMovieFile()
        stopSession()
        coordinator?.didFinishFlow()
    }

    private func cleanupTemporaryMovieFile() {
        if let url = currentLivePhotoMovieURL {
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        currentLivePhotoMovieURL = nil
        currentPhotoData = nil
        livePhotoCaptureInProgress = false
    }

    private func stopSession() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning()
            }
        }
    }
}
