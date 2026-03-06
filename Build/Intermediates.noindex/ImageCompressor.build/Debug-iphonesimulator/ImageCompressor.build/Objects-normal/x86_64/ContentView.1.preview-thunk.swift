import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeString
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeBoolean

#sourceLocation(file: "/Users/user/Documents/Project/Mac Apps/ImageCompressor/ImageCompressor/ImageCompressor/ContentView.swift", line: 1)
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

    @State private var statusMessage = "Select multiple images from your gallery or take a photo. Everything will be automatically compressed below 750 KB and saved to Photos."
    @State private var isCompressing = false

    private let targetSizeBytes = 750 * 1024 // 750 KB

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: __designTimeInteger("#2654_0", fallback: 20)) {

                    GroupBox(__designTimeString("#2654_1", fallback: "Select Images")) {
                        VStack(spacing: __designTimeInteger("#2654_2", fallback: 12)) {
                            PhotosPicker(
                                selection: $selectedItems,
                                maxSelectionCount: __designTimeInteger("#2654_3", fallback: 20),
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label(__designTimeString("#2654_4", fallback: "Pick Multiple Images from Gallery"), systemImage: __designTimeString("#2654_5", fallback: "photo.on.rectangle.angled"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isCompressing)

                            Button {
                                showCamera = __designTimeBoolean("#2654_6", fallback: true)
                            } label: {
                                Label(__designTimeString("#2654_7", fallback: "Take Photo"), systemImage: __designTimeString("#2654_8", fallback: "camera"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isCompressing)

                            Text(__designTimeString("#2654_9", fallback: "Automatic target: < 750 KB"))
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if isCompressing {
                                ProgressView()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    if !originalImages.isEmpty {
                        GroupBox(__designTimeString("#2654_10", fallback: "Original Image Preview")) {
                            ScrollView(.horizontal) {
                                HStack(spacing: __designTimeInteger("#2654_11", fallback: 12)) {
                                    ForEach(Array(originalImages.enumerated()), id: \.offset) { index, image in
                                        VStack(alignment: .leading, spacing: __designTimeInteger("#2654_12", fallback: 8)) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: __designTimeInteger("#2654_13", fallback: 140), height: __designTimeInteger("#2654_14", fallback: 140))
                                                .clipShape(RoundedRectangle(cornerRadius: __designTimeInteger("#2654_15", fallback: 12)))

                                            if let data = image.jpegData(compressionQuality: __designTimeFloat("#2654_16", fallback: 1.0)) {
                                                Text("Original: \(formatBytes(data.count))")
                                                    .font(.caption)
                                            }

                                            Text("Image \(index + __designTimeInteger("#2654_17", fallback: 1))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, __designTimeInteger("#2654_18", fallback: 4))
                            }
                        }
                    }

                    if !compressedResults.isEmpty {
                        GroupBox(__designTimeString("#2654_19", fallback: "Compressed Results")) {
                            VStack(alignment: .leading, spacing: __designTimeInteger("#2654_20", fallback: 12)) {
                                ForEach(Array(compressedResults.enumerated()), id: \.offset) { index, result in
                                    VStack(alignment: .leading, spacing: __designTimeInteger("#2654_21", fallback: 8)) {
                                        Image(uiImage: result.image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxHeight: __designTimeInteger("#2654_22", fallback: 180))

                                        Text("Image \(index + __designTimeInteger("#2654_23", fallback: 1))")
                                            .font(.headline)

                                        Text("Original size: \(formatBytes(result.originalSize))")
                                            .font(.subheadline)

                                        Text("Compressed size: \(formatBytes(result.compressedSize))")
                                            .font(.subheadline)

                                        Text("Saved space: \(formatBytes(max(__designTimeInteger("#2654_24", fallback: 0), result.originalSize - result.compressedSize)))")
                                            .font(.subheadline)
                                            .foregroundStyle(.green)

                                        Divider()
                                    }
                                }

                                Button {
                                    showShareSheet = __designTimeBoolean("#2654_25", fallback: true)
                                } label: {
                                    Label(__designTimeString("#2654_26", fallback: "Share All Results"), systemImage: __designTimeString("#2654_27", fallback: "square.and.arrow.up"))
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
            .navigationTitle(__designTimeString("#2654_28", fallback: "Image Compressor"))
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in
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

        isCompressing = __designTimeBoolean("#2654_29", fallback: true)
        statusMessage = __designTimeString("#2654_30", fallback: "Loading images from the gallery...")
        compressedResults = []
        originalImages = []

        var loadedImages: [UIImage] = []

        for item in selectedItems {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loadedImages.append(image)
                }
            } catch {
                statusMessage = "Some images could not be loaded: \(error.localizedDescription)"
            }
        }

        originalImages = loadedImages

        if loadedImages.isEmpty {
            isCompressing = __designTimeBoolean("#2654_31", fallback: false)
            statusMessage = __designTimeString("#2654_32", fallback: "No images were successfully loaded.")
            return
        }

        statusMessage = "\(loadedImages.count) images loaded. Automatically compressing below 750 KB and saving to Photos..."

        var results: [CompressedImageResult] = []
        var savedCount = __designTimeInteger("#2654_33", fallback: 0)

        for image in loadedImages {
            guard let originalData = image.jpegData(compressionQuality: __designTimeFloat("#2654_34", fallback: 1.0)),
                  let compressedData = autoCompressToTarget(image: image, targetSize: targetSizeBytes),
                  let compressedImage = UIImage(data: compressedData) else {
                continue
            }

            let saveSuccess = await saveImageDataToPhotoLibrary(data: compressedData)
            if saveSuccess {
                savedCount += __designTimeInteger("#2654_35", fallback: 1)
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
        isCompressing = __designTimeBoolean("#2654_36", fallback: false)
        statusMessage = "Done. \(results.count) images were compressed to under 750 KB, and \(savedCount) were saved to Photos."
    }

    private func processCameraImage(_ image: UIImage) async {
        isCompressing = __designTimeBoolean("#2654_37", fallback: true)
        statusMessage = __designTimeString("#2654_38", fallback: "Photo captured. Automatically compressing below 750 KB and saving to Photos...")

        originalImages = [image]
        compressedResults = []

        guard let originalData = image.jpegData(compressionQuality: __designTimeFloat("#2654_39", fallback: 1.0)),
              let compressedData = autoCompressToTarget(image: image, targetSize: targetSizeBytes),
              let compressedImage = UIImage(data: compressedData) else {
            isCompressing = __designTimeBoolean("#2654_40", fallback: false)
            statusMessage = __designTimeString("#2654_41", fallback: "Failed to process the photo from the camera.")
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
        isCompressing = __designTimeBoolean("#2654_42", fallback: false)

        if saveSuccess {
            statusMessage = __designTimeString("#2654_43", fallback: "The photo was compressed to under 750 KB and saved to Photos.")
        } else {
            statusMessage = __designTimeString("#2654_44", fallback: "The photo was compressed, but it could not be saved to Photos.")
        }
    }

    private func autoCompressToTarget(image: UIImage, targetSize: Int) -> Data? {
        if let originalData = image.jpegData(compressionQuality: __designTimeFloat("#2654_45", fallback: 1.0)),
           originalData.count <= targetSize {
            return originalData
        }

        var currentImage = image
        var bestData: Data?

        for q in stride(from: __designTimeFloat("#2654_46", fallback: 1.0), through: __designTimeFloat("#2654_47", fallback: 0.1), by: __designTimeFloat("#2654_48", fallback: -0.05)) {
            if let data = currentImage.jpegData(compressionQuality: q) {
                bestData = data
                if data.count <= targetSize {
                    return data
                }
            }
        }

        for _ in __designTimeInteger("#2654_49", fallback: 0)..<__designTimeInteger("#2654_50", fallback: 10) {
            let newSize = CGSize(
                width: currentImage.size.width * __designTimeFloat("#2654_51", fallback: 0.9),
                height: currentImage.size.height * __designTimeFloat("#2654_52", fallback: 0.9)
            )

            guard let resizedImage = resizeImage(currentImage, targetSize: newSize) else {
                break
            }

            currentImage = resizedImage

            for q in stride(from: __designTimeFloat("#2654_53", fallback: 0.9), through: __designTimeFloat("#2654_54", fallback: 0.1), by: __designTimeFloat("#2654_55", fallback: -0.05)) {
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
        format.scale = __designTimeInteger("#2654_56", fallback: 1)

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func saveImageDataToPhotoLibrary(data: Data) async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        if status == .notDetermined {
            let newStatus = await requestPhotoAddPermission()
            if newStatus != .authorized && newStatus != .limited {
                return __designTimeBoolean("#2654_57", fallback: false)
            }
        } else if status != .authorized && status != .limited {
            return __designTimeBoolean("#2654_58", fallback: false)
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                let options = PHAssetResourceCreationOptions()
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: options)
            }) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    private func requestPhotoAddPermission() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
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
