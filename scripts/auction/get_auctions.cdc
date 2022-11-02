// get_auctions.cdc
// Return all auctions in Auction Wallet. Identified by AuctionIDs

import AuctionHouse  from 0xc748d23a9a804eb0

pub fun main(auction: Address): [UInt64] {    
    let auctionHouse = getAccount(auction)
        .getCapability<&AuctionHouse.AuctionWallet{AuctionHouse.AuctionWalletPublic}>
        (AuctionHouse.auctionPublicPath)
        .borrow()!
    
    return auctionHouse.getAuctions()
}