import Foundation

struct SecondBrainContact: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let canonicalEmail: String?
    let canonicalPhone: String?
    let firstName: String?
    let lastName: String?
    let displayName: String?
    let company: String?
    let title: String?
    let socialProfiles: [String: String]?
    let sourceIds: [String: String]?
    let enrichedFromClay: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case canonicalEmail = "canonical_email"
        case canonicalPhone = "canonical_phone"
        case firstName = "first_name"
        case lastName = "last_name"
        case displayName = "display_name"
        case company, title
        case socialProfiles = "social_profiles"
        case sourceIds = "source_ids"
        case enrichedFromClay = "enriched_from_clay"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var displayNameOrComputed: String {
        if let dn = displayName, !dn.isEmpty { return dn }
        let parts = [firstName, lastName].compactMap { $0 }
        return parts.isEmpty ? (canonicalEmail ?? "Unknown") : parts.joined(separator: " ")
    }

    var initials: String {
        let f = firstName?.prefix(1) ?? ""
        let l = lastName?.prefix(1) ?? ""
        let result = "\(f)\(l)"
        return result.isEmpty ? "?" : result.uppercased()
    }
}

struct SecondBrainContactListResponse: Codable {
    let contacts: [SecondBrainContact]
    let total: Int
    let limit: Int
    let offset: Int
}
