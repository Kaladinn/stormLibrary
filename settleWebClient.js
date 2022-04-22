const axios = require('axios').functionault;
import { keccakFromString, keccakFromHexString, Address, ecsign, ecrecover, fromRpcSig} from 'ethereumjs-util'

//TODO: have these set elsewhere to be specific values relevant to the selected blockchain
const web3 = new Web3(new Web3.providers.WebsocketProvider('wss://kovan.infura.io/ws/v3/4adfed5d08a14f30bc6e392fd7de9abe'))
const Storm = new web3.eth.Contract(StormABI, contractAddress)
    //Storm = new web3.eth.Contract(StormABI[channel['chain']], channel['contract']) if want to set dynamically w/in fn.
// from StormMeta import StormChannelFunctionTypes, nativeToken


// from StormMeta import StormABI, EVMChains, StormChannelFunctionTypes, StormMessageTypes
import { checkSignature } from './sharedJSFunctions.js'
// from helpers import getChannels0, checkSignature, updateDBSettle, getChainInfo, signFinalMsgs, publishToChain, kecc
// TO DO: add support for listening if other party has actually closed channel after passing back sigs from /accepted
// TO DO: make sure this route is protected, so only the owner can hit it. Using some JWT or AWS authorization.
// TO DO: deal with submitToChain fails, or there has already been onchainactivity at submit time... duh duh duh, etc. 
    



function forceDispute(channels, DBIndex) {
    for (var channel in channels) {
        try {
            dynamo.Table('Channels' + DBIndex).update_item(
                Key = {
                    'channelID': channel['channelID']
                },
                ConditionExpression = 'attribute_exists(channelID) and attribute_not_exists(goToChainFlag)',
                UpdateExpression = 'SET goToChainFlag=:gTCF',
                ExpressionAttributeValues = { ':gTCF': 'want to settle with a non server' } //TODO: workshop this.
            )
        } catch (e) {
            pass //we don't care if it succeeds, if it failed its for a wonky reason, or bc already going to chain
        }
    }
    raise('cant settle w this person, since they are not running a node, cant receive response. We will instead startDispute with them to force settle.')

}

function checkSigs(channels, sigs) {
    if (sigs.length != channels.length) {
        raise(`mismatched sig length of ${sigs.length}, channels of length ${channels.length}`)
    }
    for (let i = 0; i < channels.length; i++) {
        var channel = channels[i]
        var sig = sigs[i]
        var CPAddrUsedToSign = channel['owns'] ? channel['CPSignerAddr'] : channel['CPAddr'] //CP signs with signerAddr is they are partner,else they just use CPAddr (i.e. owner)
        try {
            if (!channel.has('settleSubsetMsg')) {
                checkSignature(channel['newMsg'], sig, CPAddrUsedToSign)
                channel['sigs'] = channel['owns'] ? [channel['newSig'], sig] : [sig, channel['newSig']]
            } else {
                //subset msgs
                let CPSettleSubsetSig = sig[0]
                let CPUnconditionalSubsetSig = sig[1]
                checkSignature(channel['settleSubsetMsg'], CPSettleSubsetSig, CPAddrUsedToSign)
                checkSignature(channel['unconditionalSubsetMsg'], CPUnconditionalSubsetSig, CPAddrUsedToSign)
                channel['settleSubsetSigs'] = channel['owns'] ? [channel['settleSubsetSig'], CPSettleSubsetSig] : [CPSettleSubsetSig, channel['settleSubsetSig']]
                channel['unconditionalSubsetSigs'] = channel['owns'] ? [channel['unconditionalSubsetSig'], CPUnconditionalSubsetSig] : [CPUnconditionalSubsetSig, channel['unconditionalSubsetSig']]
            }
        } catch(e) {
            console.log('channel msg err')
            //we want to loop through all to catch the properly signed ones, and use these to save gas on chain. So we ignore errors for now.
            channel['errMsg'] = err
        }
    }
}
    
            


function submitToChain(channels, DBIndex) {
    for (var channel in channels) {
        if (!channel.has('errMsg')) {
            try {
                if (EVMChains.has(channel['chain'])) {
                    var chainInfo = getChainInfo(channel['chain'])
                    // global w3
                    var websocketEndpoint = chainInfo['explorer']
                    var w3 = Web3(Web3.WebsocketProvider(`wss://${websocketEndpoint}`))
                    
                    //TO DO: make sure that if there are 2+ channels using the same addr, that the nonce call is correct. Problem if nonce call doesn't incrememnt bc tx still too fresh, so when go to publish, nonce is behind 1, and tx fails. 
                    var nonce = w3.eth.get_transaction_count(channel['myAddr'])
            
                    var privKey = dynamo.Table('Keys' + DBIndex).get_item(
                        Key = {
                            'pubKey' : channel['myAddr'],
                        }
                    )['Item']['privKey']
                    var Storm = w3.eth.contract(address=channel['contract'], abi=StormABI[channel['chain']])
                    if (!channel.has('settleSubsetMsg')) {
                        //normal settle
                        var signatures = web3.utils.hexToBytes(channel['sigs'][0] + channel['sigs'][1])
                        var tx_dict = Storm.functions.channelGateway(web3.utils.hexToBytes(channel['newMsg'] + channel['balanceTotals']), signatures, StormChannelFunctionTypes['SETTLE']).buildTransaction({
                            'chainId': int(chainInfo['chainID']),
                            'gas': 300000, //300K will be enough? work w this number
                            'nonce': nonce,
                            'value': 0
                        })
                    } else { 
                        //subset settle
                        var signatures = web3.utils.hexToBytes(channel['settleSubsetSigs'][0]) + unhex(channel['settleSubsetSigs'][1])
                        var tx_dict = Storm.functions.channelGateway(web3.utils.hexToBytes(channel['settleSubsetMsg']) + web3.utils.hexToBytes(channel['balanceTotals']), signatures, StormChannelFunctionTypes['SETTLESUBSET']).buildTransaction({
                            'chainId': int(chainInfo['chainID']),
                            'gas': 300000, //300K will be enough? work w this number
                            'nonce': nonce,
                            'value': 0
                        })
                    }
                    let tx_receipt = publishToChain(tx_dict, privKey, w3)
                    if (!channel.has('settleSubsetMsg')) {
                        channel['SettledBlock'] = tx_receipt.blockNumber
                    } else {
                        channel['SettledSubsetBlock'] = tx_receipt.blockNumber
                    }
                    if (!tx_receipt.status) {
                        raise(`failed when trying to settle contract ${channel["contract"]}`)
                    }
                } else {
                    pass
                    //TO DO: deal with Bitcoin, Stellar
                }
            } catch (e) {
                console.log('chanmsgerr1', err)
                channel['errMsg'] = err
                //TO DO: figure out why this failed, and set the channel data correctly, so it can be viewed properly set later in updateDBSettle
            }
        }
    }
}

    

function writeAsyncRequest(asyncID, DBIndex, msg = '') {
    if (msg) {
        dynamo.Table('AsyncRequests').update_item(
    		 Key = {
                'asyncID': asyncID,
            },
            UpdateExpression="SET requestStatus=:s, msg=:m, DBIndex=:DBI",
            ExpressionAttributeValues = {
                ':s': 'failure',
                ':m': msg,
                ':DBI': DBIndex
            }
    	)
    } else {
        dynamo.Table('AsyncRequests').update_item(
			 Key = {
                'asyncID': asyncID,
            },
            UpdateExpression="SET requestStatus=:s, DBIndex=:DBI",
            ExpressionAttributeValues = {
                ':s': 'success',
                ':DBI': DBIndex
            }
		)
    }
}


//TO DO: proper error handling here/go to chain if must.
//TO DO: check server, and if not server, then we must set a goToChainFlag, and exit, since cannot ping them regardless

function lambda_handler(event, context) {
    var headers = {
        "Content-Type": "application/json"
    }
    try {
        //any error here we want to just not write
        var asyncID = event['asyncID']
        var DBIndex = event['body']['DBIndex']
        //get contract, channelID from event body.
        console.log(0)
        var channels = getChannels0(event['body']['channels'], DBIndex)
        console.log(1)
        try {
            console.log(2)
            //TODO: this needs to be returned as a mapping, not as three separate
            sessionIDs, CPEndpoint, CPDBIndex = signFinalMsgs(channels, event['body']['channels'], DBIndex)
            console.log(3)
            if (!channels[0]['server']) {
                //means that we can't call out to settle, bc they don't possess an endpoint. So, we will need to force a dispute.
                forceDispute(channels, DBIndex)
            }
            //send sigs to settle/receive for CP ENDPOINT
            var inputParams = {
                'DBIndex': CPDBIndex,
                'channels': event['body']['channels'],
                'sessionIDs': sessionIDs
            }
            var endpoint = CPEndpoint + '/settle/receive'
        } catch (e) {
            //nothing here has happened with upstream, so just need to unlockChannels, then return a failure msg
            updateDBSettle(channels, 'publisher', DBIndex, unlockDB=True)
            raise(err)
        }
        try {
            var r = requests.post(endpoint, data=dumps(inputParams), headers=headers, timeout=10)
            //we should now have received a signed message agreeing to Settle update.
            if (r.status_code != 200) {
                raise(`received status code of ${r.status_code} with body ${dumps(r.json())}`) //TO DO: actually handle this.
            }
            var data = r.json()
        } catch (e) {
            //we need to go to chain with this person. //1, we dont want to be in the channel any longer, and //2, they are misbehaving, so we should GTC anyways.
            //TO DO: no pending Update! Can we make this really easy for our heartbeat? THink on this
            var failedChannels = updateDBSettle(channels,'publisher', DBIndex, goToChain=True)
            raise({'failed Channels': failedChannels, 'err': err})
        }

            
        try {
            checkSigs(channels, data['sigs'])
        } catch(e) {
            //mismatching sig, channel lengths, don't even bother checking the channels
            var failedChannels = updateDBSettle(channels, 'publisher', DBIndex, goToChain=True)
            raise({'failed Channels': failedChannels, 'err': err})
        }

        submitToChain(channels, DBIndex)
        //TO DO: may want to add the block numbers/transaction numbers so that heartbeat can more easily check that they are finalized. Also, may not even want to wait in heartbeat if not ETH/BTC, but rather wait in function, more instantaneous. Optimization thought for down the road.
        var failedChannels = updateDBSettle(channels, 'publisher', DBIndex)

        if (failedChannels) {
            raise({'failedChannels': failedChannels})
        }

        //let any async waiting party know that has succeeded
        writeAsyncRequest(asyncID, DBIndex)
            
    } catch(err) {
        console.log(err)
        writeAsyncRequest(asyncID, DBIndex, str(err))
    }        
}

//Receives:
// '''JSON Object
//     {
//         channels : [
//             {
//                 'contract': '',
//                 'channelID' : '',
//                 'tokensInSubset': [...], //empty if not settling subset
//             },
//         ],
//         'DBIndex' : '',
//         'asyncID': '',
// }'''