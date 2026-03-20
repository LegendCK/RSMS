import Foundation

struct BrandCollectionDTO: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let brand: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description, brand
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct BrandCollectionInsertDTO: Codable {
    let name: String
    let description: String?
    let brand: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case name, description, brand
        case isActive = "is_active"
    }
}

struct BrandCollectionUpdateDTO: Codable {
    let name: String
    let description: String?
    let brand: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case name, description, brand
        case isActive = "is_active"
    }
}

struct CategoryUpdateDTO: Codable {
    let name: String
    let description: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case name, description
        case isActive = "is_active"
    }
}
