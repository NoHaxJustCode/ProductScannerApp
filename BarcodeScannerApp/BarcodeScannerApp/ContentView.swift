//
//  ContentView.swift
//  BarcodeScannerApp
//
//  Created by Avinash Paluri on 9/5/24.
//

import SwiftUI

struct ContentView: View {
    @State private var isShowingScanner = false
    @State private var scannedCode: String = "No code scanned"
    @State private var productDetails: String = "Product details will appear here"
    @State private var productImage: String? // To store the first image URL
    @State private var offers: [ProductInfo.Item.Offer] = [] // To store offers
    
    var body: some View {
        VStack {
            Text("Barcode/QR Code Scanner")
                .font(.largeTitle)
                .padding()
            
            Spacer()
            
            Text(scannedCode)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .padding()
            
            // Display the first image if available
            if let imageUrl = productImage, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                } placeholder: {
                    ProgressView()
                        .frame(height: 200)
                }
                .padding()
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(productDetails)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                    
                    if !offers.isEmpty {
                        Text("Offers:")
                            .font(.headline)
                            .padding(.top)
                        
                        ForEach(offers, id: \.link) { offer in
                            VStack(alignment: .leading) {
                                Text("\(offer.merchant): \(offer.title)")
                                    .font(.subheadline)
                                Text("Price: \(offer.price, specifier: "%.2f") \(offer.currency ?? "")")
                                    .font(.subheadline)
                                if !offer.shipping.isEmpty {
                                    Text("Shipping: \(offer.shipping)")
                                        .font(.subheadline)
                                }
                                Text("Condition: \(offer.condition)")
                                    .font(.subheadline)
                                Text("Link: \(offer.link)")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .onTapGesture {
                                        if let url = URL(string: offer.link) {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                    } else {
                        Text("No offers available.")
                            .padding()
                    }
                }
                .padding()
            }
            .frame(maxHeight: 400) // Adjust height as needed
            
            Button(action: {
                isShowingScanner = true
            }) {
                Text("Start Scanning")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding()
            .sheet(isPresented: $isShowingScanner) {
                ScannerView(
                    didFindCode: { code in
                        scannedCode = code
                    },
                    searchProductPrice: { code, completion in
                        searchProductPrice(upc: code) { item in
                            completion(item)
                        }
                    },
                    isPresented: $isShowingScanner,
                    productDetails: $productDetails,
                    productImage: $productImage, // Binding for productImage
                    offers: $offers // Binding for offers
                )
            }
            
            Spacer()
        }
        .padding()
    }
    
    func searchProductPrice(upc: String, completion: @escaping (ProductInfo.Item?) -> Void) {
    }
    
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
}

