// item_info.cdc
// Return item info of auction

import DAAM          from 0x7db4d10c78bad30a
import AuctionHouse  from 0xc748d23a9a804eb0

pub fun main(auction: Address, aid: UInt64): DAAM.MetadataHolder? {    
    let auctionHouse = getAccount(auction)
        .getCapability<&AuctionHouse.AuctionWallet{AuctionHouse.AuctionWalletPublic}>
        (AuctionHouse.auctionPublicPath)
        .borrow()!

    let mRef = auctionHouse.item(aid) as &AuctionHouse.Auction{AuctionHouse.AuctionPublic}?
    let metadata = mRef!.itemInfo()

    return metadata
}