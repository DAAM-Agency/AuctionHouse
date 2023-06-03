// get_current_auctions.cdc
// Return all auctions

import AuctionHouse from 0xc748d23a9a804eb0

pub fun main(): {Address : [UInt64] } {    
    return AuctionHouse.getCurrentAuctions() // Get auctioneers and AIDs {Address : [AID]}
}