// get_history.cdc
// Return all (nil) or spcific history


//import DAAM from 0x7db4d10c78bad30a
import AuctionHouse from 0xc748d23a9a804eb0

pub fun main(mid: UInt64?): {UInt64 : {UInt64: AuctionHouse.SaleHistory}}? { // {Creator { MID : {TokenID:SaleHistory} } }
    return AuctionHouse.getHistory(mid: mid) // Get SaleHostory {TokenID : SaleHstory}
}