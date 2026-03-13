//
//  User.swift
//  infosys2
//
//  SwiftData model for user accounts with role-based access control.
//

import Foundation
import SwiftData

enum UserRole: String, Codable, CaseIterable {
    case customer = "Customer"
    case salesAssociate = "Sales Associate"
    case inventoryController = "Inventory Controller"
    case boutiqueManager = "Boutique Manager"
    case corporateAdmin = "Corporate Admin"
    case serviceTechnician = "Service Technician"
}

@Model
final class User {
    var id: UUID
    var name: String
    var email: String
    var phone: String
    var passwordHash: String
    var roleRaw: String
    var createdAt: Date
    var isActive: Bool

    var role: UserRole {
        get { UserRole(rawValue: roleRaw) ?? .customer }
        set { roleRaw = newValue.rawValue }
    }

    init(
        name: String,
        email: String,
        phone: String = "",
        passwordHash: String,
        role: UserRole = .customer,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.phone = phone
        self.passwordHash = passwordHash
        self.roleRaw = role.rawValue
        self.createdAt = Date()
        self.isActive = isActive
    }
}
