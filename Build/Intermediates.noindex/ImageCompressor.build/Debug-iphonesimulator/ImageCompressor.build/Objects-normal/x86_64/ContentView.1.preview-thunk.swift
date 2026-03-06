import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeString
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeBoolean

#sourceLocation(file: "/Users/user/Documents/Project/Mac Apps/ImageCompressor/ImageCompressor/ImageCompressor/ContentView.swift", line: 1)
//  ImageCompressor
//
//  Created by Rafid on 2026/03/06.
//
import SwiftUI
import PhotosUI
import UIKit
import Photos

struct ContentView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var originalImages: [UIImage] = []
    @State private var compressedResults: [CompressedImageResult] = []

    @State private var quality: Double = 0.6
    @State private var useAutoUnder1MB = true

    @State private var showCamera = false
    @State private var showShareSheet = false

    @State private var statusMessage = "Pilih satu atau beberapa gambar dari galeri, atau ambil foto baru."
    @State private var isCompressing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: __designTimeInteger("#2654_0", fallback: 20)) {

                    GroupBox(__designTimeString("#2654_1", fallback: "Ambil Gambar")) {
                        VStack(spacing: __designTimeInteger("#2654_2", fallback: 12)) {
                            PhotosPicker(
                                selection: $selectedItems,
                                maxSelectionCount: __designTimeInteger("#2654_3", fallback: 20),
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label(__designTimeString("#2654_4", fallback: "Pilih Beberapa Gambar dari Galeri"), systemImage: __designTimeString("#2654_5", fallback: "photo.on.rectangle.angled"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                showCamera = __designTimeBoolean("#2654_6", fallback: true)
                            } label: {
                                Label(__designTimeString("#2654_7", fallback: "Ambil Foto Langsung"), systemImage: __designTimeString("#2654_8", fallback: "camera"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Text("Jumlah gambar dipilih: \(originalImages.count)")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !originalImages.isEmpty {
                        GroupBox(__designTimeString("#2654_9", fallback: "Preview Gambar Asli")) {
                            ScrollView(.horizontal) {
                                HStack(spacing: __designTimeInteger("#2654_10", fallback: 12)) {
                                    ForEach(Array(originalImages.enumerated()), id: \.offset) { index, image in
                                        VStack(alignment: .leading, spacing: __designTimeInteger("#2654_11", fallback: 8)) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: __designTimeInteger("#2654_12", fallback: 140), height: __designTimeInteger("#2654_13", fallback: 140))
                                                .clipShape(RoundedRectangle(cornerRadius: __designTimeInteger("#2654_14", fallback: 12)))

                                            if let data = image.jpegData(compressionQuality: __designTimeFloat("#2654_15", fallback: 1.0)) {
                                                Text("Asli: \(formatBytes(data.count))")
                                                    .font(.caption)
                                            }

                                            Text("Gambar \(index + __designTimeInteger("#2654_16", fallback: 1))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, __designTimeInteger("#2654_17", fallback: 4))
                            }
                        }

                        GroupBox(__designTimeString("#2654_18", fallback: "Pengaturan Kompresi")) {
                            VStack(alignment: .leading, spacing: __designTimeInteger("#2654_19", fallback: 12)) {
                                Toggle(__designTimeString("#2654_20", fallback: "Auto compress sampai < 1 MB"), isOn: $useAutoUnder1MB)

                                if !useAutoUnder1MB {
                                    Text("Quality manual: \(Int(quality * __designTimeInteger("#2654_21", fallback: 100)))%")
                                        .font(.headline)

                                    Slider(value: $quality, in: __designTimeFloat("#2654_22", fallback: 0.1)...__designTimeFloat("#2654_23", fallback: 1.0), step: __designTimeFloat("#2654_24", fallback: 0.05))
                                }

                                Button {
                                    Task {
                                        await compressAllImages()
                                    }
                                } label: {
                                    Label(
                                        isCompressing ? __designTimeString("#2654_25", fallback: "Sedang Mengompres...") : __designTimeString("#2654_26", fallback: "Compress & Simpan ke Gallery"),
                                        systemImage: __designTimeString("#2654_27", fallback: "arrow.down.circle")
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isCompressing)
                            }
                        }
                    }

                    if !compressedResults.isEmpty {
                        GroupBox(__designTimeString("#2654_28", fallback: "Hasil Kompresi")) {
                            VStack(alignment: .leading, spacing: __designTimeInteger("#2654_29", fallback: 12)) {
                                ForEach(Array(compressedResults.enumerated()), id: \.offset) { index, result in
                                    VStack(alignment: .leading, spacing: __designTimeInteger("#2654_30", fallback: 8)) {
                                        Image(uiImage: result.image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxHeight: __designTimeInteger("#2654_31", fallback: 180))

                                        Text("Gambar \(index + __designTimeInteger("#2654_32", fallback: 1))")
                                            .font(.headline)

                                        Text("Ukuran asli: \(formatBytes(result.originalSize))")
                                            .font(.subheadline)

                                        Text("Ukuran hasil: \(formatBytes(result.compressedSize))")
                                            .font(.subheadline)

                                        Text("Hemat: \(formatBytes(max(__designTimeInteger("#2654_33", fallback: 0), result.originalSize - result.compressedSize)))")
                                            .font(.subheadline)
                                            .foregroundStyle(.green)

                                        Divider()
                                    }
                                }

                                Button {
                                    showShareSheet = __designTimeBoolean("#2654_34", fallback: true)
                                } label: {
                                    Label(__designTimeString("#2654_35", fallback: "Bagikan Semua Hasil"), systemImage: __designTimeString("#2654_36", fallback: "square.and.arrow.up"))
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
            .navigationTitle(__designTimeString("#2654_37", fallback: "Image Compressor"))
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in
                    originalImages = [image]
                    compressedResults = []
                    statusMessage = __designTimeString("#2654_38", fallback: "Foto berhasil diambil. Sekarang tekan tombol compress.")
                }
            }
            .sheet(isPresented: $showShareSheet) {
                let items = compressedResults.map { $0.data as Any }
                if !items.isEmpty {
                    ShareSheet(items: items)
                }
            }
            .task(id: selectedItems) {
                await loadSelectedImages()
            }
        }
    }

    // MARK: - Load images from gallery
    private func loadSelectedImages() async {
        guard !selectedItems.isEmpty else { return }

        statusMessage = __designTimeString("#2654_39", fallback: "Sedang memuat gambar dari galeri...")
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
                statusMessage = "Ada gambar yang gagal dimuat: \(error.localizedDescription)"
            }
        }

        originalImages = loadedImages
        statusMessage = "\(loadedImages.count) gambar berhasil dimuat. Siap untuk dikompres."
    }

    // MARK: - Compress all images
    private func compressAllImages() async {
        guard !originalImages.isEmpty else {
            statusMessage = __designTimeString("#2654_40", fallback: "Belum ada gambar untuk dikompres.")
            return
        }

        isCompressing = __designTimeBoolean("#2654_41", fallback: true)
        statusMessage = "Sedang mengompres \(originalImages.count) gambar..."
        compressedResults = []

        var results: [CompressedImageResult] = []
        var savedCount = __designTimeInteger("#2654_42", fallback: 0)

        for image in originalImages {
            guard let originalData = image.jpegData(compressionQuality: __designTimeFloat("#2654_43", fallback: 1.0)) else { continue }

            let compressedData: Data?
            if useAutoUnder1MB {
                compressedData = autoCompressToUnder1MB(image: image)
            } else {
                compressedData = image.jpegData(compressionQuality: quality)
            }

            guard let compressedData,
                  let compressedImage = UIImage(data: compressedData) else {
                continue
            }

            let saveSuccess = await saveImageToPhotoLibrary(image: compressedImage)
            if saveSuccess {
                savedCount += __designTimeInteger("#2654_44", fallback: 1)
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
        isCompressing = __designTimeBoolean("#2654_45", fallback: false)

        if useAutoUnder1MB {
            statusMessage = "Selesai. \(results.count) gambar dikompres dengan target < 1 MB, \(savedCount) berhasil disimpan ke gallery."
        } else {
            statusMessage = "Selesai. \(results.count) gambar dikompres manual, \(savedCount) berhasil disimpan ke gallery."
        }
    }

    // MARK: - Auto compress under 1 MB
    private func autoCompressToUnder1MB(image: UIImage) -> Data? {
        let targetSize = 1_000_000 // ~1 MB

        // Coba dari kualitas tinggi ke rendah
        var bestData: Data?

        for q in stride(from: __designTimeFloat("#2654_46", fallback: 1.0), through: __designTimeFloat("#2654_47", fallback: 0.1), by: __designTimeFloat("#2654_48", fallback: -0.05)) {
            if let data = image.jpegData(compressionQuality: q) {
                bestData = data
                if data.count <= targetSize {
                    return data
                }
            }
        }

        // Kalau masih belum < 1MB, resize gambar bertahap
        var currentImage = image
        var resizeStep: CGFloat = __designTimeFloat("#2654_49", fallback: 0.9)

        for _ in __designTimeInteger("#2654_50", fallback: 0)..<__designTimeInteger("#2654_51", fallback: 8) {
            let newSize = CGSize(
                width: currentImage.size.width * resizeStep,
                height: currentImage.size.height * resizeStep
            )

            guard let resizedImage = resizeImage(currentImage, targetSize: newSize) else {
                break
            }

            currentImage = resizedImage

            for q in stride(from: __designTimeFloat("#2654_52", fallback: 0.7), through: __designTimeFloat("#2654_53", fallback: 0.1), by: __designTimeFloat("#2654_54", fallback: -0.05)) {
                if let data = currentImage.jpegData(compressionQuality: q) {
                    bestData = data
                    if data.count <= targetSize {
                        return data
                    }
                }
            }

            resizeStep = __designTimeFloat("#2654_55", fallback: 0.9)
        }

        return bestData
    }

    // MARK: - Resize helper
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    // MARK: - Save to photo library
    private func saveImageToPhotoLibrary(image: UIImage) async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        if status == .notDetermined {
            let newStatus = await requestPhotoAddPermission()
            if newStatus != .authorized && newStatus != .limited {
                return __designTimeBoolean("#2654_56", fallback: false)
            }
        } else if status != .authorized && status != .limited {
            return __designTimeBoolean("#2654_57", fallback: false)
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
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

    // MARK: - Formatter
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Model
struct CompressedImageResult {
    let image: UIImage
    let data: Data
    let originalSize: Int
    let compressedSize: Int
}

#Preview {
    ContentView()
}
