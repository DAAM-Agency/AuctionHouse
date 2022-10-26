// but_it_now.cdc
// Used for direct purchases

import FungibleToken from 0xf233dcee88fe0abe
import FUSD          from 0x3c5959b568896393
import AuctionHouse  from 0x045a1763c93006ca
import DAAM          from 

transaction(auction: Address, aid: UInt64, bid: UFix64)
{
    let bidder          : Address
    let auctionHouse    : &AuctionHouse.AuctionWallet{AuctionHouse.AuctionWalletPublic}
    let fusdStoragePath : StoragePath
    let collection      : &{DAAM.CollectionPublic}
    let vaultRef        : &FUSD.Vault{FungibleToken.Provider}
    let aid             : UInt64
    let bid             : UFix64
    
    prepare(bidder: AuthAccount) {
        self.bidder = bidder.address
        self.fusdStoragePath = /storage/fusdVault
        self.vaultRef   = bidder.borrow<&FUSD.Vault{FungibleToken.Provider}>(from: self.fusdStoragePath)!
        self.collection = bidder.borrow<&{DAAM.CollectionPublic}>(from: DAAM.collectionStoragePath)!
        self.auctionHouse = getAccount(auction)
            .getCapability<&AuctionHouse.AuctionWallet{AuctionHouse.AuctionWalletPublic}>
            (AuctionHouse.auctionPublicPath)
            .borrow()!

        self.aid = aid
        self.bid = bid
    }

    execute {
        let amount <- self.vaultRef.withdraw(amount: self.bid)!
        self.auctionHouse.item(self.aid)!.buyItNow(bidder: self.bidder, amount: <-amount)!
    }
}
