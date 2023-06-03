// get_display.cdc
// Return the MetadataViews of an Auction.

import MetadataViews from 0x1d7e57aa55817448
import AuctionHouse  from 0xc748d23a9a804eb0

pub fun main(auction: Address, aid: UInt64): {String: MetadataViews.Media} {    
    let auctionHouse = getAccount(auction)
        .getCapability<&AuctionHouse.AuctionWallet{AuctionHouse.AuctionWalletPublic}>
        (AuctionHouse.auctionPublicPath)
        .borrow()!

    let mRef = auctionHouse.item(aid) as &AuctionHouse.Auction{AuctionHouse.AuctionPublic}?
    let metadata = mRef!.getDisplay()

    return metadata
}