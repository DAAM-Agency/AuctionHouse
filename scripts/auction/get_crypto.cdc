// get_crypto.cdc
// Return all accepted Cryptos/Tokens in AuctionHouse

import AuctionHouse from 0xc748d23a9a804eb0

pub fun main(): [String] {    
    return AuctionHouse.getCrypto()
}