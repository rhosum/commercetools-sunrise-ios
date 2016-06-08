//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Quick
import Nimble
import ObjectMapper
import ReactiveCocoa
import Result
@testable import Sunrise

class CartViewModelSpec: QuickSpec {

    override func spec() {
        describe("CartViewModel") {
            var cartViewModel: CartViewModel!

            beforeEach {
                let path = NSBundle.currentTestBundle!.pathForResource("cart", ofType: "json")!
                let cartJSON = try! NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
                let cart = Mapper<Cart>().map(cartJSON)!

                cartViewModel = CartViewModel()
                cartViewModel.cart.value = cart
            }

            it("has the correct number of cells line items + summary") {
                expect(cartViewModel.numberOfRowsInSection(0)).to(equal(4))
            }

            it("has the correct number of items") {
                expect(cartViewModel.numberOfItems.value).to(equal("3"))
            }

            context("retrieving data for the first cell") {
                let indexPath = NSIndexPath(forRow: 0, inSection: 0)

                it("product name is properly extracted") {
                    expect(cartViewModel.lineItemNameAtIndexPath(indexPath)).to(equal("Dress “Olivia“ Polo Ralph Lauren blue"))
                }

                it("imageUrl selected from variant") {
                    expect(cartViewModel.lineItemImageUrlAtIndexPath(indexPath)).to(equal("https://s3-eu-west-1.amazonaws.com/commercetools-maximilian/products/078990_1_medium.jpg"))
                }

                it("sku is properly extracted") {
                    expect(cartViewModel.lineItemSkuAtIndexPath(indexPath)).to(equal("M0E20000000DVL9"))
                }

                it("has correct price before discount") {
                    expect(cartViewModel.lineItemPriceAtIndexPath(indexPath)).to(equal("€87.50"))
                }

                it("has correct discounted price") {
                    expect(cartViewModel.lineItemOldPriceAtIndexPath(indexPath)).to(equal("€175.00"))
                }

                it("has correct quantity") {
                    expect(cartViewModel.lineItemQuantityAtIndexPath(indexPath)).to(equal("2"))
                }

                it("has correct total item price") {
                    expect(cartViewModel.lineItemTotalPriceAtIndexPath(indexPath)).to(equal("€175.00"))
                }
            }

            context("retrieving data for the second cell") {
                let indexPath = NSIndexPath(forRow: 1, inSection: 0)

                it("product name is properly extracted") {
                    expect(cartViewModel.lineItemNameAtIndexPath(indexPath)).to(equal("Pumps ”Flex” Michael Kors red"))
                }

                it("imageUrl selected from variant") {
                    expect(cartViewModel.lineItemImageUrlAtIndexPath(indexPath)).to(equal("https://s3-eu-west-1.amazonaws.com/commercetools-maximilian/products/073017_1_medium.jpg"))
                }

                it("sku is properly extracted") {
                    expect(cartViewModel.lineItemSkuAtIndexPath(indexPath)).to(equal("M0E20000000DMV1"))
                }

                it("has correct item price") {
                    expect(cartViewModel.lineItemPriceAtIndexPath(indexPath)).to(equal("€137.50"))
                }

                it("doesn't show discount when there's no any") {
                    expect(cartViewModel.lineItemOldPriceAtIndexPath(indexPath)).to(equal(""))
                }

                it("has correct quantity") {
                    expect(cartViewModel.lineItemQuantityAtIndexPath(indexPath)).to(equal("1"))
                }

                it("has correct total item price") {
                    expect(cartViewModel.lineItemTotalPriceAtIndexPath(indexPath)).to(equal("€127.50"))
                }
            }
        }
    }
}