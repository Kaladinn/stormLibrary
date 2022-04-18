const axios = require('axios').default;
import { keccakFromString, keccakFromHexString, Address, ecsign, ecrecover, fromRpcSig} from 'ethereumjs-util'

//TODO: have these set elsewhere to be specific values relevant to the selected blockchain
const web3 = new Web3(new Web3.providers.WebsocketProvider('wss://kovan.infura.io/ws/v3/4adfed5d08a14f30bc6e392fd7de9abe'))
const Storm = new web3.eth.Contract(StormABI, contractAddress)
    //Storm = new web3.eth.Contract(StormABI[channel['chain']], channel['contract']) if want to set dynamically w/in fn.
// from StormMeta import StormChannelFunctionTypes, nativeToken



//msg, sig must contain a leading 0x
function checkSignature(msg, sig, pubKey) {
    const sigComps = fromRpcSig(sig)
    const msgHash = keccakFromHexString(msg, 256)
    const pubKeyComputed = bufferToHex(pubToAddress(ecrecover(msgHash, sigComps.v, sigComps.r, sigComps.s))) //TO DO: add 27 to v??
    
    if (pubKeyComputed !== pubKey) {
        raise('Signature Verification Failed')
    }
}


//msg must contain a leading 0x
function signMessage(msg, pubKey, DBIndex) {
    const privKey = ''//TODO: get privKey from give pubKey
    const privKeyBuf = Buffer.from(privKey, "hex")
    
    let msgHash = keccakFromHexString(msg, 256)
    let sig = ecsign(msgHash, privKeyBuf)
    let sigV = '0' + (sig.v % 2 == 0 ? '1' : '0')//set to either 00, 01, from 27/28, 31/32
    let sigString = sig.r.toString('hex') + sig.s.toString('hex') + sigV
    console.log('sigstring', sigString)
    return sigString 
}


// function updateChannelPartner(channel, ownerSig, DBIndex) {
//     dynamo.Table('Channels' + DBIndex).update_item(
//         Key = {
//             'channelID': channel['channelID']
//         },
//         UpdateExpression = "SET newMsg=:nM, newTokenBalanceMap=:nTBM, newSigs=:newSigs, channelStatus=:cS, FundsAddedToChannelBlock=:FATCB, newBalanceTotals=:nBT",
//         ExpressionAttributeValues = {
//             ':nM': channel['newMsg'],
//             ':nTBM': channel['tokenBalanceMap'],
//             ':newSigs': [ownerSig, channel['newSig']],
//             ':cS': 'aFAc',
//             ':FATCB': channel['FATCB'],
//             ':nBT': channel['newBalanceTotals']
//         }
//     )
// }


function publishToStorm(channel, body, CPAddFundsSig, web3, Storm, DBIndex) {
    //We must call addFundsToChannel
    let signatures = web3.utils.hexToBytes(CPAddFundsSig + channel['addFundsSig'])
    let msg = web3.utils.hexToBytes((channel['addFundsMsg'] + channel['balanceTotals']))
    let value = body['funds'].has(nativeToken) ? parseInt(body['funds'][nativeToken]['partnerAmount'], 16) : 0

    encodedData = Storm.methods.channelGateway(msg, signatures, StormChannelFunctionTypes['ADDFUNDSTOCHANNEL']).encodeABI()
    var tx_dict = {
        to : channel['contract'],
        chainID: channel['chainID'],
        from: channel['myAddr'],
        nonce: channel['onChainNonce'],
        value: value, //TODO: set this to be the value
        gasLimit: web3.utils.toHex(300000),
        gasPrice: web3.utils.toHex(web3.utils.toWei('20', 'gwei')),
        data : encodedData,
    }

    //TODO: Publish these to chain.

}


//checks whether I have enough in my approved and my tokens to be able to support adding this many. If yes, then I check owner has enough free in tokenAmounts, and if both pass I am good.
async function partnerHelper(channel, partnerAmount, ownerAmount, tokenAddr){
    //check CPFunds
    if (tokenAddr == nativeToken) {
        if (await web3.eth.getBalance(channel['myAddr']) < partnerAmount) {
            raise('not enough native partner funds')
        }
    } else {
        let approved = channel['currUnstakedFunds'][tokenAddr]['approved'][channel['contract']] //will have this contract in approved, since is added during the anchor handling
        if (channel['currUnstakedFunds'][tokenAddr]['amount'] + approved  < partnerAmount) {
            raise(`you own ${channel["currUnstakedFunds"][tokenAddr]["amount"]} plus approved ${approved} of ${tokenAddr} but tried to add into channel ${partnerAmount}`)
        }
        //check ownerFunds
        ownerChannelFunds =  await Storm.methods.tokenAmounts('0x' + tokenAddr).call()
        if (ownerChannelFunds < ownerAmount) {
            raise(`owner has in contract ${ownerChannelFunds} of ${tokenAddr} but you are requesting ${ownerAmount}`)
        }
    }
}

function pad(data, length) { 
    if (data.length > length || data.slice(2) == '0x' || typeof(data) != str) {
        raise('Unsupported padding length, has leading 0x, or already longer than max pad')
    }
    //TODO: add check to make sure only hex vals (regex)
    return '0'.repeat(length - len(data)) + data
}

function populateMetadata(channel, DBIndex) {
    let chainInfo = getChainInfo(channel['chain'])
    channel['chainID'] = int(chainInfo['chainID'])
    channel['onChainNonce'] = await web3.eth.getTransactionCount(channel['myAddr'])

    // //get privKey for this pubKey from Keys DB
    // channel['privKey'] = dynamo.Table('Keys' + DBIndex).get_item(
    //     Key = {
    //         'pubKey' : channel['myAddr'],
    //     }    
    // )['Item']['privKey']
  
    channel['currUnstakedFunds'] = populateCurrUnstakedFunds(channel['chain'], channel['myAddr'], DBIndex)
}

//convert all of the amounts to ints, check that there are enough funds to make it happen(for both ourself, and for owner) (web3 calls)
//format new msgs to be signed, and send sigs, to other party
function checkAndFormatAddFundsMsgs(eventFunds, channel, DBIndex, contractFunds = {}) {
    populateMetadata(channel, DBIndex) //defines the global web3 for later use w/in this fn.
    if (channel['channelStatus'] == 'sharded') {
        raise('increaseChannelFunds only supported for non sharded channels')
    }
    //start with msgType, channelID, add on all new balances, then tack on rest of information, but increment nonce by 2
    let addFundsMsg = StormMessageTypes['ADDFUNDSTOCHANNEL'] + channel['msg'].slice(2, balancesIndex + (len(channel['tokenBalanceMap']) * 40)) //for MsgType addFundsToChannel + channelID
    let newMsg = StormMessageTypes['UNCONDITIONAL'] + channel['msg'].slice(2, balancesIndex + (len(channel['tokenBalanceMap']) * 40)) //done so that will update from anchor Msg -> unconditional if was an anchor (i.e. first byte was 00)

    let newBalanceTotals = ""
    for (let i = 0; i < channel['tokenBalanceMap'].size(); i++) {
        let token = channel['msg'].slice(balancesIndex + (i * 40), balancesIndex + ((i + 1) * 40))
        //assumes that we are partner
        ownerAmount = '00'.repeat(32)
        partnerAmount = '00'.repeat(32)
        if (eventFunds.has(token)) {
            partnerAmount = parseInt(eventFunds[token]['partnerAmount'], 16)
            ownerAmount =  parseInt(eventFunds[token]['ownerAmount'], 16)
            if (isNaN(partnerAmount) || isNaN(ownerAmount)) {
                raise('Cant convert given vals to a number, aborting') //TODO: add other checks (regex?) to make sure is hex string? parseInt will convert axsgsdg => a => 10, instead of returning NaN
            }
            partnerHelper(channel, partnerAmount, ownerAmount, token)
            channel['tokenBalanceMap'][token]['ownerBalance'] += ownerAmount
            channel['tokenBalanceMap'][token]['partnerBalance'] += partnerAmount
            ownerAmount = pad(eventFunds[token]['partnerAmount'], 64, 'ownerAmount')
            partnerAmount = pad(eventFunds[token]['ownerAmount'], 64, 'partnerAmount')
        }
        newMsg += ( pad(channel['tokenBalanceMap'][token]['ownerBalance'].toString(16), 64) + pad(channel['tokenBalanceMap'][token]['ownerBalance'].toString(16), 64) )
        addFundsMsg += (ownerAmount + partnerAmount)
        newBalanceTotals += pad((channel['tokenBalanceMap'][token]['ownerBalance'] + channel['tokenBalanceMap'][token]['partnerBalance']).toString(16), 64)
    }

    //add on nonces, after we have added all the balances on.
    addFundsMsg += pad((channel['nonce'] + 1).toString(16), 8)
    newMsg +=  pad((channel['nonce'] + 1).toString(16), 8) 
    channel['addFundsSig'] = signMessage(addFundsMsg, channel['mySignerAddr'], DBIndex)
    channel['newSig'] = signMessage(newMsg, channel['mySignerAddr'], DBIndex)
    channel['addFundsMsg'] = addFundsMsg
    channel['newMsg'] = newMsg
    channel['newBalanceTotals'] = newBalanceTotals
}


function approveToken(tokenAddr, amountToApprove, dataStructure, nonce, chainID, pubKey, w3, DBIndex, unapprove=False) {
    let token = new web3.eth.Contract(tokenABI[dataStructure['chain']], '0x'+ tokenAddr)
    if  (!unapprove) {
        //then we have no desire to change amount approve, since already sufficient. But if need to unapprove, then we want to change new amount to amountToApprove, so we skip this.
        let amountAlreadyApproved = await token.methods.allowance(pubKey, dataStructure['contract']).call() //owner, spender
        if (amountAlreadyApproved >= amountToApprove) {
            return { 'approved': False, 'tx_receipt': {}, 'amountApproved': 0}  //returns False since no approve call made, and 0 since no new tokens were approved
        } else {
            amountToApprove -= amountAlreadyApproved //no need to approve extra funds if some has already been approved, albeit not quite enough for amountToApprove
        }
    }

    encodedData = token.methods.approve(dataStructure['contract'], amountToApprove).encodeABI()
    var tx_dict = {
        to : '0x' + tokenAddr,
        chainID: channel['chainID'],
        from: channel['myAddr'],
        nonce: channel['onChainNonce'],
        value: value, //TODO: set this to be the value
        gasLimit: web3.utils.toHex(300000),
        gasPrice: web3.utils.toHex(web3.utils.toWei('20', 'gwei')),
        data : encodedData,
    }

    //TODO: publish to chain, return tx_receipt

    return { 'approved': True, 'tx_receipt': '', 'amountApproved': amountToApprove }
}


function addFundsToChannel(channel, body) {
    const headers = { "Content-Type": "application/json" }
    const DBIndex = body['DBIndex']
    
    try {
        Storm = address=channel['contract'], abi=StormABI[channel['chain']]
        if (channel['owns']) {
            raise('cant own and propose extra funds; only partner can do that')
        }
        
        checkAndFormatAddFundsMsgs(body['funds'], channel, DBIndex, contractFunds = {})
        inputParams = {
            'funds': body['funds'],
            'channelID': body['channelID'],
            'DBIndex': channel['CPDBIndex'],
            'addFundsSig': channel['addFundsSig'],
            'newMsgSig': channel['newSig'],
            'sessionID': channel['sessionID']
        }
        try {
            var resp = await axios.post(channel['CPEndpoint'] + '/increaseChannelFunds/receive', inputParams, {headers: headers})
        } catch(err) {
            raise(err)  //TO DO: see why failed. If failed cuz owner doesn't want to add more funds, may want to pass a settle message, move on and find new partner.
        }
        if (r.status == 480) {
            //means that partner does not want to accept this stake. Do we settle, try again?
        } else if (r.status != 200) {
            //TO DO: should we go to chain here?
            console.log(`!200 err of ${r.json()}`)
            raise('errrrr')
            // raise GoToChainException(f'increaseChannelFunds/receive failed with err code {r.status_code}, msg {r.json()}')
        } 
        try {
            resp = r.data
            CPNewMsgSig = resp['newMsgSig']
            CPAddFundsSig = resp['addFundsSig']
            checkSignature('0x' + channel['addFundsMsg'], '0x' + CPAddFundsSig, channel['CPAddr']) //since we know CP owns, no need to check CPSignerAddr; it doesnt exist
            checkSignature('0x' + channel['newMsg'], '0x' + CPNewMsgSig, channel['CPAddr'])
        } catch(err) {
            raise(err)
        }
        try {
            for (let [tokenAddr, tokenData] of body['funds']) {
                //TO DO: deal with errors that could happen if only a portion of these funds properly publish. Look at update channels and unstaked
                if (tokenAddr != nativeToken) {
                    let approveData = approveToken(tokenAddr, int(tokenData['partnerAmount'], 16), channel, channel['onChainNonce'], channel['chainID'], channel['myAddr'], DBIndex) //again, assuming that we are always the partner bc doesnt own contract
                    if (approveData.approved) {
                        //means that we needed to add extra funds, and we added amountApproved of them. Note this isn't necessarily amount, because may have already had some funds approved
                        //if not approved, means we already had sufficient approved funds, and amountApproved will be == 0
                        if (!approveData.tx_receipt.status) {
                            raise(`oh no, approve to IERC20 ${tokenAddr} has failed`)
                        }
                        channel['onChainNonce'] += 1
                    }
                    //increment the approved amount of this token. NOTE: no need to check if in approved; we know it will be, since always added in anchor.
                    channel['currUnstakedFunds'][tokenAddr]['approved'][channel['contract']] += approveData.amountApproved
                    //now, we need to decrement funds we approved from our 'amount' field, since we didnt do this before in checkAndFormat, we just checked
                    channel['currUnstakedFunds'][tokenAddr]['amount'] -= approveData.amountApproved
                }
            }
            publishToStorm(channel, body, CPAddFundsSig, web3, Storm, DBIndex)
        } catch(err) {
            // channel['currUnstakedFunds'][nativeToken]['amount'] = web3.eth.get_balance(channel['myAddr']) //could have had some successes, still probably want to decrement this value. 
            // updateUnstakedFunds({'chain': channel['chain'], 'pubKey': channel['myAddr'], 'currUnstakedFunds': channel['currUnstakedFunds']}, DBIndex)
            // channel['FATCB'] = 'placeholder, delete me, set this properly if failure.For use in updateChannel'
            // updateChannelPartner(channel, CPNewMsgSig, DBIndex)
            // raise ("oh man, late error when publishing shit, need to think through this case: " + str(err))
        } 
        //all succeeded, including approves and the addFundsMsg! Yay.
        updateUnstakedFunds({'chain': channel['chain'], 'pubKey': channel['myAddr'], 'currUnstakedFunds': channel['currUnstakedFunds']}, DBIndex)
        updateChannelPartner(channel, CPNewMsgSig, DBIndex)
    
    } catch(err) {
        raise(err)
    }

}
//
// example input: {
//     "channel": {
//          ...channelData
//     }
//     "body": {
//         "channelID": "abcd....", //hex string, no 0x.
//         "funds": {
//             tokenAddr (hex string, w/ 0x) => {
//                 partnerAmount: amount, //specifies how much partner will add. Hex string, no 0x
//                 ownerAmount: amount //specifies how much owner will add. Hex string, no 0x.
//             },
//             ...
//         },
//         "DBIndex" : "0" (str, base 10)
//     },
//     "asyncID": "abc..." .hex string no 0x
// }
//
