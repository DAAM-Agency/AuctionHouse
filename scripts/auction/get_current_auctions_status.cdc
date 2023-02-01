// get_current_auctions_status.cdc
// Return all auctions

import AuctionHouse from 0xc748d23a9a804eb0

pub fun main(status: Bool?): {Address : [UInt64] } {    
    return AuctionHouse.getCurrentAuctionsStatus(status) // Get auctioneers and AIDs {Address : [AID]}
}