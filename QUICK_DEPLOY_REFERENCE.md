# Quick Deploy Reference - CreatorCoin Implementation

## TL;DR - Fast Track

```bash
# 1. Setup
cd packages/coins
cat > .env << 'EOF'
PRIVATE_KEY=your_key_here
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASE_RPC_URL=https://mainnet.base.org
ETHERSCAN_API_KEY=your_api_key_here
EOF

# 2. Test on Sepolia
forge script script/DeployCreatorCoinImpl.s.sol:DeployCreatorCoinImpl \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv

# 3. Deploy to Mainnet
forge script script/DeployCreatorCoinImpl.s.sol:DeployCreatorCoinImpl \
  --rpc-url $BASE_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

## Network Addresses

### Base Mainnet (8453)
```
Reward Recipient: 0x7bf90111Ad7C22bec9E9dFf8A01A44713CC1b1B6
Pool Manager:     0x498581ff718922c3f8e6a244956af099b2652b2b
Airlock:          0x660eAaEdEBc968f8f3694354FA8EC0b4c5Ba8D12
```

### Base Sepolia (84532)
```
Reward Recipient: 0x5F14C23983c9e0840Dc60dA880349622f0785420
Pool Manager:     0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
Airlock:          0xa24E35a5d71d02a59b41E7c93567626302da1958
```

## Common Commands

```bash
# Check balance
cast balance YOUR_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL

# Verify contract manually
forge verify-contract YOUR_ADDRESS src/CreatorCoin.sol:CreatorCoin \
  --chain-id 84532 \
  --constructor-args $(cast abi-encode "constructor(address,address,address,address)" \
    0x5F14C23983c9e0840Dc60dA880349622f0785420 \
    0x7777777F279eba3d3Ad8F4E708545291A6fDBA8B \
    0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408 \
    0xa24E35a5d71d02a59b41E7c93567626302da1958) \
  --etherscan-api-key $ETHERSCAN_API_KEY

# Test implementation
cast call YOUR_IMPL_ADDRESS "coinType()(uint8)" --rpc-url $BASE_SEPOLIA_RPC_URL
```

## Gas Costs
- Deployment: ~3-4M gas (~0.001-0.002 ETH)
- Verification: Free

## Links
- Base Sepolia Explorer: https://sepolia.basescan.org
- Base Mainnet Explorer: https://basescan.org
- Faucet: https://www.coinbase.com/faucets/base-ethereum-goerli-faucet
- Full Guide: [DEPLOY_CREATOR_COIN.md](./DEPLOY_CREATOR_COIN.md)
