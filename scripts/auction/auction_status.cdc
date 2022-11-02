// auction_status.cdc
// Gets auction status: nil = not started, true = ongoing, false = ended

import AuctionHouse  from 0xc748d23a9a804eb0

pub fun main(auction: Address, auctionID: UInt64): Bool? {    
    let auctionHouse = getAccount(auction)
        .getCapability<&AuctionHouse.AuctionWallet{AuctionHouse.AuctionWalletPublic}>
        (AuctionHouse.auctionPublicPath)
        .borrow()!

    let mRef = auctionHouse.item(auctionID) as &AuctionHouse.Auction{AuctionHouse.AuctionPublic}?
    return mRef!.getStatus()
}
