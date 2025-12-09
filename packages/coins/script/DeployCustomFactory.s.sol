// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {ZoraFactory} from "../src/proxy/ZoraFactory.sol";
import {ZoraFactoryImpl} from "../src/ZoraFactoryImpl.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title DeployCustomFactory
 * @notice Step 3: Deploy your own ZoraFactory proxy with your custom CreatorCoin
 * @dev This creates a complete factory that you control and can use immediately
 *
 * Usage:
 * 1. Complete Step 1 (deploy CreatorCoin implementation)
 * 2. Complete Step 2 (deploy ZoraFactoryImpl with your CreatorCoin)
 * 3. Update FACTORY_IMPL below with address from Step 2
 * 4. Run deployment:
 *    forge script script/DeployCustomFactory.s.sol:DeployCustomFactory \
 *      --rpc-url $RPC_URL \
 *      --broadcast \
 *      --verify \
 *      -vvvv
 *
 * After deployment, you can immediately start using your factory to create coins!
 */
contract DeployCustomFactory is Script {
    // ========================================
    // TODO: UPDATE THIS WITH YOUR FACTORY IMPL ADDRESS FROM STEP 2
    // ========================================
    address constant FACTORY_IMPL = 0x0000000000000000000000000000000000000000; // <-- UPDATE THIS!

    function run() public {
        require(FACTORY_IMPL != address(0), "ERROR: Update FACTORY_IMPL with your deployed address from Step 2!");

        address owner = msg.sender; // You will be the owner

        console.log("=== Custom ZoraFactory Deployment ===");
        console.log("Network Chain ID:", block.chainid);
        console.log("Deployer (will be owner):", owner);
        console.log("Factory Implementation:", FACTORY_IMPL);
        console.log("");

        vm.startBroadcast();

        // Deploy the proxy pointing to your implementation
        ZoraFactory factory = new ZoraFactory(FACTORY_IMPL);

        // Upgrade to the implementation and initialize with your address as owner
        UUPSUpgradeable(address(factory)).upgradeToAndCall(FACTORY_IMPL, abi.encodeWithSelector(ZoraFactoryImpl.initialize.selector, owner));

        vm.stopBroadcast();

        console.log("=== Deployment Complete ===");
        console.log("Your ZoraFactory Proxy:", address(factory));
        console.log("Owner:", ZoraFactoryImpl(address(factory)).owner());
        console.log("");
        console.log("SUCCESS! Your factory is ready to use!");
        console.log("");
        console.log("=== How to Use Your Factory ===");
        console.log("");
        console.log("You can now deploy creator coins with ANY ERC20 token:");
        console.log("");
        console.log("Example (USDC-backed creator coin):");
        console.log("  IZoraFactory(", address(factory), ").deployCreatorCoin(");
        console.log("    payoutRecipient,");
        console.log("    [owner1, owner2],");
        console.log('    "ipfs://metadata",');
        console.log('    "My Coin",');
        console.log('    "COIN",');
        console.log("    poolConfig,  // Use CoinConfigurationVersions.defaultConfig(usdcAddress)");
        console.log("    platformReferrer,");
        console.log("    bytes32(0)  // salt");
        console.log("  );");
        console.log("");
        console.log("Supported currencies: ETH, USDC, DAI, or ANY ERC20 token!");
        console.log("");
        console.log("=== Important Addresses ===");
        console.log("Factory Proxy:  ", address(factory));
        console.log("Factory Impl:   ", FACTORY_IMPL);
        console.log("Owner:          ", owner);
        console.log("");
    }
}
