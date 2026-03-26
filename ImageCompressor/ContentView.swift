import SwiftUI
import PhotosUI
import UIKit
import Photos

struct ContentView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var originalImages: [UIImage] = []
    @State private var compressedResults: [CompressedImageResult] = []

    @State private var showCamera = false
    @State private var showShareSheet = false

    @State private var statusMessage = "Select multiple images from your gallery or take a photo. Everything will be automatically compressed below 500 KB, saved to Photos, and the original gallery image will be deleted."
    @State private var isCompressing = false

    private let targetSizeBytes = 500 * 1024 // 500 KB

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    GroupBox("Select Images") {
                        VStack(spacing: 12) {
                            PhotosPicker(
                                selection: $selectedItems,
                                maxSelectionCount: 20,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("Pick Multiple Images from Gallery", systemImage: "photo.on.rectangle.angled")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isCompressing)

                            Button {
                                showCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isCompressing)

                            Text("Automatic target: < 500 KB")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if isCompressing {
                                ProgressView()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    if !originalImages.isEmpty {
                        GroupBox("Original Image Preview") {
                            ScrollView(.horizontal) {
                                HStack(spacing: 12) {
                                    ForEach(Array(originalImages.enumerated()), id: \.offset) { index, image in
                                        VStack(alignment: .leading, spacing: 8) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 140, height: 140)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                            if let data = image.jpegData(compressionQuality: 1.0) {
                                                Text("Original: \(formatBytes(data.count))")
                                                    .font(.caption)
                                            }

                                            Text("Image \(index + 1)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    if !compressedResults.isEmpty {
                        GroupBox("Compressed Results") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(compressedResults.enumerated()), id: \.offset) { index, result in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Image(uiImage: result.image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxHeight: 180)

                                        Text("Image \(index + 1)")
                                            .font(.headline)

                                        Text("Original size: \(formatBytes(result.originalSize))")
                                            .font(.subheadline)

                                        Text("Compressed size: \(formatBytes(result.compressedSize))")
                                            .font(.subheadline)

                                        Text("Saved space: \(formatBytes(max(0, result.originalSize - result.compressedSize)))")
                                            .font(.subheadline)
                                            .foregroundStyle(.green)

                                        Divider()
                                    }
                                }

                                Button {
                                    showShareSheet = true
                                } label: {
                                    Label("Share All Results", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .navigationTitle("Image Compressor")
            .sheet(isPresented: $showCamera) {
                CameraPicker(livePhotoEnabled: true) { image in
                    Task {
                        await processCameraImage(image)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                let items = compressedResults.map { $0.data as Any }
                if !items.isEmpty {
                    ShareSheet(items: items)
                }
            }
            .task(id: selectedItems) {
                await loadAndProcessSelectedImages()
            }
        }
    }

    private func loadAndProcessSelectedImages() async {
        guard !selectedItems.isEmpty else { return }

        let permissionGranted = await requestPhotoLibraryAccessIfNeeded()
        guard permissionGranted else {
            statusMessage = "Photo Library access was denied. Please allow read and write access in Settings."
            return
        }

        isCompressing = true
        statusMessage = "Loading images from the gallery..."
        compressedResults = []
        originalImages = []

        var loadedEntries: [(image: UIImage, assetId: String?)] = []

        for item in selectedItems {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loadedEntries.append((image: image, assetId: item.itemIdentifier))
                }
            } catch {
                statusMessage = "Some images could not be loaded: \(error.localizedDescription)"
            }
        }

        let loadedImages = loadedEntries.map { $0.image }
        originalImages = loadedImages

        if loadedImages.isEmpty {
            isCompressing = false
            statusMessage = "No images were successfully loaded."
            return
        }

        statusMessage = "\(loadedImages.count) images loaded. Compressing, saving to Photos, and deleting original gallery images..."

        var results: [CompressedImageResult] = []
        var savedCount = 0
        var deletedCount = 0

        for entry in loadedEntries {
            let image = entry.image
            let assetId = entry.assetId

            guard let originalData = image.jpegData(compressionQuality: 1.0),
                  let compressedData = autoCompressToTarget(image: image, targetSize: targetSizeBytes),
                  let compressedImage = UIImage(data: compressedData) else {
                continue
            }

            let saveSuccess = await saveImageDataToPhotoLibrary(data: compressedData)

            var deleteSuccess = false
            if saveSuccess, let assetId {
                deleteSuccess = await deleteOriginalPhoto(assetIdentifier: assetId)
            }

            if saveSuccess {
                savedCount += 1
            }
            if deleteSuccess {
                deletedCount += 1
            }

            let result = CompressedImageResult(
                image: compressedImage,
                data: compressedData,
                originalSize: originalData.count,
                compressedSize: compressedData.count
            )
            results.append(result)
        }

        compressedResults = results
        isCompressing = false
        statusMessage = "Done. \(results.count) images were compressed, \(savedCount) were saved to Photos, and \(deletedCount) original gallery images were deleted."
    }

    private func processCameraImage(_ image: UIImage) async {
        let permissionGranted = await requestPhotoLibraryAccessIfNeeded()
        guard permissionGranted else {
            statusMessage = "Photo Library access was denied. Please allow read and write access in Settings."
            return
        }

        isCompressing = true
        statusMessage = "Photo captured. Automatically compressing below 500 KB and saving to Photos..."

        originalImages = [image]
        compressedResults = []

        guard let originalData = image.jpegData(compressionQuality: 1.0),
              let compressedData = autoCompressToTarget(image: image, targetSize: targetSizeBytes),
              let compressedImage = UIImage(data: compressedData) else {
            isCompressing = false
            statusMessage = "Failed to process the photo from the camera."
            return
        }

        let saveSuccess = await saveImageDataToPhotoLibrary(data: compressedData)

        let result = CompressedImageResult(
            image: compressedImage,
            data: compressedData,
            originalSize: originalData.count,
            compressedSize: compressedData.count
        )

        compressedResults = [result]
        isCompressing = false

        if saveSuccess {
            statusMessage = "The photo was compressed and saved to Photos. No original gallery image needed to be deleted for the camera flow."
        } else {
            statusMessage = "The photo was compressed, but it could not be saved to Photos."
        }
    }

    private func autoCompressToTarget(image: UIImage, targetSize: Int) -> Data? {
        if let originalData = image.jpegData(compressionQuality: 1.0),
           originalData.count <= targetSize {
            return originalData
        }

        var currentImage = image
        var bestData: Data?

        for q in stride(from: 1.0, through: 0.1, by: -0.05) {
            if let data = currentImage.jpegData(compressionQuality: q) {
                bestData = data
                if data.count <= targetSize {
                    return data
                }
            }
        }

        for _ in 0..<10 {
            let newSize = CGSize(
                width: currentImage.size.width * 0.9,
                height: currentImage.size.height * 0.9
            )

            guard let resizedImage = resizeImage(currentImage, targetSize: newSize) else {
                break
            }

            currentImage = resizedImage

            for q in stride(from: 0.9, through: 0.1, by: -0.05) {
                if let data = currentImage.jpegData(compressionQuality: q) {
                    bestData = data
                    if data.count <= targetSize {
                        return data
                    }
                }
            }
        }

        return bestData
    }

    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func requestPhotoLibraryAccessIfNeeded() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                    continuation.resume(returning: status)
                }
            }
            return newStatus == .authorized || newStatus == .limited
        default:
            return false
        }
    }

    private func saveImageDataToPhotoLibrary(data: Data) async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                let options = PHAssetResourceCreationOptions()
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: options)
            }) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    private func deleteOriginalPhoto(assetIdentifier: String) async -> Bool {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)

        guard let asset = assets.firstObject else {
            return false
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct CompressedImageResult {
    let image: UIImage
    let data: Data
    let originalSize: Int
    let compressedSize: Int
}

#Preview {
    ContentView()
}
