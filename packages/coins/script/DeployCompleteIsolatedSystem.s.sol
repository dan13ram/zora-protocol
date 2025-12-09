// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {CreatorCoin} from "../src/CreatorCoin.sol";
import {ContentCoin} from "../src/ContentCoin.sol";
import {ZoraFactoryImpl} from "../src/ZoraFactoryImpl.sol";
import {ZoraFactory} from "../src/proxy/ZoraFactory.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {HooksDeployment} from "../src/libs/HooksDeployment.sol";
import {HookUpgradeGate} from "../src/hooks/HookUpgradeGate.sol";
import {TrustedMsgSenderProviderLookup} from "../src/utils/TrustedMsgSenderProviderLookup.sol";
import {ITrustedMsgSenderProviderLookup} from "../src/interfaces/ITrustedMsgSenderProviderLookup.sol";
import {CoinConfigurationVersions} from "../src/libs/CoinConfigurationVersions.sol";
import {IZoraFactory} from "../src/interfaces/IZoraFactory.sol";

/**
 * @title DeployCompleteIsolatedSystem
 * @notice Deploy a COMPLETE isolated system including your own hook
 * @dev This deploys everything needed for a fully functional coin system:
 *      1. TrustedMsgSenderLookup
 *      2. HookUpgradeGate
 *      3. ZoraV4CoinHook (YOUR OWN - recognizes your factory)
 *      4. CreatorCoin implementation (supports any ERC20)
 *      5. ContentCoin implementation
 *      6. ZoraFactoryImpl
 *      7. ZoraFactory proxy
 *
 * Usage:
 *   forge script script/DeployCompleteIsolatedSystem.s.sol:DeployCompleteIsolatedSystem \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --verify \
 *     -vvvv
 *
 * This creates a completely independent system that doesn't depend on Zora's infrastructure.
 */
contract DeployCompleteIsolatedSystem is Script {
    // Protocol rewards contract (same across all networks)
    address internal constant PROTOCOL_REWARDS = 0x7777777F279eba3d3Ad8F4E708545291A6fDBA8B;

    struct Deployment {
        address trustedMsgSenderLookup;
        address hookUpgradeGate;
        address zoraV4CoinHook;
        bytes32 hookSalt;
        address creatorCoinImpl;
        address contentCoinImpl;
        address factoryImpl;
        address factoryProxy;
        address owner;
        address testCoin;
    }

    function run() public {
        Deployment memory deployment;
        deployment.owner = msg.sender;

        // Get network-specific addresses
        (
            address protocolRewardRecipient,
            address poolManager,
            address airlock,
            address proxyAdmin,
            address uniswapUniversalRouter,
            address uniswapV4PositionManager
        ) = getNetworkAddresses();

        console.log("=======================================================");
        console.log("  COMPLETE ISOLATED ZORA COIN SYSTEM DEPLOYMENT");
        console.log("=======================================================");
        console.log("Network Chain ID:", block.chainid);
        console.log("Deployer/Owner:", deployment.owner);
        console.log("");
        console.log("NOTE: This deploys your own hook, so it's independent");
        console.log("      from Zora's production infrastructure.");
        console.log("");

        vm.startBroadcast();

        // ============================================================
        // STEP 1: Deploy TrustedMsgSenderLookup
        // ============================================================
        console.log("STEP 1: Deploying TrustedMsgSenderLookup...");
        address[] memory trustedSenders = new address[](2);
        trustedSenders[0] = uniswapUniversalRouter;
        trustedSenders[1] = uniswapV4PositionManager;

        deployment.trustedMsgSenderLookup = address(new TrustedMsgSenderProviderLookup(trustedSenders, proxyAdmin));
        console.log("  TrustedMsgSenderLookup:", deployment.trustedMsgSenderLookup);
        console.log("");

        // ============================================================
        // STEP 2: Deploy HookUpgradeGate
        // ============================================================
        console.log("STEP 2: Deploying HookUpgradeGate...");
        deployment.hookUpgradeGate = address(new HookUpgradeGate(proxyAdmin));
        console.log("  HookUpgradeGate:", deployment.hookUpgradeGate);
        console.log("");

        // ============================================================
        // STEP 3: Deploy Factory Proxy (placeholder for hook deployment)
        // ============================================================
        console.log("STEP 3: Deploying Factory Proxy (placeholder)...");
        // We need the factory address before deploying the hook, so deploy proxy first
        deployment.factoryProxy = address(new ZoraFactory(address(0)));
        console.log("  Factory Proxy (placeholder):", deployment.factoryProxy);
        console.log("");

        // ============================================================
        // STEP 4: Deploy ZoraV4CoinHook
        // ============================================================
        console.log("STEP 4: Deploying ZoraV4CoinHook...");
        (IHooks hook, bytes32 salt) = HooksDeployment.deployHookWithExistingOrNewSalt(
            HooksDeployment.FOUNDRY_SCRIPT_ADDRESS,
            HooksDeployment.makeHookCreationCode(
                address(IPoolManager(poolManager)),
                deployment.factoryProxy,
                ITrustedMsgSenderProviderLookup(deployment.trustedMsgSenderLookup),
                deployment.hookUpgradeGate
            ),
            bytes32(0) // Let it generate a new salt
        );
        deployment.zoraV4CoinHook = address(hook);
        deployment.hookSalt = salt;
        console.log("  ZoraV4CoinHook:", deployment.zoraV4CoinHook);
        console.log("  Hook Salt:", vm.toString(deployment.hookSalt));
        console.log("");

        // ============================================================
        // STEP 5: Deploy Coin Implementations
        // ============================================================
        console.log("STEP 5: Deploying Coin Implementations...");

        deployment.creatorCoinImpl = address(
            new CreatorCoin({
                protocolRewardRecipient_: protocolRewardRecipient,
                protocolRewards_: PROTOCOL_REWARDS,
                poolManager_: IPoolManager(poolManager),
                airlock_: airlock
            })
        );
        console.log("  CreatorCoin Implementation:", deployment.creatorCoinImpl);
        console.log("    (Modified to support ANY ERC20 token)");

        deployment.contentCoinImpl = address(
            new ContentCoin({
                protocolRewardRecipient_: protocolRewardRecipient,
                protocolRewards_: PROTOCOL_REWARDS,
                poolManager_: IPoolManager(poolManager),
                airlock_: airlock
            })
        );
        console.log("  ContentCoin Implementation:", deployment.contentCoinImpl);
        console.log("");

        // ============================================================
        // STEP 6: Deploy ZoraFactoryImpl
        // ============================================================
        console.log("STEP 6: Deploying ZoraFactoryImpl...");
        deployment.factoryImpl = address(
            new ZoraFactoryImpl({
                coinV4Impl_: deployment.contentCoinImpl,
                creatorCoinImpl_: deployment.creatorCoinImpl,
                hook_: deployment.zoraV4CoinHook,
                zoraHookRegistry_: address(0) // We don't need hook registry for isolated system
            })
        );
        console.log("  ZoraFactoryImpl:", deployment.factoryImpl);
        console.log("");

        // ============================================================
        // STEP 7: Initialize Factory Proxy
        // ============================================================
        console.log("STEP 7: Initializing Factory Proxy...");
        UUPSUpgradeable(deployment.factoryProxy).upgradeToAndCall(
            deployment.factoryImpl,
            abi.encodeWithSelector(ZoraFactoryImpl.initialize.selector, deployment.owner)
        );
        console.log("  Factory initialized with owner:", deployment.owner);
        console.log("");

        // ============================================================
        // STEP 8: Deploy Test Creator Coin
        // ============================================================
        console.log("STEP 8: Deploying Test Creator Coin...");
        console.log("  This verifies your system works end-to-end!");
        console.log("");

        // Get the backing currency (ETH wrapped or USDC depending on preference)
        address backingCurrency = getBackingCurrency();
        console.log("  Using backing currency:", backingCurrency);

        // Create pool configuration for the backing currency
        bytes memory poolConfig = CoinConfigurationVersions.defaultConfig(backingCurrency);

        // Create array with deployer as the only owner
        address[] memory owners = new address[](1);
        owners[0] = deployment.owner;

        // Deploy the test creator coin
        deployment.testCoin = IZoraFactory(deployment.factoryProxy).deployCreatorCoin({
            payoutRecipient: deployment.owner,
            owners: owners,
            uri: "ipfs://bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku", // Example metadata
            name: "Test Creator Coin",
            symbol: "TEST",
            poolConfig: poolConfig,
            platformReferrer: address(0),
            coinSalt: bytes32(0)
        });

        console.log("  Test Creator Coin deployed:", deployment.testCoin);
        console.log("  SUCCESS! Your system is working!");
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
        console.log("TrustedMsgSenderLookup:    ", deployment.trustedMsgSenderLookup);
        console.log("HookUpgradeGate:           ", deployment.hookUpgradeGate);
        console.log("ZoraV4CoinHook:            ", deployment.zoraV4CoinHook, "<-- YOUR OWN HOOK");
        console.log("CreatorCoin Implementation:", deployment.creatorCoinImpl);
        console.log("ContentCoin Implementation:", deployment.contentCoinImpl);
        console.log("Factory Implementation:    ", deployment.factoryImpl);
        console.log("Factory Proxy:             ", deployment.factoryProxy, "<-- USE THIS");
        console.log("Owner:                     ", deployment.owner);
        console.log("Test Creator Coin:         ", deployment.testCoin, "<-- DEPLOYED & WORKING!");
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
        console.log("    msg.sender,");
        console.log("    [msg.sender],");
        console.log('    "ipfs://metadata",');
        console.log('    "My Creator Coin",');
        console.log('    "MCC",');
        console.log("    poolConfig,");
        console.log("    address(0),");
        console.log("    bytes32(0)");
        console.log(");");
        console.log("");
        console.log("This system is COMPLETELY ISOLATED from Zora's production");
        console.log("infrastructure and will work with your custom CreatorCoin!");
        console.log("");
        console.log("=======================================================");
        console.log("");
    }

    function getNetworkAddresses()
        internal
        view
        returns (
            address protocolRewardRecipient,
            address poolManager,
            address airlock,
            address proxyAdmin,
            address uniswapUniversalRouter,
            address uniswapV4PositionManager
        )
    {
        uint256 chainId = block.chainid;

        if (chainId == 8453) {
            // Base Mainnet
            protocolRewardRecipient = 0x7bf90111Ad7C22bec9E9dFf8A01A44713CC1b1B6;
            poolManager = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
            airlock = 0x660eAaEdEBc968f8f3694354FA8EC0b4c5Ba8D12;
            proxyAdmin = 0x004d6611884B4A661749B64b2ADc78505c3e1AB3;
            uniswapUniversalRouter = 0x6fF5693b99212Da76ad316178A184AB56D299b43;
            uniswapV4PositionManager = 0x7C5f5A4bBd8fD63184577525326123B519429bDc;
        } else if (chainId == 84532) {
            // Base Sepolia (Testnet)
            protocolRewardRecipient = 0x5F14C23983c9e0840Dc60dA880349622f0785420;
            poolManager = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
            airlock = 0xa24E35a5d71d02a59b41E7c93567626302da1958;
            proxyAdmin = 0x5F14C23983c9e0840Dc60dA880349622f0785420;
            uniswapUniversalRouter = 0x492E6456D9528771018DeB9E87ef7750EF184104;
            uniswapV4PositionManager = 0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80;
        } else {
            revert("Unsupported network. Add configuration for this chain ID.");
        }
    }

    function getBackingCurrency() internal pure returns (address) {
        // Use address(0) for native ETH backing
        return address(0);
    }
}
