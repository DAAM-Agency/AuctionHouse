// withdraw_bid.cdc
// Used to withdraw bid made on item. Must not be lead bidder

import FungibleToken from 0xf233dcee88fe0abe
import FUSD          from 0x3c5959b568896393
import AuctionHouse  from 0x045a1763c93006ca

transaction(auction: Address, aid: UInt64)
{
    let bidder          : AuthAccount
    let aid             : UInt64
    let auctionHouse    : &AuctionHouse.AuctionWallet{AuctionHouse.AuctionWalletPublic}
    let fusdStoragePath : StoragePath
    let vaultRef        : &FUSD.Vault{FungibleToken.Receiver}
    
    prepare(bidder: AuthAccount) {
        self.bidder          = bidder
        self.aid             = aid
        self.fusdStoragePath = /storage/fusdVault
        self.auctionHouse = getAccount(auction)
            .getCapability<&AuctionHouse.AuctionWallet{AuctionHouse.AuctionWalletPublic}>
            (AuctionHouse.auctionPublicPath)
            .borrow()!
        self.vaultRef = bidder.borrow<&FUSD.Vault{FungibleToken.Receiver}>(from: self.fusdStoragePath)!
    }

    execute {
        let amount <- self.auctionHouse.item(self.aid)!.withdrawBid(bidder: self.bidder)!
        self.vaultRef.deposit(from: <- amount)
    }
}
