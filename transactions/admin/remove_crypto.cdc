// remove_crypto.cdc
// Removes Crypto selection from AuctionHouse

import DAAM         from 0x7db4d10c78bad30a
import AuctionHouse from 0xc748d23a9a804eb0


transaction(crypto: String)
{
    let crypto : String
    let admin  : &DAAM.Admin

    prepare(admin: AuthAccount) {
       
        self.crypto = crypto
        self.admin  = admin.borrow<&DAAM.Admin>(from: DAAM.adminStoragePath)!
    }

    execute {
        AuctionHouse.removeCrypto(crypto: self.crypto, permission: self.admin)
    }
}
