import Foundation
import SwiftData

// Records reference each other by `uid` rather than SwiftData relationships,
// which keeps the store simple and easy to sync later.

enum MemberRole: String, Codable, CaseIterable, Identifiable {
    case practitioner = "Practitioner"
    case farmer = "Farmer"
    case both = "Farmer & Practitioner"
    var id: String { rawValue }
}

/// A person in the network, with what they produce and what they know how to do.
@Model
final class Member {
    var uid: UUID
    var name: String
    var role: MemberRole
    var region: String
    var bio: String
    var products: [String]
    var skills: [String]
    var joinedAt: Date
    /// Approximate home location. Only ever shown fuzzed, as a distance.
    var latitude: Double
    var longitude: Double
    var status: MemberStatus
    var isAdmin: Bool
    var invitedByID: UUID?
    var signInMethod: String

    init(name: String, role: MemberRole, region: String = "", bio: String = "",
         products: [String] = [], skills: [String] = [], joinedAt: Date = .now,
         latitude: Double = 42.0, longitude: Double = -73.9, status: MemberStatus = .approved,
         isAdmin: Bool = false, invitedByID: UUID? = nil, signInMethod: String = "Apple") {
        self.uid = UUID()
        self.name = name
        self.role = role
        self.region = region
        self.bio = bio
        self.products = products
        self.skills = skills
        self.joinedAt = joinedAt
        self.latitude = latitude
        self.longitude = longitude
        self.status = status
        self.isAdmin = isAdmin
        self.invitedByID = invitedByID
        self.signInMethod = signInMethod
    }

    /// The broad area shown before two members connect, e.g. "NY" from "Hudson Valley, NY".
    var generalArea: String {
        region.split(separator: ",").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
    }

    /// Distance in miles, rounded to the nearest 5 so nobody's exact location is revealed.
    func approxMiles(to other: Member) -> Int {
        let r = 3958.8
        let dLat = (other.latitude - latitude) * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(latitude * .pi / 180) * cos(other.latitude * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        let miles = r * 2 * atan2(sqrt(a), sqrt(1 - a))
        return max(5, Int((miles / 5).rounded()) * 5)
    }
}

enum MemberStatus: String, Codable {
    case pending, approved, declined
}

/// A one-time code a member gives to someone they want to bring in.
@Model
final class Invite {
    var code: String
    var createdByID: UUID
    var usedByID: UUID?
    var createdAt: Date

    init(createdByID: UUID, code: String = Invite.makeCode(), createdAt: Date = .now) {
        self.code = code
        self.createdByID = createdByID
        self.createdAt = createdAt
    }

    static func makeCode() -> String {
        let letters = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in letters.randomElement()! })
    }
}

enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case veggies = "Veggies"
    case fruit = "Fruit"
    case meat = "Meat"
    case dairy = "Dairy"
    case eggs = "Eggs"
    case wood = "Wood"
    case timeSkill = "Time + Skill"
    case other = "Other"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .veggies: "carrot"
        case .fruit: "leaf"
        case .meat: "fork.knife"
        case .dairy: "drop"
        case .eggs: "oval"
        case .wood: "tree"
        case .timeSkill: "hammer"
        case .other: "shippingbox"
        }
    }

    /// Picture used when a listing has no picture of its own.
    var defaultImage: String {
        switch self {
        case .veggies: "item-veggies"
        case .fruit: "item-fruit"
        case .meat: "item-lamb"
        case .dairy: "item-dairy"
        case .eggs: "item-eggs"
        case .wood: "item-firewood"
        case .timeSkill: "item-timeskill"
        case .other: "item-other"
        }
    }
}

/// Something a member can spare and is willing to barter.
@Model
final class SpareItem {
    var uid: UUID
    var ownerID: UUID
    var title: String
    var category: ItemCategory
    var quantity: String
    var details: String
    var isAvailable: Bool
    var createdAt: Date
    /// Name of a picture in the asset catalog.
    var imageName: String = "item-other"

    init(ownerID: UUID, title: String, category: ItemCategory, quantity: String = "",
         details: String = "", imageName: String? = nil, createdAt: Date = .now) {
        self.imageName = imageName ?? category.defaultImage
        self.uid = UUID()
        self.ownerID = ownerID
        self.title = title
        self.category = category
        self.quantity = quantity
        self.details = details
        self.isAvailable = true
        self.createdAt = createdAt
    }
}

enum TradeStatus: String, Codable {
    case awaitingOwner, awaitingRequester, accepted, declined

    var isOpen: Bool { self == .awaitingOwner || self == .awaitingRequester }
}

/// A barter negotiation for one item. The owner picks what they'd like from the
/// requester's spare items, and the two go back and forth until one accepts or declines.
@Model
final class Trade {
    var uid: UUID
    var itemID: UUID
    var requesterID: UUID
    var ownerID: UUID
    var status: TradeStatus
    /// The requester's items currently on the table.
    var offeredItemIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date

    init(itemID: UUID, requesterID: UUID, ownerID: UUID, createdAt: Date = .now) {
        self.uid = UUID()
        self.itemID = itemID
        self.requesterID = requesterID
        self.ownerID = ownerID
        self.status = .awaitingOwner
        self.offeredItemIDs = []
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    /// The member who needs to act next, if the trade is still open.
    var waitingOnID: UUID? {
        switch status {
        case .awaitingOwner: ownerID
        case .awaitingRequester: requesterID
        case .accepted, .declined: nil
        }
    }

    func otherParty(to me: UUID) -> UUID { me == ownerID ? requesterID : ownerID }
}

enum TradeAction: String, Codable {
    case started = "started a trade"
    case asked = "made an ask"
    case countered = "proposed something new"
    case accepted = "accepted"
    case declined = "declined"
}

/// One step in a trade's history.
@Model
final class TradeEvent {
    var tradeID: UUID
    var actorID: UUID
    var action: TradeAction
    var itemIDs: [UUID]
    var note: String
    var date: Date

    init(tradeID: UUID, actorID: UUID, action: TradeAction, itemIDs: [UUID] = [], note: String = "", date: Date = .now) {
        self.tradeID = tradeID
        self.actorID = actorID
        self.action = action
        self.itemIDs = itemIDs
        self.note = note
        self.date = date
    }
}

enum GuideTopic: String, Codable, CaseIterable, Identifiable {
    case recipe = "Recipe"
    case buildingPlan = "Building plan"
    case preserving = "Canning & preserving"
    case howTo = "How-to"
    case animals = "Animal care"
    case other = "Other"
    var id: String { rawValue }
}

/// A free resource anyone can read: a recipe, building plan, canning instructions, or how-to.
@Model
final class Guide {
    var uid: UUID
    var authorID: UUID
    var title: String
    var topic: GuideTopic
    var body: String
    var createdAt: Date
    /// An optional photo or drawing, such as a recipe card or plan.
    @Attribute(.externalStorage) var attachment: Data?

    init(authorID: UUID, title: String, topic: GuideTopic, body: String, attachment: Data? = nil, createdAt: Date = .now) {
        self.attachment = attachment
        self.uid = UUID()
        self.authorID = authorID
        self.title = title
        self.topic = topic
        self.body = body
        self.createdAt = createdAt
    }
}

@Model
final class Post {
    var uid: UUID
    var authorID: UUID
    var title: String
    var body: String
    var createdAt: Date

    init(authorID: UUID, title: String, body: String, createdAt: Date = .now) {
        self.uid = UUID()
        self.authorID = authorID
        self.title = title
        self.body = body
        self.createdAt = createdAt
    }
}

@Model
final class Comment {
    var uid: UUID
    var postID: UUID
    var authorID: UUID
    /// Set when the poster replies to a specific commenter.
    var replyToAuthorID: UUID?
    var text: String
    var createdAt: Date

    init(postID: UUID, authorID: UUID, text: String, replyToAuthorID: UUID? = nil, createdAt: Date = .now) {
        self.uid = UUID()
        self.postID = postID
        self.authorID = authorID
        self.replyToAuthorID = replyToAuthorID
        self.text = text
        self.createdAt = createdAt
    }
}

/// One side of a connection. Two members are connected once each has requested the other.
@Model
final class ConnectionRequest {
    var fromID: UUID
    var toID: UUID
    var createdAt: Date

    init(fromID: UUID, toID: UUID, createdAt: Date = .now) {
        self.fromID = fromID
        self.toID = toID
        self.createdAt = createdAt
    }
}

@Model
final class DirectMessage {
    var fromID: UUID
    var toID: UUID
    var text: String
    var createdAt: Date

    init(fromID: UUID, toID: UUID, text: String, createdAt: Date = .now) {
        self.fromID = fromID
        self.toID = toID
        self.text = text
        self.createdAt = createdAt
    }
}

// MARK: - Lookup by uid

protocol HasUID { var uid: UUID { get } }
extension Member: HasUID {}
extension SpareItem: HasUID {}
extension Trade: HasUID {}
extension Guide: HasUID {}
extension Post: HasUID {}

extension Array where Element: HasUID {
    func find(_ id: UUID?) -> Element? {
        guard let id else { return nil }
        return first { $0.uid == id }
    }
}

extension Array where Element == Member {
    func name(_ id: UUID?) -> String { find(id)?.name ?? "Someone" }
}

/// Splits "a, b, c" into ["a", "b", "c"].
func parseList(_ text: String) -> [String] {
    text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
}
