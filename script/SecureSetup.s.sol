// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {DeployConfig} from "../src/DeployConfig.sol";

contract SecureSetup is Script {
    uint256 internal constant MINIMUM_DEPLOYER_BALANCE = 0.01 ether;

    function run() external returns (DeployConfig.NetworkConfig memory config) {
        config = _resolveConfig();

        (string memory resolvedRpcUrl, bool hasResolvedRpcUrl) =
            _tryResolveRpcUrl(config.rpcUrl);

        _printSummary(config, resolvedRpcUrl, hasResolvedRpcUrl);
        _printConfirmationRequirement(config);
        _printBalanceStatus(config);
    }

    function resolveRpcUrl(string memory rpcUrl)
        external
        returns (string memory)
    {
        return _resolveEnv(rpcUrl);
    }

    function _resolveConfig()
        internal
        returns (DeployConfig.NetworkConfig memory)
    {
        DeployConfig deployConfig = _newDeployConfig();
        string memory network = _networkEnv();

        if (bytes(network).length == 0) {
            return deployConfig.getConfig();
        }

        return deployConfig.getNetworkConfig(network);
    }

    function _tryResolveRpcUrl(string memory rpcUrl)
        internal
        returns (string memory resolvedRpcUrl, bool hasResolvedRpcUrl)
    {
        if (bytes(rpcUrl).length == 0) {
            return ("", false);
        }

        try this.resolveRpcUrl(rpcUrl) returns (string memory resolved) {
            return (resolved, bytes(resolved).length != 0);
        } catch {
            return ("", false);
        }
    }

    function _printSummary(
        DeployConfig.NetworkConfig memory config,
        string memory resolvedRpcUrl,
        bool hasResolvedRpcUrl
    ) internal view {
        console2.log("");
        console2.log("==============================");
        console2.log(" forge-secure-deploy setup    ");
        console2.log("==============================");
        console2.log(" Network  :", config.network);
        console2.log(" Chain ID :", block.chainid);
        console2.log(" Keystore :", config.keystoreName);
        console2.log(" Deployer :", config.deployer);
        console2.log(" Local    :", config.isLocal);

        if (hasResolvedRpcUrl) {
            console2.log(" RPC      :", resolvedRpcUrl);
        } else if (bytes(config.rpcUrl).length == 0) {
            console2.log(" RPC      : <not configured>");
        } else {
            console2.log(" RPC      : <env not resolved>");
        }

        console2.log(" Balance  :", config.deployer.balance);
        console2.log("==============================");
    }

    function _printConfirmationRequirement(DeployConfig.NetworkConfig memory config)
        internal
        pure
    {
        console2.log("");

        if (config.isLocal) {
            console2.log("Confirmation: not required on local.");
            return;
        }

        if (_isMainnet(config.network)) {
            console2.log("Confirmation: set CONFIRM_DEPLOY=deploy_to_mainnet");
            return;
        }

        console2.log("Confirmation: set CONFIRM_DEPLOY=yes");
    }

    function _printBalanceStatus(DeployConfig.NetworkConfig memory config)
        internal
        view
    {
        console2.log("");

        if (config.isLocal) {
            console2.log("Balance check: skipped on local.");
            return;
        }

        if (config.deployer.balance >= MINIMUM_DEPLOYER_BALANCE) {
            console2.log("Balance check: OK");
            return;
        }

        console2.log("Balance check: below 0.01 ether minimum.");
    }

    function _isMainnet(string memory network)
        internal
        pure
        returns (bool)
    {
        return keccak256(bytes(network)) == keccak256(bytes("mainnet"));
    }

    function _newDeployConfig() internal virtual returns (DeployConfig) {
        return new DeployConfig();
    }

    function _networkEnv() internal view virtual returns (string memory) {
        return vm.envOr("NETWORK", string(""));
    }

    function _resolveEnv(string memory value)
        internal
        virtual
        returns (string memory)
    {
        return vm.resolveEnv(value);
    }
}
