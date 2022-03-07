// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.7;
//TO DO: get fees paid out to Kaladin, settlers/watchtowers (in KLD?) figured out
//TO DO: get rewards paid in Kaladimes for making/taking trades, etc figured and paid out. 
    //IDEA: could have KLD balance as a state variable. For every "single" swap, we can increment this balance as a function of amount, and for every anchor we could do the same thing(even fancier, we pay out to anchor as an increasing fucntion dependent on time spent in the channel to encourage less anchors, exits).
    //Finally, at any time a owner can call out on the contract, saying 'send my KLD elsewhere'. This will then call out a specialTransfer call to the IERC20 protocol to allow transferring these funds. 
    //The way this will work to dynamically support whatever value of funds is that there is a treasury address with lots of KLD. When you call out to the contract factory, this contract is created, and given proper permissions in the KLD contract to transfer funds from this treasury address.

//TO DO: make sure that the nonces of all the msg types are incremented appropriately (in here and protocol wise) so that there are no bugs with a potential > vs >=, etc.
//TO DO: determine if we want some notion of slashing for getting trumped. Would need a clause that only allows slash if trump 2+ higher. Can't do 1 higher, bc this happens when waiting in aRc or cLa if party goes unresponsive.
    //Im thinking not? And we reserve the slashing primarily for the shards? Just too hard for txs, bc we are trusting watchtowers with signed txs, and we need to give these to them to preserve liveness, so nothing to stop them from pubbing old txs, and causing a slashing.
    //Only real way I see us having slashing is if we incorporate CCs like BTC, and only send watchtowers CCs, not txs. Messy though, doesnt really seem worth it. 

    //Another slashing related idea is that maybe if a owner, partner submits startDispute, and then gets trumped, they get fully slashed. Something to do with watchtowers submitting startDispute and staking KLD, if they are trumped,
    //KLD slashed, but if they aren't trumped, their KLD doubles. IDK. Need to make sure that owner, partner can't collude, not send most recent txs, in order to intentionally slash a watchtower/hold their KLD ransom. 
     

//TO DO: update how we are storing all of the shard data, maybe change it so it can be passed in as calldata, so that it wont
    //be so expensive to store these things on chain. 
//TO DO: include logic so that if an anchor call fails due to insufficient owner funds, then owner transfers funds to CP, 
    //to pay for the gas costs. Will require the use of an additional data structure so no replay repay gas attack possible.

//TO DO: change contract so that construct supports initializing with array of tokens, funds (in other words, calls out to addFundsToContract). 
    //DOUBLE TO DO: dont think this is possible due to IERC20's needing the contract address to be set for approve call, but can't be done until contract initialized
//TO DO: decide whether safer to have disputeBlockTimeout, shardBlockTimeouts be set on time, or on blocks.

//TO DO: move as many functions as possible to a library to reduce the contract code size. See this for other helpful tricks: https://ethereum.org/en/developers/tutorials/downsizing-contracts-to-fight-the-contract-size-limit/
    //TO DO: figure out whether I should make these library functions internal or external.
    //TO DO: figure out whether I want to try and stick things like event definitions, struct defs in another library, just to save compile time gas.

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";


// channelID:
//     uint8 disputeBlockTimeout
//         single byte because the value represents the number of hours of the timeout in blocks. i.e. for eith, disputeBlockTimeout = 1 corresponds to 240 blocks.
//         This is the timeout, a constant in the channel, that last from when startDispute is called, in blocks. 
//         Other parties can trump this message as long as it falls within disputeBlockTimeout. 
//         Note that even after disputeBlockTimeout has ended, parties can still change shardBlockTimeouts. Also, a withdraw call cant succed until after this timeout has ended, to allow counterparty time to trump. 
//     uint32 contractNonce:
//         this is the nonce for the channel, which is incremented for every new channel that is entered into in the contract. 
//         This is to prevent against a replay attack by someone who has restaked into the contract with the same tokens,
//         otherTokens, and also the same address. Also, this needs to be kept track of in an off chain DB, for if this were an on chain variable, it would a). be more expensive. 
//         b). could allow a party to resubmit an anchor multiple times, as the anchor would get the contractNonce added on chain, have a differnet channelID, 
//         and would not be recognized as a repeat.
//         Problem: does not prevent against reuse on another contract w exact same metadata, AND owner used same pk on both chains. We could get around this by including contract Addr in channelID. TO DO: decide if this is necessary vector to protect against. Seems easier to mandata different contracts need to use different secret keys?
//     uint24 chainID 
//         (use to differentiate between two blockchains that may have naming overlap, so that is anchored into intended chain). I anticipate 2^24 is a high enough value to capture any chain we may need.
//     address partnerAddress
//     address contractAddress
//     byte numTokens
//         represents number of 20 byte ERC20 addrs below that are in contract. Note this is limited to 255 by nature of being a byte. 
//     address[] tokens:
//         array of ERC. If first addr = 0x000000..0000 (20 bytes of 0), then represents ether. All other addresses assumed to be ERC20. 

// shard: 
//     byte index
//         this reference the index in tokens (in channelID) to which this is referring. 
//     uint value
//         the amount of the token reference by index which is to be traded

// shardData: 
    //byte numGiving
        //byte that represents the number of tokens which the contract owner is giving up in the swap. 
    //shard[] givingShards
        //array of type shard that the contract owner is giving
    //byte numReceiving
    //shard[] receivingShards
    //uint hashlock
    //bool updateIncludesTuringIncomplete
        //currently, means that it is interwoven with BTC and/or stellar
    //bool ownerControlsHashlock
        //1(true) if owner is the upstream party who created the preimage, 0 if its the partner
    //uint8 shardBlockTimeoutHours
        //again, as other timeout, represents hours

// msgType:
//     0: Initial
//     1: Unconditional
//     2: Sharded
//     3: Settle
//     4: SettleSubset
//     5: UnconditionalSubset
//     6: AddFundsToChannel
//     7: SingleChain
//     8: Multichain




// Messages:
//     Initial
//         byte msgType
//         (variable) channelID 
//         uint[] balances
//             array of all the balances, given by ownerAmount, then partnerAmount. 
//             For example, if there are two tokens in the channel, this will be 2 * (2 * 32) = 128 bytes long, arranged by ownerAmount0, partnerAmount0, ownerAmount1, partnerAmount1.
//             It is assumed balances in same order as tokens. Not side by side, bc balances change and channelID must be immutable. 
//         uint deadline
//             the block number by which this tx must be submitted. Used to scope validity of anchor signatures 
//     Unconditional
//         byte msgType
//         (variable) channelID 
//         uint[] balances
//         uint32 nonce
//     Sharded
//         byte msgType
//         (variable) channelID
//         uint[] balances
//         byte numShards
//             represents how many shards are attached to this Shard Msg
//         shardData[] shards
//             array of all the shards in the Shard msg
//         uint32 nonce
//     Settle
//         byte msgType
//         (variable) channelID 
//         uint[] balances
//     SettleSubset
//         byte msgType
//         (variable) channelID 
//         uint[] balances
//         bool[] closeOutTokens
//         uint32 nonce
//     UnconditionalSubset
//         This message is exactly the same as an Unconditional except it requires that the on chain stored nonce == msg nonce - 1.
//         This is done to ensure that one party cannot publish the new tx, with a portion of the funds missing (bc presumedly settled) b4 a party can actually submit the settleSubset msg.
//     AddFundsToChannel
//         byte msgType
//         (variable) channelID 
//         uint[] fundsToAdd
//         nonce 
//     SingleChain
//         byte msgType
//         5 bytes zeros (padding) //done so that complies with anchor format, doAnchorChecks is successful
//         uint24 chainID
//         address partnerAddress
//         address contractAddress
//         address ownerToken
//         address partnerToken
//         uint ownerAmount
//         uint partnerAmount
//         uint deadline
//     MultiChain
//         byte msgType
//         3 bytes zeros (padding) //done so that complies with anchor format, doAnchorChecks is successful
//         bool owner/partnerFlag
//         uint8 blockHourTimeout
//         uint24 chainID
//         address partnerAddress
//         address contractAddress
//         address personToken
//         uint personAmount
//         uint hashlock
//         uint deadline



library StormLib {
    enum MsgType{ INITIAL, UNCONDITIONAL, SHARDED, SETTLE, SETTLESUBSET, UNCONDITIONALSUBSET, ADDFUNDSTOCHANNEL, SINGLECHAIN, MULTICHAIN }

    struct swapStruct {
        uint hashlock;
        uint timeout;
    }

    struct Shard {
        mapping(uint8 => uint) givingBalances; //mapping from index in balances, which is index in the array tokens
        mapping(uint8 => uint) receivingBalances;
        uint8 pushedForward; //indicates whether hashlock owner revealed the secret, and pushed state forward. Now, we have this in an interesting way as a uint8.
            //MOTIVATION: create a solution where we dont require Alice to stay live and publish herself in the last hour of the timeout, but don't give Bob/watchtower colluding with Bob any ability to hurt Alice.
            
            //0 indicates that it is in its base state, which is to revert. (TO DO: make base form to push forward? test to see which is more common, then choose one that causes fewest on chain changeShardState calls)
            //1 (INCLUDESTURINGINCOMPLETE only) indicates that it is in the revert state from a reveal of secret to revertHashlock
            //2  indicates that it is in the fwd state from a reveal of secret to forwardHashlock
            //3  indicates that whoever owns hashlcok has cheated in some way. 
                
                //If INCLUDESTURINGINCOMPLETE:
                // Cheating determined by revealing two secrets. So, if fwd secret pubbed in (1), or revert secret in (2),
                //then we enter (3). This allows watchtower aid so that we don't require only Alice having publishing power to Ethereum in last hour; Bob can publish too, but if he does one thing on BTC, another on ETH, or tries to flip on ETH right at end of timeout, Alice or watchtower
                //can publish BTC revealed secret/he will end up slashing himself. (Note that order of Bob and Alice/Watchtower pub here is unimportant).
                    //bug concern: Bob pubs to ETH, does nothing on BTC. Alice must publish tx_delay on BTC before Ethereum expires. Else, Bob could race case her after ETH times out in revert state and publish tx2F. However
                        //if she pubs tx_delay, Bob can push forward ETH, and Alice can do nothing about moving BTC forward as well.
                            //SOLUTION: we have tx_delay have three things in Bobs ScriptPK. Can be redeemed as follows. First t = 0, Bob sig + cc Alice. Second t = 1, Alice sig + secretForwardBob. Third t = 2, Bob sig. NOTE: Alice ScriptPK in this txdelay is a standard lightning ScriptPK: Bob redeem instant w cc, Alice redeem at timeout t. 
                                //Now, the timeouts functions so that Bob will have enough time to figure out fwd or rvrt with upstream. Then, he SHOULD publish txR, txF. This is all before tx1d becomes valid. Now, with at least 1 hr left on eth,
                                //tx1d becomes valid. Alice publishes this. Finally, ample enough time before t = 2, the eth contracts times out. This means if Bob pushes forward eth at last second, Alice will still have ability to slash and steal Bobs BTC funds.
                                //Finally, in case where Alice has a downstream, this eth timeout happens before her downstream is able to publish her own tx1d. Note that this is not protected by watchtowers, as she cant send both tx2f, tx2r to watchtowers without placing too much trust in them. 
                                    //However, note that Alice will only have a upstream/downstream if she is routing swaps, which means she would be running a full node anyways, so there is no (minimal?) problem here.
                                //WATCHTOWERS: Alice is assumed to be fully offline. She publishes ETH2 on her own, and advertises to watchtowers the associated bitcoin pk. She also sends the watchtowers
                                //tx1delay, to publish when becomes valid if Bob has not published on BTC, as well as a signature to spend from Bob's output of the txdelay1 ScriptPK. Then, she falls offline! Trusts watchtowers to pub BTC, slash Bobs BTC if necessary, and transfer published BTC secrets
                                //to chain on ETH, and if Bob double reveals, to slash him on ETH. 
                                    //TO DO: I believe that in order for Alice to send a proper sig spending from Bobs tx1delay scriptPK, it will need to be (coming from?, going to?
                        
                    //Q: whats stopping watchtowers from publishing any of the old msgs which have now had their CC revealed? Answer: you only send watchtower signed msg if you want that one to go to chain. Else, you just send over all cancel codes.

                //If not INCLUDESTURINGINCOMPLETE:
                    //Originally, only the non secret owning party were able to publish in the last hour, with 2 hour timeout chunks. Imagine you go to chain with both your upstream, timeout 2 hours, and downstream, timeout 4. Your upstream has 1 hour to publish. Then, you have another hour to see this, 
                    //publish to the appropriate chains. That leaves two hours left on your downstream, where you then have another hour to publish yourself. Finally, there is another hour for your downstream partner to publish.
                    
                    //I am proposing a new system. First, I propose a delay of 2 hours, 3 hours, 4 hours, 5 hours... First Person A has 1 hour to pub. Then there are 1, 2, 3, 4... hours remaining in all contracts. Person B has 1 hour to trump upstream, 1 to publish downstream. Now, 0, 1, 2, 3 hours remaining. Person 
                    //C has 1 hour to trump upstream, 1 to pub downstream. Now 0, 0, 1, 2 left. Person D has 1 hour to trump, 1 to pub. Finally, 0, 0, 0, 1. Person E has 1 hour to trump. 
                    
                    //In the previous system we were requiring that only the non owning party be able to publish their funds in the last hour. This meant that if the secret owning party waited till 1 hour, 1 second left in shard and published,
                    //no watchtower could see this in time and aid the non owning party. It required liveness on the non owning parties part to counteract the event of a last second pub. This is untenable for non node runners.
                    //Instead, I propose this new system: up until the final hour, anyone can publish. Then, during the final hour, anyone can publish, BUT if a secret is published FOR THE FIRST TIME, the secret owning party has all of their funds slashed. 
                    //So, secret owners can wait till last second on one chain, then publish, but this wont force state n + 1 on this chain, n on other chain. Instead, it pushes through ALL, n on the two chains. This is an acceptable state for the non owning party, and can only be brought about by malevolence by the owning party.
                    //Furthermore, it encourages secret owners to publish to all chains, and to do so very early. If they wait until the last second on one chain with 1 hour 1 second left, good chance on the other chain the update wont get pubbed in time, and they will be slashed.
                    // In the event that they go offline accidentally after a single chain pub, we are relying on our network of watchtowers to propagate this secret around well before the 1 hour left mark is hit. 
                    //Flaws: 
                        //could theoretically DoS both a user and all honest watchtowers to prevent pubs? Or concentrated effort on part of miners to censor txs so that a party gets slashed? But highly unlikely.
                        //If a blockchain goes down, like Solana earlier this year, could cause some wonky issues, there to be timeout discrepancies between the chains. IDK how to get around this issue. 
                        //If we are going of unix timestamp, and times given by miners suuuuper whack, could be an issue. May be smart to keep the 2, 4, 6, etc. system as before in light of this. Furthermore, if we are using a 
                        //block based timestamp, and block times not predictable/ too fast (think first few weeks of BCH), could also present an issue. 

        bool updateIncludesTuringIncomplete;
        bool ownerControlsHashlock; //owner is the preimage owner, or the upstream party. Means they can't publish in final hour of shardBlockTimeout.
        uint32 shardBlockTimeout; //TO DO: should this be a block.timestamp instead? Currently block.number, to prevent attack where no new blocks published. Also, is uint64 large enough?
        uint forwardHashlock; 
        uint revertHashlock;
    }

    struct Channel {
        //slot 0
        bool exists; //Indicates that channel exists.
        bool settlementInProgress;
        uint8 numShards; //Number of shards.
        uint8 numTokens; 
        uint32 nonce; 
        uint32 disputeBlockTimeout; //blockNumber before which a trump of the provided startSettlment message can be trumped w a higher nonce message. After this ends, can't start new settlement. However, before you can't withdraw. Important for notion of withdraw for non Sharded msgs.
        //slot 1
        uint msgHash; //Stores the keccak of the message used in startDispute. We do this so that we can check that in withdraw, this is the same msg as was used in startDispute. We need it bc we dont store all of balances in shard0, instead relying on the cheaper option of repassing them in calldata in withdraw.
        //slot 2+
        mapping(uint8 => uint) balances; //Mapping, not uint[], bc solidity prefers mappings. The keys are 0, 1, 2, ... numTokens - 1. TO DO: should I change this to uint not uint8 for gas efficiency?
        mapping(uint8 => Shard) shards; //Mapping from shard_no => shard data. To loop through, use counter 0, 1, ... , numShards - 1 
    }

    

    uint constant BLOCKS_PER_HOUR = 240;
    uint8 constant CHAIN_ID = 0; //TO DO: once we determine CHAIN_ID numbering system, update this value.
    
   
    //MAGIC NUMBERS
    uint8 constant NUM_TOKEN = 49;
    uint8 constant START_ADDRS = 50;
    uint8 constant SHARD_LEN = 33;
    uint8 constant TOKEN_PLUS_BALS_UNIT = 84;
    

    //****************************** Debugging Methods *****************************/
    function getBalancesTotals(Channel storage channel) external view returns (uint[] memory, uint32 nonce, bool exists, bool settlementInProgress) { 
        uint[] memory _balances = new uint[](channel.numTokens);
        for (uint8 i = 0; i < channel.numTokens; i++) {
            _balances[i] = channel.balances[i];
        }
        return (_balances, channel.nonce, channel.exists, channel.settlementInProgress);
    }

    function getContractBalances(address[] calldata tokens,  mapping(address => uint) storage tokenAmounts) external view returns (bytes memory) {
        bytes memory balances = new bytes(tokens.length * 32);
        for (uint i = 0; i < tokens.length; i++) {
            address addr = tokens[i];
            uint val = tokenAmounts[addr];
            assembly{ mstore(add(add(balances, 32), mul(i, 32)), val) }
        }
        return balances;
    }
    

    //****************************** Debugging Methods *****************************/


    //function that will revert if not eligble for withdraw. Called by both clients to know if able to withdraw, and internally by the withdraw function. 
    function eligibleForWithdraw(Channel storage channel) public view {
        require(channel.exists && channel.settlementInProgress, "b");
        require(channel.disputeBlockTimeout < block.number, "c");
        //checks that all of the timeouts have occurred. TO DO: make all of this more gas efficient by avoided repeated SLOAD calls
        for (uint8 shardNo = 0; shardNo < channel.numShards; shardNo++) {
            require(channel.shards[shardNo].shardBlockTimeout < block.number, "d");
            //TO DO: could allow for faster settle if a claim here that this timeout can be skipped if channels.shards[shardNo].pushedForward == true for nonTuringIncomplete, or channel.shards[shardNo].pushedForward == 3 for TuringIncomplete.
        }
    }

    

    /**
     * checks that given a message and two pairs of signatures, the signatures are valid for the keccak of the message,
     * given that ownerSignature matches owner of the contract, and partnerSignature matches partnerAaddress that is embedded in message as part of pairID.
     * Signatures are ECDSA sigs in the form v || r || s
     */
    function checkSignatures(bytes calldata message, bytes calldata ownerSignature, bytes calldata partnerSignature, address owner) external pure returns (address partnerAddress) {
        bytes32 messageHash = keccak256(message);
        bytes32 r;
        bytes32 s;
        assembly {
            r := calldataload(add(ownerSignature.offset, 0))
            s := calldataload(add(ownerSignature.offset, 32))
        }
        uint8 magicETHNumber = 27; //27 is magic eth # to add to v value, per ETH docs
        require(address(ecrecover(messageHash, magicETHNumber + uint8(ownerSignature[0x40]), r, s)) == owner, "n");

        assembly {
            partnerAddress := calldataload(sub(message.offset, 3)) //MAGICNUMBERNOTE: bc ends at 29, and 29 - 32 = -3
            r := calldataload(add(partnerSignature.offset, 0))
            s := calldataload(add(partnerSignature.offset, 32))
        }
        require(address(ecrecover(messageHash, magicETHNumber + uint8(partnerSignature[64]), r, s)) == partnerAddress, "o"); 
        
    }


    // //checks that there is sufficient liquidity to add tokens, and then do so. 
    // function lockTokens(bytes calldata tokens, uint numTokens, address partnerAddress, uint[] storage tokenAmounts) external returns ( uint[] memory) {
    //     uint _ownerBalance;
    //     uint _partnerBalance;
    //     address tokenAddress;
    //     uint[] memory balances = new uint[](numTokens);
    //     uint startBal = numTokens * 20;

    //     for (uint i = 0; i < numTokens; i++) {
    //         assembly { 
    //             tokenAddress := calldataload(add(sub(tokens.offset, 12), mul(i, 20)))
    //             _ownerBalance := calldataload(add(tokens.offset, add(startBal, mul(i, 64))))
    //             _partnerBalance := calldataload(add(tokens.offset, add(startBal, add(32, mul(i, 64)))))
    //         }
    //         balances[i] = _ownerBalance + _partnerBalance;
    //         if (i == 0 && tokenAddress == address(0)) {
    //             //process ETH
    //             require(msg.value == _partnerBalance, "k");
    //         } else {
    //             IERC20 token = IERC20(tokenAddress);
    //             bool success = token.transferFrom(partnerAddress, address(this), _partnerBalance);
    //             require(success, "j");
    //         }
    //         tokenAmounts[tokenAddress] -= _ownerBalance; //solidity 0.8.x should catch overflow here. 
    //     }
    //     //have looped through all of them, update the balances in the tokenAmounts, and also encountered no errors! can now set balances to be balances in this msg.
    //     return balances;
    // }


//     function doAnchorChecks(bytes calldata message) external pure returns (uint assemblyVariable) {
//         assemblyVariable; //first is chainID, then is contractAddress, then finally deadline
//         assembly { assemblyVariable := calldataload(sub(message.offset, 23)) } //MAGICNUMBERNOTE: bc chainID sits at position 6-8, so -23 + 32 = 9, will have last byte as pos. 8, as desired!
//         require(uint(uint24(assemblyVariable)) == block.chainid, "q"); //have to cast it to a uint24 bc thats how it is in message, to strip out all invalid data before it, then recast it to compare it to the chainid, which is a uint. 

//         assembly { assemblyVariable := calldataload(add(message.offset, 17)) } //MAGICNUMBERNOTE: bc contractAddress ends at NUM_TOKEN (or 49), so we do NUM_TOKEN - 32 = 17 
//         require(address(uint160(assemblyVariable)) == address(this), "r");

//         assembly{ assemblyVariable := calldataload(add(message.offset, sub(message.length, 32))) } //MAGICNUMBERNOTE: -32 from end bc deadline uint, at very end msg
//         require(block.number <= assemblyVariable, "t"); //TO DO: ¿ <= or < ?
//     }

    
    
//     //TO DO: in multichain, chain on which secret holder is receiving funds must have both a shorter timeout anddd a shorter deadline, where intrachain deadline must also be shorter than timeout.
//         //the reason for this is that we don't want secretholder to delay publishing msg on chain where they are receiving to last second, then publish and leave other chains deadline expired, essentially stealing funds.
//         //furthermore, lets say both are pubbed at same time, we want the redeem period to be shorter on the receiving chain, so nonsecretholder always has time to redeem on their chain. Finally, we need that the timeout is always longer than
//         //the deadline for a chain, so that we cant have a msg pubbed, redeemed, and then erased, and then published again since the deadline hasn't passed. This is partial as is because we store the timeout in the struct that is stored in seenMsgs,
//         //and this struct cant be deleted till timeout has expired
//     function singleSwapStake(bytes calldata message, bytes calldata ownerSignature, bytes calldata partnerSignature, bytes32 entryToDelete) external payable {
//         require(reentrancyLock == 0, "a");
//         uint deadline = doAnchorChecks(message);
//         reentrancyLock = 1;
//         address partnerAddress = checkSignatures(message, ownerSignature, partnerSignature);
//         bytes32 msgHash = keccak256(message);
//         require(seenSwaps[msgHash].timeout == 0, "C");

//         bool singleChain = false;
//         uint8 person;
//         uint8 timeoutHours;
//         if (MsgType(uint8(message[0])) == MsgType.SINGLECHAIN) {
//             singleChain = true;
//             person = uint8(message[4]);
//             timeoutHours = uint8(message[5]);
//         } else {
//             require(MsgType(uint8(message[0])) == MsgType.MULTICHAIN, "G");
//         }
        
//         //process funds
//         uint amount;
//         address addr;
//         assembly { 
//             addr := calldataload(add(message.offset, 37))//MAGICNUMBERNOTE: fetching personToken or ownerToken, which sits at 37 + 32 = 69
//             amount := calldataload(add(message.offset, 89))//MAGICNUMBERNOTE: fetching personAmount or ownerAmount, which starts at 89, uint
//         }

//         if (person == 0 || singleChain) {
//             //these are funds owner is providing
//             tokenAmounts[addr] -= amount;
//             if (singleChain) {
//                 //distribute funds instantly
//                 if (addr == address(0)) {
//                     //is native token
//                     payable(partnerAddress).transfer(amount);
//                 } else {
//                     bool success = IERC20(addr).transfer(partnerAddress, amount);
//                     require(success, "j");
//                 }
//             }
//         } else if (person == 1 || singleChain) {
//             //these are funds partner is providing
//             if (singleChain) {
//                 //get new funds amount to reflect the partner funds
//                 assembly {
//                     addr := calldataload(add(message.offset, 57))//MAGICNUMBERNOTE: fetching partnerToken, which sits at 57 + 32 = 89
//                     amount := calldataload(add(message.offset, 121))//MAGICNUMBERNOTE: fetching partnerAmount, which starts at 121, uint
//                 }
//                 tokenAmounts[addr] += amount;
//             }
//             if (addr == address(0)) {
//                 require(msg.value == amount, "k");
//             } else {
//                 bool success = IERC20(addr).transferFrom(partnerAddress, address(this), amount);
//                 require(success, "j");
//             }
//         }

//         //gas saver, clears out old entries to make putting in our entry above less costly. First checks that deadline has expired, so that can't do replay attack. 
//         if (seenSwaps[entryToDelete].timeout < block.number && seenSwaps[entryToDelete].hashlock == 0) {
//             delete seenSwaps[entryToDelete];
//         }

//         lockCount += 1;
//         reentrancyLock = 0;

//         if (singleChain) {
//             seenSwaps[msgHash].timeout = deadline;
//             emit Swapped(msgHash, true, 0);
//         } else {
//             assembly{ amount := calldataload(sub(message.length, 64)) } //here, we are storing the hashlock in our variable amount.
//             seenSwaps[msgHash].hashlock = amount;
//             seenSwaps[msgHash].timeout = block.number + (timeoutHours * BLOCKS_PER_HOUR);
//             emit Swapped(msgHash, false, 0);
//         }
//     }

//     //only available/necessary if singleSwap is multichain
//     function singleSwapRedeem(bytes calldata message, uint preimage) external {
//         require(reentrancyLock == 0, "a");
//         reentrancyLock = 1;

//         bytes32 msgHash = keccak256(message);
//         require(seenSwaps[msgHash].hashlock != 0, "D"); //funds have already been redeemed, or wasn't a multichain in the first place!
//         //valid redemption, should now send the proper funds to the proper person
        
//         uint8 person = uint8(message[4]);
//         //process funds
//         address partnerAddress;
//         uint amount;
//         address addr;
//         assembly { 
//             partnerAddress := calldataload(sub(message.offset, 3))
//             addr := calldataload(add(message.offset, 37))//MAGICNUMBERNOTE: fetching personToken, which sits at 37 + 32 = 69
//             amount := calldataload(add(message.offset, 89))//MAGICNUMBERNOTE: fetching personToken, which starts at 89, uint
//         }
        
//         bool timedOut = seenSwaps[msgHash].timeout > block.number;
//         if (timedOut) {
//             //hasn't timed out yet
//             require(seenSwaps[msgHash].hashlock == uint(keccak256(abi.encodePacked(preimage))), "E");
//         } else {
//             //has timed out, which means we want to return the funds to sender. This is the exact same code, but with values flipped. To avoid code duplication, 
//             //we can instead just flip the person, so the funds return to owner/partner instead of partner/owner.
//             person = (person == 0) ? 1 : 0;
//         }
//         if (person == 0) {
//             //is owner, so owner paid, means partner should receive. OR, got flipped up above, so is owner, but partner paid, which means partner gets return
//             if (addr == address(0)) {
//                 payable(partnerAddress).transfer(amount);
//             } else {
//                 bool success = IERC20(addr).transfer(partnerAddress, amount);
//                 require(success, "j");
//             }
//         } else {
//             //is partner, so partner paid, owner should receive. OR, got flipped up above, so is partner, but owner paid, owner gets return
//             tokenAmounts[addr] += amount;
//         }
        
//         lockCount -= 1;
//         reentrancyLock = 0;
//         if (timedOut) {
//             //now safe to fully delete
//             delete seenSwaps[msgHash];
//             emit Swapped(msgHash, false, 2);
//         } else {
//             //just delete hashlock, not whole structure bc deadline may not have yet timed out, we don't want a replay attack
//             delete seenSwaps[msgHash].hashlock;
//             emit Swapped(msgHash, false, 1);
//         }
//     }
    
    
//     /**
//      * Entry point for anchoring a pair transaction. If ETH is a token, anchor should be called 
//      * by the partner, not the contract owner, since the partner must send value in through msg.value. This function only 
//      * succeeds if the nonce is zero, deadline hasnt passed, and there is no open trading pair between these two people for 
//      * the token pair. Only accepts an Initial message. 
//      */
//     function anchor(bytes calldata message, bytes calldata ownerSignature, bytes calldata partnerSignature) external payable {
//         require(reentrancyLock == 0, "a");
//         doAnchorChecks(message);
//         reentrancyLock = 1;
//         address partnerAddress = checkSignatures(message, ownerSignature, partnerSignature); 
//         MsgType msgType = MsgType(uint8(message[0]));
//         require(msgType == MsgType.INITIAL, "p");
    
//         uint numTokens = uint(uint8(message[NUM_TOKEN])); //otherwise, when multiplying, will overflow
        
//         uint channelID = uint(keccak256(message[1: START_ADDRS + (numTokens * 20)]));
//         require(!channels[channelID].exists, "s");
        
        
//         (uint[] memory balances) = lockTokens(message[START_ADDRS : START_ADDRS + (TOKEN_PLUS_BALS_UNIT * numTokens)], numTokens, partnerAddress);

//         Channel storage channel = channels[channelID];
//         channel.exists = true;
        
//         for (uint8 i = 0; i < numTokens; i++) {
//             channel.balances[i] = balances[i]; 
//         }
        
//         channel.numTokens = uint8(numTokens);
//         lockCount += 1;
//         reentrancyLock = 0;
//         emit Anchored(channelID, partnerAddress, message[START_ADDRS : START_ADDRS + (20 * numTokens)], balances);
//     }

    
//     /**
//     * update() checks the current balances described in the passed message, then updates just the nonce. Update is called when you want to  
//     * lock in a state to guarantee that you will never revert to a state before this. If you dont want to 
//     * stay live but dont want to settle, you can call this with the most recent message and go offline for a period of time,
//     * knowing startsettlment can not be called with a prior message, and no new messages will be signed, making you safe. 
//     * We only update nonce so its cheaper, but do all the checks so a faulty signed msg couldn't permanently lock funds (no higher
//     * nonced msgs, cant settle on this one, CP wont respond).
//     * update() is only valid for Unconditional messages from an external call, for obvious reasons.
//     * TO DO: Also make this valid for a sharded msg? Seems legit yeah?
//     */
//     function update(bytes calldata message, bytes calldata ownerSignature, bytes calldata partnerSignature) external {
//         require(reentrancyLock == 0, "a");
        
//         MsgType msgType = MsgType(uint8(message[0]));
//         require (msgType == MsgType.UNCONDITIONAL, "p");

//         uint numTokens = uint(uint8(message[NUM_TOKEN]));

//         uint channelID = uint(keccak256(message[1: START_ADDRS + (numTokens * 20)]));
//         checkSignatures(message, ownerSignature, partnerSignature);

//         Channel storage channel = channels[channelID];
//         require(channel.exists, "u");
//         require(!channel.settlementInProgress, "w");//User should just call startDispute instead.
//         uint32 nonce;
//         assembly{ nonce := calldataload(add(message.offset, sub(message.length, 32))) } //TO DO: overflow checks?
//         require(nonce > channel.nonce, "x");
       
//         //check balances
//         uint _ownerBalance;
//         uint _partnerBalance;
        
//         for (uint8 i = 0; i < numTokens; i++){
//             assembly {
//                 let startBals := add(add(message.offset, 49), mul(numTokens, 20)) //MAGICNUMBERNOTE: 49 for START_ADDRS
//                 _ownerBalance := calldataload(add(startBals, mul(i, 64)))
//                 _partnerBalance := calldataload(add(add(startBals, 32), mul(i, 64)))
//             }
//             require(_ownerBalance + _partnerBalance <= channel.balances[i], "l");
//         }

//         //All looks good! Update nonce(the only thing we actually update)
//         channel.nonce = nonce;

//         //TO DO: do we want to emit an event for a successful update? seems unnecessary?
//         emit Updated(channelID, nonce);
//     } 

//     //add extra owner and partner funds to a channel, provided it is not settling?
//     //check both signatures
//     //check that channel exists and is not settling. 
//     //check the nonce; must be greater than nonce stored. For protocol, this nonce should be equal to the highest nonced msg seen thus far in the channel, so that can still arbitrate on other msg, but also locks in funds at this state.Furthermore, strict greater than prevents replay attack with addFunds calls.
//     //For each of the funds given, if not zero, try to add them from the contract(owner), or make the requisite IERC20 calls.
//     function addFundsToChannel(bytes calldata message, bytes calldata ownerSignature, bytes calldata partnerSignature) external payable {
//         require(reentrancyLock == 0, "a");
//         reentrancyLock = 1;
        
//         require (MsgType(uint8(message[0])) == MsgType.ADDFUNDSTOCHANNEL, "p");
        
//         uint numTokens = uint(uint8(message[NUM_TOKEN]));
//         uint channelID = uint(keccak256(message[1: START_ADDRS + (numTokens * 20)]));
//         address partnerAddress = checkSignatures(message, ownerSignature, partnerSignature);

//         require(channels[channelID].exists, "u");
//         require(!channels[channelID].settlementInProgress, "w");

//         uint32 nonce;
//         assembly{ nonce := calldataload(add(message.offset, sub(message.length, 32))) } //TO DO: overflow checks?
//         require(nonce > channels[channelID].nonce, "x"); //TO DO: probably not necessary?

//         bytes calldata tokensData = message[START_ADDRS: message.length];

//         //loop over the tokens, and if the balance field is not 0, then we make the requisite calls
//         uint startBals = 20 * numTokens;
//         uint amountToAddOwner;
//         uint amountToAddPartner;
//         address tokenAddress;

//         for (uint8 i = 0; i < numTokens; i++) {
//             assembly { 
//                 tokenAddress := calldataload(add(sub(tokensData.offset, 12), mul(i, 20)))
//                 amountToAddOwner := calldataload(add(tokensData.offset, add(startBals, mul(i, 64))))
//                 amountToAddPartner := calldataload(add(tokensData.offset, add(startBals, add(mul(i, 64), 32))))
//             }
//             if (i == 0 && tokenAddress == address(0) && amountToAddPartner != 0) {
//                 //is ETH. Process appropriately
//                 require(msg.value == amountToAddPartner, "k"); 
//             } else if (amountToAddPartner != 0) {
//                 IERC20 token = IERC20(tokenAddress);
//                 bool success = token.transferFrom(partnerAddress, address(this), amountToAddPartner);
//                 require(success, "j");
//             }
//             if (amountToAddOwner != 0) {
//                 tokenAmounts[tokenAddress] -= amountToAddOwner;
//             }
//             channels[channelID].balances[i] += (amountToAddOwner + amountToAddPartner);
//         }

//         //set nonce
//         channels[channelID].nonce = nonce;
//         reentrancyLock = 0;
//         emit FundsAddedToChannel(channelID, nonce, tokensData);
//     }

//     //helper that distributes the funds, used by settle and settlesubset
//     function distributeSettleTokens(bytes calldata message, uint numTokens, mapping(uint8 => uint) storage balances, address partnerAddress, bool finalNotSubset) private {
//         uint startBals = START_ADDRS + (20 * numTokens);
//         uint _ownerBalance;
//         uint _partnerBalance;
//         address tokenAddress;

//         for (uint8 i = 0; i < numTokens; i++) {
//             if (balances[i] != 0 && (finalNotSubset || (uint8(message[START_ADDRS + (TOKEN_PLUS_BALS_UNIT * numTokens) + i]) == 1))) {
//                 //should settle this token. Either bc nonempty and settle, or nonempty and subsetSettle with flag set
//                 assembly {
//                     tokenAddress := calldataload(add(add(message.offset, 37), mul(i, 20))) //MAGICNUMBERNOTE: bc START_ADDRS is at 49, so first addr ends at 69, 69 - 32 = 37
//                     _ownerBalance := calldataload(add(message.offset, add(startBals, mul(i, 64))))
//                     _partnerBalance := calldataload(add(message.offset, add(startBals, add(mul(i, 64), 32))))
//                 }
//                 require(balances[i] >= _ownerBalance + _partnerBalance, "l");
//                 if (i == 0 && tokenAddress == address(0)) {
//                     payable(partnerAddress).transfer(_partnerBalance);
//                 } else {
//                     IERC20 token = IERC20(tokenAddress);
//                     token.transfer(partnerAddress, _partnerBalance); //TO DO: is this susceptible to a reentrancy attack?? 
//                 }
//                 tokenAmounts[tokenAddress] += _ownerBalance;
//                 balances[i] == 0;
//             }    
//         }
//     }

//     /**
//      * Requires a settle message. When two parties agree they want to settle out to chain, they can sign a settle message. This is 
//      * the expected exit strategy for a channel. Because its agreed upon as the last message, it is safe to immediately distribute funds
//      * without needing to wait for a settlement period. 
//      */
//     function settle(bytes calldata message, bytes calldata ownerSignature, bytes calldata partnerSignature) external {
//         require(reentrancyLock == 0, "a");
//         reentrancyLock = 1;

//         MsgType msgType = MsgType(uint8(message[0]));
//         require (msgType == MsgType.SETTLE, "! a SETTLE");

//         uint numTokens = uint(uint8(message[NUM_TOKEN]));
//         uint channelID = uint(keccak256(message[1: START_ADDRS + (numTokens * 20)]));
//         address partnerAddress = checkSignatures(message, ownerSignature, partnerSignature);
//         require(msg.sender == partnerAddress || msg.sender == owner, "i"); // TO DO: necesssary? Prevents watchtower-called settled, but is this a flaw?
//         require(channels[channelID].exists, "u");
        
//         distributeSettleTokens(message, numTokens, channels[channelID].balances, partnerAddress, true);
    
//         //clean up
//         wipeOutChannel(channelID);
//         reentrancyLock = 0;
//         emit Settled(channelID, partnerAddress, message[START_ADDRS: message.length]);
//     }


//     function settleSubset(bytes calldata message, bytes calldata ownerSignature, bytes calldata partnerSignature) external {
//         require(reentrancyLock == 0, "a");
//         reentrancyLock = 1;
        
//         MsgType msgType = MsgType(uint8(message[0]));
//         require (msgType == MsgType.SETTLESUBSET, "p");

//         uint numTokens = uint(uint8(message[NUM_TOKEN]));
//         uint channelID = uint(keccak256(message[1: START_ADDRS + (numTokens * 20)]));
//         address partnerAddress = checkSignatures(message, ownerSignature, partnerSignature);
//         require(msg.sender == partnerAddress || msg.sender == owner, "i"); // TO DO: necesssary? Prevents watchtower-called settled, but is this a flaw?
//         require(channels[channelID].exists, "u"); 
//         require(!channels[channelID].settlementInProgress, "w"); //TO DO: necessary? Can we nix a channel even if settling? I think necessary, think further on this. 
//         uint32 nonce;
//         assembly { nonce := calldataload(add(message.offset, sub(message.length, 32))) }
//         require(nonce > channels[channelID].nonce, "x");

//         distributeSettleTokens(message, numTokens, channels[channelID].balances, partnerAddress, false);

//         channels[channelID].nonce = nonce; //Enables the UnconditionalSubset msg to now be spent
//         reentrancyLock = 0;
//         emit SettledSubset(channelID, nonce, message);
//     }


//     /** Note that not all of shards are deleted: if shards go from 8 -> 6, then there are still two shards (7,8) which remain. They 
//      * get deleted in withdraw. Design decision, could delete all if I wanted here. 
//      */
//     function updateShards(Channel storage channel, bytes calldata message, uint shardPointer, uint numShards, uint numTokens) private {
//         //check that update is valid. TO DO: check all of these operations, esp assembly, for overflow
//         require(reentrancyLock == 0, "a");
//         shardPointer += 1; //jump past len encoding byte
//         for (uint8 i = 0; i < numShards; i++) {
//             //clear submappings within a shard
//             for (uint8 j = 0; j < numTokens; j++) {
//                 delete channel.shards[i].givingBalances[j];
//                 delete channel.shards[i].receivingBalances[j];
//             }
//             delete channel.shards[i]; //shard mapping blank slate to write on now.

//             Shard storage shard = channel.shards[i];

//             uint8 numGiving = uint8(message[shardPointer]);
//             shardPointer += 1;

//             for (uint j = 0; j < numGiving; j++) {
//                 uint8 tokenIndex = uint8(message[shardPointer]);
//                 uint value;
//                 assembly { value := calldataload(add(message.offset, add(shardPointer, 1))) }
//                 require(shard.givingBalances[tokenIndex] == 0, "y"); //this prevents against having two, say, ETH balances in the givingTokens. Would fuck up exceeding balances calculation.
//                 shard.givingBalances[tokenIndex] = value;
//                 shardPointer += SHARD_LEN;
//             }

//             uint8 numReceiving = uint8(message[shardPointer]);
//             shardPointer += 1;

//             for (uint j = 0; j < numReceiving; j++) {
//                 uint8 tokenIndex = uint8(message[shardPointer]);
//                 uint value;
//                 assembly { value := calldataload(add(message.offset, add(shardPointer, 1))) }
//                 require(shard.receivingBalances[tokenIndex] == 0, "y"); //TO DO: ¿necessary? this prevents against having two, say, ETH balances in the givingTokens. Maybe would fuck up exceeding balances calculation.
//                 require(shard.givingBalances[tokenIndex] == 0, "z"); //TO DO: ¿necessary? Done to prevent wonky stuff from happening in exceeding balances calculations. 
//                 shard.receivingBalances[tokenIndex] = value;
//                 shardPointer += SHARD_LEN;
//             }
//             uint _hashlock;
//             bool _updateIncludesTuringIncomplete;
//             bool _ownerControlsHashlock;
//             uint8 shardBlockTimeoutHours;
//             assembly {
//                 _hashlock := calldataload(add(message.offset, shardPointer))
//                 _updateIncludesTuringIncomplete := calldataload(add(message.offset, add(shardPointer, 1)))
//                 _ownerControlsHashlock := calldataload(add(message.offset, add(shardPointer, 2)))
//                 shardBlockTimeoutHours := calldataload(add(message.offset, add(shardPointer, 3)))
//             }
//             shard.forwardHashlock = _hashlock;
//             if (_updateIncludesTuringIncomplete) {
//                 assembly { _hashlock := calldataload(add(message.offset, add(shardPointer, 35))) } //MAGICNUMBERNOTE: 35 here is from + hashlock(32) + (2 bools, 1 uint8) following the hashlock
//                 shard.revertHashlock = _hashlock;
//             }
//             shard.updateIncludesTuringIncomplete = _updateIncludesTuringIncomplete;
//             shard.ownerControlsHashlock = _ownerControlsHashlock;
//             shard.shardBlockTimeout = uint32(block.number + (uint(shardBlockTimeoutHours) * BLOCKS_PER_HOUR));
//         }

//         //We have updated all of the shards. Now, we need to check whether for a given token, it will exceed the allotted balance in the channel.
//         //we do this by looping over all the balances. Then, to each we add the amount that is locked in the giving and receiving channels for all
//         //the shards for this given token. If this is greater than the channel balance, we revert.
//         uint startBal = START_ADDRS + (numTokens * 20);
//         for (uint8 tokenIndex = 0; tokenIndex < numTokens; tokenIndex++) {
//             uint balanceInitial;
//             assembly {
//                 let ownerBalanceIndex := add(message.offset, add(startBal, mul(64, tokenIndex)))
//                 balanceInitial := add(calldataload(ownerBalanceIndex), calldataload(add(ownerBalanceIndex, 32)))
//             }
//             for (uint8 shardIndex = 0; shardIndex < numShards; shardIndex++) {
//                 balanceInitial += channel.shards[shardIndex].givingBalances[tokenIndex];
//                 balanceInitial += channel.shards[shardIndex].receivingBalances[tokenIndex];
//             }
//             require(balanceInitial <= channel.balances[tokenIndex], "l");
//         }
//     }


//     /**
//      * Endpoint for when a party is noncompliant/offline and the other party needs to force a settle. Starts a settlment period. 
//      * Accepts either a Unconditional/Initial message or a Sharded message. Unconditional/Initial messages will only succeed if there is not a settlment already started. 
//      * Sharded messages will only succeed if nonce is higher, and will reset the timeout to what is passed in. Can be called after a settlement has started. 
//      * startDispute can be called by owner or partner only. Done to prevent any malicious activity on the part of the watchtowers.//TO DO: necessary??
//      */
//     function startDispute(bytes calldata message, bytes calldata ownerSignature, bytes calldata partnerSignature) external {
//         require(reentrancyLock == 0, "a");
//         uint numTokens = uint(uint8(message[NUM_TOKEN]));
//         uint channelID = uint(keccak256(message[1: START_ADDRS + (numTokens * 20)]));
//         address partnerAddress = checkSignatures(message, ownerSignature, partnerSignature);
//         require(msg.sender == partnerAddress || msg.sender == owner, "i");//Done so that watchtowers cant startDisputes. They can only trump already started settlements.//TO DO: move this around in here, funkiness with startDisupte and trump being in the same function
                
//         Channel storage channel = channels[channelID]; 
//         require(channel.exists, "u");

//         uint32 nonce; 
//         assembly{ nonce := calldataload(add(message.offset, sub(message.length, 32))) }

//         MsgType msgType = MsgType(uint8(message[0]));
        
//         //if after a subset settle, ensure that subset settle has been published
//         if (msgType == MsgType.UNCONDITIONALSUBSET) {
//             require(nonce == channel.nonce + 1, "x");
//             msgType = MsgType.UNCONDITIONAL;
//         }
//         uint shardPointer = START_ADDRS + (TOKEN_PLUS_BALS_UNIT * numTokens); //points to location of importance in shards. Starts at numShards
//         uint8 numShards = (msgType == MsgType.SHARDED) ? uint8(message[shardPointer]) : 0; //0 unless SHARDED, 

//         require(msgType == MsgType.INITIAL || msgType == MsgType.UNCONDITIONAL || msgType == MsgType.SHARDED, "p"); //TO DO: ¿necessary?

//         //properly set the shards, while also checking for overflows of channel balances
//         updateShards(channel, message, shardPointer, numShards, numTokens);
        
//         //everything looks good. Modify channel, then return
        
//         if (!channel.settlementInProgress) {
//             if (msgType == MsgType.SHARDED) {
//                 //TO DO: can I combine both of below into a single update, since shard will always bc >, < but never equal, so checking >= equivalent to checking > anyways
//                 require(nonce > channel.nonce, "x");
//             } else {
//                 require(nonce >= channel.nonce, "x"); //>= is for case where starting settlement with a message that was used in a update() call already. Note shards cannot be used in update().
//             }
//             uint8 disputeBlockTimeoutHours;
//             assembly{ disputeBlockTimeoutHours := calldataload(sub(message.offset, 30)) } //MAGICNUMBERNOTE: 30 bc disputeBlockTimeout sits at position 01, so -30 + 32 = 2, will have last byte as pos. 1, as desired!
//             channel.disputeBlockTimeout = uint32(block.number + (uint(disputeBlockTimeoutHours) * BLOCKS_PER_HOUR)); //Note we only set this first startDispute call: all subsequent trumps must make it within this initially activated timeout. There is no reset.
//             channel.settlementInProgress = true;
//         } else {
//             require(nonce > channel.nonce, "x");
//             require(channel.disputeBlockTimeout > block.number, "f"); // TO DO: ¿necessary?
//         }
//         // TO DO: can we do these in one SSTORE update, so to save gas? All fit into the same storage slot. (Would be harder to fit disputeBlockTimeout, settlementInProgress, in there as well)
//         channel.nonce = nonce;
//         channel.numShards = numShards;
//         channel.msgHash = uint256(keccak256(message[0 : START_ADDRS + (TOKEN_PLUS_BALS_UNIT * numTokens)]));

//         emit DisputeStarted(channelID, nonce, msgType);
//     }


//     /**
//      * Done to push either push fwd(normal, turing incomplete), or revert(turing incomplete) a shard. 
//      * For this call to succeed, there must be a settlement on a Sharded message already in place.
//      * Must still call withdraw when timeout ends. Balances are set here, but funds not yet distributed. 
//      */
//     function changeShardState(bytes calldata channelIDMsg, uint hashlockPreimage, uint8 shardNo, bool pushForward) external {
//         require(reentrancyLock == 0, "a");
//         uint channelID = uint(keccak256(channelIDMsg));
//         require(channels[channelID].exists, "u");
//         require(channels[channelID].numShards > shardNo, "v");
//         Shard storage shard = channels[channelID].shards[shardNo];
        
//         require(shard.shardBlockTimeout >= block.number, "e");
//         address partnerAddress;
//         assembly{ partnerAddress := calldataload(sub(channelIDMsg.offset, 4)) } //MAGICNUMBERNOTE: so that reads up to -4 + 32 = 28, which is where partnerAddress ends in channelID
               
//         if (shard.updateIncludesTuringIncomplete) {
//             uint hashlock = pushForward ? shard.forwardHashlock : shard.revertHashlock;
//             require(hashlock == uint(keccak256(abi.encodePacked(hashlockPreimage))), "A");
//             //slash if pushedForward in revert, reverted in pushForward
//             if ((shard.pushedForward == 1 && pushForward) || (shard.pushedForward == 2 && !pushForward)) {
//                 shard.pushedForward = 3;
//             } else if (shard.pushedForward == 0) {
//                 shard.pushedForward = pushForward ? 2 : 1;
//             } else {
//                 revert('m');
//             }
//         } else {
//             //nonTuringInc. case. If shard has not been pushed forward; if hashlock given is correct, push forward. But, if less than 1 hour remaining, then slash.
//             require(shard.pushedForward == 0, "m");
//             require(shard.forwardHashlock == uint(keccak256(abi.encodePacked(hashlockPreimage))), "A");
//             shard.pushedForward = (shard.shardBlockTimeout - block.number > BLOCKS_PER_HOUR) ? 2 : 3;
//         }
        
//         emit ShardStateChanged(channelID, shardNo, hashlockPreimage, shard.pushedForward);
//     }

//     function wipeOutChannel(uint channelID) private {
//         //loop over balances mapping, delete all. Then loop over shards, loop over submappings, delete all, then finally delete channel
//         Channel storage channel = channels[channelID];
        
//         for (uint8 i = 0; i < channel.numTokens; i++) {
//             delete(channel.balances[i]);
//         }
//         for (uint8 i = 0; i < channel.numShards; i++) {
//             for (uint8 j = 0; j < channel.numTokens; j++) {
//                 delete(channel.shards[i].givingBalances[j]);
//                 delete(channel.shards[i].receivingBalances[j]);
//             }
//             delete(channel.shards[i]);
//         }
//         delete channels[channelID];
//         lockCount -= 1;
//     }


//     /**
//      * Is precisely the message used in the keccak at the end of startDispute
//      */
//     function withdraw(bytes calldata message) external {
//         require(reentrancyLock == 0, "a");
//         reentrancyLock = 1;
        
//         uint numTokens = uint(uint8(message[NUM_TOKEN])); 
//         uint channelID = uint(keccak256(message[1: START_ADDRS + (20 * numTokens)]));
        
//         eligibleForWithdraw(channelID);
//         //all shardBlockTimeouts,disputeBlockTimeout have ended, channel actually exists, it is now safe to send out values

//         Channel storage channel = channels[channelID];        
//         require(uint256(keccak256(message)) == channel.msgHash, "B");
        
//         address partnerAddress;
//         assembly{ partnerAddress := calldataload(sub(message.offset, 3)) } //MAGICNUMBERNOTE: so that reads up to -3 + 32 = 29, which is where partnerAddress ends in message
        
//         uint startBal = START_ADDRS + (numTokens * 20);
//         for (uint8 tokenIndex = 0; tokenIndex < numTokens; tokenIndex++) {
//             uint ownerBalance;
//             uint partnerBalance;
//             address tokenAddress;
//             assembly {
//                 ownerBalance := calldataload(add(message.offset, add(startBal, mul(64, tokenIndex))))
//                 partnerBalance := calldataload(add(message.offset, add(startBal, add(mul(tokenIndex, 64), 32))))
//                 tokenAddress := calldataload(add(message.offset, add(37, mul(tokenIndex, 20)))) //MAGICNUMBERNOTE: bc START_ADDRS is at 49, so first addr ends at 69 - 32 = 37
//             }
//             for (uint8 shardIndex = 0; shardIndex < channel.numShards; shardIndex++) {
//                 if (channel.shards[shardIndex].pushedForward == 2) {
//                     //pushedFwd. owner is giving the balances, and getting the receiving balances
//                     ownerBalance += channel.shards[shardIndex].receivingBalances[tokenIndex];
//                     partnerBalance += channel.shards[shardIndex].givingBalances[tokenIndex];
//                 } else if (channel.shards[shardIndex].pushedForward == 3) {
//                     //slashed. This means that hashlock owner has lost all of their funds
//                     uint total = channel.shards[shardIndex].receivingBalances[tokenIndex] + channel.shards[shardIndex].givingBalances[tokenIndex];
//                     channel.shards[shardIndex].ownerControlsHashlock ? (partnerBalance += total) : (ownerBalance += total);
//                 } else {
//                     //Must be 0, 1, a revert. Thus, owner is not giving the balances. So, giving balances go to owner, receiving to partner. In reality, one of below should be 0, but we add both rather than checking which it is.
//                     ownerBalance += channel.shards[shardIndex].givingBalances[tokenIndex];
//                     partnerBalance += channel.shards[shardIndex].receivingBalances[tokenIndex];
//                 }
//             }
//             //TO DO: could do another check here that ownerBalance + partnerBalance <= channel.balances[tokenIndex], but this feels unnecessary as already checked in startDispute
//             if (tokenIndex == 0 && tokenAddress == address(0)) {
//                 payable(partnerAddress).transfer(partnerBalance);   
//             } else {
//                 IERC20 token = IERC20(tokenAddress);
//                 token.transfer(partnerAddress, partnerBalance); //TO DO: is this susceptible to a reentrancy attack?? I do delete the channelID above, but it feels very risky.
//             }
//             tokenAmounts[tokenAddress] += ownerBalance;
//         }
        
//         //clean up
//         wipeOutChannel(channelID);
//         reentrancyLock = 0;
//         emit Settled(channelID, partnerAddress, message[START_ADDRS : START_ADDRS + (numTokens * TOKEN_PLUS_BALS_UNIT)]);
//     }
}

























//Error Msg Key:
// a: "can't reenter contract"
// b: "either channel does not exist or no settlement is in progress"
// c: can't withdraw yet bc disputeBlockTimeout has not expired
// d: at least one shardBlockTimeout hasn't expired yet
// e: shard has already expired
// f: disputeBlockTimeout has expired; too late to pass new message
// g: only owner can add funds
// h: invalid terminate conditions exist, either sender != owner or lockCount != 0
// i: no 3rd party submission; msg.sender must be owner or partner
// j: failed transferFrom attempt on an IERC20 contract
// k: the msg.value was too small for amount of native token requested in msg
// l: the updated balances are invalid, as they sum to a greater total than that staked into the channel
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
// x: update nonce is not high enough (either equal or old msg passed)
// y: can't have two of same token
// z: can't sell and buy same token
// A: preimage does not hash to hashlock (either fwd/revert, depending on pushForward bool)
// B: message passed to withdraw does not match that given in startDispute 
// C: cant use a recycled message!