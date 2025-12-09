# Deploying Your Modified CreatorCoin Implementation

This guide walks you through deploying your modified CreatorCoin implementation that supports any ERC20 token (not just hardcoded ETH).

## Overview

You've modified `packages/coins/src/CreatorCoin.sol` to remove the hardcoded currency restriction. Now you need to deploy this new implementation so it can be used to create coins with any ERC20 backing token.

## Prerequisites

### 1. Install Foundry (if not already installed)

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. Set Up Your Environment

Create a `.env` file in `packages/coins/`:

```bash
cd packages/coins
cat > .env << 'EOF'
# Your deployer private key (NEVER commit this!)
PRIVATE_KEY=your_private_key_here

# Network RPC URLs
BASE_RPC_URL=https://mainnet.base.org
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# Etherscan API key for verification (get from https://basescan.org/myapikey)
ETHERSCAN_API_KEY=your_etherscan_api_key_here
EOF
```

**IMPORTANT**: Add `.env` to `.gitignore` to avoid committing secrets!

### 3. Fund Your Deployer Wallet

Your deployer wallet needs ETH for gas:

- **Base Sepolia (Testnet)**: Get free testnet ETH from https://www.coinbase.com/faucets/base-ethereum-goerli-faucet
- **Base Mainnet**: You'll need real ETH (~0.01 ETH should be enough)

Check your balance:

```bash
cast balance $YOUR_DEPLOYER_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL
```

## Step-by-Step Deployment

### Step 1: Test Build Locally

First, ensure everything compiles:

```bash
cd packages/coins
forge build
```

You should see:

```
Compiler run successful with warnings
```

### Step 2: Deploy to Base Sepolia (Testnet First!)

**Always test on testnet before mainnet!**

```bash
cd packages/coins

# Deploy to Base Sepolia testnet
forge script script/DeployCreatorCoinImpl.s.sol:DeployCreatorCoinImpl \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

**What this does:**

1. Deploys the CreatorCoin implementation contract
2. Automatically verifies the source code on BaseScan
3. Shows you the deployed address

**Expected Output:**

```
=== CreatorCoin Implementation Deployment ===
Network Chain ID: 84532
Deployer: 0x...
Constructor Parameters:
  Protocol Reward Recipient: 0x5F14C23983c9e0840Dc60dA880349622f0785420
  Protocol Rewards: 0x7777777F279eba3d3Ad8F4E708545291A6fDBA8B
  Pool Manager: 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
  Airlock: 0xa24E35a5d71d02a59b41E7c93567626302da1958

=== Deployment Complete ===
CreatorCoin Implementation: 0x... <-- SAVE THIS ADDRESS!
```

**Save the implementation address!** You'll need it for the next steps.

### Step 3: Verify Deployment

Check the contract on BaseScan:

```bash
# Open in browser
open "https://sepolia.basescan.org/address/YOUR_IMPLEMENTATION_ADDRESS"
```

Verify:

- ✅ Contract is verified (green checkmark)
- ✅ Constructor arguments match expected values
- ✅ Source code is readable

### Step 4: Test the Implementation

Create a simple test deployment script to verify your implementation works:

```bash
cd packages/coins

# Test that the implementation can be initialized
cast call YOUR_IMPLEMENTATION_ADDRESS "coinType()(uint8)" --rpc-url $BASE_SEPOLIA_RPC_URL
```

Expected output: `1` (indicating it's a CreatorCoin type)

### Step 5: Deploy to Base Mainnet (Production)

**⚠️ CAUTION: This costs real money and is irreversible!**

Only proceed if:

- ✅ Testnet deployment succeeded
- ✅ Contract is verified
- ✅ You've tested thoroughly
- ✅ You have enough ETH for gas

```bash
cd packages/coins

# Deploy to Base Mainnet
forge script script/DeployCreatorCoinImpl.s.sol:DeployCreatorCoinImpl \
  --rpc-url $BASE_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

**Gas Cost Estimate**: ~3-4M gas ≈ 0.001-0.002 ETH (depending on network congestion)

### Step 6: Save Deployment Information

Create a record of your deployment:

```bash
cd packages/coins

# Save to a deployment record
cat > deployments/creator-coin-custom-$(date +%Y%m%d).txt << EOF
Deployment Date: $(date)
Network: Base Mainnet (Chain ID: 8453)
Deployer: $(cast wallet address --private-key $PRIVATE_KEY)
Implementation Address: YOUR_DEPLOYED_ADDRESS
Transaction Hash: YOUR_TX_HASH
BaseScan Link: https://basescan.org/address/YOUR_DEPLOYED_ADDRESS

Changes:
- Removed hardcoded currency restriction
- Now supports any ERC20 token as backing currency

Constructor Args:
- protocolRewardRecipient: 0x7bf90111Ad7C22bec9E9dFf8A01A44713CC1b1B6
- protocolRewards: 0x7777777F279eba3d3Ad8F4E708545291A6fDBA8B
- poolManager: 0x498581ff718922c3f8e6a244956af099b2652b2b
- airlock: 0x660eAaEdEBc968f8f3694354FA8EC0b4c5Ba8D12
EOF
```

## Using Your Deployed Implementation

### Option A: Deploy Your Own Factory

If you want complete control, deploy a new ZoraFactory that uses your CreatorCoin:

```solidity
// Deploy new factory implementation
ZoraFactoryImpl newFactory = new ZoraFactoryImpl({
    coinV4Impl_: 0x7Cad62748DDf516CF85bC2C05C14786D84Cf861c,  // Existing ContentCoin
    creatorCoinImpl_: YOUR_NEW_CREATOR_COIN_ADDRESS,           // Your deployment
    hook_: 0xC8d077444625eB300A427a6dfB2b1DBf9b159040,         // Existing hook
    zoraHookRegistry_: 0x777777C4c14b133858c3982D41Dbf02509fc18d7  // Existing registry
});

// Deploy factory proxy
ZoraFactory myFactory = new ZoraFactory(address(newFactory));
myFactory.initialize(msg.sender);
```

### Option B: Propose Upgrade to Existing Factory

To upgrade the official Zora factory (requires multisig approval):

1. **Deploy new ZoraFactoryImpl** with your CreatorCoin address
2. **Create multisig proposal** to call:
   ```solidity
   ZoraFactory(0x777777751622c0d3258f214F9DF38E35BF45baF3)
       .upgradeToAndCall(newFactoryImplAddress, "")
   ```
3. **Get multisig signers** to approve and execute

### Option C: Use Directly (Advanced)

You can interact with your implementation directly using `Clones.clone()`:

```solidity
address clone = Clones.clone(YOUR_CREATOR_COIN_IMPL);
ICreatorCoin(clone).initialize(
    payoutRecipient,
    owners,
    tokenURI,
    name,
    symbol,
    platformReferrer,
    customCurrency,  // <-- Now can be any ERC20!
    poolKey,
    sqrtPriceX96,
    poolConfiguration
);
```

## Network Information

### Base Mainnet (Chain ID: 8453)

```
Protocol Reward Recipient: 0x7bf90111Ad7C22bec9E9dFf8A01A44713CC1b1B6
Pool Manager:              0x498581ff718922c3f8e6a244956af099b2652b2b
Airlock:                   0x660eAaEdEBc968f8f3694354FA8EC0b4c5Ba8D12
Protocol Rewards:          0x7777777F279eba3d3Ad8F4E708545291A6fDBA8B

RPC URL: https://mainnet.base.org
Block Explorer: https://basescan.org
```

### Base Sepolia (Chain ID: 84532)

```
Protocol Reward Recipient: 0x5F14C23983c9e0840Dc60dA880349622f0785420
Pool Manager:              0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
Airlock:                   0xa24E35a5d71d02a59b41E7c93567626302da1958
Protocol Rewards:          0x7777777F279eba3d3Ad8F4E708545291A6fDBA8B

RPC URL: https://sepolia.base.org
Block Explorer: https://sepolia.basescan.org
Faucet: https://www.coinbase.com/faucets/base-ethereum-goerli-faucet
```

## Troubleshooting

### "Insufficient funds for gas"

- Check your wallet balance: `cast balance YOUR_ADDRESS --rpc-url $RPC_URL`
- Get testnet ETH from faucet or send mainnet ETH to your deployer

### "Contract verification failed"

- Wait a few minutes and try manual verification on BaseScan
- Ensure ETHERSCAN_API_KEY is set correctly
- Check that you're using the same compiler version (0.8.28)

### "RPC URL not found"

- Make sure .env file is in `packages/coins/` directory
- Load environment: `source .env`
- Verify RPC is working: `cast block-number --rpc-url $RPC_URL`

### "Transaction reverted"

- Check you're on the correct network
- Verify all constructor arguments are correct
- Look at the revert reason in the transaction on BaseScan

### Deployment script fails with "Unsupported network"

- You're trying to deploy to a network not configured in the script
- Add your network configuration to `getNetworkAddresses()` function
- Or use the raw `forge create` command with manual parameters

## Security Checklist

Before deploying to mainnet:

- [ ] Tested on Base Sepolia testnet
- [ ] Contract verified on block explorer
- [ ] Constructor arguments are correct
- [ ] Removed .env from git tracking
- [ ] Using a dedicated deployer wallet (not your main wallet)
- [ ] Have backups of private keys stored securely
- [ ] Understand the gas costs and have sufficient ETH
- [ ] Know how you'll use the implementation after deployment

## Next Steps

After successful deployment:

1. **Create a coin with custom currency**:

   - Use your implementation to create coins backed by USDC, DAI, or any ERC20
   - Test with small amounts first

2. **Monitor the deployment**:

   - Watch for any unusual activity
   - Check that coins can be created successfully
   - Verify trading works as expected

3. **Consider upgrading the factory**:
   - If you want your implementation to be the default
   - Work with the Zora team to propose an upgrade
   - Or deploy your own factory for independent operation

## Getting Help

- **Zora Discord**: https://discord.gg/zora
- **Zora Docs**: https://docs.zora.co
- **Foundry Book**: https://book.getfoundry.sh
- **Base Docs**: https://docs.base.org

---

**Happy Deploying! 🚀**
