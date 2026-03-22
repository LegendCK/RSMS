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

    func updateCategory(
        id: UUID,
        name: String,
        description: String?,
        isActive: Bool = true
    ) async throws -> CategoryDTO {
        let payload = CategoryUpdateDTO(
            name: name,
            description: description.flatMap { $0.isEmpty ? nil : $0 },
            isActive: isActive
        )

        return try await withRetry(label: "updateCategory") {
            try await client
                .from("categories")
                .update(payload)
                .eq("id", value: id.uuidString)
                .select()
                .single()
                .execute()
                .value
        }
    }

    /// Soft-delete category by marking it inactive to avoid FK breakages.
    func deleteCategory(id: UUID) async throws -> CategoryDTO {
        return try await withRetry(label: "deleteCategory") {
            let current: CategoryDTO = try await client
                .from("categories")
                .select()
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value

            return try await updateCategory(
                id: id,
                name: current.name,
                description: current.description,
                isActive: false
            )
        }
    }

    // MARK: - Collections

    func fetchCollections() async throws -> [BrandCollectionDTO] {
        try await withRetry(label: "fetchCollections") {
            try await client
                .from("brand_collections")
                .select()
                .order("name")
                .execute()
                .value
        }
    }

    func createCollection(
        name: String,
        description: String?,
        brand: String?,
        isActive: Bool = true
    ) async throws -> BrandCollectionDTO {
        let payload = BrandCollectionInsertDTO(
            name: name,
            description: description.flatMap { $0.isEmpty ? nil : $0 },
            brand: brand.flatMap { $0.isEmpty ? nil : $0 },
            isActive: isActive
        )
        return try await withRetry(label: "createCollection") {
            try await client
                .from("brand_collections")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
        }
    }

    func updateCollection(
        id: UUID,
        name: String,
        description: String?,
        brand: String?,
        isActive: Bool = true
    ) async throws -> BrandCollectionDTO {
        let payload = BrandCollectionUpdateDTO(
            name: name,
            description: description.flatMap { $0.isEmpty ? nil : $0 },
            brand: brand.flatMap { $0.isEmpty ? nil : $0 },
            isActive: isActive
        )
        return try await withRetry(label: "updateCollection") {
            try await client
                .from("brand_collections")
                .update(payload)
                .eq("id", value: id.uuidString)
                .select()
                .single()
                .execute()
                .value
        }
    }

    /// Soft-delete collection by marking inactive.
    func deleteCollection(id: UUID) async throws -> BrandCollectionDTO {
        return try await withRetry(label: "deleteCollection") {
            let current: BrandCollectionDTO = try await client
                .from("brand_collections")
                .select()
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value

            return try await updateCollection(
                id: id,
                name: current.name,
                description: current.description,
                brand: current.brand,
                isActive: false
            )
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
        collectionId: UUID?,
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
            name: name,
            brand: brand.flatMap { $0.isEmpty ? nil : $0 },
            categoryId: categoryId,
            collectionId: collectionId,
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

    /// Performs a strict bulk insert of product catalog definitions.
    /// Will fail explicitly if any SKU violates the database UNIQUE constraint.
    func createProductsBulk(products: [ProductInsertDTO]) async throws {
        _ = try await withRetry(label: "createProductsBulk") {
            try await client
                .from("products")
                .insert(products)
                .execute()
        }
    }

    func updateProduct(
        id: UUID,
        sku: String,
        name: String,
        brand: String?,
        categoryId: UUID?,
        collectionId: UUID?,
        price: Double,
        costPrice: Double?,
        description: String?,
        barcode: String?,
        isActive: Bool
    ) async throws -> ProductDTO {
        let payload = ProductUpdateDTO(
            sku: sku,
            name: name,
            brand: brand.flatMap { $0.isEmpty ? nil : $0 },
            categoryId: categoryId,
            collectionId: collectionId,
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

    static func generateSKU(prefix: String = "SKU") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let datePart = formatter.string(from: Date())
        let randPart = String(Int.random(in: 1000...9999))
        return "\(prefix.uppercased())-\(datePart)-\(randPart)"
    }
}
