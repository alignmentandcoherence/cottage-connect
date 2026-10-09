import Foundation
import SwiftData

/// Seeds a small community on first launch so the demo has something to show.
/// The first member (Rosa) is the default signed-in user and has a trade and a
/// connection request waiting for her.
enum SampleData {
    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Member>())) ?? 0
        guard count == 0 else { return }

        func ago(_ hours: Double) -> Date { Date.now.addingTimeInterval(-hours * 3600) }

        let rosa = Member(name: "Rosa Alvarez", role: .practitioner, region: "Hudson Valley, NY",
                          bio: "Small-batch cheeses and ferments. Always happy to teach.",
                          products: ["Cheese", "Sauerkraut", "Kimchi"], skills: ["Cheesemaking", "Fermentation"],
                          joinedAt: ago(400), latitude: 41.93, longitude: -73.91, isAdmin: true)
        let eli = Member(name: "Eli Turner", role: .farmer, region: "Hudson Valley, NY",
                         bio: "40 acres with Icelandic sheep and a big hay field.",
                         products: ["Lamb", "Fleece", "Hay"], skills: ["Fencing", "Shearing"],
                         joinedAt: ago(300), latitude: 42.10, longitude: -73.80, invitedByID: rosa.uid)
        let june = Member(name: "June Park", role: .both, region: "Berkshires, MA",
                          bio: "Bees, hens, and a market garden. Looking for land to expand hives.",
                          products: ["Honey", "Eggs", "Greens", "Candles"], skills: ["Beekeeping", "Candle making"],
                          joinedAt: ago(200), latitude: 42.30, longitude: -73.25, invitedByID: rosa.uid, signInMethod: "Google")
        let sam = Member(name: "Sam Okafor", role: .practitioner, region: "Catskills, NY",
                         bio: "Woodworker. Builds coops, sheds and raised beds.",
                         products: ["Firewood", "Cedar offcuts"], skills: ["Woodworking", "Timber framing"],
                         joinedAt: ago(100), latitude: 42.08, longitude: -74.30, invitedByID: eli.uid, signInMethod: "Phone")
        // Waiting on an admin (Rosa) to review.
        let maya = Member(name: "Maya Chen", role: .farmer, region: "Litchfield, CT",
                          bio: "Goat dairy, just getting started.", products: ["Goat milk"], skills: ["Milking"],
                          joinedAt: ago(4), latitude: 41.75, longitude: -73.19, status: .pending,
                          invitedByID: june.uid, signInMethod: "Phone")
        [rosa, eli, june, sam, maya].forEach { context.insert($0) }
        let mayaInvite = Invite(createdByID: june.uid, code: "GOAT42", createdAt: ago(5))
        mayaInvite.usedByID = maya.uid
        context.insert(mayaInvite)
        context.insert(Invite(createdByID: rosa.uid, code: "HARVEST", createdAt: ago(1)))

        let cheddar = SpareItem(ownerID: rosa.uid, title: "Aged cheddar", category: .dairy, quantity: "1 lb wheel",
                                details: "Six months aged, cloth bound.", createdAt: ago(20))
        let kraut = SpareItem(ownerID: rosa.uid, title: "Sauerkraut", category: .veggies, quantity: "2 quarts", createdAt: ago(30))
        let cheeseClass = SpareItem(ownerID: rosa.uid, title: "Cheesemaking lesson", category: .timeSkill, quantity: "2 hours",
                                    details: "At my kitchen or yours. Fresh mozzarella or chèvre.", createdAt: ago(40))
        let lamb = SpareItem(ownerID: eli.uid, title: "Lamb, half share", category: .meat, quantity: "About 20 lbs",
                             details: "Pasture raised, butchered in November.", createdAt: ago(10))
        let fleece = SpareItem(ownerID: eli.uid, title: "Raw fleece", category: .other, quantity: "12 lbs, skirted", createdAt: ago(50))
        let fencing = SpareItem(ownerID: eli.uid, title: "Fence repair help", category: .timeSkill, quantity: "Half a day", createdAt: ago(60))
        let eggs = SpareItem(ownerID: june.uid, title: "Pastured eggs", category: .eggs, quantity: "2 dozen a week", createdAt: ago(5))
        let honey = SpareItem(ownerID: june.uid, title: "Wildflower honey", category: .other, quantity: "1 quart jars", createdAt: ago(15))
        let greens = SpareItem(ownerID: june.uid, title: "Fall greens box", category: .veggies, quantity: "Weekly through November",
                               details: "Kale, chard, lettuce, and whatever else is thriving.", createdAt: ago(25))
        let firewood = SpareItem(ownerID: sam.uid, title: "Seasoned firewood", category: .wood, quantity: "1/2 cord",
                                 details: "Oak and maple, split and dry. Can deliver locally.", createdAt: ago(8))
        let raisedBed = SpareItem(ownerID: sam.uid, title: "Build a raised bed", category: .timeSkill, quantity: "One 4x8 bed",
                                  details: "You supply lumber or I use my cedar offcuts.", createdAt: ago(35))
        [cheddar, kraut, cheeseClass, lamb, fleece, fencing, eggs, honey, greens, firewood, raisedBed]
            .forEach { context.insert($0) }

        // June wants Eli's lamb; Eli asked for honey and eggs; it's June's turn.
        let lambTrade = Trade(itemID: lamb.uid, requesterID: june.uid, ownerID: eli.uid, createdAt: ago(6))
        lambTrade.offeredItemIDs = [honey.uid, eggs.uid]
        lambTrade.status = .awaitingRequester
        lambTrade.updatedAt = ago(3)
        context.insert(lambTrade)
        context.insert(TradeEvent(tradeID: lambTrade.uid, actorID: june.uid, action: .started,
                                  note: "Would love a half share for the winter!", date: ago(6)))
        context.insert(TradeEvent(tradeID: lambTrade.uid, actorID: eli.uid, action: .asked,
                                  itemIDs: [honey.uid, eggs.uid], note: "Honey and eggs through the winter?", date: ago(3)))

        // Sam wants Rosa's cheddar; waiting on Rosa to pick from Sam's items.
        let cheeseTrade = Trade(itemID: cheddar.uid, requesterID: sam.uid, ownerID: rosa.uid, createdAt: ago(1))
        context.insert(cheeseTrade)
        context.insert(TradeEvent(tradeID: cheeseTrade.uid, actorID: sam.uid, action: .started,
                                  note: "That cheddar looks amazing. Take a look at what I've got.", date: ago(1)))

        // Rosa and June are connected and chatting; Eli has asked to connect with Rosa.
        context.insert(ConnectionRequest(fromID: rosa.uid, toID: june.uid, createdAt: ago(90)))
        context.insert(ConnectionRequest(fromID: june.uid, toID: rosa.uid, createdAt: ago(89)))
        context.insert(ConnectionRequest(fromID: eli.uid, toID: rosa.uid, createdAt: ago(2)))
        context.insert(DirectMessage(fromID: june.uid, toID: rosa.uid, text: "Do you still have rennet to spare?", createdAt: ago(48)))
        context.insert(DirectMessage(fromID: rosa.uid, toID: june.uid, text: "Yes! Swing by Saturday.", createdAt: ago(47)))

        [
            Guide(authorID: rosa.uid, title: "Starting a sauerkraut crock", topic: .preserving,
                  body: "Shred 5 lbs of cabbage and mix in 3 tbsp of salt. Massage until it releases liquid, then pack tightly into a crock so the brine covers it. Weigh it down, cover with a cloth, and taste after a week. Keep it cool, around 65°F, for the best texture.",
                  createdAt: ago(120)),
            Guide(authorID: eli.uid, title: "Lambing season checklist", topic: .animals,
                  body: "Clean jugs with fresh bedding, iodine for navels, colostrum on hand, a heat lamp with a safe mount, and the vet's number on the barn door. Check ewes every few hours once bags fill.",
                  createdAt: ago(150)),
            Guide(authorID: june.uid, title: "Overwintering bees in the Northeast", topic: .animals,
                  body: "Leave at least 60 lbs of honey per hive. Add a moisture quilt, reduce entrances, and wrap hives on the windward side. Heft from behind in January to check stores.",
                  createdAt: ago(80)),
            Guide(authorID: sam.uid, title: "Splitting and seasoning firewood", topic: .building,
                  body: "Split green, stack bark-up in single rows off the ground, and cover only the top. Oak needs a full year; maple and ash are ready in six to nine months.",
                  createdAt: ago(60)),
        ].forEach { context.insert($0) }

        let swap = Post(authorID: june.uid, title: "Seed swap at the grange, Oct 20",
                        body: "Bring saved seeds, labeled with variety and year. Coffee and pie provided.", createdAt: ago(30))
        let press = Post(authorID: eli.uid, title: "Anyone have a cider press to borrow?",
                         body: "Apples are coming in fast this year. Happy to share a few gallons back.", createdAt: ago(12))
        [swap, press].forEach { context.insert($0) }
        context.insert(Comment(postID: swap.uid, authorID: sam.uid, text: "Is there a table for tools too?", createdAt: ago(28)))
        context.insert(Comment(postID: swap.uid, authorID: june.uid, text: "Yes, bring them along!",
                               replyToAuthorID: sam.uid, createdAt: ago(27)))
        context.insert(Comment(postID: press.uid, authorID: rosa.uid, text: "My neighbor has one. I'll ask!", createdAt: ago(10)))
    }
}
