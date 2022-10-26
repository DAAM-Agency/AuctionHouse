// get_direct.history.cdc
// Return all (nil) or spcific history

import MetadataViews from 0x1d7e57aa55817448
import DAAM          from 0x7db4d10c78bad30a
import AuctionHouse  from 0x045a1763c93006ca

pub struct DirectHistory {
    pub let mid : UInt64
	pub let name: String
	pub let file: {String: MetadataViews.Media}
	pub let creator: Address
	pub let royalty: MetadataViews.Royalties
	pub var collection : [DAAM.NFTCollectionDisplay] // contains feature
	pub var saleHistory: {UInt64: AuctionHouse.SaleHistory}//[AuctionHouse.SaleHistoryEntry]

    init(creator:Address, mid: UInt64) {
        let metadataRef = getAccount(creator)
			.getCapability<&DAAM.MetadataGenerator{DAAM.MetadataGeneratorPublic}>(DAAM.metadataPublicPath).borrow()!
		let metadata = metadataRef.viewMetadata(mid: mid)!
		
		self.mid  = metadata.mid!
        self.name = metadata.edition.name!
        self.file = metadataRef.getFile(mid: self.mid)!
        self.creator = metadata.creatorInfo!.creator!
		self.royalty = DAAM.getRoyalties(mid: self.mid)

        let collectionRef = getAccount(creator)
			.getCapability<&{DAAM.CollectionPublic}>(DAAM.collectionPublicPath).borrow()!    
        let collections   = collectionRef.getCollection()

        self.collection  = []
        for c in collections {
            if c.mid.containsKey(self.mid) {
				self.collection.append(c) // adding collection
			}
        }

        let history = AuctionHouse.getHistory(mid: self.mid)!
		let saleHistory = history[self.mid]!
		self.saleHistory = saleHistory
    }
}

pub fun main(creator: Address, mid: UInt64): DirectHistory { // {Creator { MID : {TokenID:SaleHistory} } }
	return DirectHistory(creator: creator, mid: mid)
}