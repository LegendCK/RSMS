//
//  SeedData.swift
//  infosys2
//
//  Pre-populates the database with SRS-compliant luxury products, categories,
//  and sample data for all domain models.
//

import Foundation
import SwiftData

struct SeedData {

    static func seedIfNeeded(modelContext: ModelContext) {
        seedUsersIfNeeded(modelContext: modelContext)
        seedCatalogIfNeeded(modelContext: modelContext)
        seedOrdersIfNeeded(modelContext: modelContext)
        seedClientsIfNeeded(modelContext: modelContext)
        seedAppointmentsIfNeeded(modelContext: modelContext)
        seedAfterSalesIfNeeded(modelContext: modelContext)
        seedTransfersIfNeeded(modelContext: modelContext)
        seedEventsIfNeeded(modelContext: modelContext)
        seedNotificationsIfNeeded(modelContext: modelContext)
        try? modelContext.save()
    }

    // MARK: - Users

    private static func seedUsersIfNeeded(modelContext: ModelContext) {
        let desc = FetchDescriptor<User>()
        guard (try? modelContext.fetchCount(desc)) == 0 else { return }

        let users = [
            User(name: "Victoria Sterling", email: "admin@maisonluxe.com", phone: "+1-800-555-0001", passwordHash: "admin123", role: .corporateAdmin),
            User(name: "James Beaumont", email: "manager@maisonluxe.com", phone: "+1-800-555-0010", passwordHash: "manager123", role: .boutiqueManager),
            User(name: "Sophia Laurent", email: "sophia.l@maisonluxe.com", phone: "+1-800-555-0011", passwordHash: "manager123", role: .boutiqueManager),
            User(name: "Alexander Chase", email: "sales@maisonluxe.com", phone: "+1-800-555-0020", passwordHash: "sales123", role: .salesAssociate),
            User(name: "Isabella Moreau", email: "isabella.m@maisonluxe.com", phone: "+1-800-555-0021", passwordHash: "sales123", role: .salesAssociate),
            User(name: "Daniel Park", email: "inventory@maisonluxe.com", phone: "+1-800-555-0030", passwordHash: "inventory123", role: .inventoryController),
            User(name: "Marcus Webb", email: "service@maisonluxe.com", phone: "+1-800-555-0040", passwordHash: "service123", role: .serviceTechnician),
            User(name: "Olivia Hartwell", email: "olivia@example.com", phone: "+1-555-123-4567", passwordHash: "customer123", role: .customer),
            User(name: "Liam Chen", email: "liam.c@example.com", phone: "+1-555-234-5678", passwordHash: "customer123", role: .customer),
        ]
        for u in users { modelContext.insert(u) }
    }

    // MARK: - Catalog (Categories + Products)

    private static func seedCatalogIfNeeded(modelContext: ModelContext) {
        let desc = FetchDescriptor<Category>()
        guard (try? modelContext.fetchCount(desc)) == 0 else { return }

        // ── 4 SRS Categories with 10 product types each ──

        let jewelleryTypes = "[\"Engagement Rings\",\"Wedding Bands\",\"Necklaces & Pendants\",\"Earrings\",\"Bracelets\",\"Brooches & Pins\",\"Cufflinks & Tie Bars\",\"Anklets\",\"Fine Body Jewellery\",\"Bespoke & Custom\"]"
        let watchTypes = "[\"Dress Watches\",\"Sport & Dive Watches\",\"Chronographs\",\"Tourbillons\",\"Skeleton Watches\",\"GMT & World-Time\",\"Perpetual Calendars\",\"Minute Repeaters\",\"Smart Luxury Watches\",\"Limited Edition Timepieces\"]"
        let leatherTypes = "[\"Handbags\",\"Crossbody & Shoulder Bags\",\"Clutches & Evening Bags\",\"Totes & Shoppers\",\"Briefcases & Portfolios\",\"Wallets & Card Holders\",\"Belts\",\"Luggage & Travel\",\"Leather Accessories\",\"Exotic Leather Pieces\"]"
        let coutureTypes = "[\"Evening Gowns\",\"Tailored Suits\",\"Silk Blouses & Tops\",\"Cashmere Knitwear\",\"Outerwear & Coats\",\"Scarves & Shawls\",\"Ready-to-Wear Dresses\",\"Bridal Couture\",\"Resort & Cruise Wear\",\"Limited Edition Capsules\"]"

        let categories = [
            Category(name: "Jewellery", icon: "sparkles", description: "Fine jewellery and precious gemstones crafted by master artisans", displayOrder: 0, productTypes: jewelleryTypes),
            Category(name: "Watches", icon: "clock.fill", description: "Precision timepieces from the world's most prestigious horologists", displayOrder: 1, productTypes: watchTypes),
            Category(name: "Leather Goods", icon: "bag.fill", description: "Exquisite leather goods handcrafted from the finest hides", displayOrder: 2, productTypes: leatherTypes),
            Category(name: "Couture", icon: "tshirt.fill", description: "Haute couture and ready-to-wear from visionary ateliers", displayOrder: 3, productTypes: coutureTypes),
        ]
        for c in categories { modelContext.insert(c) }

        // ── Products (10+ per category, 40+ total) ──

        let products: [Product] = [
            // ═══ JEWELLERY ═══
            Product(name: "Soleil Eternity Ring", brand: "Maison Luxe", description: "Brilliant-cut diamond eternity ring set in 18k white gold. Each stone hand-selected for exceptional fire and clarity.", price: 12800, categoryName: "Jewellery", imageName: "sparkles", isFeatured: true, rating: 5.0, stockCount: 3, sku: "ML-JEW-ER-001", serialNumber: "JEW-2026-00001", barcode: "8901234560001", rfidTagID: "E2003412AC880100", certificateRef: "GIA-2026-87654", productTypeName: "Engagement Rings", attributes: "{\"metal\":\"18k White Gold\",\"mainStone\":\"Diamond\",\"carat\":\"2.5\",\"clarity\":\"VVS1\",\"cut\":\"Brilliant\",\"setting\":\"Pavé\"}", material: "18k White Gold, Diamond", countryOfOrigin: "France", weight: 4.2, dimensions: "Ring Size 6"),

            Product(name: "Heritage Wedding Band", brand: "Maison Luxe", description: "Classic platinum wedding band with milgrain detailing and comfort-fit interior.", price: 3200, categoryName: "Jewellery", imageName: "sparkles", rating: 4.8, stockCount: 12, sku: "ML-JEW-WB-002", serialNumber: "JEW-2026-00002", barcode: "8901234560002", rfidTagID: "E2003412AC880101", productTypeName: "Wedding Bands", attributes: "{\"metal\":\"Platinum 950\",\"width\":\"4mm\",\"finish\":\"Polished with Milgrain\"}", material: "Platinum", countryOfOrigin: "Italy", weight: 8.5, dimensions: "Ring Size 7"),

            Product(name: "Celestine Diamond Pendant", brand: "Maison Luxe", description: "Pear-shaped diamond pendant on an 18k rose gold chain. 1.8 carat certified stone.", price: 15800, categoryName: "Jewellery", imageName: "sparkles", isFeatured: true, rating: 5.0, stockCount: 2, sku: "ML-JEW-NP-003", serialNumber: "JEW-2026-00003", barcode: "8901234560003", rfidTagID: "E2003412AC880102", certificateRef: "GIA-2026-87655", productTypeName: "Necklaces & Pendants", attributes: "{\"metal\":\"18k Rose Gold\",\"mainStone\":\"Diamond\",\"carat\":\"1.8\",\"chainLength\":\"18 inches\",\"shape\":\"Pear\"}", material: "18k Rose Gold, Diamond", countryOfOrigin: "France", weight: 6.1, dimensions: "18\" chain, pendant 15mm"),

            Product(name: "South Sea Pearl Drops", brand: "Maison Luxe", description: "South Sea pearl drop earrings with diamond accents in platinum setting. Lustrous pearls from Australian waters.", price: 4200, categoryName: "Jewellery", imageName: "sparkles", rating: 4.8, stockCount: 6, sku: "ML-JEW-EA-004", serialNumber: "JEW-2026-00004", barcode: "8901234560004", rfidTagID: "E2003412AC880103", productTypeName: "Earrings", attributes: "{\"metal\":\"Platinum\",\"pearlType\":\"South Sea\",\"pearlSize\":\"12mm\",\"accent\":\"Diamond 0.3ct\"}", material: "Platinum, South Sea Pearl, Diamond", countryOfOrigin: "Australia", weight: 9.0, dimensions: "Drop length 35mm"),

            Product(name: "Woven Rose Gold Bracelet", brand: "Maison Luxe", description: "Intricately woven 18k rose gold bracelet with pavé diamond clasp.", price: 7500, categoryName: "Jewellery", imageName: "sparkles", rating: 4.7, stockCount: 5, sku: "ML-JEW-BR-005", serialNumber: "JEW-2026-00005", barcode: "8901234560005", rfidTagID: "E2003412AC880104", productTypeName: "Bracelets", attributes: "{\"metal\":\"18k Rose Gold\",\"claspType\":\"Pavé Diamond\",\"style\":\"Woven\"}", material: "18k Rose Gold, Diamond", countryOfOrigin: "Italy", weight: 22.0, dimensions: "Length 7.5 inches"),

            Product(name: "Art Deco Sapphire Brooch", brand: "Maison Luxe", description: "Stunning Art Deco-inspired brooch featuring a central Ceylon sapphire surrounded by diamonds.", price: 9800, categoryName: "Jewellery", imageName: "sparkles", rating: 4.9, stockCount: 2, sku: "ML-JEW-BP-006", serialNumber: "JEW-2026-00006", barcode: "8901234560006", rfidTagID: "E2003412AC880105", certificateRef: "GIA-2026-87656", productTypeName: "Brooches & Pins", attributes: "{\"metal\":\"Platinum\",\"mainStone\":\"Ceylon Sapphire\",\"carat\":\"3.2\",\"accent\":\"Diamond 1.5ct total\",\"era\":\"Art Deco\"}", material: "Platinum, Sapphire, Diamond", countryOfOrigin: "France", weight: 15.0, dimensions: "45mm x 30mm"),

            Product(name: "Onyx & Gold Cufflinks", brand: "Maison Luxe", description: "Polished black onyx cufflinks set in 18k yellow gold with diamond accent.", price: 2400, categoryName: "Jewellery", imageName: "sparkles", rating: 4.6, stockCount: 8, sku: "ML-JEW-CL-007", serialNumber: "JEW-2026-00007", barcode: "8901234560007", rfidTagID: "E2003412AC880106", productTypeName: "Cufflinks & Tie Bars", attributes: "{\"metal\":\"18k Yellow Gold\",\"stone\":\"Black Onyx\",\"accent\":\"Diamond 0.1ct\"}", material: "18k Yellow Gold, Black Onyx", countryOfOrigin: "England", weight: 12.0, dimensions: "15mm diameter"),

            Product(name: "Diamond Tennis Anklet", brand: "Maison Luxe", description: "Delicate diamond tennis anklet in 14k white gold.", price: 3800, categoryName: "Jewellery", imageName: "sparkles", rating: 4.5, stockCount: 4, sku: "ML-JEW-AN-008", serialNumber: "JEW-2026-00008", barcode: "8901234560008", rfidTagID: "E2003412AC880107", productTypeName: "Anklets", attributes: "{\"metal\":\"14k White Gold\",\"stones\":\"Round Diamond 2.0ct total\",\"style\":\"Tennis\"}", material: "14k White Gold, Diamond", countryOfOrigin: "Italy", weight: 5.5, dimensions: "Length 10 inches"),

            Product(name: "Emerald Navel Ring", brand: "Maison Luxe", description: "18k gold body jewellery featuring a natural Colombian emerald.", price: 1800, categoryName: "Jewellery", imageName: "sparkles", rating: 4.4, stockCount: 3, sku: "ML-JEW-BJ-009", serialNumber: "JEW-2026-00009", barcode: "8901234560009", rfidTagID: "E2003412AC880108", productTypeName: "Fine Body Jewellery", attributes: "{\"metal\":\"18k Yellow Gold\",\"stone\":\"Colombian Emerald 0.5ct\"}", material: "18k Yellow Gold, Emerald", countryOfOrigin: "Colombia", weight: 2.0, dimensions: "Standard gauge"),

            Product(name: "Bespoke Sapphire Suite", brand: "Maison Luxe", description: "Custom-designed sapphire and diamond jewellery suite — necklace, earrings, and ring. Consultation required.", price: 85000, categoryName: "Jewellery", imageName: "sparkles", isLimitedEdition: true, isFeatured: true, rating: 5.0, stockCount: 1, sku: "ML-JEW-BC-010", serialNumber: "JEW-2026-00010", barcode: "8901234560010", rfidTagID: "E2003412AC880109", certificateRef: "GIA-2026-87657", productTypeName: "Bespoke & Custom", attributes: "{\"metal\":\"Platinum & 18k White Gold\",\"mainStone\":\"Kashmir Sapphire\",\"carat\":\"8.5\",\"pieces\":\"Necklace, Earrings, Ring\"}", material: "Platinum, Kashmir Sapphire, Diamond", countryOfOrigin: "France", weight: 65.0, dimensions: "Suite — multiple pieces"),

            // ═══ WATCHES ═══
            Product(name: "Classique Dress Watch", brand: "Maison Luxe", description: "Ultra-thin automatic dress watch with enamel dial and alligator strap.", price: 8500, categoryName: "Watches", imageName: "clock.fill", rating: 4.8, stockCount: 5, sku: "ML-WAT-DW-001", serialNumber: "WAT-2026-00001", barcode: "8901234570001", rfidTagID: "E2003412AC880200", productTypeName: "Dress Watches", attributes: "{\"movement\":\"Automatic\",\"case\":\"18k Rose Gold\",\"diameter\":\"39mm\",\"waterResistance\":\"30m\",\"crystal\":\"Sapphire\"}", material: "18k Rose Gold", countryOfOrigin: "Switzerland", weight: 65.0, dimensions: "39mm x 8.2mm"),

            Product(name: "Abyss Diver 300", brand: "Maison Luxe", description: "Professional dive watch with ceramic bezel and titanium case. Water resistant to 300m.", price: 6750, categoryName: "Watches", imageName: "clock.fill", isFeatured: true, rating: 4.9, stockCount: 7, sku: "ML-WAT-SD-002", serialNumber: "WAT-2026-00002", barcode: "8901234570002", rfidTagID: "E2003412AC880201", productTypeName: "Sport & Dive Watches", attributes: "{\"movement\":\"Automatic\",\"case\":\"Titanium Grade 5\",\"diameter\":\"42mm\",\"waterResistance\":\"300m\",\"bezel\":\"Ceramic Unidirectional\"}", material: "Titanium, Ceramic", countryOfOrigin: "Switzerland", weight: 95.0, dimensions: "42mm x 13.5mm"),

            Product(name: "Perpetual Chronograph", brand: "Maison Luxe", description: "Automatic chronograph with 18k gold case, sapphire crystal, and Swiss movement.", price: 12500, categoryName: "Watches", imageName: "clock.fill", isFeatured: true, rating: 5.0, stockCount: 3, sku: "ML-WAT-CH-003", serialNumber: "WAT-2026-00003", barcode: "8901234570003", rfidTagID: "E2003412AC880202", certificateRef: "COSC-2026-4421", productTypeName: "Chronographs", attributes: "{\"movement\":\"Automatic Chronograph\",\"case\":\"18k Yellow Gold\",\"diameter\":\"41mm\",\"waterResistance\":\"100m\",\"complication\":\"Chronograph, Date\"}", material: "18k Yellow Gold", countryOfOrigin: "Switzerland", weight: 120.0, dimensions: "41mm x 14mm"),

            Product(name: "Virtuoso Tourbillon", brand: "Maison Luxe", description: "Flying tourbillon with hand-engraved bridges and 80-hour power reserve. A horological masterpiece.", price: 125000, categoryName: "Watches", imageName: "clock.fill", isLimitedEdition: true, isFeatured: true, rating: 5.0, stockCount: 1, sku: "ML-WAT-TB-004", serialNumber: "WAT-2026-00004", barcode: "8901234570004", rfidTagID: "E2003412AC880203", certificateRef: "COSC-2026-4422", productTypeName: "Tourbillons", attributes: "{\"movement\":\"Manual Wind Tourbillon\",\"case\":\"Platinum 950\",\"diameter\":\"40mm\",\"powerReserve\":\"80 hours\",\"finishing\":\"Hand-engraved bridges\"}", material: "Platinum 950", countryOfOrigin: "Switzerland", weight: 110.0, dimensions: "40mm x 11mm"),

            Product(name: "Skeletonique Open Heart", brand: "Maison Luxe", description: "Openworked skeleton watch revealing the intricate movement through sapphire crystal.", price: 18500, categoryName: "Watches", imageName: "clock.fill", rating: 4.7, stockCount: 4, sku: "ML-WAT-SK-005", serialNumber: "WAT-2026-00005", barcode: "8901234570005", rfidTagID: "E2003412AC880204", productTypeName: "Skeleton Watches", attributes: "{\"movement\":\"Manual Wind\",\"case\":\"18k White Gold\",\"diameter\":\"40mm\",\"dial\":\"Openworked\",\"crystal\":\"Double Sapphire\"}", material: "18k White Gold", countryOfOrigin: "Switzerland", weight: 75.0, dimensions: "40mm x 9.5mm"),

            Product(name: "Voyager GMT", brand: "Maison Luxe", description: "Dual-timezone GMT watch with rotating bezel and jumping hour hand.", price: 9200, categoryName: "Watches", imageName: "clock.fill", rating: 4.8, stockCount: 6, sku: "ML-WAT-GM-006", serialNumber: "WAT-2026-00006", barcode: "8901234570006", rfidTagID: "E2003412AC880205", productTypeName: "GMT & World-Time", attributes: "{\"movement\":\"Automatic GMT\",\"case\":\"Stainless Steel\",\"diameter\":\"40mm\",\"waterResistance\":\"100m\",\"bezel\":\"24-hour Bi-colour Ceramic\"}", material: "Stainless Steel, Ceramic", countryOfOrigin: "Switzerland", weight: 105.0, dimensions: "40mm x 12mm"),

            Product(name: "Eternelle Perpetual Calendar", brand: "Maison Luxe", description: "Grand complication perpetual calendar with moon phase and leap year indicator.", price: 68000, categoryName: "Watches", imageName: "clock.fill", rating: 5.0, stockCount: 2, sku: "ML-WAT-PC-007", serialNumber: "WAT-2026-00007", barcode: "8901234570007", rfidTagID: "E2003412AC880206", certificateRef: "COSC-2026-4423", productTypeName: "Perpetual Calendars", attributes: "{\"movement\":\"Automatic\",\"case\":\"18k Rose Gold\",\"diameter\":\"41mm\",\"complications\":\"Perpetual Calendar, Moon Phase, Leap Year\"}", material: "18k Rose Gold", countryOfOrigin: "Switzerland", weight: 115.0, dimensions: "41mm x 12.5mm"),

            Product(name: "Sonata Minute Repeater", brand: "Maison Luxe", description: "Grand complication minute repeater with cathedral gongs and enamel dial.", price: 195000, categoryName: "Watches", imageName: "clock.fill", isLimitedEdition: true, rating: 5.0, stockCount: 1, sku: "ML-WAT-MR-008", serialNumber: "WAT-2026-00008", barcode: "8901234570008", rfidTagID: "E2003412AC880207", certificateRef: "COSC-2026-4424", productTypeName: "Minute Repeaters", attributes: "{\"movement\":\"Manual Wind Minute Repeater\",\"case\":\"Platinum 950\",\"diameter\":\"42mm\",\"gongs\":\"Cathedral\",\"dial\":\"Grand Feu Enamel\"}", material: "Platinum 950", countryOfOrigin: "Switzerland", weight: 125.0, dimensions: "42mm x 13mm"),

            Product(name: "Diamond Bezel Watch", brand: "Maison Luxe", description: "Ladies' watch with diamond-set bezel and mother of pearl dial.", price: 8900, categoryName: "Watches", imageName: "clock.fill", rating: 4.9, stockCount: 4, sku: "ML-WAT-SL-009", serialNumber: "WAT-2026-00009", barcode: "8901234570009", rfidTagID: "E2003412AC880208", productTypeName: "Smart Luxury Watches", attributes: "{\"movement\":\"Quartz with Smart Module\",\"case\":\"18k White Gold\",\"diameter\":\"34mm\",\"bezel\":\"Diamond Set 1.2ct\",\"dial\":\"Mother of Pearl\"}", material: "18k White Gold, Diamond", countryOfOrigin: "Switzerland", weight: 55.0, dimensions: "34mm x 8mm"),

            Product(name: "Artisan Timepiece No. 1", brand: "Maison Luxe", description: "Hand-engraved platinum watch with enamel dial. Limited to 25 pieces worldwide.", price: 45000, categoryName: "Watches", imageName: "clock.fill", isLimitedEdition: true, rating: 5.0, stockCount: 1, sku: "ML-WAT-LE-010", serialNumber: "WAT-2026-00010", barcode: "8901234570010", rfidTagID: "E2003412AC880209", certificateRef: "COSC-2026-4425", productTypeName: "Limited Edition Timepieces", attributes: "{\"movement\":\"Manual Wind\",\"case\":\"Platinum 950\",\"diameter\":\"39mm\",\"edition\":\"25 Pieces\",\"engraving\":\"Hand-engraved\"}", material: "Platinum 950", countryOfOrigin: "Switzerland", weight: 100.0, dimensions: "39mm x 10mm"),

            // ═══ LEATHER GOODS ═══
            Product(name: "Classic Flap Bag", brand: "Maison Luxe", description: "Timeless quilted lambskin bag with signature gold chain strap. Handcrafted by master artisans.", price: 4850, categoryName: "Leather Goods", imageName: "bag.fill", isFeatured: true, rating: 4.9, stockCount: 5, sku: "ML-LTH-HB-001", serialNumber: "LTH-2026-00001", barcode: "8901234580001", rfidTagID: "E2003412AC880300", productTypeName: "Handbags", attributes: "{\"leather\":\"Lambskin\",\"hardware\":\"Gold-Tone\",\"lining\":\"Suede\",\"closure\":\"Turn-Lock\"}", material: "Lambskin Leather", countryOfOrigin: "Italy", weight: 450.0, dimensions: "25cm x 16cm x 7cm"),

            Product(name: "Saddle Crossbody", brand: "Maison Luxe", description: "Compact crossbody in soft calfskin with adjustable chain strap.", price: 2450, categoryName: "Leather Goods", imageName: "bag.fill", rating: 4.8, stockCount: 8, sku: "ML-LTH-CB-002", serialNumber: "LTH-2026-00002", barcode: "8901234580002", rfidTagID: "E2003412AC880301", productTypeName: "Crossbody & Shoulder Bags", attributes: "{\"leather\":\"Calfskin\",\"hardware\":\"Silver-Tone\",\"strap\":\"Adjustable Chain\"}", material: "Calfskin Leather", countryOfOrigin: "Italy", weight: 350.0, dimensions: "22cm x 15cm x 6cm"),

            Product(name: "Crystal Evening Clutch", brand: "Maison Luxe", description: "Satin-lined evening clutch with crystal encrusted clasp and detachable chain.", price: 1950, categoryName: "Leather Goods", imageName: "bag.fill", rating: 4.7, stockCount: 6, sku: "ML-LTH-EC-003", serialNumber: "LTH-2026-00003", barcode: "8901234580003", rfidTagID: "E2003412AC880302", productTypeName: "Clutches & Evening Bags", attributes: "{\"leather\":\"Nappa\",\"hardware\":\"Crystal & Gold\",\"lining\":\"Silk Satin\",\"closure\":\"Crystal Clasp\"}", material: "Nappa Leather, Crystal", countryOfOrigin: "France", weight: 280.0, dimensions: "26cm x 14cm x 4cm"),

            Product(name: "Parisian Tote", brand: "Maison Luxe", description: "Spacious pebbled calfskin tote with suede interior and gold hardware.", price: 3200, categoryName: "Leather Goods", imageName: "bag.fill", rating: 4.7, stockCount: 10, sku: "ML-LTH-TS-004", serialNumber: "LTH-2026-00004", barcode: "8901234580004", rfidTagID: "E2003412AC880303", productTypeName: "Totes & Shoppers", attributes: "{\"leather\":\"Pebbled Calfskin\",\"hardware\":\"Gold-Tone\",\"lining\":\"Alcantara\"}", material: "Calfskin Leather", countryOfOrigin: "Italy", weight: 680.0, dimensions: "34cm x 28cm x 15cm"),

            Product(name: "Executive Briefcase", brand: "Maison Luxe", description: "Double-gusset briefcase in Venezia leather with combination lock.", price: 3800, categoryName: "Leather Goods", imageName: "bag.fill", rating: 4.6, stockCount: 4, sku: "ML-LTH-BP-005", serialNumber: "LTH-2026-00005", barcode: "8901234580005", rfidTagID: "E2003412AC880304", productTypeName: "Briefcases & Portfolios", attributes: "{\"leather\":\"Venezia\",\"hardware\":\"Palladium\",\"compartments\":\"3\",\"lock\":\"Combination\"}", material: "Venezia Leather", countryOfOrigin: "Italy", weight: 1200.0, dimensions: "40cm x 30cm x 10cm"),

            Product(name: "Continental Wallet", brand: "Maison Luxe", description: "Full-grain calfskin continental wallet with 12 card slots and gold monogram.", price: 890, categoryName: "Leather Goods", imageName: "bag.fill", rating: 4.8, stockCount: 15, sku: "ML-LTH-WC-006", serialNumber: "LTH-2026-00006", barcode: "8901234580006", rfidTagID: "E2003412AC880305", productTypeName: "Wallets & Card Holders", attributes: "{\"leather\":\"Full-Grain Calfskin\",\"slots\":\"12 Card + 2 Bill\",\"closure\":\"Snap\"}", material: "Calfskin Leather", countryOfOrigin: "Italy", weight: 120.0, dimensions: "19cm x 10cm x 2.5cm"),

            Product(name: "Signature Reversible Belt", brand: "Maison Luxe", description: "Reversible calfskin belt with signature gold buckle. Black/brown.", price: 650, categoryName: "Leather Goods", imageName: "bag.fill", rating: 4.6, stockCount: 20, sku: "ML-LTH-BT-007", serialNumber: "LTH-2026-00007", barcode: "8901234580007", rfidTagID: "E2003412AC880306", productTypeName: "Belts", attributes: "{\"leather\":\"Calfskin\",\"buckle\":\"Gold-Tone Signature\",\"reversible\":\"Black/Brown\",\"width\":\"35mm\"}", material: "Calfskin Leather", countryOfOrigin: "Italy", weight: 180.0, dimensions: "Width 35mm"),

            Product(name: "Horizon Rolling Trunk", brand: "Maison Luxe", description: "Four-wheeled rolling trunk in monogram-embossed leather with TSA lock.", price: 7200, categoryName: "Leather Goods", imageName: "bag.fill", rating: 4.9, stockCount: 3, sku: "ML-LTH-LT-008", serialNumber: "LTH-2026-00008", barcode: "8901234580008", rfidTagID: "E2003412AC880307", productTypeName: "Luggage & Travel", attributes: "{\"leather\":\"Monogram Embossed\",\"wheels\":\"4 Silent\",\"lock\":\"TSA Approved\",\"capacity\":\"55L\"}", material: "Coated Canvas, Leather Trim", countryOfOrigin: "France", weight: 4800.0, dimensions: "55cm x 38cm x 21cm"),

            Product(name: "Leather Key Holder", brand: "Maison Luxe", description: "Six-hook key holder in Epsom leather with gold snap closure.", price: 420, categoryName: "Leather Goods", imageName: "bag.fill", rating: 4.5, stockCount: 18, sku: "ML-LTH-LA-009", serialNumber: "LTH-2026-00009", barcode: "8901234580009", rfidTagID: "E2003412AC880308", productTypeName: "Leather Accessories", attributes: "{\"leather\":\"Epsom\",\"hooks\":\"6\",\"closure\":\"Gold Snap\"}", material: "Epsom Leather", countryOfOrigin: "France", weight: 45.0, dimensions: "10cm x 6cm"),

            Product(name: "Python Clutch", brand: "Maison Luxe", description: "Genuine python skin clutch with gold frame and suede lining. CITES certified.", price: 5600, categoryName: "Leather Goods", imageName: "bag.fill", isLimitedEdition: true, rating: 4.9, stockCount: 2, sku: "ML-LTH-EX-010", serialNumber: "LTH-2026-00010", barcode: "8901234580010", rfidTagID: "E2003412AC880309", certificateRef: "CITES-2026-PY-0042", productTypeName: "Exotic Leather Pieces", attributes: "{\"leather\":\"Python\",\"hardware\":\"Gold Frame\",\"lining\":\"Suede\",\"certification\":\"CITES\"}", material: "Python Skin", countryOfOrigin: "Italy", weight: 320.0, dimensions: "28cm x 15cm x 5cm"),

            // ═══ COUTURE ═══
            Product(name: "Noir Sequin Evening Gown", brand: "Maison Luxe", description: "Floor-length evening gown with hand-sewn sequins and silk chiffon overlay.", price: 8900, categoryName: "Couture", imageName: "tshirt.fill", isFeatured: true, rating: 5.0, stockCount: 2, sku: "ML-COU-EG-001", serialNumber: "COU-2026-00001", barcode: "8901234590001", rfidTagID: "E2003412AC880400", productTypeName: "Evening Gowns", attributes: "{\"fabric\":\"Silk Chiffon & Sequin\",\"color\":\"Noir\",\"length\":\"Floor\",\"closure\":\"Concealed Zip\"}", material: "Silk, Sequin", countryOfOrigin: "France", weight: 1800.0, dimensions: "Custom sizing available"),

            Product(name: "Savile Row Tuxedo", brand: "Maison Luxe", description: "Peak-lapel tuxedo in Super 180s wool with silk satin lining.", price: 4500, categoryName: "Couture", imageName: "tshirt.fill", rating: 4.8, stockCount: 4, sku: "ML-COU-TS-002", serialNumber: "COU-2026-00002", barcode: "8901234590002", rfidTagID: "E2003412AC880401", productTypeName: "Tailored Suits", attributes: "{\"fabric\":\"Super 180s Wool\",\"lining\":\"Silk Satin\",\"lapel\":\"Peak\",\"buttons\":\"Horn\"}", material: "Wool, Silk", countryOfOrigin: "England", weight: 2200.0, dimensions: "Standard sizing 44-54"),

            Product(name: "Duchess Silk Blouse", brand: "Maison Luxe", description: "Flowing silk crêpe de Chine blouse with mother-of-pearl buttons.", price: 1200, categoryName: "Couture", imageName: "tshirt.fill", rating: 4.7, stockCount: 8, sku: "ML-COU-SB-003", serialNumber: "COU-2026-00003", barcode: "8901234590003", rfidTagID: "E2003412AC880402", productTypeName: "Silk Blouses & Tops", attributes: "{\"fabric\":\"Silk Crêpe de Chine\",\"color\":\"Ivory\",\"buttons\":\"Mother-of-Pearl\"}", material: "Silk", countryOfOrigin: "Italy", weight: 180.0, dimensions: "XS - XL"),

            Product(name: "Scottish Cashmere Cardigan", brand: "Maison Luxe", description: "Two-ply Scottish cashmere cardigan with gold-tone buttons. Relaxed fit.", price: 1650, categoryName: "Couture", imageName: "tshirt.fill", rating: 4.9, stockCount: 6, sku: "ML-COU-CK-004", serialNumber: "COU-2026-00004", barcode: "8901234590004", rfidTagID: "E2003412AC880403", productTypeName: "Cashmere Knitwear", attributes: "{\"fabric\":\"2-Ply Scottish Cashmere\",\"color\":\"Camel\",\"fit\":\"Relaxed\",\"buttons\":\"Gold-Tone\"}", material: "Cashmere", countryOfOrigin: "Scotland", weight: 350.0, dimensions: "S - XXL"),

            Product(name: "Cashmere Overcoat", brand: "Maison Luxe", description: "Double-breasted cashmere overcoat in charcoal with horn buttons.", price: 5200, categoryName: "Couture", imageName: "tshirt.fill", isFeatured: true, rating: 4.8, stockCount: 3, sku: "ML-COU-OC-005", serialNumber: "COU-2026-00005", barcode: "8901234590005", rfidTagID: "E2003412AC880404", productTypeName: "Outerwear & Coats", attributes: "{\"fabric\":\"Double-Face Cashmere\",\"color\":\"Charcoal\",\"style\":\"Double-Breasted\",\"buttons\":\"Horn\"}", material: "Cashmere", countryOfOrigin: "Italy", weight: 1800.0, dimensions: "Standard sizing 46-56"),

            Product(name: "Artisan Silk Scarf", brand: "Maison Luxe", description: "Hand-rolled silk twill scarf with original artwork print. Made in France.", price: 890, categoryName: "Couture", imageName: "tshirt.fill", rating: 4.5, stockCount: 12, sku: "ML-COU-SS-006", serialNumber: "COU-2026-00006", barcode: "8901234590006", rfidTagID: "E2003412AC880405", productTypeName: "Scarves & Shawls", attributes: "{\"fabric\":\"Silk Twill\",\"size\":\"90cm x 90cm\",\"print\":\"Original Artwork\",\"finish\":\"Hand-Rolled Edges\"}", material: "Silk Twill", countryOfOrigin: "France", weight: 65.0, dimensions: "90cm x 90cm"),

            Product(name: "Atelier Midi Dress", brand: "Maison Luxe", description: "Structured midi dress in double-face wool with architectural seaming.", price: 2800, categoryName: "Couture", imageName: "tshirt.fill", rating: 4.6, stockCount: 5, sku: "ML-COU-RW-007", serialNumber: "COU-2026-00007", barcode: "8901234590007", rfidTagID: "E2003412AC880406", productTypeName: "Ready-to-Wear Dresses", attributes: "{\"fabric\":\"Double-Face Wool\",\"length\":\"Midi\",\"closure\":\"Concealed Zip\",\"lining\":\"Silk\"}", material: "Wool, Silk Lining", countryOfOrigin: "France", weight: 850.0, dimensions: "XS - L"),

            Product(name: "Ivory Bridal Gown", brand: "Maison Luxe", description: "Hand-beaded bridal gown in silk mikado with cathedral train. By appointment only.", price: 25000, categoryName: "Couture", imageName: "tshirt.fill", isLimitedEdition: true, rating: 5.0, stockCount: 1, sku: "ML-COU-BC-008", serialNumber: "COU-2026-00008", barcode: "8901234590008", rfidTagID: "E2003412AC880407", productTypeName: "Bridal Couture", attributes: "{\"fabric\":\"Silk Mikado\",\"embellishment\":\"Hand-Beaded\",\"train\":\"Cathedral\",\"color\":\"Ivory\"}", material: "Silk Mikado", countryOfOrigin: "France", weight: 3500.0, dimensions: "Custom sizing"),

            Product(name: "Riviera Linen Set", brand: "Maison Luxe", description: "Relaxed linen co-ord set for resort wear. Breathable Italian linen.", price: 1800, categoryName: "Couture", imageName: "tshirt.fill", rating: 4.6, stockCount: 7, sku: "ML-COU-RC-009", serialNumber: "COU-2026-00009", barcode: "8901234590009", rfidTagID: "E2003412AC880408", productTypeName: "Resort & Cruise Wear", attributes: "{\"fabric\":\"Italian Linen\",\"color\":\"Natural\",\"pieces\":\"Shirt + Trousers\"}", material: "Linen", countryOfOrigin: "Italy", weight: 550.0, dimensions: "S - XL"),

            Product(name: "Heritage Capsule Jacket", brand: "Maison Luxe", description: "Limited edition heritage capsule jacket in hand-painted leather. Numbered 1 of 50.", price: 12500, categoryName: "Couture", imageName: "tshirt.fill", isLimitedEdition: true, isFeatured: true, rating: 5.0, stockCount: 1, sku: "ML-COU-LE-010", serialNumber: "COU-2026-00010", barcode: "8901234590010", rfidTagID: "E2003412AC880409", certificateRef: "ML-AUTH-2026-HC-001", productTypeName: "Limited Edition Capsules", attributes: "{\"fabric\":\"Hand-Painted Leather\",\"edition\":\"1 of 50\",\"lining\":\"Silk\",\"hardware\":\"Gold\"}", material: "Leather, Silk", countryOfOrigin: "France", weight: 2100.0, dimensions: "Standard sizing 44-52"),
        ]

        for p in products { modelContext.insert(p) }
    }

    // MARK: - Orders & Cart

    private static func seedOrdersIfNeeded(modelContext: ModelContext) {
        let desc = FetchDescriptor<Order>()
        guard (try? modelContext.fetchCount(desc)) == 0 else { return }

        let orders = [
            Order(orderNumber: "ML-ORD-2026-0001", customerEmail: "olivia@example.com", status: .delivered, orderItems: "[{\"name\":\"Classic Flap Bag\",\"sku\":\"ML-LTH-HB-001\",\"qty\":1,\"price\":4850}]", subtotal: 4850, tax: 388, total: 5238, fulfillmentType: .standard, paymentMethod: "Visa •••• 4242", salesAssociateEmail: "sales@maisonluxe.com", boutiqueId: "BTQ-001"),
            Order(orderNumber: "ML-ORD-2026-0002", customerEmail: "olivia@example.com", status: .processing, orderItems: "[{\"name\":\"South Sea Pearl Drops\",\"sku\":\"ML-JEW-EA-004\",\"qty\":1,\"price\":4200},{\"name\":\"Continental Wallet\",\"sku\":\"ML-LTH-WC-006\",\"qty\":1,\"price\":890}]", subtotal: 5090, tax: 407.20, total: 5497.20, fulfillmentType: .bopis, paymentMethod: "Amex •••• 1001", salesAssociateEmail: "isabella.m@maisonluxe.com", boutiqueId: "BTQ-001"),
            Order(orderNumber: "ML-ORD-2026-0003", customerEmail: "liam.c@example.com", status: .confirmed, orderItems: "[{\"name\":\"Voyager GMT\",\"sku\":\"ML-WAT-GM-006\",\"qty\":1,\"price\":9200}]", subtotal: 9200, tax: 736, total: 9936, fulfillmentType: .standard, paymentMethod: "Mastercard •••• 5678"),
            Order(orderNumber: "ML-ORD-2026-0004", customerEmail: "olivia@example.com", status: .delivered, orderItems: "[{\"name\":\"Artisan Silk Scarf\",\"sku\":\"ML-COU-SS-006\",\"qty\":2,\"price\":890}]", subtotal: 1780, tax: 142.40, total: 1922.40, fulfillmentType: .inStore, paymentMethod: "Cash", salesAssociateEmail: "sales@maisonluxe.com", boutiqueId: "BTQ-001"),
        ]
        for o in orders { modelContext.insert(o) }

        // Cart items for olivia
        let cartItems = [
            CartItem(customerEmail: "olivia@example.com", productId: UUID(), productName: "Perpetual Chronograph", productImageName: "clock.fill", unitPrice: 12500, quantity: 1),
            CartItem(customerEmail: "olivia@example.com", productId: UUID(), productName: "Scottish Cashmere Cardigan", productImageName: "tshirt.fill", unitPrice: 1650, quantity: 1),
        ]
        for ci in cartItems { modelContext.insert(ci) }
    }

    // MARK: - Client Profiles

    private static func seedClientsIfNeeded(modelContext: ModelContext) {
        let desc = FetchDescriptor<ClientProfile>()
        guard (try? modelContext.fetchCount(desc)) == 0 else { return }

        let clients = [
            ClientProfile(customerEmail: "olivia@example.com", customerName: "Olivia Hartwell", preferredCategories: "[\"Jewellery\",\"Leather Goods\"]", sizes: "{\"ring\":\"6\",\"bracelet\":\"7 inch\",\"dress\":\"US 4\"}", anniversaries: "[{\"label\":\"Birthday\",\"date\":\"1988-06-15\"},{\"label\":\"Wedding Anniversary\",\"date\":\"2018-09-22\"}]", notes: "Prefers rose gold. Allergic to nickel. VIP since 2022.", vipTier: .platinum, assignedAssociateEmail: "sales@maisonluxe.com", lifetimeSpend: 78500, visitCount: 24),
            ClientProfile(customerEmail: "liam.c@example.com", customerName: "Liam Chen", preferredCategories: "[\"Watches\",\"Couture\"]", sizes: "{\"wrist\":\"7.5 inch\",\"suit\":\"44R\"}", anniversaries: "[{\"label\":\"Birthday\",\"date\":\"1990-03-08\"}]", notes: "Watch collector. Interested in complications and limited editions.", vipTier: .gold, assignedAssociateEmail: "isabella.m@maisonluxe.com", lifetimeSpend: 42000, visitCount: 12),
            ClientProfile(customerEmail: "guest.vip@example.com", customerName: "Arabella Fontaine", preferredCategories: "[\"Couture\",\"Jewellery\"]", sizes: "{\"dress\":\"FR 38\",\"shoe\":\"EU 37\"}", anniversaries: "[]", notes: "High-profile client. Requires private appointments only.", vipTier: .prive, assignedAssociateEmail: "sales@maisonluxe.com", lifetimeSpend: 250000, visitCount: 8),
        ]
        for c in clients { modelContext.insert(c) }
    }

    // MARK: - Appointments

    private static func seedAppointmentsIfNeeded(modelContext: ModelContext) {
        let desc = FetchDescriptor<Appointment>()
        guard (try? modelContext.fetchCount(desc)) == 0 else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let appointments = [
            Appointment(customerEmail: "olivia@example.com", associateEmail: "sales@maisonluxe.com", boutiqueId: "BTQ-001", appointmentType: .styling, scheduledAt: today.addingTimeInterval(10 * 3600), durationMinutes: 60, status: .confirmed, notes: "Spring wardrobe refresh — show new couture arrivals"),
            Appointment(customerEmail: "liam.c@example.com", associateEmail: "isabella.m@maisonluxe.com", boutiqueId: "BTQ-001", appointmentType: .consultation, scheduledAt: today.addingTimeInterval(14 * 3600), durationMinutes: 45, status: .confirmed, notes: "Interested in Perpetual Calendar and Tourbillon"),
            Appointment(customerEmail: "guest.vip@example.com", associateEmail: "sales@maisonluxe.com", boutiqueId: "BTQ-001", appointmentType: .privateViewing, scheduledAt: today.addingTimeInterval(2 * 86400 + 11 * 3600), durationMinutes: 90, status: .requested, notes: "Private viewing of Bespoke Sapphire Suite"),
            Appointment(customerEmail: "olivia@example.com", associateEmail: "sales@maisonluxe.com", boutiqueId: "BTQ-001", appointmentType: .bridal, scheduledAt: today.addingTimeInterval(-3 * 86400 + 15 * 3600), durationMinutes: 120, status: .completed, notes: "Bridal gown fitting — second appointment"),
            Appointment(customerEmail: "liam.c@example.com", associateEmail: "isabella.m@maisonluxe.com", boutiqueId: "BTQ-001", appointmentType: .repairDropOff, scheduledAt: today.addingTimeInterval(5 * 86400 + 10 * 3600), durationMinutes: 30, status: .requested, notes: "Watch service check-in for Voyager GMT"),
        ]
        for a in appointments { modelContext.insert(a) }
    }

    // MARK: - After-Sales Tickets

    private static func seedAfterSalesIfNeeded(modelContext: ModelContext) {
        let desc = FetchDescriptor<AfterSalesTicket>()
        guard (try? modelContext.fetchCount(desc)) == 0 else { return }

        let tickets = [
            AfterSalesTicket(ticketNumber: "AST-2026-0001", customerEmail: "olivia@example.com", serialNumber: "LTH-2026-00001", ticketType: .repair, status: .inProgress, issueDescription: "Chain strap clasp is not closing securely. Needs replacement clasp mechanism.", estimatedCost: 180, assignedTechnicianEmail: "service@maisonluxe.com"),
            AfterSalesTicket(ticketNumber: "AST-2026-0002", customerEmail: "liam.c@example.com", serialNumber: "WAT-2026-00006", ticketType: .servicing, status: .assessed, issueDescription: "Full service requested — movement cleaning, lubrication, and accuracy calibration.", estimatedCost: 650, assignedTechnicianEmail: "service@maisonluxe.com"),
            AfterSalesTicket(ticketNumber: "AST-2026-0003", customerEmail: "olivia@example.com", serialNumber: "JEW-2026-00005", ticketType: .authentication, status: .completed, issueDescription: "Authentication requested for insurance purposes. Certificate issued.", assignedTechnicianEmail: "service@maisonluxe.com"),
        ]
        for t in tickets { modelContext.insert(t) }
    }

    // MARK: - Transfers

    private static func seedTransfersIfNeeded(modelContext: ModelContext) {
        let desc = FetchDescriptor<Transfer>()
        guard (try? modelContext.fetchCount(desc)) == 0 else { return }

        let transfers = [
            Transfer(transferNumber: "TRF-2026-0001", productName: "Virtuoso Tourbillon", quantity: 1, fromBoutiqueId: "DC-MAIN", toBoutiqueId: "BTQ-001", status: .inTransit, shippingTrackingNumber: "FDX-8901234567890"),
            Transfer(transferNumber: "TRF-2026-0002", productName: "Noir Sequin Evening Gown", quantity: 2, fromBoutiqueId: "BTQ-002", toBoutiqueId: "BTQ-001", status: .requested),
            Transfer(transferNumber: "TRF-2026-0003", productName: "Classic Flap Bag", quantity: 3, fromBoutiqueId: "DC-MAIN", toBoutiqueId: "BTQ-001", status: .delivered, shippingTrackingNumber: "UPS-1234567890ABC"),
        ]
        for t in transfers { modelContext.insert(t) }
    }

    // MARK: - Events

    private static func seedEventsIfNeeded(modelContext: ModelContext) {
        let desc = FetchDescriptor<Event>()
        guard (try? modelContext.fetchCount(desc)) == 0 else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let events = [
            Event(eventName: "Spring Haute Couture Preview", eventType: .vipPreview, boutiqueId: "BTQ-001", scheduledDate: today.addingTimeInterval(7 * 86400 + 18 * 3600), capacity: 30, rsvpEmails: "[\"olivia@example.com\",\"guest.vip@example.com\"]", status: .confirmed),
            Event(eventName: "Master Watchmaker Workshop", eventType: .masterclass, boutiqueId: "BTQ-001", scheduledDate: today.addingTimeInterval(14 * 86400 + 14 * 3600), capacity: 15, rsvpEmails: "[\"liam.c@example.com\"]", status: .planned),
        ]
        for e in events { modelContext.insert(e) }
    }

    // MARK: - Notifications

    private static func seedNotificationsIfNeeded(modelContext: ModelContext) {
        let desc = FetchDescriptor<AppNotification>()
        guard (try? modelContext.fetchCount(desc)) == 0 else { return }

        let notifications = [
            AppNotification(recipientEmail: "olivia@example.com", title: "Order Delivered", message: "Your Classic Flap Bag order ML-ORD-2026-0001 has been delivered.", category: .order, deepLink: "order/ML-ORD-2026-0001"),
            AppNotification(recipientEmail: "olivia@example.com", title: "Appointment Reminder", message: "Your styling appointment is tomorrow at 10:00 AM.", category: .appointment, deepLink: "appointment/today"),
            AppNotification(recipientEmail: "olivia@example.com", title: "Repair Update", message: "Your Classic Flap Bag repair is in progress. Estimated completion in 3 days.", category: .afterSales, deepLink: "ticket/AST-2026-0001"),
            AppNotification(recipientEmail: "sales@maisonluxe.com", title: "New Appointment", message: "Styling appointment booked by Olivia Hartwell for today at 10:00 AM.", category: .appointment),
            AppNotification(recipientEmail: "manager@maisonluxe.com", title: "Transfer Arriving", message: "Incoming transfer TRF-2026-0001 (Virtuoso Tourbillon) is in transit.", category: .inventory, deepLink: "transfer/TRF-2026-0001"),
            AppNotification(recipientEmail: "manager@maisonluxe.com", title: "VIP Event RSVP", message: "2 RSVPs received for Spring Haute Couture Preview.", category: .event),
        ]
        for n in notifications { modelContext.insert(n) }
    }
}
