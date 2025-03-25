// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {Constant} from "../src/global/Constant.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;
    uint8 private constant DECIMALS = 8;
    int256 private constant INITIAL_PRICE = 2000e8;

    struct NetworkConfig {
        address priceFeed;
        uint256 chainId;
    }

    constructor() {
        if (block.chainid == Constant.SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == Constant.ANVIL_CHAIN_ID) {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        } else if (block.chainid == Constant.MAINNET_CHAIN_ID) {
            activeNetworkConfig = getMainnetEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            chainId: block.chainid
        });
        return sepoliaConfig;
    }

    function getMainnetEthConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory mainnetConfig = NetworkConfig({
            priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            chainId: block.chainid
        });
        return mainnetConfig;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // This check help us to avoid the re-deployment of the contract "MockV3Aggregator"
        if (activeNetworkConfig.priceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
            DECIMALS,
            INITIAL_PRICE
        ); // 2000e8 = 2e11
        vm.stopBroadcast();

        NetworkConfig memory anvilConfig = NetworkConfig({
            priceFeed: address(mockPriceFeed),
            chainId: block.chainid
        });

        return anvilConfig;
    }
}
