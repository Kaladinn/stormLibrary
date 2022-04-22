import { keccakFromString, keccakFromHexString, Address, ecsign, ecrecover, fromRpcSig} from 'ethereumjs-util'
var Tx = require('@ethereumjs/tx').Transaction;


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


function kecc(msg_str) {
    return bufferToHex(keccakFromHexString(msg_str))
}
web3.eth.signTransaction({
    from: "0xEB014f8c8B418Db6b45774c326A0E64C78914dC0",
    gasPrice: "20000000000",
    gas: "21000",
    to: '0x3535353535353535353535353535353535353535',
    value: "1000000000000000000",
    data: ""
}, 'MyPassword!').then(console.log);

function publishToChain(tx_dict, privKey, w3) {
    var private_key = web3.utils.hexToBytes(privKey)
    // web3.eth.sign
    var transaction = await w3.eth.account.sendTransaction(tx_dict, private_key)
    
}


  
//function that is used by settlePropose, settleReceive. Returns different things for each one.
function signFinalMsgs(channels, channelData, DBIndex) {
    sessionIDs = []
    CPEndpoint = channels[0]['CPEndpoint']
    for (let i = 0; i < channels.length; i ++) {
        var channel = channels[i]
        var channelDatum = channelData[i]
        var mySigningAddr = channel['mySignerAddr'] //give my addr if owner, else im partner so i use mySignerAddr
        if (EVMChains.has(channel['chain'])) {
            try {
                //must make sure that we are in s0 for all channels. Cant check directly, since we have changed this to tryingToSettle
                if (isSharded(channel['msg'])) {
                    raise(`channel {channel["channelID"]} is in state {channel["channelStatus"]} not s0`)
                }
                if (channel['CPEndpoint'] != CPEndpoint) {
                    raise('cant mass settle with different counterparty endpoints') //TODO: necessary?
                }
                sessionIDs.push(channel['sessionID'])
                if (!channelDatum['tokensInSubset']) {
                    //just a plain settle, not subset
                    channel['newMsg'] = StormMessageTypes['SETTLE'] + (channel['msg'].slice(0, 2) == StormMessageTypes['INITIAL'] ? channel['msg'].slice(2,-64) : channel['msg'].slice(2,-8)) //keep same balances, channelID, but change msgType unconditional -> settle, and strip out deadline/nonce
                    channel['newSig'] = signMessage(channel['newMsg'], mySigningAddr, DBIndex)
                    channelDatum['sig'] = channel['newSig']
                } else { 
                    //subset, so need to sign a settleSubsetMsg, and an unconditionalSubsetMsg
                    var endOfChannelID = balancesIndex + (len(channel['tokenBalanceMap']) * 40)
                    channel['settleSubsetMsg'] = StormMessageTypes['SETTLESUBSET'] + (channel['msg'].slice(0, 2) == StormMessageTypes['INITIAL'] ? channel['msg'].slice(2,-64) : channel['msg'].slice(2,-8)) //keep same balances, channelID, but change msgType unconditional -> settle, and strip out deadline/nonce
                    channel['unconditionalSubsetMsg'] = StormMessageTypes['UNCONDITIONALSUBSET'] + channel['msg'].slice(2, endOfChannelID) //msgType + channelID
                    
                    //append string of bools for whether should settle on settleSubsetMsg, zero out balance or keep original for unconditionalSubsetMsg
                    
                    var newBalanceTotals = ""
                    for (let i = 0; i < channel['tokenBalanceMap'].size; i++) {
                        var token = channel['msg'].slice(balancesIndex + (i * 40), balancesIndex + ((i + 1) * 40))
                        if (channelDatum['tokensInSubset'].has(token)) {
                            channel['settleSubsetMsg'] += '01' //01 means settling this token
                            channel['unconditionalSubsetMsg'] += "0" * (TBS - 40)
                            channel['tokenBalanceMap'][token]['ownerBalance'] = 0
                            channel['tokenBalanceMap'][token]['partnerBalance'] = 0
                            newBalanceTotals += '00' * 32
                        } else {
                            channel['settleSubsetMsg'] += '00' //00 means dont settle this token
                            channel['unconditionalSubsetMsg'] += channel['msg'].slice(endOfChannelID + (i * (TBS - 40)), endOfChannelID + ((i + 1) * (TBS - 40)))
                            newBalanceTotals += pad(hex(int(channel['tokenBalanceMap'][token]['ownerBalance'] + channel['tokenBalanceMap'][token]['partnerBalance'])).slice(2), 64, 'balanceTotalsString')
                        }
                    }
                    //add nonces onto both msgs
                    channel['settleSubsetMsg'] += pad(hex(int(channel['nonce']) + 1).slice(2), 8, 'settleSubsetNonce')
                    channel['unconditionalSubsetMsg'] += pad(hex(int(channel['nonce']) + 2).slice(2), 8, 'unconditionalSubsetbNonce')
                    channel['settleSubsetSig'] = signMessage(channel['settleSubsetMsg'], mySigningAddr, DBIndex)
                    channel['unconditionalSubsetSig'] = signMessage(channel['unconditionalSubsetMsg'], mySigningAddr, DBIndex)
                    channel['newBalanceTotals'] = newBalanceTotals

                    
                    channelDatum['settleSubsetSig'] = channel['settleSubsetSig']
                    channelDatum['unconditionalSubsetSig'] = channel['unconditionalSubsetSig']
                }
                  
            } catch (e) {
                raise('none of these should error, we can just abort') //TODO: deal with resetting any of the flags
            }
        } else {
            pass
            //TO DO: deal with Bitcoin, Stellar
        }
    }
    return sessionIDs, CPEndpoint, channels[0]['CPDBIndex']
}