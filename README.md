# How To Run This Program
## Libraries Required
Requirements: Ganache, Truffle, IPFS, Python3, Node (Install These Before Attempting)
## Steps To Run
1. Clone the repo onto a Linux environment
2. ganache-cli to start the Ganache environment
3. ipfs daemon to start the IPFS server
4. cd into the project directory
5. ipfs add -Qr ipfs-policies-and-claims, this will return a hash
6. export CLAIMS_GATEWAY=http://127.0.0.1:8080
7. export POLICIES_CID=$ROOT_CID replace ROOT_CID with the hash from step 5
8. export CLAIMS_CID=$ROOT_CID replace ROOT_CID with the hash from step 5
9. npm i dotenv axios, need to run only on first time setup to use IPFS
10. truffle migrate to start the migration and initialize the contracts on Ganache
11. python3 -m http.server 8020 to start the server and see the website 

# Report Link
https://docs.google.com/document/d/1qGXcIumoPuJfsahOnL5_TuJDRfwpahVninC-ER55F3Q/edit?usp=sharing

