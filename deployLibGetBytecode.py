import json
import subprocess

from binascii import unhexlify as unhex

from web3 import Web3
from web3.middleware import geth_poa_middleware #only useful for PoA testnets

chainToChainInfo = {
    '00002a': {
        #KOVAN
        'chainID': 42,
        'websocket-url': 'kovan.infura.io/ws/v3/4adfed5d08a14f30bc6e392fd7de9abe',
        'blocksPerHour': 240,
        'buffer': 240/4,
        'blockConfirmations': 14
    },
    '00247b': {
        #Testnet1
        'chainID': 9339,
        'websocket-url': '35.172.110.164:8000', #has ws:// at start normally, should work with wss://
        'blocksPerHour': 240,
        'buffer': 240/4,
        'deadlineInterval': 240 + (240/4), # blocksPerHour + buffer. For use in heartbeat
        'websocket_kwargs': {"origin": "kaladin"},
        'blockConfirmations': 1
    },
    '0024e9': {
        #Testnet2
        'chainID': 9449,
        'websocket-url': '3.227.22.86:8000',
        'blocksPerHour': 240,
        'buffer': 240/4,
        'deadlineInterval': 240 + (240/4), # blocksPerHour + buffer. For use in heartbeat
        'websocket_kwargs': {"origin": "kaladin"},
        'blockConfirmations': 1
    },
    '013881': {
        #MATIC testy
        'chainID': 80001,
        'websocket-url': 'polygon-mumbai.infura.io/ws/v3/082d830057bd471f84c0385e42403ff9',
        'blocksPerHour': 240,
        'buffer': 240/4,
        'deadlineInterval': 240 + (240/4), # blocksPerHour + buffer. For use in heartbeat
        'websocket_kwargs': {"origin": "mumbai"},
        'blockConfirmations': 14
    },
    '000061': {
        #BSC testy
        'chainID': 97,
        'websocket-url': '',
        'blocksPerHour': 1185,
        'buffer': 1185 / 4,
        'deadlineInterval': 1185 + (1185 / 4)
    },
    '000507': {
        #ALPHA Moonbase
        'chainID': 1287,
        'websocket-url': '',
        'blocksPerHour': '?',
        'buffer': '?',
        'deadlineInterval': '?'
    },
    '000152': {
        #Cronos Testy
        'chainID': 338,
        'websocket-url': '',
        'blocksPerHour': '?',
        'buffer': '?',
        'deadlineInterval': '?'
    }
    # 'BTC': {},
    # 'AVAX': {}
}


def configWeb3(chain):
    chainInfo = chainToChainInfo[chain]
    if 'websocket_kwargs' in chainInfo:
        #currenly doing this for local testing, have to deal with PoA chain funkinees
        if chain in {'00247b', '0024e9'}:
            w3 = Web3(Web3.WebsocketProvider(f'ws://{chainInfo["websocket-url"]}', websocket_kwargs=chainInfo['websocket_kwargs']))
        else:
            w3 = Web3(Web3.WebsocketProvider(f'wss://{chainInfo["websocket-url"]}', websocket_kwargs=chainInfo['websocket_kwargs'], websocket_timeout=60))
        w3.middleware_onion.inject(geth_poa_middleware, layer=0)
    else:
        w3 = Web3(Web3.WebsocketProvider(f'wss://{chainInfo["websocket-url"]}'))
    return w3



def writeJSONToFile(dictionary, filename = 'networkData.json'):
    with open(filename, "w") as outfile:
        json.dump(dictionary, outfile)

def readJSONFromFile(filename = 'networkData.json'):
    with open(filename, 'r') as infile:
        dictionary = json.load(infile)
    return dictionary


def getStormBytecode():
    compileContracts()
    with open('./SolidityContracts/Storm.bin','r') as file:
        jss = json.loads(file.read())
        StormABI = jss["contracts"]['SolidityContracts/Storm.sol:Storm']["abi"]
        StormBIN = jss["contracts"]['SolidityContracts/Storm.sol:Storm']["bin"]
    with open('./SolidityContracts/Storm.bin','r') as file:
        jss = json.loads(file.read())
        StormLibraryABI = jss["contracts"]['SolidityContracts/StormLibrary.sol:StormLib']["abi"]
        StormLibraryBIN = jss["contracts"]['SolidityContracts/StormLibrary.sol:StormLib']["bin"]
    return StormABI, StormBIN, StormLibraryABI, StormLibraryBIN

def getIERC20Bytecodes():
    compileContracts(Storm=False)
    with open('./SolidityContracts/ERC20WBTC.bin','r') as file:
        jss = json.loads(file.read())
        WBTCABI = jss["contracts"]['SolidityContracts/ERC20WBTC.sol:RandomIERC20WBTC']["abi"]
        WBTCBIN = jss["contracts"]['SolidityContracts/ERC20WBTC.sol:RandomIERC20WBTC']["bin"]
    with open('./SolidityContracts/ERC20LINK.bin','r') as file:
        jss = json.loads(file.read())
        LINKABI = jss["contracts"]['SolidityContracts/ERC20LINK.sol:RandomIERC20LINK']["abi"]
        LINKBIN = jss["contracts"]['SolidityContracts/ERC20LINK.sol:RandomIERC20LINK']["bin"]
    
    return WBTCABI, WBTCBIN, LINKABI, LINKBIN


def compileContracts(Storm=True):
    if Storm:
        subprocess.run(["./SolidityContracts/compileStorm.zsh"])
    else:
        subprocess.run(["./SolidityContracts/compileERCs.zsh"])




def insertLibraryIntoStormBIN(bin, libraryAddress):
    return bin.replace('__$eb8b95dd541977d31a420ac467b707fbaa$__', libraryAddress)


def web3PublishHelper(tx_dict, privKey):
    private_key = unhex(privKey)
    signed_tx = w3.eth.account.sign_transaction(tx_dict, private_key=private_key)
    return w3.eth.send_raw_transaction(signed_tx.rawTransaction).hex()


def deployStormToChain(chain):
    #deploy library first
    StormABI, StormBIN, StormLibraryABI, StormLibraryBIN = getStormBytecode()
 
    global w3
    w3 = configWeb3(chain)
    StormLibrary = w3.eth.contract(abi=StormLibraryABI, bytecode=StormLibraryBIN)
    addressNonce = w3.eth.get_transaction_count('0x03eEc99D228433D81c6EDC3BB01c153a5469858b')
    tx_dict = {
        'chainId': int(chain, 16),
        'gas': 5000000, #5M will be enough? work w this number. I think, depending on how optimized, takes 2-3M gas.
        'nonce': addressNonce,
        'from': '0x03eEc99D228433D81c6EDC3BB01c153a5469858b',
    }
    # w3.eth.default_account = w3.eth.accounts[0]
    tx_dict = StormLibrary.constructor().buildTransaction(tx_dict)
    # print(StormLibrary.constructor().transact())
    txHash = web3PublishHelper(tx_dict, '60c88541801f28f604f3746529ea99abe2d832078082b8dd08bb7405b26afa90')
    libAddr = (w3.eth.wait_for_transaction_receipt(txHash).contractAddress)[2:]

    print('\n\nlibAddr', libAddr, '\n\n\n')
    print('Storm Bytecode\n\n', StormBIN)





if __name__ == '__main__':
    chains = {
        'Kovan': '00002a',
        'Testnet1': '00247b',
    }
    deployStormToChain(chains['Testnet1'])