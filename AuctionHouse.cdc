// auction.cdc
// by Ami Rajpal, 2021 // DAAM Agency

import FungibleToken    from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews    from 0x1d7e57aa55817448
import DAAM             from 0x7db4d10c78bad30a

pub contract AuctionHouse {
    // Event
    pub event AuctionCreated(auctionID: UInt64, start: UFix64)   // Auction has been created. 
    pub event AuctionClosed(auctionID: UInt64)    // Auction has been finalized and has been removed.
    pub event AuctionEnded(auctionID: UInt64, time: UFix64)   // Auction has ended, time is Unix timestamp. 
    pub event AuctionCancelled(auctionID: UInt64) // Auction has been canceled
    pub event ItemReturned(auctionID: UInt64, seller: Address)     // Auction has ended and the Reserve price was not met.
    pub event BidMade(auctionID: UInt64, bidder: Address) // Bid has been made on an Item
    pub event BidWithdrawn(auctionID: UInt64, bidder: Address)                // Bidder has withdrawn their bid
    pub event ItemWon(auctionID: UInt64, winner: Address, tokenID: UInt64, amount: UFix64, sale: SaleHistoryEntry)  // Item has been Won in an auction
    pub event BuyItNow(auctionID: UInt64, winner: Address, amount: UFix64) // Buy It Now has been completed
    pub event FundsReturned(auctionID: UInt64)   // Funds have been returned accordingly

    // Path for Auction Wallet
    pub let auctionStoragePath: StoragePath
    pub let auctionPublicPath : PublicPath

    // Variables; *Note: Do not confuse (Token)ID with MID
    access(contract) var metadataGen     : {UInt64 : Capability<&DAAM.MetadataGenerator{DAAM.MetadataGeneratorMint}> }
    access(contract) var auctionCounter  : UInt64               // Incremental counter used for AID (Auction ID)
    access(contract) var currentAuctions : {Address : [UInt64]} // {Auctioneer Address : [list of Auction IDs (AIDs)] }  // List of all auctions
    access(contract) var fee             : {UInt64 : UFix64}    // { MID : Fee precentage, 1.025 = 0.25% }
    access(contract) var agencyFirstSale : {UInt64 : UFix64}    // { MID : Agency fist sale precentage}
    access(contract) var saleHistory     : {UInt64 : SaleHistory} // Stores sale history using the id as a center point of search. {TokenID : SaleHistory} }
    access(contract) var history         : {UInt64 : {UInt64 : SaleHistory} } // Stores history using the mid as a center point of search. { MID : {TokenID : SaleHistory} }
    access(contract) var crypto          : {String : PublicPath}    // Stores accepted Cryptos { A.Address.Vault : PublicPath of Crypto}

/************************************************************************/
pub struct SaleHistoryEntry {
    pub let id      : UInt64
    pub let auction : AuctionHolder
    pub let price   : UFix64
    pub let from    : Address
    pub let to      : Address
    pub let timestamp : UFix64

    init(id: UInt64, auctionHolder: AuctionHolder, price: UFix64, from: Address, to: Address) {
        self.id      = id
        self.auction = auctionHolder 
        self.price   = price
        self.from    = from
        self.to      = to
        self.timestamp = getCurrentBlock().timestamp
    }
}
/************************************************************************/
pub struct SaleHistory {
    pub let metadata    : DAAM.MetadataHolder
    pub var saleHistory : [SaleHistoryEntry]

    init(metadata: DAAM.MetadataHolder) {
        self.metadata = metadata
        self.saleHistory = []
    }
    
    access(contract) fun add(_ history: SaleHistoryEntry) {
        self.saleHistory.append(history)
    }
}
/************************************************************************/
pub struct AuctionHolder {
        pub let status        : Bool? // nil = auction not started or no bid, true = started (with bid), false = auction ended
        pub let auctionID     : UInt64       // Auction ID number. Note: Series auctions keep the same number. 
        pub let creatorInfo   : DAAM.CreatorInfo
        pub let mid           : UInt64       // collect Metadata ID
        pub let start         : UFix64       // timestamp
        pub let length        : UFix64   // post{!isExtended && length == before(length)}
        pub let isExtended    : Bool     // true = Auction extends with every bid.
        pub let extendedTime  : UFix64   // when isExtended=true and extendedTime = 0.0. This is equal to a direct Purchase. // Time of Extension.
        pub let leader        : Address? // leading bidder
        pub let minBid        : UFix64?  // minimum bid
        pub let startingBid   : UFix64?  // the starting bid od an auction. Nil = No Bidding. Direct Purchase
        pub let reserve       : UFix64   // the reserve. must be sold at min price.
        pub let fee           : UFix64   // the fee
        pub let price         : UFix64   // original price
        pub let buyNow        : UFix64   // buy now price (original price + AuctionHouse.fee)
        pub let reprintSeries : UInt64?  // Active Series Minter (if series)
        pub let auctionLog    : {Address: UFix64}    // {Bidders, Amount} // Log of the Auction
        pub let requiredCurrency: Type

        init(
            _ status:Bool?, _ auctionID:UInt64, _ creator: DAAM.CreatorInfo, _ mid: UInt64, _ start: UFix64, _ length: UFix64,
            _ isExtended: Bool, _ extendedTime: UFix64, _ leader: Address?, _ minBid: UFix64?, _ startingBid: UFix64?,
            _ reserve: UFix64, _ fee: UFix64, _ price: UFix64, _ buyNow: UFix64, _ reprintSeries: UInt64?,
            _ auctionLog: {Address: UFix64}, _ requiredCurrency: Type
            )
            {
                self.status        = status// nil = auction not started or no bid, true = started (with bid), false = auction ended
                self.auctionID     = auctionID       // Auction ID number. Note: Series auctions keep the same number. 
                self.creatorInfo   = creator 
                self.mid           = mid       // collect Metadata ID
                self.start         = start       // timestamp
                self.length        = length   // post{!isExtended && length == before(length)}
                self.isExtended    = isExtended     // true = Auction extends with every bid.
                self.extendedTime  = extendedTime   // when isExtended=true and extendedTime = 0.0. This is equal to a direct Purchase. // Time of Extension.
                self.leader        = leader // leading bidder
                self.minBid        = minBid  // minimum bid
                self.startingBid   = startingBid // the starting bid od an auction. Nil = No Bidding. Direct Purchase
                self.reserve       = reserve   // the reserve. must be sold at min price.
                self.fee           = fee   // the fee
                self.price         = price   // original price
                self.buyNow        = buyNow   // buy now price (original price + AuctionHouse.fee)
                self.reprintSeries = reprintSeries     // Active Series Minter (if series)
                self.auctionLog    = auctionLog    // {Bidders, Amount} // Log of the Auction
                self.requiredCurrency = requiredCurrency
            }
}
/************************************************************************/
    pub resource interface AuctionWalletPublic {
        // Public Interface for AuctionWallet
        pub fun getAuctions()     : [UInt64]                 // MIDs in Auctions
        pub fun getAgentAuctions(): [UInt64]                 // Returns the Auctions deposited by Agent 
        pub fun item(_ id: UInt64): &Auction{AuctionPublic}? // item(Token ID) will return the apporiate auction.
        pub fun closeAuctions()                              // Close all finilise auctions
        pub fun closeAuction(_ auctionID: UInt64)            // Close auction by AID

        pub fun deposit(agent: &DAAM.Admin{DAAM.Agent}, metadataGenerator: Capability<&DAAM.MetadataGenerator{DAAM.MetadataGeneratorMint}>, mid: UInt64, start: UFix64,
            length: UFix64, isExtended: Bool, extendedTime: UFix64, vault: @FungibleToken.Vault, incrementByPrice: Bool, incrementAmount: UFix64,
            startingBid: UFix64?, reserve: UFix64, buyNow: UFix64, reprintSeries: UInt64?): UInt64
    }
/************************************************************************/
    pub resource AuctionWallet: AuctionWalletPublic {
        priv var currentAuctions: @{UInt64 : Auction}  // { AuctionID : Auction }
        priv var approveAuctions: @{UInt64 : Auction}

        init() {  // Auction Resources are stored here. The Auctions themselves.
            self.currentAuctions <- {}
            self.approveAuctions <- {}
        }      

        // createAuction: An Original Auction is defined as a newly minted NFT.
        // MetadataGenerator: Reference to Metadata or nil when nft argument is enterd
        // nft: DAAM.NFT or nil when MetadataGenerator argument is entered
        // id: DAAM Metadata ID or Token ID depenedent whether nft or MetadataGenerator is entered
        // start: Enter UNIX Flow Blockchain Time
        // length: Length of auction
        // isExtended: if the auction lenght is to be an Extended Auction
        // extendedTime: The amount of time the extension is to be.
        // incrementByPrice: increment by fixed amount or percentage. True = fixed amount, False = Percentage
        // incrementAmount: the increment value. when incrementByPrice is true, the minimum bid is increased by this amount.
        //                  when False, the minimin bid is increased by that Percentage. Note: 1.0 = 100%
        // startingBid: the initial price. May not be 0.0
        // reserve: The minimum price that must be meet
        // buyNow: To amount to purchase an item directly. Note: 0.0 = OFF
        // reprintSeries: to duplicate the current auction, with a reprint (Next Mint os Series)
        // *** new is defines as "never sold", age is not a consideration. ***
        pub fun createAuction(metadataGenerator: Capability<&DAAM.MetadataGenerator{DAAM.MetadataGeneratorMint}>?, nft: @DAAM.NFT?, id: UInt64, start: UFix64,
            length: UFix64, isExtended: Bool, extendedTime: UFix64, vault: @FungibleToken.Vault, incrementByPrice: Bool, incrementAmount: UFix64,
            startingBid: UFix64?, reserve: UFix64, buyNow: UFix64, reprintSeries: UInt64?): UInt64
        {
            let auction <- self.createAuctionResource(metadataGenerator: metadataGenerator, nft: <-nft, id: id, start: start, length: length, isExtended: isExtended,
                extendedTime: extendedTime, vault: <-vault, incrementByPrice: incrementByPrice, incrementAmount: incrementAmount, startingBid: startingBid,
                reserve: reserve, buyNow: buyNow, reprintSeries: reprintSeries)            
            // Add Auction
            let aid = auction.auctionID // Auction ID
            let oldAuction <- self.currentAuctions.insert(key: aid, <- auction!) // Store Auction
            destroy oldAuction // destroy placeholder

            AuctionHouse.currentAuctions.insert(key: self.owner?.address!, self.currentAuctions.keys) // Update Current Auctions
            return aid
        }

        pub fun deposit(agent: &DAAM.Admin{DAAM.Agent}, metadataGenerator: Capability<&DAAM.MetadataGenerator{DAAM.MetadataGeneratorMint}>, mid: UInt64, start: UFix64,
            length: UFix64, isExtended: Bool, extendedTime: UFix64, vault: @FungibleToken.Vault, incrementByPrice: Bool, incrementAmount: UFix64,
            startingBid: UFix64?, reserve: UFix64, buyNow: UFix64, reprintSeries: UInt64?): UInt64
        {
            pre { DAAM.isAgent(agent.grantee) == true : "Not a DAAM Agent." }

            let metadataRef = metadataGenerator!.borrow()! as &DAAM.MetadataGenerator{DAAM.MetadataGeneratorMint} // Get MetadataHolder
            let creatorAgent   = metadataRef.viewMetadata(mid : mid)!.creatorInfo.agent
            assert(agent.grantee == creatorAgent, message: "You are not a DAAM Agent.")
            
            let creator = metadataRef.viewMetadata(mid : mid)!.creatorInfo.creator
            let auction <- self.createAuctionResource(metadataGenerator:metadataGenerator, nft:nil, id:mid, start:start, length:length,
                isExtended:isExtended, extendedTime:extendedTime, vault:<-vault, incrementByPrice:incrementByPrice, incrementAmount:incrementAmount,
                startingBid:startingBid, reserve:reserve, buyNow: buyNow, reprintSeries:reprintSeries)
            let aid = auction.auctionID! // Auction ID           

            let old <- self.approveAuctions.insert(key: aid, <- auction) // Update Current Auctions
            destroy old
            return aid
        }

        pub fun agentAuction(auctionID: UInt64, approve: Bool) {
            pre { self.approveAuctions.containsKey(auctionID) : "AID does not exist." }
            // set to Approve, regardless
            let removed <- self.approveAuctions.remove(key: auctionID)!
            let old <- self.currentAuctions.insert(key: auctionID, <- removed)
            destroy old
            // If (dis)approve (false) cancel Auction
            if !approve {
                self.cancelAuction(auctionID: auctionID)
            } else {
                AuctionHouse.currentAuctions.insert(key: self.owner?.address!, self.currentAuctions.keys) // Update Current Auctions
            }
        }

        priv fun createAuctionResource(metadataGenerator: Capability<&DAAM.MetadataGenerator{DAAM.MetadataGeneratorMint}>?, nft: @DAAM.NFT?, id: UInt64, start: UFix64,
            length: UFix64, isExtended: Bool, extendedTime: UFix64, vault: @FungibleToken.Vault, incrementByPrice: Bool, incrementAmount: UFix64,
            startingBid: UFix64?, reserve: UFix64, buyNow: UFix64, reprintSeries: UInt64?): @Auction
        {
            pre {
                (metadataGenerator == nil && nft != nil) || (metadataGenerator != nil && nft == nil) : "You can not enter a Metadata and NFT."
                self.validToken(vault: &vault as &FungibleToken.Vault)       : "We do not except this Token."
            }
            
            var auction: @Auction? <- nil
            // Is Metadata, not NFT
            if metadataGenerator != nil {
                assert(DAAM.getCopyright(mid: id) != DAAM.CopyrightStatus.FRAUD, message: "This submission has been flaged for Copyright Issues.")
                assert(DAAM.getCopyright(mid: id) != DAAM.CopyrightStatus.CLAIM, message: "This submission has been flaged for a Copyright Claim.")

                AuctionHouse.metadataGen.insert(key: id, metadataGenerator!) // add access to Creators' Metadata
                let metadataRef = metadataGenerator!.borrow()! as &DAAM.MetadataGenerator{DAAM.MetadataGeneratorMint} // Get MetadataHolder
                let minterAccess <- AuctionHouse.minterAccess(mid: id)
                let metadata <-! metadataRef.generateMetadata(minter: <- minterAccess)      // Create MetadataHolder
                // Create Auctions
                let old <- auction <- create Auction(metadata: <-metadata!, nft: nil, start: start, length: length, isExtended: isExtended, extendedTime: extendedTime, vault: <-vault, incrementByPrice: incrementByPrice,
                    incrementAmount: incrementAmount, startingBid: startingBid, reserve: reserve, buyNow: buyNow, reprintSeries: reprintSeries)
                destroy old
                destroy nft // is always empyty
            } else {
                let old <- auction <- create Auction(metadata: nil, nft: <-nft!, start: start, length: length, isExtended: isExtended, extendedTime: extendedTime, vault: <-vault, incrementByPrice: incrementByPrice,
                    incrementAmount: incrementAmount, startingBid: startingBid, reserve: reserve, buyNow: buyNow, reprintSeries: reprintSeries)
                destroy old
            }
            return <- auction!
        }    

        // Resolves all Auctions. Closes ones that have been ended or restarts them due to being a reprintSeries auctions.
        // This allows the auctioneer to close auctions to auctions that have ended, returning funds and appropriating items accordingly
        // even in instances where the Winner has not claimed their item.
        pub fun closeAuctions()
        {
            for act in self.currentAuctions.keys {                
                let current_status = self.currentAuctions[act]?.updateStatus() // status may have been changed in verifyReservePrive() called by seriesMinter()
                if current_status == false { // Check to see if auction has ended. A false value.
                    let auctionID = self.currentAuctions[act]?.auctionID! // get AID
                    log("Closing Token ID: ")
                    if self.currentAuctions[act]?.auctionNFT != nil || self.currentAuctions[act]?.auctionMetadata != nil { // Winner has not yet collected
                        self.currentAuctions[act]?.verifyReservePrice()! // Winner has not claimed their item. Verify they have meet the reserve price?
                    }

                    if self.currentAuctions[act]?.status == true { // Series Minter is minting another Metadata to NFT. Auction Restarting.
                        continue
                    }  

                    self.removeAuction(auctionID)

                    log("Auction Closed: ".concat(auctionID.toString()) )                    
                    emit AuctionClosed(auctionID: auctionID)
                }
            }
        }
        
        pub fun closeAuction(_ auctionID: UInt64)
        {
            pre { self.currentAuctions.containsKey(auctionID) : "AID is not in your Wallet." }
            let current_status = self.currentAuctions[auctionID]?.updateStatus() // status may have been changed in verifyReservePrive() called by seriesMinter()
            assert(current_status==false, message: "Auction has not ended.");
                
            log("Closing Token ID: ")
            if self.currentAuctions[auctionID]?.auctionNFT != nil || self.currentAuctions[auctionID]?.auctionMetadata != nil { // Winner has not yet collected
                self.currentAuctions[auctionID]?.verifyReservePrice()! // Winner has not claimed their item. Verify they have meet the reserve price?
            }

            if self.currentAuctions[auctionID]?.status == true { // Series Minter is minting another Metadata to NFT. Auction Restarting.
                return
            }  

            self.removeAuction(auctionID)

            log("Auction Closed: ".concat(auctionID.toString()) )                    
            emit AuctionClosed(auctionID: auctionID)
        }


        priv fun removeAuction(_ auctionID: UInt64) {
            let auction <- self.currentAuctions.remove(key:auctionID)!   // No Series minting or last mint
            destroy auction                                              // end auction.!
            // Update Current Auctions List
            if self.currentAuctions.keys.length == 0 {
                AuctionHouse.currentAuctions.remove(key:self.owner!.address) // If auctioneer has no more auctions remove from list
            } else {
                AuctionHouse.currentAuctions.insert(key:self.owner!.address, self.currentAuctions.keys) // otherwise update list with reset values
            }
        }

        // Auctions can be cancelled if they have no bids.
        pub fun cancelAuction(auctionID: UInt64) {
            pre { self.currentAuctions.containsKey(auctionID) : "AID is not in your Wallet." }
            self.currentAuctions[auctionID]?.cancelAuction()
        } 

        // item(Auction ID) return a reference of the auctionID Auction
        pub fun item(_ aid: UInt64): &Auction{AuctionPublic}? { 
            pre { self.currentAuctions.containsKey(aid) }
            return &self.currentAuctions[aid] as &Auction{AuctionPublic}?
        }

        pub fun getAuctions(): [UInt64] { return self.currentAuctions.keys } // Return all auctions by User

        pub fun getAgentAuctions(): [UInt64] { return self.approveAuctions.keys } // Return all auctions by Agent, requires Approval

        pub fun endReprints(auctionID: UInt64) { // Toggles the reprint to OFF. Note: This is not a toggle
            pre {
                self.currentAuctions.containsKey(auctionID)         : "AuctionID does not exist"
                self.currentAuctions[auctionID]?.reprintSeries != 0 : "Reprint is already set to Off."
            }
            self.currentAuctions[auctionID]?.endReprints()
        }

        priv fun validToken(vault: &FungibleToken.Vault): Bool {
            let type = vault.getType()
            let identifier = type.identifier
            return AuctionHouse.crypto.containsKey(identifier)
        }

        destroy() {
        pre { self.currentAuctions.length == 0 && self.approveAuctions.length == 0 }
            destroy self.currentAuctions
            destroy self.approveAuctions
        }
    }
/************************************************************************/
    pub resource interface AuctionPublic {
        pub fun depositToBid(bidder: Address, amount: @FungibleToken.Vault) // @AnyResource{FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance}
        pub fun withdrawBid(bidder: AuthAccount): @FungibleToken.Vault
        pub fun auctionInfo(): AuctionHolder
        pub fun winnerCollect()
        pub fun getBuyNowAmount(bidder: Address): UFix64
        pub fun getMinBidAmount(bidder: Address): UFix64?
        pub fun buyItNow(bidder: Address, amount: @FungibleToken.Vault)
        pub fun buyItNowStatus(): Bool
        pub fun getAuctionLog(): {Address:UFix64}
        pub fun getStatus(): Bool?
        pub fun itemInfo(): DAAM.MetadataHolder?
        pub fun timeLeft(): UFix64?
    }
/************************************************************************/
    pub resource Auction: AuctionPublic {
        access(contract) var status: Bool? // nil = auction not started or no bid, true = started (with bid), false = auction ended
        priv var height     : UInt64?      // Stores the final block height made by the final bid only.
        pub var auctionID   : UInt64       // Auction ID number. Note: Series auctions keep the same number. 
        pub let creatorInfo : DAAM.CreatorInfo
        pub let mid         : UInt64       // collect Metadata ID
        pub var start       : UFix64       // timestamp
        priv let origLength   : UFix64   // original length of auction, needed to reset if Series
        pub var length        : UFix64   // post{!isExtended && length == before(length)}
        pub let isExtended    : Bool     // true = Auction extends with every bid.
        pub let extendedTime  : UFix64   // when isExtended=true and extendedTime = 0.0. This is equal to a direct Purchase. // Time of Extension.
        pub var leader        : Address? // leading bidder
        pub var minBid        : UFix64?  // minimum bid
        priv let increment    : {Bool : UFix64} // true = is amount, false = is percentage *Note 1.0 = 100%
        pub let startingBid   : UFix64?  // the starting bid of an auction. nil = No Bidding. Direct Purchase
        pub let reserve       : UFix64   // the reserve. must be sold at min price.
        pub let fee           : UFix64   // the fee
        pub let price         : UFix64   // original price
        pub let buyNow        : UFix64   // buy now price original price
        pub var reprintSeries : UInt64?  // Number of reprints, nil = max prints.
        pub var auctionLog    : {Address: UFix64}    // {Bidders, Amount} // Log of the Auction
        access(contract) var auctionMetadata : @DAAM.Metadata? // Store NFT for auction
        access(contract) var auctionNFT : @DAAM.NFT? // Store NFT for auction
        priv var auctionVault : @FungibleToken.Vault // Vault, All funds are stored.
        pub let requiredCurrency: Type
    
        // Auction: A resource containg the auction itself.
        // start: Enter UNIX Flow Blockchain Time
        // length: Length of auction
        // isExtended: if the auction lenght is to be an Extended Auction
        // extendedTime: The amount of time the extension is to be.
        // incrementByPrice: increment by fixed amount or percentage. True = fixed amount, False = Percentage
        // incrementAmount: the increment value. when incrementByPrice is true, the minimum bid is increased by this amount.
        //                  when False, the minimin bid is increased by that Percentage. Note: 1.0 = 100%
        // startingBid: the initial price. May not be 0.0
        // reserve: The minimum price that must be meet
        // buyNow: To amount to purchase an item directly. Note: 0.0 = OFF
        // reprintSeries: to duplicate the current auction, with a reprint (Next Mint os Series)
        // *** new is defines as "never sold", age is not a consideration. ***
        init(metadata: @DAAM.Metadata?, nft: @DAAM.NFT?, start: UFix64, length: UFix64, isExtended: Bool, extendedTime: UFix64, vault: @FungibleToken.Vault,
          incrementByPrice: Bool, incrementAmount: UFix64, startingBid: UFix64?, reserve: UFix64, buyNow: UFix64, reprintSeries: UInt64?) {
            pre {
                (metadata == nil && nft != nil) || (metadata != nil && nft == nil) : "Can not add NFT & Metadata"
                start >= getCurrentBlock().timestamp : "Time has already past."
                length >= 60.0                       : "Minimum is 1 min"
                buyNow > reserve || buyNow == 0.0    : "The BuyNow option must be greater then the Reserve."
                startingBid != 0.0 : "You can not have a Starting Bid of zero."
                isExtended && extendedTime >= 20.0 || !isExtended && extendedTime == 0.0 : "Extended Time setting are incorrect. The minimim is 20 seconds."
                startingBid == nil && buyNow != 0.0 || startingBid != nil : "Direct Purchase requires BuyItNow amount"
            }
            let metadataHolder: DAAM.MetadataHolder = (metadata != nil) ? metadata?.getHolder()! : nft?.metadata!
            if reprintSeries != nil && metadataHolder.edition.max != nil { assert(reprintSeries! <= metadataHolder.edition.max!, message: "") }
            // Verify starting bid is lower then the reserve price
            if startingBid != nil { assert(reserve > startingBid!, message: "The Reserve must be greater then your Starting Bid") }
                     
            // Manage incrementByPrice
            if incrementByPrice == false && incrementAmount < 0.01  { panic("The minimum increment is 1.0%.")   }
            if incrementByPrice == false && incrementAmount > 0.05  { panic("The maximum increment is 5.0%.")     }
            if incrementByPrice == true  && incrementAmount < 1.0   { panic("The minimum increment is 1 Crypto.") }

            AuctionHouse.auctionCounter = AuctionHouse.auctionCounter + 1 // increment Auction Counter
            self.status = nil // nil = auction not started, true = auction ongoing, false = auction ended
            self.height = nil  // when auction is ended does it get a value
            self.auctionID = AuctionHouse.auctionCounter // Auction uinque ID number
            
            self.start = start        // When auction start
            self.length = length      // Length of auction
            self.origLength = length  // If length is reset (extneded auction), a new reprint can reset the original length
            self.leader = nil         // Current leader, when nil = no leader
            self.minBid = startingBid // when nil= Direct Purchase, buyNow Must have a value
            self.isExtended = isExtended // isExtended status
            self.extendedTime = (isExtended) ? extendedTime : 0.0 // Store extended time
            self.increment = {incrementByPrice : incrementAmount} // Store increment 
            
            self.startingBid = startingBid 
            self.reserve = reserve
            self.price = buyNow
            
            let ref = (nft != nil) ? &nft?.metadata! as &DAAM.MetadataHolder : &metadata?.getHolder()! as &DAAM.MetadataHolder
            self.creatorInfo = ref.creatorInfo

            if ref.edition.max != nil && reprintSeries == nil { // if there is max and reprint is set to nil ...
                self.reprintSeries = ref.edition.max!           // set reprint to max 
            } else if reprintSeries != nil {
                self.reprintSeries = reprintSeries!             // otherwise reprint is equal to argument
            } else {
                self.reprintSeries = nil
            }              
            
            self.mid = ref.mid! // Metadata ID            
            if metadata != nil && !AuctionHouse.history.containsKey(self.mid) { // is Metadata and first Auction of Metadata
                let metadataHolder =  metadata?.getHolder()! //as &DAAM.MetadataHolder
                AuctionHouse.history.insert(key: self.mid, {0 : SaleHistory(metadata: metadataHolder)} ) // Element 0 if for data gathering of Metadata/Auction Holder through History.
            }

            self.fee = AuctionHouse.getFee(mid: self.mid)
            self.buyNow = self.price

            self.auctionLog = {} // Maintain record of Crypto // {Address : Crypto}
            self.auctionVault <- vault  // ALL Crypto is stored
            self.requiredCurrency = self.auctionVault.getType()
            self.auctionNFT <- nft // NFT Storage durning auction
            self.auctionMetadata <- metadata // NFT Storage durning auction

            log("Auction Initialized: ".concat(self.auctionID.toString()) )
            emit AuctionCreated(auctionID: self.auctionID, start: self.start)
        }

        // Makes Bid, Bids are deposited into vault
        pub fun depositToBid(bidder: Address, amount: @FungibleToken.Vault) {
            pre {
                amount.isInstance(self.requiredCurrency) : "Incorrect payment currency"    
                self.minBid != nil                    : "No Bidding. Direct Purchase Only."     
                self.updateStatus() == true           : "Auction is not in progress."
                self.validateBid(bidder: bidder, balance: amount.balance) : "You have made an invalid Bid."
                self.leader != bidder                 : "You are already lead bidder."
                self.creatorInfo.creator != bidder    : "You can not bid in your own auction."
                self.height == nil || getCurrentBlock().height < self.height! : "You bid was too late"
            }
            post { self.verifyAuctionLog() } // Verify Funds

            log("self.minBid: ".concat(self.minBid!.toString()) )

            self.leader = bidder                        // Set new leader
            self.updateAuctionLog(amount.balance)       // Update logs with new balance
            self.incrementminBid()                      // Increment accordingly
            self.auctionVault.deposit(from: <- amount)  // Deposit Crypto into Vault
            self.extendAuction()                        // Extendend auction if applicable

            log("Balance: ".concat(self.auctionLog[self.leader!]!.toString()) )
            log("Min Bid: ".concat(self.minBid!.toString()) )
            log("Bid Accepted")
            emit BidMade(auctionID: self.auctionID, bidder:self.leader! )
        }

        // validateBid: Verifies the amount given meets the minimum bid.
        priv fun validateBid(bidder: Address, balance: UFix64): Bool {
            // Bidders' first bid (New Bidder)
            if !self.auctionLog.containsKey(bidder) {
                if balance >= self.minBid! {
                    return true
                }
                log("Initial Bid too low.")
                return false
            }

            // Otherwise ... (not the Bidders' first bid)
            // Verify bidders' total amount is meets the minimum bid
            if (balance + self.auctionLog[bidder]!) >= self.minBid! {
                return true
            }
            // retutning false, reserve price not meet
            log("Bid Deposit too low.")
            return false
        }

        // increments minimum bid by fixed amount or percentage based on incrementByPrice
        priv fun incrementminBid() {
            let bid = self.auctionLog[self.leader!]! // get current bid
            if self.increment[false] != nil {        // check if increment is by percentage
                self.minBid = bid + (bid * self.increment[false]!) // increase minimum bid by percentage
            } else { // price incrememt by fixed amount
                self.minBid = bid + self.increment[true]!
            }
        }

        // Returns and Updates the current status of the Auction
        // nil = auction not started, true = started, false = auction ended
        access(contract) fun updateStatus(): Bool? {
            if self.status == false {  // false = Auction has already Ended
                log("Status: Auction Previously Ended")
                return false
            }
            // First time Auction has been flaged as Ended
            let auction_time = self.timeLeft() // a return of 0.0 signals the auction has ended.
            if auction_time == 0.0 {
                self.status = false                    // set auction to End (false)
                self.height = getCurrentBlock().height // get height for bids at enf of auction.
                log("Status: Time Limit Reached & Auction Ended")
                emit AuctionEnded(auctionID: self.auctionID, time: getCurrentBlock().timestamp)
                return false
            }

            if auction_time == nil { // nil = Auction has not yet started
                log("Status: Not Started")
                self.status = nil
            } else {
                log("Status: Auction Ongoing")
                self.status = true // true = Auction is ongoing
            }
            return self.status
        }

        // Allows bidder to withdraw their bid as long as they are not the lead bidder.
        pub fun withdrawBid(bidder: AuthAccount): @FungibleToken.Vault {
            pre {
                self.leader! != bidder.address : "You have the Winning Bid. You can not withdraw."
                self.updateStatus() != false   : "Auction has Ended."
                self.auctionLog.containsKey(bidder.address) : "You have not made a Bid"
                self.minBid != nil : "This is a Buy It Now only purchase."
                self.verifyAuctionLog() : "Internal Error!!"
            }
            post { self.verifyAuctionLog() }

            let balance = self.auctionLog[bidder.address]! // Get balance from log
            self.auctionLog.remove(key: bidder.address)!   // Remove from log
            let amount <- self.auctionVault.withdraw(amount: balance) // Withdraw balance from Vault
            log("Bid Withdrawn")
            emit BidWithdrawn(auctionID: self.auctionID, bidder: bidder.address)    
            return <- amount  // return bidders deposit amount
        }

        pub fun auctionInfo(): AuctionHolder {
            let info = AuctionHolder(
                self.status, self.auctionID, self.creatorInfo, self.mid, self.start, self.length, self.isExtended,
                self.extendedTime, self.leader, self.minBid, self.startingBid, self.reserve, self.fee,
                self.price, self.buyNow, self.reprintSeries, self.auctionLog, self.requiredCurrency
            )
            return info
        }

        // Winner can 'Claim' an item. Reserve price must be meet, otherwise returned to auctioneer
        pub fun winnerCollect() {
            pre{ self.updateStatus() == false  : "Auction has not Ended." }
            log("Leader: ")
            log(self.leader)
            self.verifyReservePrice() // Verify Reserve price is met
        }

        // This is a key function where are all the action happens.
        // Verifies the Reserve Price is met. 
        // Calls royalty() & ReturnFunds() and manages all royalities and funds are returned
        // Sends the item (NFT) or Mints Metadata then Sends, or Returns Metadata
        access(contract) fun verifyReservePrice() {
            pre  { self.updateStatus() == false   : "Auction still in progress" }
            post { self.verifyAuctionLog() } // Verify funds calcuate

            var pass = false       // false till reserve price is verified
            log("Auction Log Length: ".concat(self.auctionLog.length.toString()) )
            if self.leader != nil {
                if self.auctionLog[self.leader!]! >= self.reserve { // Does the leader meet the reserve price?
                    pass = true
                }
            }

            if pass { // leader met the reserve price              
                if self.auctionMetadata != nil { // If Metadata turn into nFt
                    let metadata <- self.auctionMetadata <- nil
                    let old <-  self.auctionNFT <- AuctionHouse.mintNFT(metadata: <-metadata!)
                    destroy old
                }
                // remove leader from log before returnFunds()!!
                let amount = self.auctionLog[self.leader!]!
                self.auctionLog.remove(key: self.leader!)!
                self.returnFunds()  // Return funds to all bidders
                self.royalty()      // Pay royalty

                let nft <- self.auctionNFT <- nil // remove nft
                let id = nft?.id!
                let metadata = nft?.metadata!
                let leader = self.leader!
                self.finalise(receiver: self.leader!, nft: <-nft!, pass: pass)
                log("Item: Won")
                let saleHistoryEntry = SaleHistoryEntry(id: id, auctionHolder: self.auctionInfo(), price: amount, from: self.owner!.address, to: leader)
                AuctionHouse.updateAllHistory(mid: self.mid, id: id, metadata: metadata, history: saleHistoryEntry)

                emit ItemWon(auctionID: self.auctionID, winner: leader, tokenID: id, amount: amount, sale: saleHistoryEntry) // Auction Ended, but Item not delivered yet.
            } else {   
                let receiver = self.owner!.address   // set receiver from leader to auctioneer 
                if self.auctionMetadata != nil { // return Metadata to Creator
                    let metadata <- self.auctionMetadata <- nil
                    let ref = getAccount(receiver!).getCapability<&DAAM.MetadataGenerator{DAAM.MetadataGeneratorPublic}>(DAAM.metadataPublicPath).borrow()!
                    ref.returnMetadata(metadata: <- metadata!)
                    self.returnFunds()              // return funds to all bidders
                    log("Item: Returned")                   
                    emit ItemReturned(auctionID: self.auctionID, seller: receiver!)
                } else {      // return NFT to Seller, reerve not meet
                    let nft <- self.auctionNFT <- nil
                    self.returnFunds()              // return funds to all bidders
                    self.finalise(receiver: receiver, nft: <-nft!, pass: pass)
                    log("Item: Returned")
                    emit ItemReturned(auctionID: self.auctionID, seller: receiver!)
                }                            
            }
        }

        priv fun finalise(receiver: Address?, nft: @DAAM.NFT, pass: Bool) {
            log("receiver: ".concat(receiver!.toString()) )   
            let collectionRef = getAccount(receiver!).getCapability<&{NonFungibleToken.CollectionPublic}>(DAAM.collectionPublicPath).borrow()!
           
            var isLast = false
            if nft.metadata!.edition.max != nil { 
                isLast = (nft.metadata!.edition.number == nft.metadata!.edition.max!)
            }

            // NFT Deposot Must be LAST !!! *except for seriesMinter
            collectionRef.deposit(token: <- nft!) // deposit nft

            if pass && !isLast { // possible re-auction Series Minter                
                self.seriesMinter() // Note must be last after transer of NFT
            }
        }

        // Verifies amount is equal to the buyNow amount. If not returns false
        priv fun verifyBuyNowAmount(bidder: Address, amount: UFix64): Bool {            
            log("self.buyNow: ".concat(self.buyNow.toString()) )
            
            var total = amount
            log("total: ".concat(total.toString()) )
            if self.auctionLog[bidder] != nil { 
                total = total + self.auctionLog[bidder]! // get bidders' total deposit
            }
            log("total: ".concat(total.toString()) )
            return self.buyNow == total // compare bidders' total deposit to buyNow
        }

        // Return the amount needed to make the correct bid
        pub fun getBuyNowAmount(bidder: Address): UFix64 {
            // If no bid had been made return buynow price, else return the difference
            return (self.auctionLog[bidder]==nil) ? self.buyNow : (self.buyNow-self.auctionLog[bidder]!)
        }
        
        // Return the amount needed to make the correct bid
        pub fun getMinBidAmount(bidder: Address): UFix64? {
            // If no bid had been made return minimum bid, else return the difference
            if self.minBid == nil { return nil } // Buy Now Only, return nil
            return (self.auctionLog[bidder]==nil) ? self.minBid : (self.minBid! - self.auctionLog[bidder]!)
        }

        // Record total amount of Crypto a bidder has deposited. Manages Log of that total.
        priv fun updateAuctionLog(_ amount: UFix64) {
            if !self.auctionLog.containsKey(self.leader!) {        // First bid by user
                self.auctionLog.insert(key: self.leader!, amount)  // append log for new bidder and log amount
            } else {
                let total = self.auctionLog[self.leader!]! + amount // get new total deposit of bidder
                self.auctionLog[self.leader!] = total               // append log with new amount
            }
        }          

        // To purchase the item directly. 
        pub fun buyItNow(bidder: Address, amount: @FungibleToken.Vault) {
            pre {
                amount.isInstance(self.requiredCurrency) : "Incorrect Crypto."
                self.creatorInfo.creator != bidder    : "You can not bid in your own auction."
                self.updateStatus() != false  : "Auction has Ended."
                self.buyNow != 0.0 : "Buy It Now option is not available."
                self.verifyBuyNowAmount(bidder: bidder, amount: amount.balance) : "Wrong Amount."
                // Must be after the above line.
                self.buyItNowStatus() : "Buy It Now option has expired."
            }
            post { self.verifyAuctionLog() } // verify log

            self.status = false          // ends the auction
            self.length = 0.0            // set length to 0; double end auction
            self.leader = bidder         // set new leader

            self.updateAuctionLog(amount.balance)       // update auction log with new leader
            let price = self.auctionLog[self.leader!]!
            self.auctionVault.deposit(from: <- amount)  // depsoit into Auction Vault
            
            emit BuyItNow(auctionID: self.auctionID, winner: self.leader!, amount: self.buyNow)

            self.winnerCollect() // Will receive NFT if reserve price is met
        }    

        // returns BuyItNowStaus, true = active, false = inactive
        pub fun buyItNowStatus(): Bool {
            pre {
                self.buyNow != 0.0 : "No Buy It Now option for this auction."
                self.updateStatus() != false : "Auction is over or invalid."
            }
            if self.leader != nil {
                return self.buyNow > self.auctionLog[self.leader!]! // return 'Buy it Now' price to the current bid
            }
            return true
        }

        // Return all funds in auction log to bidder
        // Note: leader is typically removed from auctionLog before called.
        priv fun returnFunds() {
            post { self.auctionLog.length == 0 : "Illegal Operation: returnFunds" } // Verify auction log is empty
            for bidder in self.auctionLog.keys {
                // get Crypto Wallet capability
                let bidderRef =  getAccount(bidder).getCapability<&{FungibleToken.Receiver}>
                    (MetadataViews.getRoyaltyReceiverPublicPath())
                    .borrow()!
                let amount <- self.auctionVault.withdraw(amount: self.auctionLog[bidder]!)  // Withdraw amount
                self.auctionLog.remove(key: bidder)
                bidderRef.deposit(from: <- amount)  // Deposit amount to bidder
            }
            log("Funds Returned")
            emit FundsReturned(auctionID: self.auctionID)
        }

        pub fun getAuctionLog(): {Address:UFix64} {
            return self.auctionLog
        }

        // Checks for Extended Auction and extends auction accordingly by extendedTime
        priv fun extendAuction() { 
            if !self.isExtended { return }     // not Extended Auction return
            let end = self.start + self.length // Get end time
            let new_length = (end - getCurrentBlock().timestamp) + self.extendedTime // get new length
            if new_length > end { self.length = new_length } // if new_length is greater then the original end, update
        }

        pub fun getStatus(): Bool? { // gets Auction status: nil = not started, true = ongoing, false = ended
            return self.updateStatus()
        }

        pub fun itemInfo(): DAAM.MetadataHolder? { // returns the metadata of the item NFT.
            return (self.auctionNFT != nil) ? self.auctionNFT?.metadata! : self.auctionMetadata?.getHolder()
        }

        pub fun timeLeft(): UFix64? { // returns time left, nil = not started yet.
            if self.length == 0.0 {
                return 0.0 as UFix64
            } // Extended Auction ended.

            let timeNow = getCurrentBlock().timestamp
            log("TimeNow: ".concat(timeNow.toString()) )
            if timeNow < self.start { return nil } // Auction has not started

            let end = self.start + self.length     // get end time of auction
            log("End: ".concat(end.toString()) )

            
            if timeNow >= self.start && timeNow < end { // if time is durning auction
                let timeleft = end - timeNow            // calculate time left
                return timeleft                         // return time left
            }
            return 0.0 as UFix64 // return no time left
        }

        priv fun payRoyalty(price: UFix64, royalties: [MetadataViews.Royalty]) {
            pre{ royalties.length > 0 : "Ilegal Operation 1: payRoyalties, price: ".concat(price.toString()) }

            var totalCut    = 0.0
            var totalAmount = 0.0
            var count       = 0
            let last        = royalties.length-1
            var amount      = 0.0

            for royalty in royalties {
                assert(royalty.receiver != nil, message: "Ilegal Operation 2: payRoyalties, price: ".concat(price.toString()) )
                amount   = price * royalty.cut
                totalAmount = totalAmount + amount
                // deals with remainder
                if count == last {
                    let offset = 1.0 - totalCut
                    let offsetAmount = price - totalAmount
                    amount = amount + offsetAmount
                    totalCut = totalCut + offset
                    totalAmount = totalAmount + offsetAmount
                }

                let cut <-! self.auctionVault.withdraw(amount: amount)  // Calculate Agency Crypto share
                let cap = royalty.receiver.borrow()!
                cap.deposit(from: <-cut ) //deposit royalty share

                count = count + 1
            }
            assert(totalCut == 1.0, message: "Price: ".concat(price.toString().concat(" totalCut: ").concat(totalCut.toString())))
            assert(totalAmount == price, message: "Price: ".concat(price.toString().concat(" totalAmount: ").concat(totalAmount.toString())))
        }

        priv fun convertTo100Percent(): [MetadataViews.Royalty] {
            post { rlist.length > 0 : "Illegal Operation: convertTo100Percent" }

            let royalties = self.auctionNFT?.royalty!.getRoyalties()
            assert(royalties.length > 0, message: "Illegal Operation: convertTo100Percent")

            var totalCut = 0.0
            for r in royalties { totalCut = totalCut + r.cut }
            let offset = 1.0 / totalCut
            var rlist: [MetadataViews.Royalty] = []
            let last = royalties.length-1
            var count = 0
            var cut = 0.0

            totalCut = 0.0
            for r in royalties {
                cut = r.cut * offset 
                totalCut = totalCut + cut
                assert(r.receiver != nil, message: "Invald Entry: Receipient")
                if count == last { // takes care of remainder
                    let offset = 1.0 - totalCut
                    cut = cut + offset
                    totalCut = totalCut + offset
                }
                rlist.append(MetadataViews.Royalty(
                    receiver: r.receiver!,
                    cut: cut,
                    description: "Royalty Rate"
                ))
                count = count + 1
            }
            assert(totalCut == 1.0 , message: "Illegal Operation: convertTo100Percent, totalCut: ".concat(totalCut.toString()))
            return rlist
        }

        // Returns a percentage of Group. Ex: Bob owns 10%, with percentage at 0.2, will return Bob at 8% along with the rest of Group
        priv fun payFirstSale() {
            post { self.auctionVault.balance == 0.0 : "Royalty Error: ".concat(self.auctionVault.balance.toString() ) } // The Vault should always end empty
            let price       = self.auctionVault.balance / (1.0 + AuctionHouse.getFee(mid: self.mid))
            let fee         = self.auctionVault.balance - price   // Get fee amount
            let creatorRoyalties = self.convertTo100Percent() // get Royalty data
            let daamRoyalty = AuctionHouse.getAgencyFirstSale(mid: self.mid)
            let inHouse = 0.5 // Main setting here
            
            if self.auctionNFT?.metadata!.creatorInfo.agent == DAAM.company.receiver.address {
                // Below changes are calculated from above settings
                let agency = 1.0 - inHouse
                let nonCreatorAmont = (price * daamRoyalty) + fee
                let inHouseAmount = nonCreatorAmont * inHouse
                let daamAmount = nonCreatorAmont - inHouseAmount
                let creatorAmount = self.auctionVault.balance - nonCreatorAmont
                self.payRoyalty(price: inHouseAmount, royalties: [DAAM.company])
                self.payRoyalty(price: daamAmount, royalties: DAAM.agency.getRoyalties())
                self.payRoyalty(price: creatorAmount, royalties: creatorRoyalties)
            } else {
                // Agent payment
                let agentAmount  = price * self.auctionNFT?.metadata!.creatorInfo.firstSale!
                let agentAddress = self.auctionNFT?.metadata!.creatorInfo.agent!
                let agent = getAccount(agentAddress).getCapability<&{FungibleToken.Receiver}>
                    (MetadataViews.getRoyaltyReceiverPublicPath()!)
                    .borrow()! // get Seller FUSD Wallet Capability
                let agentCut <-! self.auctionVault.withdraw(amount: agentAmount) // Calcuate actual amount
                let feeInHouseAmount = fee * inHouse
                let feeAgencyAmount = fee - feeInHouseAmount
                agent.deposit(from: <-agentCut ) // deposit amount  
                self.payRoyalty(price: feeInHouseAmount, royalties: [DAAM.company] ) // Fee Payment
                self.payRoyalty(price: feeAgencyAmount, royalties: DAAM.agency.getRoyalties() ) // Fee Paymen
                self.payRoyalty(price: self.auctionVault.balance, royalties: creatorRoyalties) // Royalty
            }           
            assert(self.auctionVault.balance==0.0, message: self.auctionVault.balance.toString().concat(" fee: ").concat(fee.toString()) )
        }

        // Royalty rates are gathered from the NFTs metadata and funds are proportioned accordingly.
        priv fun royalty()
        {
            post { self.auctionVault.balance == 0.0 : "Royalty Error: ".concat(self.auctionVault.balance.toString() ) } // The Vault should always end empty
            if self.auctionVault.balance == 0.0 { return }     // No need to run, already processed.
            let tokenID = self.auctionNFT?.id!                 // Get TokenID
            let inHouse = 0.5                                  // Portion of fee that stays inHouse
            let agency = 1.0 - inHouse
            // If 1st sale is 'new' remove from 'new list'
            if DAAM.isNFTNew(id: tokenID) {
                AuctionHouse.notNew(tokenID: tokenID) 
                self.payFirstSale()
            } else {   // 2nd Sale
                let price   = self.auctionVault.balance / (1.0 + self.fee)
                var fee     = self.auctionVault.balance - price   // Get fee amount
                let royalties = self.auctionNFT?.royalty!.getRoyalties() // get Royalty data

                self.payRoyalty(price: price, royalties:royalties)
                self.payRoyalty(price: fee * inHouse, royalties: [DAAM.company] ) // get Comapny share of fee
                self.payRoyalty(price: fee * agency, royalties: DAAM.agency.getRoyalties() ) // Pay Agency the fee

                let seller = self.owner?.getCapability<&{FungibleToken.Receiver}>
                    (MetadataViews.getRoyaltyReceiverPublicPath())!
                    .borrow()! // get Seller FUSD Wallet Capability
                let sellerCut <-! self.auctionVault.withdraw(amount: self.auctionVault.balance) // Calcuate actual amount
                seller.deposit(from: <-sellerCut ) // deposit amount
            }     
        }

        // Comapres Log to Vault. Makes sure Funds match. Should always be true!
        priv fun verifyAuctionLog(): Bool {
            var total = 0.0
            for bidder in self.auctionLog.keys {
                total = total + self.auctionLog[bidder]! // get total in logs
            }
            log("Verify Auction Log: ")
            log(self.auctionLog)
            log("AID: ".concat(self.auctionID.toString()) )
            return total == self.auctionVault.balance    // compare total to Vault
        }

        // Resets all variables that need to be reset for restarting a reprintSeries auction.
        priv fun resetAuction() {
            pre { self.auctionVault.balance == 0.0 : "Internal Error: Serial Minter" }  // already called by SerialMinter

            if self.reprintSeries != nil {                   // nil is unlimited prints
                self.reprintSeries = self.reprintSeries! - 1 // Decrement reprint
            }

            self.leader = nil
            self.start = getCurrentBlock().timestamp // reset new auction to start at current time
            self.length = self.origLength
            self.auctionLog = {}
            self.minBid = self.startingBid
            self.status = true
            self.height = nil 
            log("Reset: Variables")
        }

        // Where the reprintSeries Mints another NFT.
        priv fun seriesMinter() {
            pre { self.auctionVault.balance == 0.0 : "Internal Error: Serial Minter" } // Verifty funds from previous auction are gone.
            if self.reprintSeries == 1 { return } // if reprint is set to off (false) return
            if self.creatorInfo.creator != self.owner!.address { return } // Verify Owner is Creator (element 0) otherwise skip function

            let metadataRef = AuctionHouse.metadataGen[self.mid]!.borrow()!   // get Metadata Generator Reference
            let minterAccess <- AuctionHouse.minterAccess(mid: self.mid)
            let metadata <-! metadataRef.generateMetadata(minter: <- minterAccess)
            let old <- self.auctionNFT <- AuctionHouse.mintNFT(metadata: <-metadata) // Mint NFT and deposit into auction
            destroy old // destroy place holder

            self.resetAuction() // reset variables for next auction
        } 

        // End reprints. Set to OFF
        access(contract) fun endReprints() {
           pre {
                self.reprintSeries != 0 : "Reprints is already off."
                self.auctionNFT?.metadata!.creatorInfo.creator == self.owner!.address : "You are not the Creator of this NFT"
           }
           self.reprintSeries = 0
        }

        // Auctions can be cancelled if they have no bids.
        pub fun cancelAuction() {
            pre {
                self.updateStatus() == nil || true         : "Too late to cancel Auction."
                self.auctionLog.length == 0                : "You already have a bid. Too late to Cancel."
            }
            
            self.status = false
            self.length = 0.0

            log("Auction Cancelled: ".concat(self.auctionID.toString()) )
            emit AuctionCancelled(auctionID: self.auctionID)
        } 
        
        destroy() { // Verify no Funds, NFT are NOT in storage, Auction has ended/closed.
            pre{
                self.auctionNFT == nil           : "Illegal Operation: Auction still contains NFT Token ID: ".concat(self.auctionNFT?.metadata!.mid.toString())
                self.auctionMetadata == nil      : "Illegal Operation: Auction still contains MetadataID: ".concat(self.auctionMetadata?.mid!.toString())
                self.status == false             : "Illegal Operation: Auction is not Finished."
                self.auctionVault.balance == 0.0 : "Illegal Operation: Auction Balance is ".concat(self.auctionVault.balance.toString())
            }
            // Re-Verify Funds Allocated Properly, since it's empty it should just pass
            self.returnFunds()
            self.royalty()

            destroy self.auctionVault
            destroy self.auctionNFT
            destroy self.auctionMetadata
        }
    }
/************************************************************************/
// AuctionHouse Functions & Constructor

    // Sets NFT to 'not new' 
    access(contract) fun notNew(tokenID: UInt64) {
        let minter = self.account.borrow<&DAAM.Minter>(from: DAAM.minterStoragePath)!
        minter.notNew(tokenID: tokenID) // Set to not new
    }

    // Get current auctions { Address : [AID] }
    pub fun getCurrentAuctions(): {Address:[UInt64]} {
        return self.currentAuctions
    }   

    // Get current auctions { Address : [AID] }
    pub fun getCurrentAuctionsStatus(_ status: Bool?): {Address:[UInt64]} {
        let currentAuctions = self.currentAuctions
        let selectedAuction: {Address:[UInt64]} = {}
        for seller in currentAuctions.keys {
            let auctionHouse = getAccount(seller).getCapability<&AuctionHouse.AuctionWallet{AuctionHouse.AuctionWalletPublic}>
                (AuctionHouse.auctionPublicPath).borrow()!
            let aids = currentAuctions[seller]!
            let list: [UInt64] = []
            for aid in aids {
                let mRef = auctionHouse.item(aid) as &AuctionHouse.Auction{AuctionHouse.AuctionPublic}?
                let current_status = mRef!.getStatus()
                if status == current_status { list.append(aid) }
            }
            if list.length > 0 { selectedAuction.insert(key: seller, list)}
        }
        return selectedAuction
    }     

    // Requires Minter Key // Minter function to mint
    access(contract) fun mintNFT(metadata: @DAAM.Metadata): @DAAM.NFT {
        let minterRef = self.account.borrow<&DAAM.Minter>(from: DAAM.minterStoragePath)! // get Minter Reference
        let nft <- minterRef.mintNFT(metadata: <-metadata)! // Mint NFT
        return <- nft                                    // Return NFT
    }

    // Requires Minter Key // Minter function to mint
    access(contract) fun minterAccess(mid: UInt64): @DAAM.MinterAccess {
        let minterRef = self.account.borrow<&DAAM.Minter>(from: DAAM.minterStoragePath)! // get Minter Reference
        let minter_access <- minterRef.createMinterAccess(mid: mid)
        return <- minter_access                                  // Return NFT
    }

    access(contract) fun updateAllHistory(mid: UInt64, id: UInt64, metadata: DAAM.MetadataHolder, history: SaleHistoryEntry) {
        // update saleHistory
        if self.saleHistory.containsKey(id) {
            self.saleHistory[id]!.add(history)
        } else {
            let saleHistory = SaleHistory(metadata: metadata)
            saleHistory.add(history)
            self.saleHistory.insert(key: id, saleHistory ) // Add new TokenID auction history
        }
        // update history
        if self.history.containsKey(mid) {
            let ref = &self.history[mid]! as &{UInt64 : SaleHistory}
            ref[id] = self.saleHistory[id]
        } else {
            self.history.insert(key: mid, {id : self.saleHistory[id]! } ) // Add new TokenID auction history
        }
    }

    pub fun getSaleHistory(id: UInt64?): {UInt64: SaleHistory}? { // {TokenID : SaleHistory}
        if id == nil { return self.saleHistory }
        if !self.saleHistory.containsKey(id!) { return nil}
        let salehistory = self.saleHistory[id!]!
        return {id! : salehistory}
    }

    pub fun getHistory(mid: UInt64?): {UInt64 : {UInt64: SaleHistory}}? { //{MID : {TokenID:SaleHistory} }
        if mid == nil { return self.history }
        if !self.history.containsKey(mid!) { return nil}
        let history = self.history[mid!]!
        return {mid! : history}
    }

    pub fun getFee(mid: UInt64): UFix64 {
        return (self.fee[mid] == nil) ? 0.025 : self.fee[mid]!
    }

    pub fun addFee(mid: UInt64, fee: UFix64, permission: &DAAM.Admin) {
        pre { DAAM.isAdmin(permission.owner!.address) == true : "Permission Denied" }
        self.fee[mid] = fee
    }

    pub fun removeFee(mid: UInt64, fee: UFix64, permission: &DAAM.Admin) {
        pre {
            DAAM.isAdmin(permission.owner!.address) == true : "Permission Denied"
            self.fee[mid] != nil : "No set Fee for this MID."
        }
        self.fee.remove(key: mid)
    }

    pub fun getAgencyFirstSale(mid: UInt64): UFix64 {
        return (self.agencyFirstSale[mid] == nil) ? 0.15 : self.agencyFirstSale[mid]!
    }

    pub fun addAgencyFirstSale(mid: UInt64, fee: UFix64, permission: &DAAM.Admin) {
        pre { DAAM.isAdmin(permission.owner!.address) == true : "Permission Denied" }
        self.agencyFirstSale[mid] = fee
    }

    pub fun removeAgencyFirstSale(mid: UInt64, fee: UFix64, permission: &DAAM.Admin) {
        pre {
            DAAM.isAdmin(permission.owner!.address) == true : "Permission Denied"
            self.fee[mid] != nil : "No set Fee for this MID."
        }
        self.agencyFirstSale.remove(key: mid)
    }

    pub fun addCrypto(crypto: &FungibleToken.Vault, path: PublicPath, permission: &DAAM.Admin) {
        pre { DAAM.isAdmin(permission.owner!.address) == true : "Permission Denied" }
        let type = crypto.getType()
        let identifier = type.identifier
        self.crypto.insert(key: identifier, path)
    }

    pub fun removeCrypto(crypto: String, permission: &DAAM.Admin) {
        pre {
            DAAM.isAdmin(permission.owner!.address) == true : "Permission Denied"
            self.crypto[crypto] != nil : "This Crypto is not accepted.."
        }
        self.crypto.remove(key: crypto)
    }

    pub fun getCrypto(): [String] {
        return self.crypto.keys
    }
    
    // Create Auction Wallet which is used for storing Auctions.
    pub fun createAuctionWallet(): @AuctionWallet { 
        return <- create AuctionWallet() 
    }

    init() {
        self.crypto          = {}
        self.metadataGen     = {}
        self.currentAuctions = {}
        self.fee             = {}
        self.saleHistory     = {}
        self.history         = {}
        self.agencyFirstSale = {}
        self.auctionCounter  = 0
        self.auctionStoragePath = /storage/DAAM_Auction
        self.auctionPublicPath  = /public/DAAM_Auction
    }
}
 
