// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {CreatorCoin} from "../src/CreatorCoin.sol";
import {ZoraFactoryImpl} from "../src/ZoraFactoryImpl.sol";
import {ZoraFactory} from "../src/proxy/ZoraFactory.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title DeployCompleteCustomSystem
 * @notice Deploy the complete system: CreatorCoin implementation + Factory implementation + Factory proxy
 * @dev This is a one-shot deployment that gives you a fully functional factory with custom CreatorCoin
 *
 * Usage:
 *   forge script script/DeployCompleteCustomSystem.s.sol:DeployCompleteCustomSystem \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --verify \
 *     -vvvv
 *
 * This will deploy:
 * 1. Your modified CreatorCoin implementation (supports any ERC20)
 * 2. ZoraFactoryImpl pointing to your CreatorCoin
 * 3. ZoraFactory proxy (you own it and can use it immediately)
 */
contract DeployCompleteCustomSystem is Script {
    // Protocol rewards contract (same across all networks)
    address internal constant PROTOCOL_REWARDS = 0x7777777F279eba3d3Ad8F4E708545291A6fDBA8B;

    struct Deployment {
        address creatorCoinImpl;
        address contentCoinImpl;
        address hook;
        address hookRegistry;
        address factoryImpl;
        address factoryProxy;
        address owner;
    }

    function run() public {
        Deployment memory deployment;
        deployment.owner = msg.sender;

        // Get network-specific addresses
        (
            address protocolRewardRecipient,
            address poolManager,
            address airlock,
            address existingContentCoinImpl,
            address existingHook,
            address existingHookRegistry
        ) = getNetworkAddresses();

        console.log("=======================================================");
        console.log("  COMPLETE CUSTOM ZORA SYSTEM DEPLOYMENT");
        console.log("=======================================================");
        console.log("Network Chain ID:", block.chainid);
        console.log("Deployer/Owner:", deployment.owner);
        console.log("");

        vm.startBroadcast();

        // ============================================================
        // STEP 1: Deploy CreatorCoin Implementation
        // ============================================================
        console.log("STEP 1: Deploying CreatorCoin Implementation...");
        CreatorCoin creatorCoinImpl = new CreatorCoin({
            protocolRewardRecipient_: protocolRewardRecipient,
            protocolRewards_: PROTOCOL_REWARDS,
            poolManager_: IPoolManager(poolManager),
            airlock_: airlock
        });
        deployment.creatorCoinImpl = address(creatorCoinImpl);
        deployment.contentCoinImpl = existingContentCoinImpl;
        deployment.hook = existingHook;
        deployment.hookRegistry = existingHookRegistry;
        console.log("  CreatorCoin Implementation:", deployment.creatorCoinImpl);
        console.log("  (Modified to support ANY ERC20 token)");
        console.log("");

        // ============================================================
        // STEP 2: Deploy ZoraFactoryImpl
        // ============================================================
        console.log("STEP 2: Deploying ZoraFactoryImpl...");
        ZoraFactoryImpl factoryImpl = new ZoraFactoryImpl({
            coinV4Impl_: deployment.contentCoinImpl,
            creatorCoinImpl_: deployment.creatorCoinImpl,
            hook_: deployment.hook,
            zoraHookRegistry_: deployment.hookRegistry
        });
        deployment.factoryImpl = address(factoryImpl);
        console.log("  ZoraFactoryImpl:", deployment.factoryImpl);
        console.log("");

        // ============================================================
        // STEP 3: Deploy ZoraFactory Proxy and Initialize
        // ============================================================
        console.log("STEP 3: Deploying ZoraFactory Proxy...");
        ZoraFactory factory = new ZoraFactory(deployment.factoryImpl);
        deployment.factoryProxy = address(factory);

        console.log("  ZoraFactory Proxy:", deployment.factoryProxy);
        console.log("  Owner:", ZoraFactoryImpl(deployment.factoryProxy).owner());
        console.log("");

        vm.stopBroadcast();

        // ============================================================
        // DEPLOYMENT SUMMARY
        // ============================================================
        console.log("=======================================================");
        console.log("  DEPLOYMENT COMPLETE!");
        console.log("=======================================================");
        console.log("");
        console.log("Deployed Addresses:");
        console.log("-------------------");
        console.log("CreatorCoin Implementation:", deployment.creatorCoinImpl);
        console.log("ContentCoin Implementation:", deployment.contentCoinImpl, "(reused)");
        console.log("Factory Implementation:    ", deployment.factoryImpl);
        console.log("Factory Proxy:             ", deployment.factoryProxy, "<-- USE THIS");
        console.log("Hook:                      ", deployment.hook, "(reused)");
        console.log("Hook Registry:             ", deployment.hookRegistry, "(reused)");
        console.log("Owner:                     ", deployment.owner);
        console.log("");
        console.log("=======================================================");
        console.log("  HOW TO USE YOUR FACTORY");
        console.log("=======================================================");
        console.log("");
        console.log("Your factory is ready! Deploy creator coins with ANY ERC20:");
        console.log("");
        console.log("Example - USDC-backed creator coin:");
        console.log("------------------------------------");
        console.log("address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base USDC");
        console.log("bytes memory poolConfig = CoinConfigurationVersions.defaultConfig(usdc);");
        console.log("");
        console.log("address coin = IZoraFactory(", deployment.factoryProxy, ").deployCreatorCoin(");
        console.log("    msg.sender,              // payoutRecipient");
        console.log("    [msg.sender],            // owners");
        console.log('    "ipfs://metadata",       // uri');
        console.log('    "My Creator Coin",       // name');
        console.log('    "MCC",                   // symbol');
        console.log("    poolConfig,              // pool config with USDC");
        console.log("    address(0),              // platformReferrer");
        console.log("    bytes32(0)               // salt");
        console.log(");");
        console.log("");
        console.log("Supported Tokens:");
        console.log("  - ETH (wrapped): 0x4200000000000000000000000000000000000006");
        console.log("  - USDC:          0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913");
        console.log("  - DAI:           0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb");
        console.log("  - Or ANY ERC20 token!");
        console.log("");
        console.log("=======================================================");
        console.log("");
        console.log("SAVE THESE ADDRESSES - YOU'LL NEED THEM!");
        console.log("");
    }

    function getNetworkAddresses()
        internal
        view
        returns (address protocolRewardRecipient, address poolManager, address airlock, address contentCoinImpl, address hook, address hookRegistry)
    {
        uint256 chainId = block.chainid;

        if (chainId == 8453) {
            // Base Mainnet
            protocolRewardRecipient = 0x7bf90111Ad7C22bec9E9dFf8A01A44713CC1b1B6;
            poolManager = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
            airlock = 0x660eAaEdEBc968f8f3694354FA8EC0b4c5Ba8D12;
            contentCoinImpl = 0x7Cad62748DDf516CF85bC2C05C14786D84Cf861c; // Existing ContentCoin
            hook = 0xC8d077444625eB300A427a6dfB2b1DBf9b159040; // Existing hook
            hookRegistry = 0x777777C4c14b133858c3982D41Dbf02509fc18d7; // Existing registry
        } else if (chainId == 84532) {
            // Base Sepolia (Testnet)
            protocolRewardRecipient = 0x5F14C23983c9e0840Dc60dA880349622f0785420;
            poolManager = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
            airlock = 0xa24E35a5d71d02a59b41E7c93567626302da1958;
            contentCoinImpl = 0x1cAE9ceA75Ac862bb3dF6AAf7BE028EDe8e67Afd;
            hook = 0xe0eC17Ab9f7ce52cC60DFB64E0A0A705d02Bd040;
            hookRegistry = 0x777777C4c14b133858c3982D41Dbf02509fc18d7; // Existing registry from Base Mainnet (not functional)
        } else {
            revert("Unsupported network. Add configuration for this chain ID.");
        }
    }
}
