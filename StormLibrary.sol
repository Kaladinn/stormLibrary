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

    struct SwapStruct {
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

    function doATest(SwapStruct storage swappy) external view {
        swappy.hashlock == 3;
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
}