// check_auction_wallet.cdc
// Checks to see if there is an Auction Wallet

import NonFungibleToken from 0x1d7e57aa55817448
import AuctionHouse     from 0xc748d23a9a804eb0

pub fun main(auction: Address): Bool {
    let auctionHouse = getAccount(auction)
        .getCapability<&AuctionHouse.AuctionWallet{AuctionHouse.AuctionWalletPublic}>
        (AuctionHouse.auctionPublicPath)
        .borrow()
        
    return auctionHouse != nil
}
