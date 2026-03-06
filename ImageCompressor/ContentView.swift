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
                VStack(spacing: 20) {

                    GroupBox("Ambil Gambar") {
                        VStack(spacing: 12) {
                            PhotosPicker(
                                selection: $selectedItems,
                                maxSelectionCount: 20,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("Pilih Beberapa Gambar dari Galeri", systemImage: "photo.on.rectangle.angled")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                showCamera = true
                            } label: {
                                Label("Ambil Foto Langsung", systemImage: "camera")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Text("Jumlah gambar dipilih: \(originalImages.count)")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !originalImages.isEmpty {
                        GroupBox("Preview Gambar Asli") {
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
                                                Text("Asli: \(formatBytes(data.count))")
                                                    .font(.caption)
                                            }

                                            Text("Gambar \(index + 1)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        GroupBox("Pengaturan Kompresi") {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle("Auto compress sampai < 1 MB", isOn: $useAutoUnder1MB)

                                if !useAutoUnder1MB {
                                    Text("Quality manual: \(Int(quality * 100))%")
                                        .font(.headline)

                                    Slider(value: $quality, in: 0.1...1.0, step: 0.05)
                                }

                                Button {
                                    Task {
                                        await compressAllImages()
                                    }
                                } label: {
                                    Label(
                                        isCompressing ? "Sedang Mengompres..." : "Compress & Simpan ke Gallery",
                                        systemImage: "arrow.down.circle"
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isCompressing)
                            }
                        }
                    }

                    if !compressedResults.isEmpty {
                        GroupBox("Hasil Kompresi") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(compressedResults.enumerated()), id: \.offset) { index, result in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Image(uiImage: result.image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxHeight: 180)

                                        Text("Gambar \(index + 1)")
                                            .font(.headline)

                                        Text("Ukuran asli: \(formatBytes(result.originalSize))")
                                            .font(.subheadline)

                                        Text("Ukuran hasil: \(formatBytes(result.compressedSize))")
                                            .font(.subheadline)

                                        Text("Hemat: \(formatBytes(max(0, result.originalSize - result.compressedSize)))")
                                            .font(.subheadline)
                                            .foregroundStyle(.green)

                                        Divider()
                                    }
                                }

                                Button {
                                    showShareSheet = true
                                } label: {
                                    Label("Bagikan Semua Hasil", systemImage: "square.and.arrow.up")
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
                CameraPicker { image in
                    originalImages = [image]
                    compressedResults = []
                    statusMessage = "Foto berhasil diambil. Sekarang tekan tombol compress."
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

        statusMessage = "Sedang memuat gambar dari galeri..."
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
            statusMessage = "Belum ada gambar untuk dikompres."
            return
        }

        isCompressing = true
        statusMessage = "Sedang mengompres \(originalImages.count) gambar..."
        compressedResults = []

        var results: [CompressedImageResult] = []
        var savedCount = 0

        for image in originalImages {
            guard let originalData = image.jpegData(compressionQuality: 1.0) else { continue }

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
                savedCount += 1
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

        for q in stride(from: 1.0, through: 0.1, by: -0.05) {
            if let data = image.jpegData(compressionQuality: q) {
                bestData = data
                if data.count <= targetSize {
                    return data
                }
            }
        }

        // Kalau masih belum < 1MB, resize gambar bertahap
        var currentImage = image
        var resizeStep: CGFloat = 0.9

        for _ in 0..<8 {
            let newSize = CGSize(
                width: currentImage.size.width * resizeStep,
                height: currentImage.size.height * resizeStep
            )

            guard let resizedImage = resizeImage(currentImage, targetSize: newSize) else {
                break
            }

            currentImage = resizedImage

            for q in stride(from: 0.7, through: 0.1, by: -0.05) {
                if let data = currentImage.jpegData(compressionQuality: q) {
                    bestData = data
                    if data.count <= targetSize {
                        return data
                    }
                }
            }

            resizeStep = 0.9
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
                return false
            }
        } else if status != .authorized && status != .limited {
            return false
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
