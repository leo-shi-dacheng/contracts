// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

import {ProtocolForwarder} from "../contracts/ProtocolForwarder.sol";
import {Pool} from "../contracts/Pool.sol";
import {PoolFactory} from "../contracts/factories/PoolFactory.sol";
import {Router} from "../contracts/Router.sol";

/// @notice Minimal deployment script for the DEX core (forwarder, pool impl, factory, router)
contract DeployDex is Script {
    using stdJson for string;

    uint256 internal constant DEFAULT_STABLE_FEE = 5; // 0.05%
    uint256 internal constant DEFAULT_VOLATILE_FEE = 30; // 0.30%

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");
        address feeManager = vm.envOr({name: "FEE_MANAGER", defaultValue: address(0)});
        address pauser = vm.envOr({name: "PAUSER", defaultValue: address(0)});
        address whsk = vm.envAddress("WHSK");

        uint256 stableFee = vm.envOr({name: "STABLE_FEE", defaultValue: DEFAULT_STABLE_FEE});
        uint256 volatileFee = vm.envOr({name: "VOLATILE_FEE", defaultValue: DEFAULT_VOLATILE_FEE});

        vm.startBroadcast(deployerPrivateKey);

        ProtocolForwarder forwarder = new ProtocolForwarder();
        Pool implementation = new Pool();
        PoolFactory factory = new PoolFactory(address(implementation));
        Router router = new Router(address(forwarder), address(factory), whsk);

        // configure roles
        if (pauser != address(0) && pauser != factory.pauser()) {
            factory.setPauser(pauser);
        }

        if (feeManager != address(0) && feeManager != factory.feeManager()) {
            factory.setFeeManager(feeManager);
        }

        if (stableFee != DEFAULT_STABLE_FEE) {
            factory.setFee(true, stableFee);
        }

        if (volatileFee != DEFAULT_VOLATILE_FEE) {
            factory.setFee(false, volatileFee);
        }

        vm.stopBroadcast();

        _writeOutput(forwarder, implementation, factory, router, whsk, stableFee, volatileFee);
    }

    function _writeOutput(
        ProtocolForwarder forwarder,
        Pool implementation,
        PoolFactory factory,
        Router router,
        address whsk,
        uint256 stableFee,
        uint256 volatileFee
    ) internal {
        string memory root = vm.projectRoot();
        string memory basePath = string.concat(root, "/script/constants/output/");
        string memory fileName = vm.envOr({name: "OUTPUT_FILENAME", defaultValue: string("dex-latest.json")});
        string memory path = string.concat(basePath, fileName);

        string memory label = "dex";
        string memory json;
        json = vm.serializeAddress(label, "Forwarder", address(forwarder));
        json = vm.serializeAddress(label, "PoolImplementation", address(implementation));
        json = vm.serializeAddress(label, "PoolFactory", address(factory));
        json = vm.serializeAddress(label, "Router", address(router));
        json = vm.serializeAddress(label, "WHSK", whsk);
        json = vm.serializeUint(label, "StableFee", stableFee);
        json = vm.serializeUint(label, "VolatileFee", volatileFee);

        vm.writeJson(json, path);
    }
}
