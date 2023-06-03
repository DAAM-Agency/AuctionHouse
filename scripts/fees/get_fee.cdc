// get_fee.cdc
// Gets the fee for a Metadata ID

import AuctionHouse from 0xc748d23a9a804eb0

pub fun main(mid: UInt64): UFix64? {
    return AuctionHouse.getFee(mid: mid) // 1.0 represents 100%
}
// nil = MID does not exist
