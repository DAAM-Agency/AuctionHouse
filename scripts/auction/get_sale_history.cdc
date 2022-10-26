// get_sale_history.cdc
// Return all (nil) or spcific sale history of TokenID


//import DAAM from 0x7db4d10c78bad30a
import AuctionHouse from 0x045a1763c93006ca

pub fun main(id: UInt64?): {UInt64: AuctionHouse.SaleHistory}?  {    
    return AuctionHouse.getSaleHistory(id: id) // Get SaleHostory {TokenID : SaleHstory}
}