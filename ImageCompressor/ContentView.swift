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
                VStack(spacing: 20) {
                    GroupBox("Ambil Gambar") {
                        VStack(spacing: 12) {
                            PhotosPicker(
                                selection: $selectedItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("Pilih dari Galeri", systemImage: "photo.on.rectangle")
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
                        }
                    }

                    if let originalImage {
                        GroupBox("Gambar Asli") {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(uiImage: originalImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 250)

                                if let originalData = originalImage.jpegData(compressionQuality: 1.0) {
                                    Text("Ukuran asli: \(formatBytes(originalData.count))")
                                        .font(.subheadline)
                                }
                            }
                        }

                        GroupBox("Pengaturan Kompresi") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Quality: \(Int(quality * 100))%")
                                    .font(.headline)

                                Slider(value: $quality, in: 0.1...1.0, step: 0.1)

                                Button {
                                    compressImage()
                                } label: {
                                    Label("Kompres Sekarang", systemImage: "arrow.down.circle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }

                    if let compressedImage, let compressedData {
                        GroupBox("Hasil Kompresi") {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(uiImage: compressedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 250)

                                Text("Ukuran hasil: \(formatBytes(compressedData.count))")
                                    .font(.subheadline)

                                if let originalImage,
                                   let originalData = originalImage.jpegData(compressionQuality: 1.0) {
                                    let saved = max(0, originalData.count - compressedData.count)
                                    Text("Hemat: \(formatBytes(saved))")
                                        .font(.subheadline)
                                }

                                Button {
                                    showShareSheet = true
                                } label: {
                                    Label("Bagikan / Simpan Hasil", systemImage: "square.and.arrow.up")
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
                    originalImage = image
                    compressedData = nil
                    compressedImage = nil
                    statusMessage = "Foto berhasil diambil. Atur quality lalu kompres."
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
                        statusMessage = "Gambar dari galeri berhasil dipilih. Atur quality lalu kompres."
                    } else {
                        statusMessage = "Gagal membaca gambar yang dipilih."
                    }
                } catch {
                    statusMessage = "Terjadi error saat mengambil gambar: \(error.localizedDescription)"
                }
            }
        }
    }

    private func compressImage() {
        guard let originalImage else {
            statusMessage = "Belum ada gambar untuk dikompres."
            return
        }

        guard let data = originalImage.jpegData(compressionQuality: quality) else {
            statusMessage = "Gagal mengompres gambar."
            return
        }

        compressedData = data
        compressedImage = UIImage(data: data)
        statusMessage = "Kompresi selesai. Sekarang kamu bisa bagikan atau simpan hasilnya."
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
