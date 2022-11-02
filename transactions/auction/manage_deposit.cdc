// manage_auction.cdc
// Used to Approve / Disapprove an Auction made by an Agent

import AuctionHouse  from 0xc748d23a9a804eb0

transaction(aid: UInt64, approve: Bool)
{
    let aid          : UInt64
    let approve      : Bool
    let auctionHouse : &AuctionHouse.AuctionWallet
    
    prepare(auctioneer: AuthAccount) {
        self.aid          = aid
        self.approve      = approve
        self.auctionHouse = auctioneer.borrow<&AuctionHouse.AuctionWallet>(from: AuctionHouse.auctionStoragePath)!
    }

    execute {
        self.auctionHouse.agentAuction(auctionID: self.aid, approve: self.approve)
    }
}
 