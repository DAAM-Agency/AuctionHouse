// get_creator_history.cdc
// Return all (nil) or spcific creator history

import DAAM         from 0x7db4d10c78bad30a
import AuctionHouse from 0x045a1763c93006ca

pub fun main(creator: Address): {UInt64 : {UInt64: AuctionHouse.SaleHistory}} { // {MID : {TokenID:SaleHistory} }
    let creatorMIDs = DAAM.getCreatorMIDs(creator: creator)
    var history: {UInt64 : {UInt64:AuctionHouse.SaleHistory} } = {}
    for mid in creatorMIDs! {
        let historyEntry = AuctionHouse.getHistory(mid: mid)
        if historyEntry == nil { continue }
        history.insert(key: mid, historyEntry![mid]! )
    }
    return history
}