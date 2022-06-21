   // //Goes through, and transfer into the contract the necessary funds
    // function processFundsSingleswap(bytes calldata message, uint8 person, bool singleChain, address partnerAddr, mapping(address => FeeStruct) storage tokenAmounts) private {
    //     //process funds
    //     uint ownerAmount;
    //     uint partnerAmount;
    //     address addr;
    //     assembly { 
    //         addr := calldataload(add(message.offset, 37))//MAGICNUMBERNOTE: fetching ownerToken, which sits at 37 + 32 = 69
    //         ownerAmount := calldataload(add(message.offset, 89))//MAGICNUMBERNOTE: fetching ownerAmount, which starts at 89, uint
    //     }
    //     if (person == 0 || singleChain) {
    //         //these are funds owner is providing
    //         tokenAmounts[addr].ownerBalance -= ownerAmount;
    //         if (singleChain) {
    //             //distribute funds instantly
    //             if (addr == NATIVE_TOKEN) {
    //                 //is native token
    //                 payable(partnerAddr).transfer(ownerAmount);
    //             } else {
    //                 bool success = IERC20(addr).transfer(partnerAddr, ownerAmount);
    //                 require(success, "j");
    //             }
    //         }
    //     } else if (person == 1 || singleChain) {
    //         //these are funds partner is providing
    //         if (singleChain) {
    //             //get new funds amount to reflect the partner funds
    //             assembly {
    //                 addr := calldataload(add(message.offset, 57))//MAGICNUMBERNOTE: fetching partnerToken, which sits at 57 + 32 = 89
    //                 partnerAmount := calldataload(add(message.offset, 121))//MAGICNUMBERNOTE: fetching partnerAmount, which starts at 121, uint
    //             }
    //             tokenAmounts[addr].ownerBalance += partnerAmount;
    //         }
    //         if (addr == NATIVE_TOKEN) {
    //             require(msg.value == partnerAmount, "k");
    //         } else {
    //             bool success = IERC20(addr).transferFrom(partnerAddr, address(this), partnerAmount);
    //             require(success, "j");
    //         }
    //     }
    // }
    
    // //NOTE: in multichain, chain on which secret holder is receiving funds must have both a shorter timeout than other chain. 
    //     //the reason for this is that we don't want secretholder to delay redeeming msg on chain where they are receiving to last second, then not leave nonsecretholder enough time to redeem on ther own chain. 
    //     //Secondly, we need that the timeout is always longer than the deadline for a chain, so that we cant have a msg pubbed, redeemed, and then erased, and then published again since the deadline hasn't passed.
    // function singleswapStake(bytes calldata message, bytes calldata signatures, uint entryToDelete, address owner, mapping(address => FeeStruct) storage tokenAmounts, mapping(uint => SwapStruct) storage seenSwaps) external returns(uint swapID) {
    //     uint deadline = doAnchorChecks(message);
    //     address partnerAddr;
    //     assembly { partnerAddr := calldataload(sub(message.offset, 3)) } //MAGICNUMBERNOTE: sits at finish at 29, and 29 - 32 = -3
    //     checkSignatures(keccak256(message), signatures, owner, partnerAddr);
    //     swapID = uint(keccak256(message));
    //     require(seenSwaps[swapID].timeout == 0, "C");

    //     bool singleChain = false;
    //     uint8 person;
    //     uint8 timeoutHours;
    //     if (MsgType(uint8(message[0])) == MsgType.SINGLECHAIN) {
    //         singleChain = true;
    //     } else {
    //         require(MsgType(uint8(message[0])) == MsgType.MULTICHAIN, "G");
    //         person = uint8(message[4]);
    //         timeoutHours = uint8(message[5]);
    //     }
    //     processFundsSingleswap(message, person, singleChain, partnerAddr, tokenAmounts);
    //     if (singleChain) {
    //         seenSwaps[swapID].timeout = deadline;
    //     } else {
    //         uint hashlock;
    //         assembly{ hashlock := calldataload(sub(message.length, 64)) }
    //         seenSwaps[swapID].hashlock = hashlock;
    //         seenSwaps[swapID].timeout = block.number + (timeoutHours * BLOCKS_PER_HOUR);
    //     }

    //     //gas saver, clears out old entries to make putting in our entry above less costly. First checks that deadline has expired, so that can't do replay attack. 
    //     if (block.number > seenSwaps[entryToDelete].timeout && seenSwaps[entryToDelete].hashlock == 0) {
    //         delete seenSwaps[entryToDelete];
    //     }
        
    // }

    // //only available/necessary if singleSwap is multichain
    // function singleswapRedeem(bytes calldata message, uint preimage, mapping(address => FeeStruct) storage tokenAmounts, mapping(uint => SwapStruct) storage seenSwaps) external returns(uint swapID, bool redeemed) {
    //     swapID = uint(keccak256(message));
    //     require(seenSwaps[swapID].hashlock != 0, "D"); //funds have already been redeemed, or wasn't a multichain in the first place!
    //     //valid redemption, should now send the proper funds to the proper person
        
    //     uint8 person = uint8(message[4]);
    //     //process funds
    //     address partnerAddr;
    //     uint amount;
    //     address addr;
    //     assembly { 
    //         partnerAddr := calldataload(sub(message.offset, 3))
    //         addr := calldataload(add(message.offset, 37))//MAGICNUMBERNOTE: fetching personToken, which sits at 37 + 32 = 69
    //         amount := calldataload(add(message.offset, 89))//MAGICNUMBERNOTE: fetching personToken, which starts at 89, uint
    //     }
        
    //     bool timedOut = block.number > seenSwaps[swapID].timeout;
    //     if (timedOut) {
    //         //has timed out, which means we want to return the funds to sender. This is the exact same code, but with values flipped. To avoid code duplication, 
    //         //we can instead just flip the person, so the funds return to owner/partner instead of partner/owner.
    //         person = (person == 0) ? 1 : 0;
    //     } else {
    //         //hasn't timed out yet
    //         require(seenSwaps[swapID].hashlock == uint(keccak256(abi.encodePacked(preimage))), "E");
    //     }
    //     if (person == 0) {
    //         //is owner, so owner paid, means partner should receive. OR, got flipped up above, so is owner, but partner paid, which means partner gets return
    //         if (addr == NATIVE_TOKEN) {
    //             payable(partnerAddr).transfer(amount);
    //         } else {
    //             bool success = IERC20(addr).transfer(partnerAddr, amount);
    //             require(success, "j");
    //         }
    //     } else {
    //         //is partner, so partner paid, owner should receive. OR, got flipped up above, so is partner, but owner paid, owner gets return
    //         tokenAmounts[addr].ownerBalance += amount;
    //     }
    //     if (timedOut) {
    //         //now safe to fully delete
    //         delete seenSwaps[swapID];
    //     } else {
    //         //just delete hashlock, not whole structure bc deadline may not have yet timed out, we don't want a replay attack
    //         delete seenSwaps[swapID].hashlock;
    //     }
    //     redeemed = (!timedOut); //returns value for redeemed, which is 0 if timedOut, 1 if not timedOut, as desired
    // }
    
    
     //TODO: I want to delete this. Keeping it around just for safety in case needed. If every re-added, would also need to add logic in the StormLib to call it.
    // /**
    // * update() checks the current balances described in the passed message, then updates just the nonce. Update is called when you want to  
    // * lock in a state to guarantee that you will never revert to a state before this. If you dont want to 
    // * stay live but dont want to settle, you can call this with the most recent message and go offline for a period of time,
    // * knowing startsettlment can not be called with a prior message, and no new messages will be signed, making you safe. 
    // * We only update nonce so its cheaper, but do all the checks so a faulty signed msg couldn't permanently lock funds (no higher
    // * nonced msgs, cant settle on this one, CP wont respond).
    // * update() is only valid for Unconditional messages from an external call, for obvious reasons.
    // * Not valid for a sharded Msg. Just call out to the watchtowers, sending them the double sig. TO DO: decide if want to make valid for shardedMsg
    // */
    // function update(bytes calldata message, bytes calldata signatures, address owner, mapping(uint => Channel) storage channels) external {        
    //     require (MsgType(uint8(message[0])) == MsgType.UNCONDITIONAL, "p");
    //     uint numTokens = uint(uint8(message[NUM_TOKEN]));
    //     address pSignerAddr;
    //     assembly { pSignerAddr := calldataload(add(message.offset, sub(NUM_TOKEN, 32))) } //MAGICNUMBERNOTE: pSignerAddr finishes at start of NUM_TOKEN, so we backtrack 32 bytes
    //     checkSignatures(keccak256(message[0: message.length - (32 * numTokens)]), signatures, owner, pSignerAddr); //MAGICNUMBERNOTE: dont take whole msg bc the last 32*numTokens bytes are the balanceTotals string, not part of signature.
    //     uint channelID = uint(keccak256(message[1: START_ADDRS + (numTokens * 20)]));
    //     Channel storage channel = channels[channelID];
    //     require(channel.exists, "u");
    //     require(!channel.settlementInProgress, "w");//User should just call startDispute instead.
    //     require(channel.balanceTotalsHash == uint160(bytes20(keccak256(message[message.length - (32 * numTokens): message.length]))), "E"); //MAGICNUMBER NOTE: take last numTokens values, since these are the uint[] balanceTotals

    //     uint _ownerBalance;
    //     uint _partnerBalance;
    //     uint balanceTotal;
    //     for (uint i = 0; i < numTokens; i++){
    //         assembly {
    //             let startBals := add(add(message.offset, START_ADDRS), mul(numTokens, 20))
    //             _ownerBalance := calldataload(add(startBals, mul(i, BALANCESTRUCT_UNIT)))
    //             _partnerBalance := calldataload(add(add(startBals, 32), mul(i, BALANCESTRUCT_UNIT)))
    //             balanceTotal := calldataload(add(add(startBals, mul(numTokens, BALANCESTRUCT_UNIT)), mul(i, 32)))
    //         }
    //         require(_ownerBalance + _partnerBalance == balanceTotal, "l");
    //     }
        
    //     //All looks good! Update nonce(the only thing we actually update)
    //     uint32 nonce;
    //     assembly { nonce := calldataload(add(message.offset, sub(message.length, add(32, mul(numTokens, 32))))) } //MAGICNUMBERNOTE: this comes from removing the balanceTotals, then skipping back 32 for the nonce
    //     require(channel.nonce < nonce, "x");
    //     channel.nonce = nonce;
    // } 


