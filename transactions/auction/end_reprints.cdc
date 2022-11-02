// end_reprints.cdc
// to toggle reprints to OFF.

import AuctionHouse from 0xc748d23a9a804eb0

transaction(aid: UInt64) {
    let aid    : UInt64
    let auctionHouse : &AuctionHouse.AuctionWallet

    prepare(signer: AuthAccount) {
        self.aid          = aid
        self.auctionHouse = signer.borrow<&AuctionHouse.AuctionWallet>(from: AuctionHouse.auctionStoragePath)!
    }

    execute {
        self.auctionHouse.endReprints(auctionID: self.aid)
        log("Ending Reprints")
    }
}
