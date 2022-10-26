// agent_deposit.cdc
// Used for Agent deposit Auction for Creator Approval/Disapproval

import NonFungibleToken from 0x1d7e57aa55817448
import DAAM             from 0x7db4d10c78bad30a
import FUSD             from 0x3c5959b568896393
import AuctionHouse     from 0x045a1763c93006ca

transaction(creator: Address, mid: UInt64, start: UFix64, length: UFix64, isExtended: Bool, extendedTime: UFix64, /*vault: @FungibleToken.Vault,*/
    incrementByPrice: Bool, incrementAmount: UFix64, startingBid: UFix64?, reserve: UFix64, buyNow: UFix64, reprintSeries: UInt64?)
{
    let auctionHouse     : &AuctionHouse.AuctionWallet{AuctionHouse.AuctionWalletPublic}
    let metadataGenerator: Capability<&DAAM.MetadataGenerator{DAAM.MetadataGeneratorMint}>
    let agent       : &DAAM.Admin{DAAM.Agent}
    let mid         : UInt64
    let start       : UFix64
    let length      : UFix64
    let isExtended  : Bool
    let extendedTime: UFix64
    let incrementByPrice: Bool
    let incrementAmount : UFix64
    let startingBid     : UFix64?
    let reserve         : UFix64
    let buyNow          : UFix64
    let reprintSeries   : UInt64?

    prepare(agent: AuthAccount) {
        self.agent = agent.borrow<&DAAM.Admin{DAAM.Agent}>(from: DAAM.adminStoragePath)!

        self.metadataGenerator  = getAccount(creator)
            .getCapability<&DAAM.MetadataGenerator{DAAM.MetadataGeneratorMint}>
            (DAAM.metadataPublicPath)

        self.auctionHouse = getAccount(creator)
            .getCapability<&AuctionHouse.AuctionWallet{AuctionHouse.AuctionWalletPublic}>
            (AuctionHouse.auctionPublicPath)
            .borrow()!
        
        self.mid              = mid
        self.start            = start
        self.length           = length
        self.isExtended       = isExtended
        self.extendedTime     = extendedTime
        self.incrementByPrice = incrementByPrice
        self.incrementAmount  = incrementAmount
        self.startingBid      = startingBid
        self.reserve          = reserve
        self.buyNow           = buyNow
        self.reprintSeries    = reprintSeries
    }

    execute {
        let vault <- FUSD.createEmptyVault()

        let aid = self.auctionHouse.deposit(agent: self.agent, metadataGenerator: self.metadataGenerator, mid: self.mid, start: self.start, length: self.length,
        isExtended: self.isExtended, extendedTime: self.extendedTime, vault:<-vault, incrementByPrice: self.incrementByPrice, incrementAmount: self.incrementAmount,
        startingBid: self.startingBid, reserve: self.reserve, buyNow: self.buyNow, reprintSeries: self.reprintSeries)
        
        log("Deposited AID: ".concat(aid.toString()))
    }
}
