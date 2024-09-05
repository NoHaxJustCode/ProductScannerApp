//
//  ScannerView.swift
//  BarcodeScannerApp
//
//  Created by Avinash Paluri on 9/5/24.
//

import SwiftUI
import AVFoundation

struct ScannerView: UIViewControllerRepresentable {
    
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: ScannerView
        private var captureSession: AVCaptureSession?
        
        init(parent: ScannerView) {
            self.parent = parent
        }
        
        func startSession(_ session: AVCaptureSession) {
            self.captureSession = session
        }
        
        func stopSession() {
            captureSession?.stopRunning()
        }
        
        // Delegate method called when a barcode/QR code is detected
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                if let stringValue = readableObject.stringValue {
                    AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate)) // Vibrate on successful scan
                    DispatchQueue.main.async {
                        self.parent.didFindCode(stringValue)
                        
                        // Perform the product price search
                        self.parent.searchProductPrice(upc: stringValue) { item in
                            DispatchQueue.main.async {
                                // Update ContentView's state with product details
                                if let item = item {
                                    self.parent.productDetails = item.formattedDetails()
                                    self.parent.productImage = item.images?.first
                                    self.parent.offers = item.offers ?? []
                                } else {
                                    self.parent.productDetails = "Product details not found."
                                    self.parent.productImage = nil
                                    self.parent.offers = []
                                }
                            }
                        }
                        
                        self.stopSession()
                        self.parent.isPresented = false // Dismiss the scanner view
                    }
                }
            }
        }
    }
    
    var didFindCode: (String) -> Void
    var searchProductPrice: (String, @escaping (ProductInfo.Item?) -> Void) -> Void
    @Binding var isPresented: Bool
    @Binding var productDetails: String
    @Binding var productImage: String?
    @Binding var offers: [ProductInfo.Item.Offer]
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        let captureSession = AVCaptureSession()
        context.coordinator.startSession(captureSession)
        
        // Check camera authorization status
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera(for: captureSession, on: viewController, with: context.coordinator)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        setupCamera(for: captureSession, on: viewController, with: context.coordinator)
                    }
                } else {
                    print("Camera access denied.")
                }
            }
        case .denied, .restricted:
            print("Camera access denied or restricted.")
        @unknown default:
            print("Unknown camera authorization status.")
        }
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Handle any updates to the view controller if needed
    }
    
    private func setupCamera(for session: AVCaptureSession, on viewController: UIViewController, with coordinator: Coordinator) {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("No video capture device found.")
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            if (session.canAddInput(videoInput)) {
                session.addInput(videoInput)
            } else {
                print("Error: Could not add video input.")
                return
            }
        } catch {
            print("Error setting up video input: \(error.localizedDescription)")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if (session.canAddOutput(metadataOutput)) {
            session.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr, .ean13, .ean8, .code128]
        } else {
            print("Error: Could not add metadata output.")
            return
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = viewController.view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        viewController.view.layer.addSublayer(previewLayer)
        
        session.startRunning()
        print("Capture session started.")
    }
    
    // Function to search for product prices
    func searchProductPrice(upc: String, completion: @escaping (ProductInfo.Item?) -> Void) {
        let urlString = "https://api.upcitemdb.com/prod/trial/lookup?upc=\(upc)"
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching product information: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion(nil)
                return
            }
            
            // Print raw JSON data for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON Response: \(jsonString)")
            }
            
            do {
                let productInfo = try JSONDecoder().decode(ProductInfo.self, from: data)
                
                if let item = productInfo.items.first {
                    DispatchQueue.main.async {
                        completion(item) // Pass the item to the completion handler
                    }
                } else {
                    print("No items found.")
                    completion(nil)
                }
            } catch {
                print("Error decoding product information: \(error)")
                completion(nil)
            }
        }
        task.resume()
    }
}

    
import Foundation

struct ProductInfo: Decodable {
    let code: String
    let total: Int
    let offset: Int
    let items: [Item]
    
    struct Item: Decodable {
        let ean: String
        let title: String
        let description: String
        let upc: String?
        let brand: String
        let model: String
        let color: String
        let size: String
        let dimension: String?
        let weight: String
        let category: String?
        let currency: String?
        let lowest_recorded_price: Double?
        let highest_recorded_price: Double?
        let images: [String]?
        let offers: [Offer]?
        let asin: String?
        let elid: String?
        
        struct Offer: Decodable {
            let merchant: String
            let domain: String
            let title: String
            let currency: String?
            let price: Double
            let shipping: String
            let condition: String
            let availability: String?
            let link: String
            let updated_t: Int
        }
    }
}

extension ProductInfo.Item {
    func formattedDetails() -> String {
        var details = ""
        
        details += "Title: \(title)\n"
        details += "Brand: \(brand)\n"
        details += "Model: \(model)\n"
        details += "UPC: \(upc ?? "N/A")\n"
        details += "EAN: \(ean)\n"
        details += "Description: \(description)\n"
        
        if let dimension = dimension, !dimension.isEmpty {
            details += "Dimension: \(dimension)\n"
        }
        
        details += "Weight: \(weight)\n"
        
        if let category = category, !category.isEmpty {
            details += "Category: \(category)\n"
        }
        
        if let currency = currency, !currency.isEmpty {
            details += "Currency: \(currency)\n"
        }
        
        if let lowestPrice = lowest_recorded_price {
            details += "Lowest Recorded Price: \(currency ?? "") \(lowestPrice)\n"
        }
        
        if let highestPrice = highest_recorded_price {
            details += "Highest Recorded Price: \(currency ?? "") \(highestPrice)\n"
        }
        
        return details
    }
}
