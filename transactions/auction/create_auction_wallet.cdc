// create_auction_wallet.cdc
// Create an auction wallet. Used to store auctions.

import AuctionHouse from 0xc748d23a9a804eb0

transaction() {
    let signer: AuthAccount

    prepare(signer: AuthAccount) {
        self.signer = signer
    }

    execute {
        if self.signer.borrow<&AuctionHouse.AuctionWallet>(from: AuctionHouse.auctionStoragePath) == nil {
            let old <- self.signer.load<@AnyResource>(from: AuctionHouse.auctionStoragePath)
            let auctionWallet <- AuctionHouse.createAuctionWallet()
            self.signer.save<@AuctionHouse.AuctionWallet> (<- auctionWallet, to: AuctionHouse.auctionStoragePath)
            self.signer.link<&AuctionHouse.AuctionWallet{AuctionHouse.AuctionWalletPublic}>
                (AuctionHouse.auctionPublicPath, target: AuctionHouse.auctionStoragePath)
            destroy old
            log("Auction House Created, you can now have Auctions.")
        }
        else {
            log("You already have an Auction House.")
        }
    }    
}
