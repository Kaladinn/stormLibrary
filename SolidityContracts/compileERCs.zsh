#!/bin/sh

#Dont forget to chmod +x this file
solc  --optimize   --optimize-runs=4294967295  --combined-json abi,bin ./SolidityContracts/ERC20LINK.sol > ./SolidityContracts/ERC20LINK.bin
solc  --optimize   --optimize-runs=4294967295 --combined-json abi,bin ./SolidityContracts/ERC20WBTC.sol > ./SolidityContracts/ERC20WBTC.bin
