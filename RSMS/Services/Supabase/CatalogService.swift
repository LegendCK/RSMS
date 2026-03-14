//
//  CatalogService.swift
//  RSMS
//
//  Supabase CRUD service for the product catalog.
//  Handles creating/fetching categories and products,
//  and uploading product images to Supabase Storage.
//
//  Retry policy: transient network errors (URLError) are retried up to
//  `maxRetries` times with exponential back-off. Auth / RLS errors are
//  not retried and surface immediately to the caller.
//

import Foundation
import Supabase

@MainActor
final class CatalogService {

    static let shared = CatalogService()
    private let client = SupabaseManager.shared.client

    /// Maximum number of automatic retries for network operations.
    private let maxRetries = 2

    /// Base delay between retries (doubles each attempt).
    private let retryBaseDelay: UInt64 = 1_000_000_000   // 1 second in nanoseconds

    private init() {}

    // MARK: - Retry Helper

    /// Retries `operation` up to `maxRetries` times when a transient URLError occurs.
    /// Non-network errors (e.g. 4xx from Supabase) are re-thrown immediately.
    private func withRetry<T>(
        label: String,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0...maxRetries {
            do {
                return try await operation()
            } catch let urlError as URLError {
                lastError = urlError
                let isRetryable = [
                    URLError.networkConnectionLost,
                    URLError.notConnectedToInternet,
                    URLError.timedOut,
                    URLError.cannotConnectToHost,
                    URLError.dataNotAllowed,
                ].contains(urlError.code)

                guard isRetryable && attempt < maxRetries else { throw urlError }
                let delay = retryBaseDelay * UInt64(1 << attempt)   // 1s, 2s
                print("[CatalogService] \(label) — network error, retrying in \(1 << attempt)s (attempt \(attempt + 1)/\(maxRetries))")
                try await Task.sleep(nanoseconds: delay)
            }
            // Non-URLErrors propagate immediately — no retry
        }
        throw lastError!
    }

    // MARK: - Categories

    func fetchCategories() async throws -> [CategoryDTO] {
        try await withRetry(label: "fetchCategories") {
            try await client
                .from("categories")
                .select()
                .order("name")
                .execute()
                .value
        }
    }

    func createCategory(
        name: String,
        description: String?,
        isActive: Bool = true
    ) async throws -> CategoryDTO {
        let payload = CategoryInsertDTO(
            parentId: nil,
            name: name,
            description: description.flatMap { $0.isEmpty ? nil : $0 },
            isActive: isActive
        )
        return try await withRetry(label: "createCategory") {
            try await client
                .from("categories")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
        }
    }

    // MARK: - Products

    func fetchProducts() async throws -> [ProductDTO] {
        try await withRetry(label: "fetchProducts") {
            try await client
                .from("products")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
        }
    }

    func createProduct(
        sku: String,
        name: String,
        brand: String?,
        categoryId: UUID?,
        price: Double,
        costPrice: Double?,
        description: String?,
        isActive: Bool,
        imageDataList: [Data],
        createdBy: UUID?
    ) async throws -> ProductDTO {
        // 1. Upload images to Storage — best-effort per image.
        //    A 403 / RLS failure on an individual image is logged and skipped;
        //    the product record is always created regardless.
        //    Network errors on individual images are also caught and skipped
        //    (the product insert below has its own retry logic).
        var imageUrls: [String] = []
        let tempId = UUID().uuidString
        for (index, imageData) in imageDataList.enumerated() {
            let path = "products/\(tempId)/\(index + 1).jpg"
            do {
                let url = try await uploadImage(data: imageData, storagePath: path)
                imageUrls.append(url)
            } catch {
                print("[CatalogService] ⚠️ Image \(index + 1) upload skipped — \(error.localizedDescription)")
            }
        }

        // 2. Build insert payload
        let payload = ProductInsertDTO(
            sku: sku,
            barcode: nil,
            name: name,
            brand: brand.flatMap { $0.isEmpty ? nil : $0 },
            categoryId: categoryId,
            taxCategoryId: nil,
            description: description.flatMap { $0.isEmpty ? nil : $0 },
            price: price,
            costPrice: costPrice,
            imageUrls: imageUrls.isEmpty ? nil : imageUrls,
            isActive: isActive,
            createdBy: createdBy
        )

        // 3. Insert product record — retried on transient network errors
        return try await withRetry(label: "createProduct") {
            try await client
                .from("products")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
        }
    }

    func updateProduct(
        id: UUID,
        sku: String,
        name: String,
        brand: String?,
        categoryId: UUID?,
        price: Double,
        costPrice: Double?,
        description: String?,
        barcode: String?,
        isActive: Bool
    ) async throws -> ProductDTO {
        let payload = ProductUpdateDTO(
            sku: sku,
            barcode: barcode.flatMap { $0.isEmpty ? nil : $0 },
            name: name,
            brand: brand.flatMap { $0.isEmpty ? nil : $0 },
            categoryId: categoryId,
            description: description.flatMap { $0.isEmpty ? nil : $0 },
            price: price,
            costPrice: costPrice,
            isActive: isActive
        )

        return try await withRetry(label: "updateProduct") {
            try await client
                .from("products")
                .update(payload)
                .eq("id", value: id.uuidString)
                .select()
                .single()
                .execute()
                .value
        }
    }

    // MARK: - Storage

    private func uploadImage(data: Data, storagePath: String) async throws -> String {
        try await client.storage
            .from("product-images")
            .upload(
                storagePath,
                data: data,
                options: FileOptions(contentType: "image/jpeg", upsert: false)
            )

        let publicURL = try client.storage
            .from("product-images")
            .getPublicURL(path: storagePath)
        return publicURL.absoluteString
    }

    // MARK: - Helpers

    /// Generates a formatted SKU string: PREFIX-YYYYMMDD-RAND
    static func generateSKU(prefix: String = "SKU") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let datePart = formatter.string(from: Date())
        let randPart = String(Int.random(in: 1000...9999))
        return "\(prefix.uppercased())-\(datePart)-\(randPart)"
    }
}
