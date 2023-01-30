// close_auction.cdc
// Settles all auctions that have ended. Including Items, returning funds, etc.

import AuctionHouse from 0xc748d23a9a804eb0

transaction(auction: Address, aid: UInt64) {
    let auctionHouse : &AuctionHouse.AuctionWallet{AuctionHouse.AuctionWalletPublic}
    let aid: UInt64

    prepare(signer: AuthAccount) {
        self.auctionHouse = getAccount(auction)
            .getCapability<&AuctionHouse.AuctionWallet{AuctionHouse.AuctionWalletPublic}>
            (AuctionHouse.auctionPublicPath)
            .borrow()!
        
        self.aid = aid
    }

    execute {
        self.auctionHouse.closeAuction(self.aid)
        log("Auction Closed:".concat(self.aid.toString()))
    }
}
