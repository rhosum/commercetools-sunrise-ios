//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

extension ProductProjection {

    func displayVariant(country: String? = Customer.currentCountry, currency: String? = Customer.currentCurrency, customerGroup: Reference<CustomerGroup>? = Customer.customerGroup) -> ProductVariant? {
        return displayVariants(country: country, currency: currency, customerGroup: customerGroup).first
    }

    func displayVariants(country: String? = Customer.currentCountry, currency: String? = Customer.currentCurrency, customerGroup: Reference<CustomerGroup>? = Customer.customerGroup) -> [ProductVariant] {
        var displayVariants = [ProductVariant]()
        let now = Date()
        if let matchingVariant = allVariants.first(where: { $0.isMatchingVariant == true }) {
            displayVariants.append(matchingVariant)
        }
        displayVariants += allVariants.filter({ !displayVariants.contains($0) && $0.prices?.filter({ $0.validFrom != nil && $0.validFrom! < now && $0.validUntil != nil
            && $0.validUntil! > now && $0.country == country && $0.customerGroup?.id == customerGroup?.id && $0.value.currencyCode == currency }).count ?? 0 > 0 })
        if customerGroup != nil {
            displayVariants += allVariants.filter({ !displayVariants.contains($0) && $0.prices?.filter({ $0.validFrom != nil && $0.validFrom! < now && $0.validUntil != nil
                && $0.validUntil! > now && $0.country == country && $0.value.currencyCode == currency }).count ?? 0 > 0 })
            displayVariants += allVariants.filter({ !displayVariants.contains($0) && $0.prices?.filter({ $0.country == country && $0.value.currencyCode == currency }).count ?? 0 > 0 })
        }
        displayVariants += allVariants.filter({ !displayVariants.contains($0) && $0.prices?.filter({ $0.country == country && $0.customerGroup?.id == customerGroup?.id && $0.value.currencyCode == currency }).count ?? 0 > 0 })
        if let mainVariantWithPrice = mainVariantWithPrice, displayVariants.isEmpty {
            displayVariants.append(mainVariantWithPrice)
        }
        return displayVariants
    }

    /// The `masterVariant` if it has price, or  the first from `variants` with price.
    var mainVariantWithPrice: ProductVariant? {
        if let prices = masterVariant.prices, prices.count > 0 {
            return masterVariant
        } else {
            return variants.filter({ ($0.prices?.count ?? 0) > 0 }).first
        }
    }
}
