# script to run ipfs
ipfs add -Qr ipfs-policies-and-claims
export CLAIMS_GATEWAY=http://127.0.0.1:8080
export POLICIES_CID=$ROOT_CID
export CLAIMS_CID=$ROOT_CID
npm i dotenv axios (Run once)
truffle migrate --reset