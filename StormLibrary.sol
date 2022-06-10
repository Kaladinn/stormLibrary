// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

//IDEA: Kaladin Fees:
    //Constants: 
        //totalFee: x
        //Kaladin percentage: y
        //routeFee: x - (x * y)
        //Kaladin Fee: x * y. (i.e. Kaladin fee is a percentage of route fee.)
    //we have two fields, ownerTotalSent, partnerTotalSent, for each one of the tokens. These are only used during a settle call, or during a 
    //startDispute call. We could monkey around with where we want to pass them, just check that they are double signed. 
    //For the partnerTotalSent in each token, they are paying fees on this. So their token total is total - (total * totalFee). We then increment ownerTotal by total * routeFee.
    //For the ownerTotalSent, these fees are being paid to the partner, so we increment partnerFunds by routeFee and decrement ownerFunds by totalFee.
    //NOTE that an extra KaladinFee * (ownerTotalSent * partnerTotalSent) remains in the contract, but wont get added to owner funds.
    //Thus, when the owner goes to withdraw all of their funds at the very end, they can't withdraw all of the funds. The remaining funds are able to be claimed by Kaladin. We skim the difference!
    //This method saves us the need to set even more state variables after a swap completes.

    //These are just the fees... we also need to worry about KALADIMES!
        //For this, their amounts Kaladimes will be some function of the amount of ownerTotalSent, partnerTotalSent, where you receives more Kaladimes the more you send,
        //and contract owners are rewarded with significantly higher amounts.

    //Fees are checked in settle, settleSubset, in withdraw (after a dispute).

    //TODO: 
        //Call out to UNISWAP, add redemption for Kaladin, redemption for owner, contract factory => approve Kaladimes at init.

    //Additions needed:
        //Kaladin can only withdraw if lockCount == 0. we need that if owner withdraws, Kaladin can withdraw(to prevent owner keeping a single inconsequential swap open, stopping Kaladin from ever collecting fees)
            //but Kaladin can only withdraw if lockCount == 0 and owner has already withdraw, since Kaladin skimming differences.
            //TODO: make this better. One idea is to allow Kaladin to withdraw provided that they supply an array of [channelID, balanceTotalsHash]. For every one of these, they need to 
                //match with an current channelID, and the len(array) == lockCount. For each one, we add their totals to the tokenAmounts. Then after this, we can withdraw the difference between the tokenAmounts and the total in the contract
                //The difficulty here is that this requires the channels to not change rapidly, for our array will likely be out of date— for this, sean can stop allowing route calls for a bit before trying to take funds, which will help our chances
                //(we can do nothing about, increaseChannelFunds, settle, settleSubset calls). This will also be relatively expensive, so probably only makes sense to do this for high traffic contracts.
        //Function Kaladin can hit (with a signature?) to get paid.
        //Way for owner to withdraw without self destruct AND self destruct not possible till Kaladin withdraw. Or, self destruct also pays out to Kaladin. 

    //Special Notes:
        //The fee, given by fees / FEE_DENOM, are always truncated to the nearest integer.
        //If the fees are greater than the totals in the channel, then the amount for the channel is completely drained, even though this is less than the fees owed.
            // It is up to nodes to make sure this doesnt happen before signing messages.
        //If a shard reverts, the fees field isn't updated. However, if it succeeds: and ownerGiving, owner fees incremented; else, partner fees incremented.
    //Tricky Bits:
        //When figuring out how to pay Kaladimes, how do we know the conversion rate between a random IERC20 and a Kaladime? A: call out to Uniswap contract to get the conversion rate?
            //Are Kaladimes pegged to a value? Free floating? WOuld this value be a stablecoin or a fluctuating currency like ETHER?
        //How do we approve to the contract Kaladimes, so they can transferFrom and transfer and arbitrary amount.



    //Projected Fees for n tokens:
        //21k: for a call to chain
        //??: on chain logic
        //7300 * n: for call to partnerIERC20 transfers
        //5000 * n: for setting contract state variable balances
        //17300: 12300 for changing transferFrom(contract, partnerAddr)on Kaladime contract + 5000k for changing Kaladime state variable balance for owner
        //2500 * n: calls out to the Uniswap "price feeds"
        //Total: 38300 + ?? + 14800 * n.  



//TODO: get paying with one address (on enter, exit) but actually signing msgs with a separate one, so that a user
    //can use wallet to sign etner, get funds in wallet at exit, but wont have ot touch wallet for all of sigs. WIll just be touching the chromelocalstorage key for msg signing

//TO DO: make sure that the nonces of all the msg types are incremented appropriately (in here and protocol wise) so that there are no bugs with a potential > vs >=, etc.
//TO DO: determine if we want some notion of slashing for getting trumped. Would need a clause that only allows slash if trump 2+ higher. Can't do 1 higher, bc this happens when waiting in aRc or cLa if party goes unresponsive.
    //Im thinking not? And we reserve the slashing primarily for the shards? Just too hard for txs, bc we are trusting watchtowers with signed txs, and we need to give these to them to preserve liveness, so nothing to stop them from pubbing old txs, and causing a slashing.
    //Only real way I see us having slashing is if we incorporate CCs like BTC, and only send watchtowers CCs, not txs. Messy though, doesnt really seem worth it. 

    //Another slashing related idea is that maybe if a owner, partner submits startDispute, and then gets trumped, they get fully slashed. Something to do with watchtowers submitting startDispute and staking KLD, if they are trumped,
    //KLD slashed, but if they aren't trumped, their KLD doubles. IDK. Need to make sure that owner, partner can't collude, not send most recent txs, in order to intentionally slash a watchtower/hold their KLD ransom. 
     

//TO DO: include logic so that if an anchor call fails due to insufficient owner funds, then owner transfers funds to CP, 
    //to pay for the gas costs. Will require the use of an additional data structure so no replay repay gas attack possible.
    

//TO DO: change contract so that construct supports initializing with array of tokens, funds (in other words, calls out to addFundsToContract). 
    //DOUBLE TO DO: dont think this is possible due to IERC20's needing the contract address to be set for approve call, but can't be done until contract initialized
//TO DO: decide whether safer to have disputeBlockTimeout, shardBlockTimeouts be set on time, or on blocks.


//TO DO: remove any unnecessary intermediate variables to optimize gas.
//TO DO: make sure I dont declare a channel, but then use channels[channelID] unnecessarily later in the same fn. 

//TO DO: if makes a difference gas wise, cram all same slot storage variables in at once, rather than 1 at a time. 

//TODO: add selfdestruct() functionality? More complicated now, bc cant self destruct until sure that both Kaladin and owner have fully redeemed 

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";


// channelID:
//     uint32 blockAtAnchor:
//         this is the block at anchor (truncated to a uint32). Done so that guaranteed each channelID is unique. All subsequent msgs will have this embedded and will sign on the message with it embedded, but since it cannot be known before publish, 
//         the anchor msg will not be signed with this included. If starting dispute with anchor msg, care must be taken to strip out the blockAtAnchor in msg before checking sigs. Needs to be inserted so knows which channel is being referenced.
//     uint24 chainID 
//         (use to differentiate between two blockchains that may have naming overlap, so that is anchored into intended chain). I anticipate 2^24 is a high enough value to capture any chain we may need.
//     address partnerAddr
//         the address of the person providing funds. This is where funds are received from, and sent to. This sig is only checked in anchor and singleswapStake
//     address contractAddress
//     address pSignerAddr
//         the address that the partner person uses to sign messages. This may be the same as partnerAddr.
//     byte numTokens
//         represents number of 20 byte ERC20 addrs below that are in contract. Note this is limited to 255 by nature of being a byte. 
//     address[] tokens:
//         array of ERC. If first addr = 0x000000..0000 (20 bytes of 0), then represents ether. All other addresses assumed to be ERC20. 

// shardDataMsg: 
    // uint8[] shardStates
        //0 if reverted (no hashlock revealed), 1 if pushed forward (hashlock revealed)
       
// msgHash:
    // keccak256(
        // Passed in msg with trailing nonce removed (deadline removed if is initial msg)
        // shardDataMsg (ONLY IF MSGTYPE == SHARDED)
    // )
    
// balanceTotalsMsg:
    //uint[] balances
        //just an array of uints for the total amount in each token (sum of owner, partner amounts)

// balanceTotalsHash:
    //uint160(keccak256(balanceTotalsMsg))


//shardData: (static 70)
    //uint8 tokenIndex.  
        //Index of the token being traded on. 
    //uint8 ownerGivingOrReceiving: 0: ownerReceiving. 1: ownerGiving
        //says whether owner is giving token to partner, or whether owner receiving it from partner
    //uint amount 
        // amount being traded on
    //uint32 shardTimeout 
        //represents the unix timestamp at which time this shard will time out
    //uint hashlock



// msgType:
//     0: Initial
//     1: Unconditional
//     2: Sharded
//     3: Settle
//     4: SettleSubset
//     5: AddFundsToChannel
//     6: SingleChain
//     7: Multichain

// channelFunctionType:
//     0: ANCHOR
//     1: UPDATE
//     2: ADDFUNDSTOCHANNEL
//     3: SETTLE
//     4: SETTLESUBSET
//     5: STARTDISPUTE
//     6: WITHDRAW



// Messages:
//     Initial
//         byte msgType
//         (variable) channelID 
//         BalanceStruct[] balances
//             array of all the balances, given by ownerAmount, then partnerAmount, then ownerFees, then partnerFees
//                 ownerFees represent the total amount swapped through the channel, where owner was sender
//                 partnerFees represent the total amount swapped through the channel, where partner was sender
//                 NOTE: to get both of these to be fees, we need to divide them by the FEE_DENOM_TOTAL
//             For example, if there are two tokens in the channel, this will be 2 * (4 * 32) = 256 bytes long, arranged by ownerAmount0, partnerAmount0, ownerFees1, partnerFees1.
//             It is assumed balances in same order as tokens. Not side by side, bc balances change and channelID must be immutable. 
//         uint deadline
//             the block number by which this tx must be submitted. Used to scope validity of anchor signatures 
//     Unconditional
//         byte msgType
//         (variable) channelID 
//         BalanceStruct[] balances
//         uint32 nonce
//     Sharded
//         byte msgType
//         (variable) channelID
//         BalanceStruct[] balances
//         byte numShards
//             represents how many shards are attached to this Shard Msg
//         shardData[] shards
//             array of all the shards in the Shard msg
//         uint32 nonce
//     Settle
//         byte msgType
//         (variable) channelID 
//         BalanceStruct[] balances (length: numTokens * 2 * 32)
//     SettleSubset
//         byte msgType
//         (variable) channelID 
//         BalanceStruct[] balances
//         bool[] closeOutTokens
//         uint32 nonce
//     AddFundsToChannel
//         byte msgType
//         (variable) channelID 
//         (uint, uint)[] fundsToAdd
//         nonce 
// 05 01e92822 00002a d19B7fF9a32855321B94BD96E9d0a345480AD701 26915193861AeB14ecb29e6470C09ca3a71Fbb0f d19B7fF9a32855321B94BD96E9d0a345480AD701 03 0000000000000000000000000000000000000000 F96b2CFf7E588a8Bd07cEfdD8595B6573bebf753 8ea749CbC644E2Ada55479Dd124a995bCC5F4F35 000000000000000000000000000000000000000000000000000000000000005f 000000000000000000000000000000000000000000000000000000000000005f 0000000000000000000000000000000000000000000000000000000000000014 0000000000000000000000000000000000000000000000000000000000000014 00000000000000000000000000000000000000000000000000000000000017d1 00000000000000000000000000000000000000000000000000000000000017d1 00000005
//     SingleChain
//         byte msgType
//         5 bytes zeros (padding) //done so that complies with anchor format, doAnchorChecks can be reused on this
//         uint24 chainID
//         address partnerAddr
//         address contractAddress
//         address ownerToken
//         address partnerToken
//         uint ownerAmount
//         uint partnerAmount
//         uint deadline
//     MultiChain
//         byte msgType
//         3 bytes zeros (padding) //done so that complies with anchor format, doAnchorChecks can be reused on this. TODO: fix this
//         bool owner/partnerFlag. 00 if owner is providing the funds, 01 if partner providing
//         uint8 blockHourTimeout
//         uint24 chainID
//         address partnerAddr
//         address contractAddress
//         address personToken
//         uint personAmount
//         uint hashlock
//         uint deadline

//DESIGN DECISION: All timeouts that are checked in contract are valid up unitl that timeout occurs. For example, if the time is block 1000, then submission is valid at block 998, 999, 1000, but then invalud at 1001. 
    //Means you either check within deadline,timeout, valid if block.number <= timeout. For checking whether invalid, we make sure that block.number > timeout
    //for shardTimeout, final hour means less than 1 hour of blocks remaining. If exactly 1 hour remaining, does not count as a slashing case (the no TuringInComplete case)
    
library StormLib {
    event Anchored(uint indexed channelID, bytes message, bytes partnerSig);
    event Settled(uint indexed channelID, bytes tokenBalances);
    event SettledSubset(uint indexed channelID, uint32 indexed nonce, bytes tokenBalances);
    event DisputeStarted(uint indexed channelID, uint32 indexed nonce, bytes message);
    event ShardStatesAtDisputeStart(uint indexed channelID, uint32 indexed nonce, uint8[] shardDataMsgArr);
    event ShardStateChanged(uint indexed channelID, uint32 indexed nonce, uint8[] indexed shardNos, uint preimage);
    event FundsAddedToChannel(uint indexed channelID, uint32 indexed nonce, bytes tokensAdded);
    event Swapped(uint indexed msgHash); //in singlechain case, means that swap has completed. In multichain, means that has been anchored
    event MultichainRedeemed(uint indexed msgHash, bool redeemed, uint hashlock); //redeemed here is a variable that says whether the propoer preimage shown to unlcok funds. If false, means that timeout occurred and funds reverted back to their sources. if redeemed, hashlock is the proper preimage used.

    
    enum ChannelFunctionTypes { ANCHOR, SETTLE, SETTLESUBSET, ADDFUNDSTOCHANNEL, STARTDISPUTE, WITHDRAW }
    enum MsgType { INITIAL, UNCONDITIONAL, SHARDED, SETTLE, SETTLESUBSET, ADDFUNDSTOCHANNEL} //, SINGLECHAIN, MULTICHAIN } TODO: uncomment if using singleswap
    
    struct SwapStruct {
        uint hashlock;
        uint timeout;
    }

    struct FeeStruct {
        uint ownerBalance; //how much available of this token the owner has
        uint KaladinBalance; //how much in fees Kaladin has accrued that is sitting in contract, waiting to be redeemed.
    }


    struct BalanceStruct {
        uint ownerBalance;
        uint partnerBalance;
        uint ownerFee;
        uint partnerFee;
    }


    struct Channel {
        //slot 0
        bool exists; //Indicates that channel exists.
        bool settlementInProgress;
        uint32 nonce; 
        uint32 disputeBlockTimeout; //blockNumber before which a trump of the provided startSettlment message can be trumped w a higher nonce message. After this ends, can't start new settlement. However, before you can't withdraw. Important for notion of withdraw for non Sharded msgs.
        uint160 balanceTotalsHash; //hash of the total value locked into the contract for each token
        //slot 1
        uint msgHash; //Stores the keccak of the message used in startDispute. We do this so that we can check that in withdraw, this is the same msg as was used in startDispute. We need it bc we dont store all of balances in shard0, instead relying on the cheaper option of repassing them in calldata in withdraw.
    }


    uint constant BLOCKS_PER_HOUR = 240;
    
    //MAGIC NUMBERS
    uint constant DISPUTE_BLOCK_HOURS = 1;
    uint8 constant NUM_TOKEN = 68;
    uint8 constant START_ADDRS = 69;
    uint8 constant TOKEN_PLUS_BALANCESTRUCT_UNIT = 148; //for 20 byte addr + 64 bytes bals + 64 bytes fees
    uint8 constant BALANCESTRUCT_UNIT = 128; //for 64 btes vals, 64 bytes fees
    uint8 constant PARTNERADDR_OFFSET = 4; //gives the offset that you subtract from start of message to get the partner addr in a calldataload
    address constant NATIVE_TOKEN = address(0);
    IERC20 constant KALADIMES_CONTRACT = IERC20(address(0)); //TODO: make this a real contract
    address constant KALADIMES_BAL_MAP_INDEX = address(1); //constant, essentially a mapping key, to store how much Kaladime the owner has earned in yield. Cheaper to store, then call out all at once to contract rather than call transferFrom for each settle
    address constant KALADIN_ADDR = address(2); //TODO: remove 2 as placeholder. This is address that Kaladin will remove funds from, call withdraw from. 
    uint constant LEN_SHARD = 70;
    //With the current vals below, we have it work out that the fee receiver gets a bip, and Kaladin gets 1/10 of a bip. Thus, we anticipate that with fees of 1.1 bips, receiver gets 1, Kal gets 0.1. (1.1 / 11 - 0.1, as desired.)
    uint constant FEE_DENOM_KAL = 11; //is the denom for the percentage of the fees that Kaladin takes
    uint constant FEE_DENOM_TOTAL = 9090;// corresponds to 0.00011 of which 0.0001 to CP, 0.00001 to Kaladin

    /**
     * This has two endpoints bundled into one to save gas; one to withdraw, and one to add funds.
     * Tokens, funds dictate the tokens and how much of them to either add or subtract from contract
     * Sends funds to owner. Note that any IERC20s that have approved this contract to spend from an allowance will need to be set back to 0 independently.
     * NOTE: by default, any time the other withdraws funds from the contract, it will also pay out Kaladin fees. Kaladin can independently collect their fees by calling updateChannelFunds in the given contrct.
     */
    function updateContractFunds(address[] calldata tokens, uint[] calldata funds, mapping(address => FeeStruct) storage tokenAmounts, address owner, bool addingFunds) external {
        if (addingFunds) {
            for (uint i = 0; i < tokens.length; i++) {
                bool success = IERC20(tokens[i]).transferFrom(owner, address(this), funds[i]); //TO DO: consider reentrancy attacks here.
                require(success, "j"); 
                tokenAmounts[tokens[i]].ownerBalance += funds[i];
            }
            tokenAmounts[NATIVE_TOKEN].ownerBalance += msg.value;
        } else {
            for (uint i = 0; i < tokens.length; i++) {
                //settle KaladinBals
                if (tokens[i] == NATIVE_TOKEN) {
                    payable(KALADIN_ADDR).transfer(tokenAmounts[tokens[i]].KaladinBalance);
                } else {
                    IERC20(tokens[i]).transfer(KALADIN_ADDR, tokenAmounts[tokens[i]].KaladinBalance); 
                }
                tokenAmounts[tokens[i]].KaladinBalance = 0;
                if (owner != address(0)) {
                    //settle ownerBals
                    tokenAmounts[tokens[i]].ownerBalance -= funds[i]; //This will throw error if underflow bc trying to withdraw more funds than are owned.
                    if (tokens[i] == NATIVE_TOKEN) {
                        payable(owner).transfer(funds[i]);
                    } else {
                        IERC20(tokens[i]).transfer(owner, funds[i]); 
                    }
                    // delete tokenAmounts[address(tokensInContract[i])];         //TODO: **only is valid question if terminateFlag!! is it more cheap/get a gas refund to delete all of the metadata? Or is this done automatically since its a self destruct? If not, delete this and below line. 
                }
            }  
        }
    }



    //function that will revert if not eligble for withdraw. Called by both clients to know if able to withdraw, and internally by the withdraw function. 
    function eligibleForWithdraw(bytes calldata message, Channel storage channel, uint numTokens) public view returns (uint8 numShards) {
        require(channel.exists && channel.settlementInProgress, "b");
        require(block.number > channel.disputeBlockTimeout, "c");

        uint shardPointer = START_ADDRS + (TOKEN_PLUS_BALANCESTRUCT_UNIT * numTokens) + 1; //pointing to the first shard
        if (MsgType(uint8(message[0])) == MsgType.SHARDED) {
            numShards = uint8(message[shardPointer - 1]); //bc shardPointer pointing to first object after numShards
        }
        //checks that all of the timeouts have occurred.
        uint timeout;
        for (uint8 i = 0; i < numShards; i++) {
            uint8 shardState = uint8(message[message.length - 32 - (numTokens - i)]);
            
            if (shardState == 0) {
                //means that hasn't been pushed forward, so we must wait the full time out. if has been, can't get reverted, so we can skip checking timoeut
                assembly { timeout := calldataload(add(message.offset, add(shardPointer, 6))) } //so ends at +38 into shard, which is end of shardTimeout
                require(block.timestamp > uint(uint32(timeout)), "d"); //uint(uint32( bc need to clear away garbage that came before shardTimeout, and only examine last 4 bytes
            } 
            shardPointer += LEN_SHARD; //jump ahead to next shard
        }
    }

    

    /**
     * checks that given a message and two pairs of signatures, the signatures are valid for the keccak of the message,
     * given that ownerSignature matches owner of the contract, and partnerSignature matches partnerAaddress that is embedded in message as part of pairID.
     * Signatures are ECDSA sigs in the form v || r || s. Also, signatures in form ownerSignature | partnerSignature.
     * Is anchor states whether we should use partnerAddr(anchoring), or pSignerAddr(everything else)
     */
    function checkSignatures(bytes32 messageHash, bytes calldata signatures, address owner, address nonOwnerAddr) private pure {
        bytes32 r;
        bytes32 s;
        assembly {
            r := calldataload(add(signatures.offset, 0))
            s := calldataload(add(signatures.offset, 32))
        }
        uint8 magicETHNumber = 27; //27 is magic eth # to add to v value, per ETH docs
        require(address(ecrecover(messageHash, magicETHNumber + uint8(signatures[64]), r, s)) == owner, "n");

        assembly {
            r := calldataload(add(signatures.offset, 65))
            s := calldataload(add(signatures.offset, 97))
        }
        require(address(ecrecover(messageHash, magicETHNumber + uint8(signatures[129]), r, s)) == nonOwnerAddr, "o"); 
    }


    //checks that there is sufficient liquidity to add tokens, and then do so. 
    function lockTokens(bytes calldata tokens, uint numTokens, address partnerAddr, mapping(address => FeeStruct) storage tokenAmounts) private returns ( uint160 ) {
        uint _ownerBalance;
        uint _partnerBalance;
        address tokenAddress;
        uint[] memory balances = new uint[](numTokens);
        uint startBal = numTokens * 20;

        for (uint i = 0; i < numTokens; i++) {
            assembly { 
                tokenAddress := calldataload(add(sub(tokens.offset, 12), mul(i, 20))) //MAGICNUMBERNOTE: bc tokens starts at first tokenAddr, is 20 bytes, so we go back -12 so that -12+32 ends at 20
                _ownerBalance := calldataload(add(tokens.offset, add(startBal, mul(i, BALANCESTRUCT_UNIT))))
                _partnerBalance := calldataload(add(tokens.offset, add(startBal, add(32, mul(i, BALANCESTRUCT_UNIT)))))
            }
            balances[i] = _ownerBalance + _partnerBalance;
            if (i == 0 && tokenAddress == NATIVE_TOKEN) {
                //process ETH
                require(msg.value == _partnerBalance, "k");
            } else {
                IERC20 token = IERC20(tokenAddress);
                bool success = token.transferFrom(partnerAddr, address(this), _partnerBalance);
                require(success, "j");
            }
            tokenAmounts[tokenAddress].ownerBalance -= _ownerBalance; //solidity 0.8.x should catch overflow here. 
        }
        //have looped through all of them, update the balances in the tokenAmounts, and also encountered no errors! can now set balances to be balances in this msg.
        return uint160(bytes20(keccak256(abi.encodePacked(balances))));
    }


    function doAnchorChecks(bytes calldata message) private view returns (uint) {
        uint assemblyVariable; //first is chainID, then is contractAddress, then finally deadline
        assembly { assemblyVariable := calldataload(sub(message.offset, 24)) } //MAGICNUMBERNOTE: chainID  at 5-7,  so -24 + 32 = 8, will have last byte as pos. 7, as desired!
        require(uint(uint24(assemblyVariable)) == block.chainid, "q"); //have to cast it to a uint24 bc thats how it is in message, to strip out all invalid data before it, then recast it to compare it to the chainid, which is a uint. 

        assembly { assemblyVariable := calldataload(add(message.offset, sub(NUM_TOKEN, 52))) } //MAGICNUMBERNOTE: bc contractAddress ends at NUM_TOKEN - pSignerAddr, or NUM_TOKEN - 20
        require(address(uint160(assemblyVariable)) == address(this), "r");

        assembly{ assemblyVariable := calldataload(add(message.offset, sub(message.length, 32))) } //MAGICNUMBERNOTE: -32 from end bc deadline uint, at very end msg
        require(block.number <= assemblyVariable, "t");
        return assemblyVariable;
    }

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
    
    
    /**
     * Entry point for anchoring a pair transaction. If ETH is a token, anchor should be called 
     * by the partner, not the contract owner, since the partner must send value in through msg.value. This function only 
     * succeeds if the nonce is zero, deadline hasnt passed, and there is no open trading pair between these two people for 
     * the token pair. Only accepts an Initial message. 
     */
    function anchor(bytes calldata message, bytes calldata signatures, address owner, mapping(uint => Channel) storage channels, mapping(address => FeeStruct) storage tokenAmounts) external returns (uint) {
        doAnchorChecks(message);
        address partnerAddr;
        assembly { partnerAddr := calldataload(sub(message.offset, PARTNERADDR_OFFSET)) } 
        checkSignatures(keccak256(message), signatures, owner, partnerAddr);
        require(MsgType(uint8(message[0])) == MsgType.INITIAL, "p");
    
        uint numTokens = uint(uint8(message[NUM_TOKEN])); //otherwise, when multiplying, will overflow
        
        uint channelID = uint(keccak256(abi.encodePacked(uint32(block.number), message[5: START_ADDRS + (numTokens * 20)]))); //calcs channelID, inserting the block number in front. 
        require(!channels[channelID].exists, "s");

        uint160 balanceTotalsHash = lockTokens(message[START_ADDRS : START_ADDRS + (TOKEN_PLUS_BALANCESTRUCT_UNIT * numTokens)], numTokens, partnerAddr, tokenAmounts);
        Channel storage channel = channels[channelID];
        channel.exists = true;
        channel.balanceTotalsHash = balanceTotalsHash;
        return channelID;
    }

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

    //loop over the tokens, and if the balance field is not 0, then we make the requisite calls
    function addFundsHelper(bytes calldata message, uint numTokens, mapping(address => FeeStruct) storage tokenAmounts) private returns (uint160 balanceTotalsHashNew) {
        address tokenAddress;
        uint amountToAddOwner;
        uint amountToAddPartner;
        uint prevBalanceTotal;
        address partnerAddr; //is calced here not in addFundsToChannel, bc msg sig was based off of pSignerAddr, whihc may not actually have possession of funds
        assembly { partnerAddr := calldataload(sub(message.offset, 4)) }//MAGICNUMBERNOTE: -4 bc ends at 28, 28 - 32 = -4

        uint[] memory balanceTotalsNew = new uint[](numTokens);
        for (uint i = 0; i < numTokens; i++) {
            assembly { 
                let startBalOwner := add(add(add(message.offset, START_ADDRS), mul(20, numTokens)), mul(i, 64)) //MAGICNUMBERNOTE: add 20 * numTokens to this to get start of balances, then jump over 32 +32 bytes for the new amts adding
                tokenAddress := calldataload(add(add(message.offset, sub(START_ADDRS, 12)), mul(i, 20)))
                amountToAddOwner := calldataload(startBalOwner)
                amountToAddPartner := calldataload(add(startBalOwner, 32))
                prevBalanceTotal := calldataload(add(message.offset, sub(message.length, mul(32, sub(numTokens, i))))) //MAGICNUMBERNOTE: Go back (numTokens - i) * 32 bytes to get to the ith prevBalanceTotal
            }
            //process any owner added funds
            if (amountToAddOwner != 0) {
                tokenAmounts[tokenAddress].ownerBalance -= amountToAddOwner;
            }

            //process any partner added funds
            if (i == 0 && tokenAddress == NATIVE_TOKEN && amountToAddPartner != 0) {
                //is ETH. Process appropriately
                require(msg.value == amountToAddPartner, "k"); 
            } else if (amountToAddPartner != 0) {
                IERC20 token = IERC20(tokenAddress);
                bool success = token.transferFrom(partnerAddr, address(this), amountToAddPartner);
                require(success, "j");
            }
            balanceTotalsNew[i] = prevBalanceTotal + amountToAddOwner + amountToAddPartner;
        }
        balanceTotalsHashNew = uint160(bytes20(keccak256(abi.encodePacked(balanceTotalsNew))));
    }

    //add extra owner and partner funds to a channel, provided it is not settling?
    //check both signatures
    //check that channel exists and is not settling. 
    //check the nonce; must be greater than nonce stored. For protocol, this nonce should be equal to the highest nonced msg seen thus far in the channel, so that can still arbitrate on other msg, but also locks in funds at this state.Furthermore, strict greater than prevents replay attack with addFunds calls.
    //For each of the funds given, if not zero, try to add them from the contract(owner), or make the requisite IERC20 calls.
    function addFundsToChannel(bytes calldata message, bytes calldata signatures, address owner, mapping(uint => Channel) storage channels, mapping(address => FeeStruct) storage tokenAmounts) external returns (uint channelID, uint32 nonce) {
        require (MsgType(uint8(message[0])) == MsgType.ADDFUNDSTOCHANNEL, "p");
        uint numTokens = uint(uint8(message[NUM_TOKEN]));
        address pSignerAddr;
        assembly { pSignerAddr := calldataload(add(message.offset, sub(NUM_TOKEN, 32))) } //MAGICNUMBERNOTE: pSignerAddr finishes at start of NUM_TOKEN, so we backtrack 32 bytes        
        checkSignatures(keccak256(message[0: message.length - (32 * numTokens)]), signatures, owner, pSignerAddr); //MAGICNUMBERNOTE: dont take whole msg bc the last 32*numTokens bytes are the balanceTotals string, not part of signature.
        
        channelID = uint(keccak256(message[1: START_ADDRS + (uint(uint8(message[NUM_TOKEN])) * 20)]));  
        Channel storage channel = channels[channelID];
        require(channel.exists, "u");
        require(!channel.settlementInProgress, "w");
        require(channel.balanceTotalsHash == uint160(bytes20(keccak256(message[message.length - (32 * numTokens): message.length]))), "E");  //MAGICNUMBER NOTE: take last numTokens values, since these are the uint[] balanceTotals      

        assembly { nonce := calldataload(add(message.offset, sub(message.length, add(32, mul(numTokens, 32))))) } //MAGICNUMBERNOTE: this comes from removing the balanceTotals, then skipping back 32 for the nonce
        require(nonce > channel.nonce, "x"); //TO DO: probably not necessary? Could only fail if partners not following protocol.
        
        channel.balanceTotalsHash = addFundsHelper(message, numTokens, tokenAmounts);
        //set nonce
        channel.nonce = nonce;
    }

    //here, it is assumed that fee1 > fee2, or person 1 losing net money, person 2 gaining net money, before consider Kaladime fees.
    //First, we calculate the fees that each person owes Kaladin based on their fee1, fee2 number. Now, we look at how much they owe each other.
    //Primary objective is to get Kaladin as much as they are due, then have partners pay each other, and also to make sure that fee1, fee2 represent how much was paid in fees to Kaladin, 
    //which is the number that is used to calculate their number of Kaladimes. 
    //1. Check whether person who is receiving net money can pay their Kaladime fees with their balance plus the net gain from their partner. 
        //If they can't, we suck out all of their funds, and set their contribution equal to their bal + amount from their partner, and set that they are sending their partner nothing. 
        //If they can, we just decrement their funds.
    //2. Now, check whether person who is losing money can pay their Kaladime fees, with addition that their CP may not be giving them money, if they couldn't pay Kaladime fees.
        //If they can't, we check how short they are.
            //If they can't even pay fee w/ balance + what downstream paid them, then their contribution to downstream (CtD) is zero. If they can do that, but can't pay full contribution to downstream, 
                //then CtD is the amount they pay downstream before running out of funds.
            //Now, we check whether the downstream was actually able to their fees if they lost fee1To2 and only got CtD. If they still could, we just update their balance to reflect getting CtD, not the full fee1To2.
            //If they can't, we set their balance to 0, to reflect paying the full fees. Then, the fees they actually paid are proportial to how much they originally had + how much they sent to 1 + CtD.
        //If they can, we just decrement their balance proportional to paying those fees, and we exit.

    //In the end, an individual can lose money based on whether their CPs fees end up being greater than the channel fees, but Kaladin will never give out more Kaladimes that they receive in fees (up to a constant of proportionality).
    function feeLogic(uint bal1, uint bal2, uint fee1, uint fee2) private pure returns (uint, uint, uint, uint) {
            //partner is gaining funds from fees, but may owe more than they can pay, to Kaladin
            fee1 = uint(fee1 / FEE_DENOM_TOTAL); //convert fee from total sent through channel, to amount acutally needing to pay.
            fee2 = uint(fee2 / FEE_DENOM_TOTAL);
            uint KaladinFee1 = uint(fee1 / FEE_DENOM_KAL);
            uint KaladinFee2 = uint(fee2 / FEE_DENOM_KAL);
            uint fee2To1 = fee2 - KaladinFee2;
            uint fee1To2 = fee1 - KaladinFee1;
            uint originalBal2 = bal2;
            if (bal2 + (fee1To2 - fee2To1) < KaladinFee2) {
                //bal2 is not able to pay the full Kaladin Fee. They can only pay a partial. So, we will ignore any money sent to them.
                //so, we set their fees paid(for Kaladime purposes) to be their entire balance plus what is paid to them by the CP
                fee2 = (bal2 + fee1To2) * FEE_DENOM_KAL;
                bal2 = 0;
                fee2To1 = 0;
            } else {
                bal2 = bal2 + (fee1To2 - fee2To1) - KaladinFee2;
            }
            if (bal1 < (fee1To2 - fee2To1) + KaladinFee1) {
                uint fee1To2Actual = (bal1 + fee2To1) < KaladinFee1 ? 0 : KaladinFee1 - (bal1 + fee2To1);
                fee1 = (bal1 + fee2To1) * FEE_DENOM_KAL;
                bal1 = 0;
                if (bal2 < (fee1To2 - fee1To2Actual)) {
                    //means wont be able to afford the fees. Will have actually paid less. So, their funds go to zero, and their fees are now a function of their original balance + how much they were paid
                    bal2 = 0;
                    fee2 = (originalBal2 + fee2To1 + fee1To2Actual) * FEE_DENOM_KAL;
                } else {
                    bal2 -= (fee1To2 - fee1To2Actual);
                }
            } else {
                bal1 -= ((fee1To2 - fee2To1) + KaladinFee1);
            }
            return (bal1, bal2, fee1 / FEE_DENOM_KAL, fee2 / FEE_DENOM_KAL);
    }

    //message starts at where the owner, partner balances will be.
    //This is called by both withdraw and settle/settlesubset. If its withdraw, we have already built out the balanceStruct, so we dont do that here. We have also checked that the balances dont exceed the 
    //balanceTotal, so again, we only do this if settle/settleSubset. 
    function calcBalsAndFees(bytes calldata message, BalanceStruct memory balanceStruct, uint balanceTotal, address partnerAddr, uint i) private returns (address tokenAddress) {
        bool isSettle = (MsgType(uint8(message[0])) == MsgType.SETTLE || MsgType(uint8(message[0])) == MsgType.SETTLESUBSET);   
             
        if (isSettle) {
            uint numTokens = uint(uint8(message[NUM_TOKEN]));
            assembly { calldatacopy(add(balanceStruct, 32), add(add(add(message.offset, START_ADDRS), mul(numTokens, 20)), mul(i, BALANCESTRUCT_UNIT)), BALANCESTRUCT_UNIT) }
            require(balanceStruct.ownerBalance + balanceStruct.partnerBalance == balanceTotal, "l");
        }
        assembly { tokenAddress := calldataload(add(add(message.offset, sub(START_ADDRS, 12)), mul(i, 20))) }
    
        
        if (balanceStruct.ownerFee > balanceStruct.partnerFee) {
            (balanceStruct.ownerBalance, balanceStruct.partnerBalance, balanceStruct.ownerFee, balanceStruct.partnerFee) = feeLogic(balanceStruct.ownerBalance, balanceStruct.partnerBalance, balanceStruct.ownerFee, balanceStruct.partnerFee);
        } else {
            (balanceStruct.partnerBalance, balanceStruct.ownerBalance, balanceStruct.partnerFee, balanceStruct.ownerFee) = feeLogic(balanceStruct.partnerBalance, balanceStruct.ownerBalance, balanceStruct.partnerFee, balanceStruct.ownerFee);
        }
        //now, ownerFee and partnerFee correspond to the amount they should pay Kaladin
        uint conversionRate = 1; //TODO: call out to uniswap to get our actual conversion rate

        if (balanceStruct.partnerBalance != 0) {
            if (tokenAddress == NATIVE_TOKEN) {
                payable(partnerAddr).transfer(balanceStruct.partnerBalance);
            } else {
                IERC20(tokenAddress).transfer(partnerAddr, balanceStruct.partnerBalance);
            }
        }
        
        KALADIMES_CONTRACT.transferFrom(address(this), partnerAddr, conversionRate * balanceStruct.partnerFee); 
        balanceStruct.ownerFee *= conversionRate;
        return (tokenAddress);
    }

    //helper that distributes the funds, used by settle and settlesubset
    function distributeSettleTokens(bytes calldata message, uint numTokens, mapping(address => FeeStruct) storage tokenAmounts, bool isSettleSubset) private returns (uint160) {
        address partnerAddr;
        assembly { partnerAddr := calldataload(sub(message.offset, 4)) }//MAGICNUMBERNOTE: -4 bc ends at 28, 28 - 32 = -4
        uint totalKLD;
        uint[] memory balanceTotalsNew = new uint[]((isSettleSubset ? numTokens : 0)); //TO DO: make sure this costs no gas if in ! isSettleSubset case
        for (uint i = 0; i < numTokens; i++) {
            uint balanceTotal;
            assembly { balanceTotal := calldataload(add(add(add(message.offset, START_ADDRS), mul(numTokens, TOKEN_PLUS_BALANCESTRUCT_UNIT)), mul(i, 32))) } 
            if (balanceTotal != 0 && (!isSettleSubset || (uint8(message[START_ADDRS + (TOKEN_PLUS_BALANCESTRUCT_UNIT * numTokens) + i]) == 1))) {
                //should settle this token. Either bc nonempty and settle, or nonempty and subsetSettle with flag set
                BalanceStruct memory balanceStruct;
                address tokenAddress = calcBalsAndFees(message, balanceStruct, balanceTotal, partnerAddr, i);
                totalKLD += balanceStruct.ownerFee;
                tokenAmounts[tokenAddress].ownerBalance += balanceStruct.ownerBalance;
                tokenAmounts[tokenAddress].KaladinBalance += (balanceStruct.ownerFee + balanceStruct.partnerFee);
                if (isSettleSubset) {
                    //is subset, so we want to track the new balanceTotals
                    balanceTotalsNew[i] = 0;
                }
            }  
            else if (isSettleSubset) {
                //is subset, but we aren't settling this token, so we just keep it the same as before
                balanceTotalsNew[i] == balanceTotal;
            }  
            //NOTE: in case where balanceTotal == 0 and isSettleSubset, then we dont set the balanceTotalsNew[i]. This is okay, as balanceTotalsNew defaults to 0. 
        }
        tokenAmounts[KALADIMES_BAL_MAP_INDEX].ownerBalance += totalKLD;
        return uint160(bytes20(abi.encodePacked(balanceTotalsNew)));
    }

    //TO DO: if any cheaper, combine this and settleSubset into one function. Need to test if it inc/dec funds for publishing contract and also flows.
    //TO DO: I have eliminated checks that msg.sender == partnerAddr, ownerAddr. This allows watchtower called settle. Are we okay with this? Seems safe to me.
    /**
     * Requires a settle message. When two parties agree they want to settle out to chain, they can sign a settle message. This is 
     * the expected exit strategy for a channel. Because its agreed upon as the last message, it is safe to immediately distribute funds
     * without needing to wait for a settlement period. 
     */
    function settle(bytes calldata message, bytes calldata signatures, address owner, mapping(uint => Channel) storage channels, mapping(address => FeeStruct) storage tokenAmounts) external returns(uint channelID) {
        require (MsgType(uint8(message[0])) == MsgType.SETTLE, "p"); 

        uint numTokens = uint(uint8(message[NUM_TOKEN]));
        channelID = uint(keccak256(message[1: START_ADDRS + (numTokens * 20)]));
        address pSignerAddr;
        assembly { pSignerAddr := calldataload(add(message.offset, sub(NUM_TOKEN, 32))) } //MAGICNUMBERNOTE: pSignerAddr finishes at start of NUM_TOKEN, so we backtrack 32 bytes        
        checkSignatures(keccak256(message[0: message.length - (32 * numTokens)]), signatures, owner, pSignerAddr); //MAGICNUMBERNOTE: dont take whole msg bc the last 32*numTokens bytes are the balanceTotals string, not part of signature.
     
        require(channels[channelID].exists, "u");
        require(channels[channelID].balanceTotalsHash == uint160(bytes20(keccak256(message[message.length - (32 * numTokens): message.length]))), "E"); //MAGICNUMBER NOTE: take last numTokens values, since these are the uint[] balanceTotals
        
        distributeSettleTokens(message, numTokens, tokenAmounts, true);
        
        //clean up
        delete channels[channelID];
    }


    function settleSubset(bytes calldata message, bytes calldata signatures, address owner, mapping(uint => Channel) storage channels, mapping(address => FeeStruct) storage tokenAmounts) external returns(uint channelID, uint32 nonce) {
        require (MsgType(uint8(message[0])) == MsgType.SETTLESUBSET, "p");

        uint numTokens = uint(uint8(message[NUM_TOKEN]));
        channelID = uint(keccak256(message[1: START_ADDRS + (numTokens * 20)]));
        address pSignerAddr;
        assembly { pSignerAddr := calldataload(add(message.offset, sub(NUM_TOKEN, 32))) } //MAGICNUMBERNOTE: pSignerAddr finishes at start of NUM_TOKEN, so we backtrack 32 bytes        
        checkSignatures(keccak256(message[0: message.length - (32 * numTokens)]), signatures, owner, pSignerAddr); //MAGICNUMBERNOTE: dont take whole msg bc the last 32*numTokens bytes are the balanceTotals string, not part of signature.
        require(channels[channelID].exists, "u"); 
        require(channels[channelID].balanceTotalsHash == uint160(bytes20(keccak256(message[message.length - (32 * numTokens): message.length]))), "E"); //MAGICNUMBER NOTE: take last numTokens values, since these are the uint[] balanceTotals
        
        //check that sender of msg is partner, so we know partner has a double sig they could go to chain with for the UncondiitonalSubsetMessage after the SettleSubset msg is published
        assembly { pSignerAddr:= calldataload(sub(message.offset, 4)) } //MAGICNUMBERNOTE: -4 bc ends at 28, 28 - 32 = -4
        require(msg.sender == pSignerAddr, "I");
    
        require(!channels[channelID].settlementInProgress, "w"); //Cant distribute if settling; don't know which direction to shove the shards.
        
        assembly { nonce := calldataload(add(message.offset, sub(message.length, add(32, mul(numTokens, 32))))) } //MAGICNUMBERNOTE: this comes from removing the balanceTotals, then skipping back 32 for the nonce
        require(nonce > channels[channelID].nonce, "x");

        channels[channelID].balanceTotalsHash = distributeSettleTokens(message, numTokens, tokenAmounts, false);
        channels[channelID].nonce = nonce;
    }

     
    /** 
     */
    function updateShards(Channel storage channel, bytes calldata message, MsgType msgType, uint numTokens) private {
        //check that startDispute is valid. TO DO: check all of these operations, esp assembly, for overflow
        uint shardPointer = START_ADDRS + (TOKEN_PLUS_BALANCESTRUCT_UNIT * numTokens); //points to byte for numShards
        uint8 numShards = (msgType == MsgType.SHARDED) ? uint8(message[shardPointer]) : 0; 
        shardPointer += 1; //point to first shards tokenIndex
        uint[] memory balanceTotalsWithShards = new uint[](numTokens);
        for (uint8 i = 0; i < numShards; i++) { 
            //looping over ownerGivingOrReceivingFirst in shard in shardData
            uint amount;
            assembly { amount := calldataload(add(message.offset, add(shardPointer, 2))) } //point this to the start of amount, which is 2 after tokenIndex
            balanceTotalsWithShards[uint8(message[shardPointer])] += amount;
            //looped over amounts in the shard, now lets increment the shardPointer to jump and point to the next shard
            shardPointer += LEN_SHARD; //use LEN_SHARD to jump ahead to next shards tokenIndex
        }
        //We have updated all of the shards. Now, we need to check whether for a given token, it will exceed the allotted balance in the channel.
        //we do this by looping over all the balances, adding how much the shards will add to these when settled, making sure no overflow when compared with the stored balanceTotals
        uint startBal = START_ADDRS + (numTokens * 20);
        for (uint i = 0; i < numTokens; i++) {
            uint balanceTotal;
            uint notInShards;
            assembly {
                let startOwnerBal := add(message.offset, add(startBal, mul(BALANCESTRUCT_UNIT, i)))
                notInShards := add(calldataload(startOwnerBal), calldataload(add(startOwnerBal, 32)))
                balanceTotal := calldataload(sub(message.length, mul(sub(numTokens, i), 32))) //jumps to ith total in balanceTotals
            }
            balanceTotalsWithShards[i] += notInShards;
            require(balanceTotalsWithShards[i] == balanceTotal, "l");
        }
        //none of the shards(if sharded) + ownerPartnerBals overflowed, so we create our msg, and then keccak, store this in the contract
        if (msgType == MsgType.SHARDED) {
            setShardDataMsg(channel, message, numShards, numTokens);
        } else {
            channel.msgHash = uint(keccak256(message[0 : message.length - (numTokens * 32) - ((msgType == MsgType.INITIAL) ? 32 : 4)])); //We need everything(channelID, token splits, msg data, except for the balanceTotals and the nonce)
        }
    }

    /**
     *Tkaes a message that is trying to trump with a sharded message, and properly sets the shardDataMsg, the calcs and sets the msgHash.
     * If the prior message was not sharded, we set shardDataMsg to all zeros. 
     * If prior message sharded, we need to see if any of the old shards are in this new msg, and if they are and the preimage has already been revealed, push forward this shard in the new state as well. 
     * So, we loop over all of the oldShards. Shards can be deleted in any order, but are added in an append only fashion. 
     * So, starting with old shard 0. Compare this with new shard 0. If equal, copy over old val of shardDataMsg to new shardDataMsg.
        * If not equal, I argue this shard is gone. If it were further down the array, that would mean that shards were added in a non append fashion, breaking protocol. So, we look at old val 1, comparing it to new val 0.
            *Note, we haven't gone ahead and started lookin at new val 1 yet. 
     * We continue this until we run out of old shards or new shards. When either happens, we have guaranteed that for every old shard, if it exists in new shards, its value in shardDataMsg has been copied over. 
    */
    function setShardDataMsg(Channel storage channel, bytes calldata message, uint numShards, uint numTokens) private {
        uint8[] memory shardDataMsg = new uint8[](numShards); //initialized all to 0, or false, at the start
        if (channel.settlementInProgress) {
            uint shardPointerNew = START_ADDRS + (TOKEN_PLUS_BALANCESTRUCT_UNIT * numTokens) + 1; //points at first shards in new msg
            uint shardPointerOld = shardPointerNew + (numShards * LEN_SHARD) + 4;
            uint numShardsOld = 0;
            //check if old msg wasnt sharded, and if not, we can ignore it. 
            if (MsgType(uint8(message[shardPointerOld])) == MsgType.SHARDED) { //if old msg not sharded, no sharded states to relay, can skip over below loop
                shardPointerOld += START_ADDRS + (TOKEN_PLUS_BALANCESTRUCT_UNIT * numTokens) + 1;
                uint currIndexNew = 0;
                numShardsOld = uint(uint8(message[shardPointerOld - 1]));
                for (uint i = 0; i < numShardsOld; i++) {
                    //direct bytes comparison not allowed, so we will compare the keccakd values to check whether the two shards are equal
                    if (keccak256(message[shardPointerOld : shardPointerOld + 32]) == keccak256(message[shardPointerNew : shardPointerNew + 32])) {
                        //these are the same shard!!
                        shardDataMsg[currIndexNew] = uint8(message[shardPointerOld + (numShardsOld * LEN_SHARD) + i]); //take on whether or not succeeded, from old shardDataMsgArr
                        currIndexNew += 1; //increment new to look at next shard
                    }
                    if (currIndexNew == numShards) { break; }
                }
            }
            channel.msgHash = uint(keccak256(abi.encodePacked(message[0: START_ADDRS + (TOKEN_PLUS_BALANCESTRUCT_UNIT * numTokens) + 1 + (numShards * LEN_SHARD)], shardDataMsg)));
        } else {
            channel.msgHash = uint(keccak256(abi.encodePacked(message[0: message.length - (numTokens * 32) - 4], shardDataMsg)));
        }
        uint channelID = uint(keccak256(message[1: START_ADDRS + (numTokens * 20)]));
        emit ShardStatesAtDisputeStart(channelID, channel.nonce, shardDataMsg);
    }

    function disputeStartedChecks(Channel storage channel, bytes calldata message, bytes calldata signatures, uint numTokens, address owner) private returns (uint32 nonce, MsgType msgType) {
        msgType = MsgType(uint8(message[0]));
        require(msgType == MsgType.INITIAL || msgType == MsgType.UNCONDITIONAL || msgType == MsgType.SHARDED, "p");
        address partnerAddr;
        uint endMsg0 = START_ADDRS + (numTokens * TOKEN_PLUS_BALANCESTRUCT_UNIT); //gives the end of the first message, up to either the deadline or the nonce. If sharded, line below will skip over shards
        if (msgType == MsgType.SHARDED) { endMsg0 += uint(uint8(message[endMsg0])) * LEN_SHARD; } 
        if (msgType != MsgType.INITIAL) {
            //if is initial, we dont touch nonce, and leave it initialized to 0. Remember, INITIALS end in a deadline, not a nonce, since nonce is implicitly 0
            assembly { 
                nonce := calldataload(add(message.offset, sub(endMsg0, 28))) //-32 from end msg, + 4 bc not actually at end but is really at start nonce, so 4 - 32 = -28
                partnerAddr := calldataload(add(message.offset, sub(NUM_TOKEN, 32)))  //MAGICNUMBERNOTE: pSignerAddr finishes at start of NUM_TOKEN, so we backtrack 32 bytes            }
            }
            checkSignatures(keccak256(message[0: endMsg0 + 4]), signatures, owner, partnerAddr); //MAGICNUMBERNOTE: add 4 for nonce
            assembly { partnerAddr := calldataload(sub(message.offset, 4)) } //MAGICNUMBERNOTE: getting partnerAddr set correctly for check below, where we require msg.sender == partnerAddr
 
        } else {
            //is initial, so we want to check sig off of the partnerAddr, not pSignerAddr
            assembly { partnerAddr := calldataload(sub(message.offset, 4)) }//MAGICNUMBERNOTE: bc end of partnerAddr sits at 28, 28 - 32 = -4
            checkSignatures(keccak256(abi.encodePacked(message[0: 1], bytes4(0), message[5: endMsg0 + 32])), signatures, owner, partnerAddr); //MAGICNUMBERNOTE: have to add 32 bc goes right up to deadline. DO this funky abi.encodePacked bc signature for anchor msg does not include blockAtAnchor, but rather 4 bytes of zeros, so we must excise blocktAtAnchor, and add these in. 
        }

        if (!channel.settlementInProgress) {
            require(msg.sender == partnerAddr || msg.sender == owner, "i");//Done so that watchtowers cant startDisputes. They can only trump already started settlements.
            require(nonce >= channel.nonce, "x"); //>= includes equals for case where starting settlement with a message that was used in a update() call already. Note shards cannot be used in update(), so shards will always be >. Didn't include this separately since checking >= is the same as checking >, for if not settling no way sharded nonce could have already been seen
            channel.disputeBlockTimeout = uint32(block.number + (DISPUTE_BLOCK_HOURS * BLOCKS_PER_HOUR)); //Note we only set this first startDispute call: all subsequent trumps must make it within this initially activated timeout. There is no reset.
            channel.settlementInProgress = true;
        } else {
            require(nonce > channel.nonce, "x");
            require(block.number <= channel.disputeBlockTimeout, "f"); //must submit trump w/in original disputeBlockTimeout to prevent endless trump calls. 
            if (msgType == MsgType.SHARDED) { 
                require(channel.msgHash == uint(keccak256(message[endMsg0 + 4 : message.length - (numTokens * 32)])), "I"); //check that correct prior message is given!
            }
        }
        channel.nonce = nonce;
    }

    
    /**
     * Endpoint for when a party is noncompliant/offline and the other party needs to force a settle. Starts a settlment period. 
     * Accepts either a Unconditional/Initial message or a Sharded message. Unconditional/Initial messages will only succeed if there is not a settlment already started. 
     * Sharded messages will only succeed if nonce is higher, and will reset the timeout to what is passed in. Can be called after a settlement has started. 
     * startDispute can be called by owner or partner only. Done to prevent any malicious activity on the part of the watchtowers.
     */
     //Receives a {INITIAL, UNCONDITIONAL, SHARDED} || balanceTotalsMsg. Stores in msgHash = {msgType with deadline(INITIAL), nonce(else) stripped out} || shardDataMsg
     //If this message is trumping another message...
        //If the new message is not sharded, then message is formatted same as above
        //If the new message is sharded, then the prior msgHash msg needs to be passed in, with the proper and most recent shardDataMsg appended to it, so the message being passed is actually
        // newMsg || oldMsg || balanceTotals
    function startDispute(bytes calldata message, bytes calldata signatures, address owner, mapping(uint => Channel) storage channels) external returns(uint channelID, uint32 nonce, uint numTokens) {
        numTokens = uint(uint8(message[NUM_TOKEN]));
        channelID = uint(keccak256(message[1: START_ADDRS + (numTokens * 20)]));     
        Channel storage channel = channels[channelID]; 
        require(channel.exists, "u");
        require(channel.balanceTotalsHash == uint160(bytes20(keccak256(message[message.length - (32 * numTokens): message.length]))), "E"); //MAGICNUMBER NOTE: take last numTokens values, since these are the uint[] balanceTotals
        MsgType msgType;
        (nonce, msgType) = disputeStartedChecks(channel, message, signatures, numTokens, owner); //for simiplicity of checks concerning the partners signing addr, we call checkSignatures in here
        
        //properly set the shards, while also checking for overflows of channel balances
        updateShards(channel, message, msgType, numTokens);
        
    }

    //NOTE: dont pass in numTokens bc will stack overflow
    function changeShardStateHelper(bytes calldata message, uint8[] calldata shardNos, uint hashlockPreimage) private view returns (uint) {
        uint numTokens = uint(uint8(message[0]));

        uint numShards = uint(uint8(message[START_ADDRS + (TOKEN_PLUS_BALANCESTRUCT_UNIT * numTokens)]));
        uint8[] memory shardStatesNew = new uint8[](numShards);
        assembly { calldatacopy(add(shardStatesNew, 32),  add(message.offset, sub(message.length, add(32, numTokens))), numShards) } //store the current shardDataMsgs in shardStatesNew
        uint timeout;
        for (uint i = 0; i < shardNos.length; i++) {
            uint shardPointer = uint(uint8(message[START_ADDRS + (TOKEN_PLUS_BALANCESTRUCT_UNIT * numTokens) + 1 + (shardNos[i] * LEN_SHARD) + 6])); //point this to proper shards shardTimeout, jumpin over tokenBalances, numShards, prior shards, and then+2 so read ends at 6 + 32 = 38, the end of shardTimeout
            assembly { timeout := calldataload(add(message.offset, shardPointer)) }
            require(block.timestamp <= uint(uint32(timeout)), "e"); //uint(uint32( bc need to clear away garbage that came before shardTimeout, and only examine last 4 bytes
            address partnerAddr;
            assembly { partnerAddr := calldataload(sub(message.offset, 4)) } //MAGICNUMBERNOTE: so that reads up to -4 + 32 = 28, which is where partnerAddr ends in message
            
            //If shard has not been pushed forward; if hashlock given is correct, push forward. But, if less than 1 hour remaining, then slash.
            uint hashlock;
            assembly { hashlock := calldataload(add(message.offset, add(shardPointer, 1))) } //MAGICNUMBERNOTE: 1 is just to jump over shardBlockTimeout
            require(hashlock == uint(keccak256(abi.encodePacked(hashlockPreimage))), "A");
            shardStatesNew[shardNos[i]] = 1; //1 for pushedForward. TODO: solidity will throw an out of bounds error, correct?
            
        }
        //construct new msg, swapping in proper value for the updated shard(s)
        return uint(keccak256(abi.encodePacked(message[0: message.length - 32 - numTokens], shardStatesNew, message[message.length - 32: message.length])));
    }


    /**
     * Done to push either push fwd(normal, turing incomplete), or revert(turing incomplete) a shard. 
     * For this call to succeed, there must be a settlement on a Sharded message already in place.
     * Must still call withdraw when timeout ends. Balances are set here, but funds not yet distributed. 
     * This can be called for an array of shardNos provided they all share the same hashlock.
     */
     //message here is the message that was stored for channel.msgHash + shardStateChangeData
     //takes in same message that is stored in msgHash in startDispute, or that has been updated and restored here in changeShardState
    function changeShardState(bytes calldata message, uint hashlockPreimage, uint8[] calldata shardNos, mapping(uint => Channel) storage channels) external returns(uint channelID) {
        require(MsgType(uint8(message[0])) == MsgType.SHARDED, "p");
        uint numTokens = uint(uint8(message[NUM_TOKEN]));
        channelID = uint(keccak256(message[1: START_ADDRS + (numTokens * 20)]));
        require(channels[channelID].exists, "u");
        require(channels[channelID].msgHash == uint(keccak256(message)), "B");

        // channelID = doChecksUpdateShard(channels, message, shardNos);
        channels[channelID].msgHash = changeShardStateHelper(message, shardNos, hashlockPreimage);
    }


    function addShardsInWithdraw(bytes calldata message, BalanceStruct[] memory shardTokenBals, uint numTokens, uint8 numShards) pure private {
        //we will go through and add all the shard information to shardTokenBals.
        uint shardPointer = START_ADDRS + (TOKEN_PLUS_BALANCESTRUCT_UNIT * numTokens) + 1; //points now to tokenIndex of first shard.
        for (uint8 i = 0; i < numShards; i++) {
            uint8 shardState = uint8(message[message.length - 32 - (numShards - i)]);
            uint amount;
            bool ownerGiving = uint8(message[shardPointer + 1]) == 1; //jumps shardPointer over tokenIndex
            assembly { amount := calldataload(add(message.offset, add(shardPointer, 2))) } //MAGICNUMBERNOTE: jumps over tokenIndex, ownerGoR
            if ((ownerGiving && shardState == 0) || (!ownerGiving && shardState == 1)) {
                //owner was giving and the funds reverted, so owner gets them back, or owner was receiving and it was pushed through, so owner actually gets them.
                shardTokenBals[i].ownerBalance += amount;
                if (shardState == 1) {
                    shardTokenBals[i].partnerFee += amount; //partnerFee since they were the sender. Only add fees for swaps that suceeed
                }
            } else {
                //owner was giving and funds pushed through, so partner gets them, or partner was receiving and reverted, so partner gets them back
                shardTokenBals[i].partnerBalance += amount;
                if (shardState == 1) {
                    shardTokenBals[i].ownerFee += amount; //ownerFee since they were the sender. Only add fees for swaps that suceeed
                }
            }
            shardPointer += LEN_SHARD;
        }
    }

    /**
     * Is precisely the message used in the keccak at the end of startDispute, or this same msg with modification from any successful changeShardState calls. If sharded, also has tacked onto the end the shardedDataMsg
     * So, msg == up to nonce/deadline if unconditional, else msg == up to nonce/deadline + shardDataMsg
     */
    function withdraw(bytes calldata message, mapping(uint => Channel) storage channels, mapping(address => FeeStruct) storage tokenAmounts) external returns (uint channelID) {        
        uint numTokens = uint(uint8(message[NUM_TOKEN])); 
        channelID = uint(keccak256(message[1: START_ADDRS + (20 * numTokens)]));
        
        Channel storage channel = channels[channelID];    
        require(uint256(keccak256(message)) == channel.msgHash, "B");
        uint8 numShards = eligibleForWithdraw(message, channel, numTokens);
        //all shardBlockTimeouts, disputeBlockTimeout have ended, channel actually exists, it is now safe to send out values
        
        uint startBals = START_ADDRS + (numTokens * 20);
        BalanceStruct[] memory shardTokenBals = new BalanceStruct[](numTokens); //this stores owner, partner split for each token.
        assembly { calldatacopy(add(shardTokenBals, 32), add(message.offset, startBals), mul(numTokens, BALANCESTRUCT_UNIT)) }  //lets initialize it with the non sharded information stored in message balances right after tokens

        if (numShards > 0) {
            addShardsInWithdraw(message, shardTokenBals, numTokens, numShards);
        }
        //now, we have added all the shardedFunds into the shardTokenBals. Now, we need to go into unsharded token balances, and add in each owner, partner amount
        address partnerAddr;
        assembly{ partnerAddr := calldataload(sub(message.offset, 4)) } //MAGICNUMBERNOTE: so that reads up to -4 + 32 = 28, which is where partnerAddr ends in message
        
        address tokenAddress;
        uint totalKLD;
        for (uint i = 0; i < numTokens; i++) {
            //NOTE: no need ot check local bals are les than balanceTotal; havev already done so in startDispute. So, we pass 0 as balanceTotal, as a dummy paramt that calcBalsAndFees will just ignore.
            tokenAddress = calcBalsAndFees(message, shardTokenBals[i], 0, partnerAddr, i);
            totalKLD += shardTokenBals[i].ownerFee;
            tokenAmounts[tokenAddress].ownerBalance += shardTokenBals[i].ownerBalance;
            tokenAmounts[tokenAddress].KaladinBalance += (shardTokenBals[i].ownerFee + shardTokenBals[i].partnerFee);
        }
        tokenAmounts[KALADIMES_BAL_MAP_INDEX].ownerBalance += totalKLD;
        //clean up
        delete channels[channelID];
    }
}








//Error Msg Key:
// a: "can't reenter contract"
// b: "either channel does not exist or no settlement is in progress"
// c: can't withdraw yet bc disputeBlockTimeout has not expired
// d: at least one shardBlockTimeout hasn't expired yet
// e: shard has already expired
// f: disputeBlockTimeout has expired; too late to pass new message
// g: only owner can add funds
// h: the channel give by Kaladin does not seem to exist
// i: no 3rd party submission; msg.sender must be owner or partner
// j: failed transferFrom attempt on an IERC20 contract
// k: the msg.value was too small for amount of native token requested in msg
// l: the updated balances are invalid, as they do not sum to that staked into the channel
// m: the shard was either already slashed, or in the nonTuringIncomplete case, pushedForward, or in the TuringIncomplete case, tried to pushForward a fwd, or revert an already rvrt
// n: bad owner sig
// o: bad partner sig
// p: the msg type provided is not one of the accepted msg types for this function
// q: chainID given in the anchor msg does not match block.chainid
// r: signed anchor message contract field does not match address(this)
// s: channel already created
// t: deadline passed
// u: channel does not exist
// v: no such shard
// w: cant process request because there is a settlementInProgress
// x: update nonce is not high enough (either equal or old msg passed). This is also important, bc if say, due to concurrency, two different msgs with same nonce are passed in a Kaladin route,
    // we dont want the one that is going to finalized to be flip flopping back and forth with every startDispute call until disputeBlockTimeout expires.
// y: can't have two of same token
// z: can't sell and buy same token
// A: preimage does not hash to hashlock (either fwd/revert, depending on pushForward bool)
// B: provided msgHash fails
// C: cant use a recycled message!
// D: This channelFunction is not recognized
// E: Provided balanceTotals does not match hash stored on record
// F: shardDataMsg does not equal that which is stored on chain. 
// G: the numAmounts byte in Shard does not accurately represent the size of the amounts.
// H: the index given in withdraw Kaladin does not align with the address pulled from the contract
// I: only partner can publish