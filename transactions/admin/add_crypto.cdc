// add_crypto.cdc
// Returns all accepted Cryptos from AuctionHouse

import FungibleToken from 0xf233dcee88fe0abe
import FUSD          from 0x3c5959b568896393 
import DAAM          from 0x7db4d10c78bad30a
import AuctionHouse  from 0xc748d23a9a804eb0

transaction()
{
    let admin : &DAAM.Admin

    prepare(admin: AuthAccount) {
       
        self.admin  = admin.borrow<&DAAM.Admin>(from: DAAM.adminStoragePath)!
    }

    execute {
        let vault <-FUSD.createEmptyVault()
        AuctionHouse.addCrypto(crypto: &vault as &FungibleToken.Vault, path: self.path, permission: self.admin)
        destroy vault
    }
}
 