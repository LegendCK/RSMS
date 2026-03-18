import Foundation

struct TaxableLineItem {
    let productId: UUID
    let goodsCategory: String
    let baseUnitPrice: Double
    let quantity: Int
}

struct IndianTaxBreakdown {
    let cgst: Double
    let sgst: Double
    let igst: Double
    let cess: Double
    let additionalLevy: Double

    var totalTax: Double { cgst + sgst + igst + cess + additionalLevy }
}

struct PricingComputation {
    let subtotal: Double
    let taxBreakdown: IndianTaxBreakdown
    let lineItems: [ComputedLineItem]

    struct ComputedLineItem {
        let productId: UUID
        let unitPrice: Double
        let quantity: Int
        let taxableValue: Double
        let tax: Double
    }
}

enum IndianPricingEngine {

    static func calculate(
        items: [TaxableLineItem],
        buyerState: String,
        policy: PricingPolicySettings,
        regionalPrices: [RegionalPriceRule],
        taxRules: [IndianTaxRule]
    ) -> PricingComputation {
        let normalizedBuyer = normalizeState(buyerState)
        let normalizedBusiness = normalizeState(policy.businessState)
        let isIntraState = !normalizedBuyer.isEmpty && normalizedBuyer == normalizedBusiness

        var subtotal = 0.0
        var cgst = 0.0
        var sgst = 0.0
        var igst = 0.0
        var cess = 0.0
        var additional = 0.0
        var computedItems: [PricingComputation.ComputedLineItem] = []

        for item in items {
            let effectiveUnit = effectivePrice(
                basePrice: item.baseUnitPrice,
                productId: item.productId,
                buyerState: normalizedBuyer,
                regionalPrices: regionalPrices
            )
            let taxableValue = effectiveUnit * Double(item.quantity)
            subtotal += taxableValue

            let rule = matchedTaxRule(for: item.goodsCategory, taxRules: taxRules)
            let gstRate = max(rule?.gstPercent ?? 18, 0) / 100
            let cessRate = max(rule?.cessPercent ?? 0, 0) / 100
            let additionalRate = max(rule?.additionalLevyPercent ?? 0, 0) / 100

            if isIntraState {
                cgst += taxableValue * gstRate / 2
                sgst += taxableValue * gstRate / 2
            } else {
                igst += taxableValue * gstRate
            }

            cess += taxableValue * cessRate
            additional += taxableValue * additionalRate

            computedItems.append(
                .init(
                    productId: item.productId,
                    unitPrice: round2(effectiveUnit),
                    quantity: item.quantity,
                    taxableValue: round2(taxableValue),
                    tax: round2((taxableValue * gstRate) + (taxableValue * cessRate) + (taxableValue * additionalRate))
                )
            )
        }

        return PricingComputation(
            subtotal: round2(subtotal),
            taxBreakdown: IndianTaxBreakdown(
                cgst: round2(cgst),
                sgst: round2(sgst),
                igst: round2(igst),
                cess: round2(cess),
                additionalLevy: round2(additional)
            ),
            lineItems: computedItems
        )
    }

    static func taxLabel(for buyerState: String, businessState: String) -> String {
        normalizeState(buyerState) == normalizeState(businessState) ? "CGST + SGST" : "IGST"
    }

    static func normalizeState(_ raw: String) -> String {
        let key = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if key.isEmpty { return "" }

        let aliases: [String: String] = [
            "mh": "maharashtra",
            "dl": "delhi",
            "ka": "karnataka",
            "tn": "tamil nadu",
            "gj": "gujarat",
            "up": "uttar pradesh",
            "wb": "west bengal",
            "tg": "telangana",
            "ts": "telangana",
            "ap": "andhra pradesh",
            "pb": "punjab",
            "hr": "haryana",
            "rj": "rajasthan",
            "kl": "kerala",
            "mp": "madhya pradesh",
            "ct": "chhattisgarh",
            "cg": "chhattisgarh",
            "br": "bihar",
            "jk": "jammu and kashmir",
            "jh": "jharkhand",
            "as": "assam",
            "or": "odisha",
            "od": "odisha",
            "uk": "uttarakhand",
            "ut": "uttarakhand",
            "ga": "goa"
        ]

        return aliases[key] ?? key
    }

    private static func effectivePrice(
        basePrice: Double,
        productId: UUID,
        buyerState: String,
        regionalPrices: [RegionalPriceRule]
    ) -> Double {
        guard !buyerState.isEmpty else { return basePrice }

        let rule = regionalPrices.first {
            $0.productId == productId &&
            $0.isActive &&
            normalizeState($0.regionState) == buyerState
        }
        return rule?.overridePrice ?? basePrice
    }

    private static func matchedTaxRule(
        for goodsCategory: String,
        taxRules: [IndianTaxRule]
    ) -> IndianTaxRule? {
        let normalizedCategory = goodsCategory.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if let exact = taxRules.first(where: {
            $0.isActive && $0.goodsCategory.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedCategory
        }) {
            return exact
        }

        return taxRules.first {
            $0.isActive && $0.goodsCategory.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "default"
        }
    }

    private static func round2(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
