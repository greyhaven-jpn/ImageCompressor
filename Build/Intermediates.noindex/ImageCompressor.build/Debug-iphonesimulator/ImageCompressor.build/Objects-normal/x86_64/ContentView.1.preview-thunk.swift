import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeString
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeBoolean

#sourceLocation(file: "/Users/user/Documents/Project/Mac Apps/ImageCompressor/ImageCompressor/ImageCompressor/ContentView.swift", line: 1)
import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var originalImage: UIImage?
    @State private var compressedData: Data?
    @State private var compressedImage: UIImage?
    @State private var quality: Double = 0.6
    @State private var showCamera = false
    @State private var showShareSheet = false
    @State private var statusMessage = "Pilih gambar dari galeri atau ambil foto baru."

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: __designTimeInteger("#2654_0", fallback: 20)) {
                    GroupBox(__designTimeString("#2654_1", fallback: "Ambil Gambar")) {
                        VStack(spacing: __designTimeInteger("#2654_2", fallback: 12)) {
                            PhotosPicker(
                                selection: $selectedItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label(__designTimeString("#2654_3", fallback: "Pilih dari Galeri"), systemImage: __designTimeString("#2654_4", fallback: "photo.on.rectangle"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                showCamera = __designTimeBoolean("#2654_5", fallback: true)
                            } label: {
                                Label(__designTimeString("#2654_6", fallback: "Ambil Foto Langsung"), systemImage: __designTimeString("#2654_7", fallback: "camera"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if let originalImage {
                        GroupBox(__designTimeString("#2654_8", fallback: "Gambar Asli")) {
                            VStack(alignment: .leading, spacing: __designTimeInteger("#2654_9", fallback: 12)) {
                                Image(uiImage: originalImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: __designTimeInteger("#2654_10", fallback: 250))

                                if let originalData = originalImage.jpegData(compressionQuality: __designTimeFloat("#2654_11", fallback: 1.0)) {
                                    Text("Ukuran asli: \(formatBytes(originalData.count))")
                                        .font(.subheadline)
                                }
                            }
                        }

                        GroupBox(__designTimeString("#2654_12", fallback: "Pengaturan Kompresi")) {
                            VStack(alignment: .leading, spacing: __designTimeInteger("#2654_13", fallback: 12)) {
                                Text("Quality: \(Int(quality * __designTimeInteger("#2654_14", fallback: 100)))%")
                                    .font(.headline)

                                Slider(value: $quality, in: __designTimeFloat("#2654_15", fallback: 0.1)...__designTimeFloat("#2654_16", fallback: 1.0), step: __designTimeFloat("#2654_17", fallback: 0.1))

                                Button {
                                    compressImage()
                                } label: {
                                    Label(__designTimeString("#2654_18", fallback: "Kompres Sekarang"), systemImage: __designTimeString("#2654_19", fallback: "arrow.down.circle"))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }

                    if let compressedImage, let compressedData {
                        GroupBox(__designTimeString("#2654_20", fallback: "Hasil Kompresi")) {
                            VStack(alignment: .leading, spacing: __designTimeInteger("#2654_21", fallback: 12)) {
                                Image(uiImage: compressedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: __designTimeInteger("#2654_22", fallback: 250))

                                Text("Ukuran hasil: \(formatBytes(compressedData.count))")
                                    .font(.subheadline)

                                if let originalImage,
                                   let originalData = originalImage.jpegData(compressionQuality: __designTimeFloat("#2654_23", fallback: 1.0)) {
                                    let saved = max(__designTimeInteger("#2654_24", fallback: 0), originalData.count - compressedData.count)
                                    Text("Hemat: \(formatBytes(saved))")
                                        .font(.subheadline)
                                }

                                Button {
                                    showShareSheet = __designTimeBoolean("#2654_25", fallback: true)
                                } label: {
                                    Label(__designTimeString("#2654_26", fallback: "Bagikan / Simpan Hasil"), systemImage: __designTimeString("#2654_27", fallback: "square.and.arrow.up"))
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
                    originalImage = image
                    compressedData = nil
                    compressedImage = nil
                    statusMessage = __designTimeString("#2654_29", fallback: "Foto berhasil diambil. Atur quality lalu kompres.")
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let compressedData {
                    ShareSheet(items: [compressedData])
                }
            }
            .task(id: selectedItem) {
                guard let selectedItem else { return }
                do {
                    if let data = try await selectedItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        originalImage = image
                        compressedData = nil
                        compressedImage = nil
                        statusMessage = __designTimeString("#2654_30", fallback: "Gambar dari galeri berhasil dipilih. Atur quality lalu kompres.")
                    } else {
                        statusMessage = __designTimeString("#2654_31", fallback: "Gagal membaca gambar yang dipilih.")
                    }
                } catch {
                    statusMessage = "Terjadi error saat mengambil gambar: \(error.localizedDescription)"
                }
            }
        }
    }

    private func compressImage() {
        guard let originalImage else {
            statusMessage = __designTimeString("#2654_32", fallback: "Belum ada gambar untuk dikompres.")
            return
        }

        guard let data = originalImage.jpegData(compressionQuality: quality) else {
            statusMessage = __designTimeString("#2654_33", fallback: "Gagal mengompres gambar.")
            return
        }

        compressedData = data
        compressedImage = UIImage(data: data)
        statusMessage = __designTimeString("#2654_34", fallback: "Kompresi selesai. Sekarang kamu bisa bagikan atau simpan hasilnya.")
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    ContentView()
}
