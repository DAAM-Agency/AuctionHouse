// get_current_auctions.cdc
// Return all auctions

import AuctionHouse from 0x045a1763c93006ca

pub fun main(): {Address : [UInt64] } {    
    return AuctionHouse.getCurrentAuctions() // Get auctioneers and AIDs {Address : [AID]}
}