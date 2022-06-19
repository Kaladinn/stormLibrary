#!/bin/sh

#Dont forget to chmod +x this file
solc  --optimize  --optimize-runs=4294967295  --combined-json abi,bin  ./SolidityContracts/Storm.sol > ./SolidityContracts/Storm.bin
solc  --optimize  --optimize-runs=4294967295  --combined-json abi,bin  ./SolidityContracts/StormLibrary.sol > ./SolidityContracts/StormLibrary.bin

