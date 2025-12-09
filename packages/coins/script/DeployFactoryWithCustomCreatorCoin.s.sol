// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {ZoraFactoryImpl} from "../src/ZoraFactoryImpl.sol";

/**
 * @title DeployFactoryWithCustomCreatorCoin
 * @notice Step 2: Deploy a new ZoraFactoryImpl that uses your custom CreatorCoin implementation
 * @dev This creates a new factory implementation that points to your modified CreatorCoin
 *
 * Usage:
 * 1. First complete Step 1 (deploy CreatorCoin implementation)
 * 2. Update CREATOR_COIN_IMPL below with your deployed address
 * 3. Run deployment:
 *    forge script script/DeployFactoryWithCustomCreatorCoin.s.sol:DeployFactoryWithCustomCreatorCoin \
 *      --rpc-url $RPC_URL \
 *      --broadcast \
 *      --verify \
 *      -vvvv
 *
 * After deployment, you can either:
 * - Option A: Deploy your own ZoraFactory proxy pointing to this implementation
 * - Option B: Propose upgrading the official factory to use this implementation
 */
contract DeployFactoryWithCustomCreatorCoin is Script {
    // ========================================
    // TODO: UPDATE THIS WITH YOUR DEPLOYED CREATOR COIN ADDRESS FROM STEP 1
    // ========================================
    address constant CREATOR_COIN_IMPL = 0x0000000000000000000000000000000000000000; // <-- UPDATE THIS!

    function run() public {
        require(CREATOR_COIN_IMPL != address(0), "ERROR: Update CREATOR_COIN_IMPL with your deployed address!");

        // Get network-specific addresses
        (address existingContentCoinImpl, address existingHook, address existingHookRegistry) = getNetworkAddresses();

        console.log("=== ZoraFactoryImpl Deployment (with Custom CreatorCoin) ===");
        console.log("Network Chain ID:", block.chainid);
        console.log("Deployer:", msg.sender);
        console.log("");
        console.log("Factory Configuration:");
        console.log("  Content Coin (V4) Impl:  ", existingContentCoinImpl, "(existing)");
        console.log("  Creator Coin Impl:       ", CREATOR_COIN_IMPL, "(YOUR CUSTOM)");
        console.log("  Hook:                    ", existingHook, "(existing)");
        console.log("  Hook Registry:           ", existingHookRegistry, "(existing)");
        console.log("");

        vm.startBroadcast();

        ZoraFactoryImpl factoryImpl = new ZoraFactoryImpl({
            coinV4Impl_: existingContentCoinImpl,
            creatorCoinImpl_: CREATOR_COIN_IMPL,
            hook_: existingHook,
            zoraHookRegistry_: existingHookRegistry
        });

        vm.stopBroadcast();

        console.log("=== Deployment Complete ===");
        console.log("New ZoraFactoryImpl:", address(factoryImpl));
        console.log("");
        console.log("IMPORTANT: Save this address!");
        console.log("");
        console.log("=== Next Steps ===");
        console.log("");
        console.log("Choose ONE of the following options:");
        console.log("");
        console.log("OPTION A - Deploy Your Own Factory (Recommended for Testing):");
        console.log("  1. Deploy a new ZoraFactory proxy:");
        console.log("     ZoraFactory myFactory = new ZoraFactory(", address(factoryImpl), ");");
        console.log("  2. Initialize it:");
        console.log("     myFactory.initialize(YOUR_OWNER_ADDRESS);");
        console.log("  3. Start using your factory to deploy creator coins!");
        console.log("");
        console.log("OPTION B - Upgrade Official Factory (Requires Multisig):");
        console.log("  1. Create a proposal to the multisig at:", getMultisigAddress());
        console.log("  2. Propose calling upgradeToAndCall on factory proxy:");
        console.log("     Target: ", getExistingFactoryProxy());
        console.log("     Function: upgradeToAndCall(address,bytes)");
        console.log("     Args: [", address(factoryImpl), ', ""');
        console.log("  3. Get multisig signers to approve");
        console.log("  4. Execute the upgrade");
        console.log("");
    }

    function getNetworkAddresses() internal view returns (address contentCoinImpl, address hook, address hookRegistry) {
        uint256 chainId = block.chainid;

        if (chainId == 8453) {
            // Base Mainnet - use existing production addresses
            contentCoinImpl = 0x7Cad62748DDf516CF85bC2C05C14786D84Cf861c;
            hook = 0xC8d077444625eB300A427a6dfB2b1DBf9b159040;
            hookRegistry = 0x777777C4c14b133858c3982D41Dbf02509fc18d7;
        } else if (chainId == 84532) {
            // Base Sepolia - use existing testnet addresses
            // Note: These may need to be deployed if they don't exist yet
            // Check addresses/84532.json for the latest addresses
            revert("Base Sepolia: Please add the existing addresses from addresses/84532.json");
        } else {
            revert("Unsupported network. Add configuration for this chain ID.");
        }
    }

    function getExistingFactoryProxy() internal view returns (address) {
        uint256 chainId = block.chainid;

        if (chainId == 8453) {
            return 0x777777751622c0d3258f214F9DF38E35BF45baF3; // Base Mainnet factory
        } else if (chainId == 84532) {
            return address(0); // Base Sepolia - you'll deploy your own
        } else {
            return address(0);
        }
    }

    function getMultisigAddress() internal view returns (address) {
        uint256 chainId = block.chainid;

        if (chainId == 8453) {
            return 0x004d6611884B4A661749B64b2ADc78505c3e1AB3; // Base Mainnet multisig
        } else if (chainId == 84532) {
            return 0x5F14C23983c9e0840Dc60dA880349622f0785420; // Base Sepolia
        } else {
            return address(0);
        }
    }
}
