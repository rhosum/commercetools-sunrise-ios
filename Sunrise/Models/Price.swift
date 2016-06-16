//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct Price: Mappable {

    // MARK: - Properties

    var value: Money?
    var country: String?
    var customerGroup: [String: AnyObject]?
    var channel: [String: AnyObject]?
    var validFrom: NSDate?
    var validUntil: NSDate?
    var discounted: DiscountedPrice?

    init?(_ map: Map) {}

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        value              <- map["value"]
        country            <- map["country"]
        customerGroup      <- map["customerGroup"]
        channel            <- map["channel"]
        validFrom          <- (map["validFrom"], DateTransform())
        validUntil         <- (map["validUntil"], DateTransform())
        discounted         <- map["discounted"]
    }

}