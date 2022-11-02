// winner_collect.cdc
// Used to claim an item. Must meet reserve price.

import AuctionHouse  from 0xc748d23a9a804eb0
transaction(auction: Address, aid: UInt64)
{ 
    let aid          : UInt64
    let auctionHouse : &AuctionHouse.AuctionWallet{AuctionHouse.AuctionWalletPublic}
    
    prepare(signer: AuthAccount) {
        self.aid          = aid
        self.auctionHouse = getAccount(auction)
            .getCapability<&AuctionHouse.AuctionWallet{AuctionHouse.AuctionWalletPublic}>
            (AuctionHouse.auctionPublicPath)
            .borrow()!
    }

    execute {
        self.auctionHouse.item(self.aid)!.winnerCollect()
    }
}
