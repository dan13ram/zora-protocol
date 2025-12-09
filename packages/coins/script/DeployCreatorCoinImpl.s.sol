// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {CreatorCoin} from "../src/CreatorCoin.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

/**
 * @title DeployCreatorCoinImpl
 * @notice Script to deploy a new CreatorCoin implementation contract
 * @dev This deploys the implementation contract that can be used by ZoraFactory
 *
 * Usage:
 * 1. Set environment variables in .env:
 *    - PRIVATE_KEY: Your deployer private key
 *    - RPC_URL: Network RPC endpoint
 *    - ETHERSCAN_API_KEY: For contract verification (optional)
 *
 * 2. Run deployment:
 *    forge script script/DeployCreatorCoinImpl.s.sol:DeployCreatorCoinImpl \
 *      --rpc-url $RPC_URL \
 *      --broadcast \
 *      --verify \
 *      -vvvv
 *
 * Network-specific parameters are automatically loaded from chainConfigs/
 */
contract DeployCreatorCoinImpl is Script {
    // Protocol rewards contract (same across all networks)
    address internal constant PROTOCOL_REWARDS = 0x7777777F279eba3d3Ad8F4E708545291A6fDBA8B;

    function run() public {
        // Get network-specific addresses
        (address protocolRewardRecipient, address poolManager, address airlock) = getNetworkAddresses();

        console.log("=== CreatorCoin Implementation Deployment ===");
        console.log("Network Chain ID:", block.chainid);
        console.log("Deployer:", msg.sender);
        console.log("");
        console.log("Constructor Parameters:");
        console.log("  Protocol Reward Recipient:", protocolRewardRecipient);
        console.log("  Protocol Rewards:", PROTOCOL_REWARDS);
        console.log("  Pool Manager:", poolManager);
        console.log("  Airlock:", airlock);
        console.log("");

        vm.startBroadcast();

        CreatorCoin implementation = new CreatorCoin({
            protocolRewardRecipient_: protocolRewardRecipient,
            protocolRewards_: PROTOCOL_REWARDS,
            poolManager_: IPoolManager(poolManager),
            airlock_: airlock
        });

        vm.stopBroadcast();

        console.log("=== Deployment Complete ===");
        console.log("CreatorCoin Implementation:", address(implementation));
        console.log("");
        console.log("IMPORTANT: Save this address!");
        console.log("You can now use this implementation with ZoraFactory");
        console.log("");
        console.log("Next Steps:");
        console.log("1. Verify the contract on block explorer (if not auto-verified)");
        console.log("2. Deploy a new ZoraFactoryImpl with this CreatorCoin address");
        console.log("3. Propose factory upgrade to multisig");
    }

    function getNetworkAddresses() internal view returns (address protocolRewardRecipient, address poolManager, address airlock) {
        uint256 chainId = block.chainid;

        if (chainId == 8453) {
            // Base Mainnet
            protocolRewardRecipient = 0x7bf90111Ad7C22bec9E9dFf8A01A44713CC1b1B6;
            poolManager = 0x498581ff718922c3f8e6a244956af099b2652b2b;
            airlock = 0x660eAaEdEBc968f8f3694354FA8EC0b4c5Ba8D12;
        } else if (chainId == 84532) {
            // Base Sepolia (Testnet)
            protocolRewardRecipient = 0x5F14C23983c9e0840Dc60dA880349622f0785420;
            poolManager = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
            airlock = 0xa24E35a5d71d02a59b41E7c93567626302da1958;
        } else {
            revert("Unsupported network. Add configuration for this chain ID.");
        }
    }
}
