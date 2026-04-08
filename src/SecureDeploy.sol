// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {DeployConfig} from "./DeployConfig.sol";

/// @title SecureDeploy
/// @notice Secure base contract for all Foundry deploy scripts
/// @dev Extend this instead of Script in your deploy scripts
///
/// Example:
///   contract DeployMyToken is SecureDeploy {
///       function run() public {
///           address deployer = startSecureBroadcast();
///           new MyToken(deployer);
///           stopSecureBroadcast();
///       }
///   }
abstract contract SecureDeploy is Script {

    // ─────────────────────────────────────────────
    //  Errors
    // ─────────────────────────────────────────────

    error SecureDeploy__DeploymentAborted();
    error SecureDeploy__InsufficientBalance(
        address deployer,
        uint256 balance,
        uint256 required
    );

    // ─────────────────────────────────────────────
    //  State
    // ─────────────────────────────────────────────

    DeployConfig.NetworkConfig private _config;
    DeployConfig               private _deployConfig;

    // ─────────────────────────────────────────────
    //  Public API
    // ─────────────────────────────────────────────

    /// @notice Call at the start of run()
    /// @return deployer The address broadcasting transactions
    function startSecureBroadcast() internal returns (address deployer) {
        // 1. Boot config
        _deployConfig = _newDeployConfig();

        // 2. Resolve network
        string memory network = _resolveNetwork();

        // 3. Load full config from deploy.toml
        _config = _deployConfig.getNetworkConfig(network);

        // 4. Print summary
        _printSummary();

        // 5. Check balance
        _checkBalance();

        // 6. Confirm
        _confirm();

        // 7. Start broadcast
        vm.startBroadcast(_config.deployer);

        return _config.deployer;
    }

    /// @notice Call at the end of run()
    function stopSecureBroadcast() internal {
        vm.stopBroadcast();
        console2.log("");
        console2.log("==============================");
        console2.log(" Deployment complete          ");
        console2.log("==============================");
        console2.log(" Network  :", _config.network);
        console2.log(" Deployer :", _config.deployer);
        console2.log("==============================");
    }

    /// @notice Returns deployer address after startSecureBroadcast()
    function getDeployer() internal view returns (address) {
        return _config.deployer;
    }

    /// @notice Returns current network name after startSecureBroadcast()
    function getNetwork() internal view returns (string memory) {
        return _config.network;
    }

    /// @notice Returns full config after startSecureBroadcast()
    function getConfig() internal view returns (DeployConfig.NetworkConfig memory) {
        return _config;
    }

    // ─────────────────────────────────────────────
    //  Internal — Network Resolution
    // ─────────────────────────────────────────────

    function _resolveNetwork()
        private
        view
        returns (string memory network)
    {
        // First — check NETWORK env var
        // NETWORK=sepolia forge script ...
        network = _networkEnv();

        // Second — fall back to chain ID
        if (bytes(network).length == 0) {
            network = _deployConfig.getConfig().network;
        }
    }

    // ─────────────────────────────────────────────
    //  Internal — Balance Check
    // ─────────────────────────────────────────────

    function _checkBalance() private view {
        // Skip balance check on local
        if (_config.isLocal) return;

        uint256 balance = _config.deployer.balance;
        uint256 minimum = 0.01 ether;

        if (balance < minimum) {
            revert SecureDeploy__InsufficientBalance(
                _config.deployer,
                balance,
                minimum
            );
        }
    }

    // ─────────────────────────────────────────────
    //  Internal — Summary
    // ─────────────────────────────────────────────

    function _printSummary() private view {
        console2.log("");
        console2.log("==============================");
        console2.log(" forge-secure-deploy v1.0.0  ");
        console2.log("==============================");
        console2.log(" Network  :", _config.network);
        console2.log(" Chain ID :", block.chainid);
        console2.log(" Deployer :", _config.deployer);
        console2.log(" Keystore :", _config.keystoreName);
        console2.log(" Balance  :", _config.deployer.balance);
        console2.log("==============================");
    }

    // ─────────────────────────────────────────────
    //  Internal — Confirmation
    // ─────────────────────────────────────────────

    function _confirm() private view {
        // Local — no confirmation needed ever
        if (_config.isLocal) {
            console2.log("Local network - skipping confirmation.");
            return;
        }

        // Mainnet — hardest confirmation
        if (_isMainnet(_config.network)) {
            console2.log("");
            console2.log("WARNING: Deploying to MAINNET");
            console2.log("This uses REAL money.");
            console2.log("");
            console2.log("Run with CONFIRM_DEPLOY=deploy_to_mainnet");

            string memory mainnetConfirmation = _confirmEnv();

            if (
                keccak256(bytes(mainnetConfirmation)) !=
                keccak256(bytes("deploy_to_mainnet"))
            ) {
                revert SecureDeploy__DeploymentAborted();
            }

            return;
        }

        // Testnet — simple confirmation
        console2.log("");
        console2.log("Run with CONFIRM_DEPLOY=yes to proceed.");

        string memory confirmation = _confirmEnv();

        if (keccak256(bytes(confirmation)) != keccak256(bytes("yes"))) {
            revert SecureDeploy__DeploymentAborted();
        }
    }

    // ─────────────────────────────────────────────
    //  Helpers
    // ─────────────────────────────────────────────

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

    function _confirmEnv() internal view virtual returns (string memory) {
        return vm.envOr("CONFIRM_DEPLOY", string(""));
    }
}
