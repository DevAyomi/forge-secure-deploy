// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";

/// @title DeployConfig
/// @notice Reads deploy.toml and returns network-specific config
/// @dev All other contracts in the package depend on this
contract DeployConfig is Script {

    // ─────────────────────────────────────────────
    //  Errors
    // ─────────────────────────────────────────────

    error DeployConfig__NetworkNotFound(string network);
    error DeployConfig__MissingDeployToml();
    error DeployConfig__MissingAddress(string network);
    error DeployConfig__MissingKeystoreName(string network);

    // ─────────────────────────────────────────────
    //  Types
    // ─────────────────────────────────────────────

    struct NetworkConfig {
        string  network;        // "sepolia", "mainnet", etc
        string  keystoreName;   // maps to ~/.foundry/keystores/
        address deployer;       // derived from keystore during setup
        string  rpcUrl;         // from deploy.toml [rpc]
        bool    isLocal;        // true if anvil
    }

    // ─────────────────────────────────────────────
    //  Constants
    // ─────────────────────────────────────────────

    string  internal constant DEFAULT_DEPLOY_TOML = "deploy.toml";
    address internal constant ANVIL_DEFAULT     =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    string  internal constant ANVIL_KEYSTORE    = "anvil";
    string  internal constant LOCAL_RPC         = "http://127.0.0.1:8545";

    // ─────────────────────────────────────────────
    //  Public API
    // ─────────────────────────────────────────────

    /// @notice Returns full config for a given network name
    /// @param network The network name e.g. "sepolia", "mainnet", "local"
    function getNetworkConfig(string memory network)
        public
        view
        returns (NetworkConfig memory config)
    {
        // Verify deploy.toml exists
        _assertDeployTomlExists();

        config.network = network;

        // Local network — hardcoded, no toml lookup needed
        if (_isLocal(network)) {
            config.keystoreName = ANVIL_KEYSTORE;
            config.deployer     = ANVIL_DEFAULT;
            config.rpcUrl       = LOCAL_RPC;
            config.isLocal      = true;
            return config;
        }

        // Live network — read everything from deploy.toml
        config.keystoreName = _readKeystoreName(network);
        config.deployer     = _readDeployerAddress(network);
        config.rpcUrl       = _readRpcUrl(network);
        config.isLocal      = false;
    }

    /// @notice Returns config for the current chain automatically
    function getConfig() public view returns (NetworkConfig memory) {
        string memory network = _chainIdToNetwork(block.chainid);
        return getNetworkConfig(network);
    }

    // ─────────────────────────────────────────────
    //  Internal — TOML Readers
    // ─────────────────────────────────────────────

    function _readKeystoreName(string memory network)
        internal
        view
        returns (string memory keystoreName)
    {
        string memory toml = vm.readFile(_deployTomlPath());
        string memory key  = string.concat(".accounts.", network);

        try vm.parseTomlString(toml, key) returns (string memory val) {
            if (bytes(val).length == 0) {
                revert DeployConfig__MissingKeystoreName(network);
            }
            return val;
        } catch {
            revert DeployConfig__MissingKeystoreName(network);
        }
    }

    function _readDeployerAddress(string memory network)
        internal
        view
        returns (address deployer)
    {
        string memory toml = vm.readFile(_deployTomlPath());
        string memory key  = string.concat(".addresses.", network);

        try vm.parseTomlAddress(toml, key) returns (address val) {
            if (val == address(0)) {
                revert DeployConfig__MissingAddress(network);
            }
            return val;
        } catch {
            revert DeployConfig__MissingAddress(network);
        }
    }

    function _readRpcUrl(string memory network)
        internal
        view
        returns (string memory rpcUrl)
    {
        string memory toml = vm.readFile(_deployTomlPath());
        string memory key  = string.concat(".rpc.", network);

        try vm.parseTomlString(toml, key) returns (string memory val) {
            if (bytes(val).length == 0) {
                return ""; // RPC url is optional — Foundry flag handles it
            }
            return val;
        } catch {
            return "";
        }
    }

    // ─────────────────────────────────────────────
    //  Internal — Helpers
    // ─────────────────────────────────────────────

    function _assertDeployTomlExists() internal view {
        try vm.readFile(_deployTomlPath()) returns (string memory content) {
            if (bytes(content).length == 0) {
                revert DeployConfig__MissingDeployToml();
            }
        } catch {
            revert DeployConfig__MissingDeployToml();
        }
    }

    function _deployTomlPath() internal view virtual returns (string memory) {
        return vm.envOr("DEPLOY_TOML_PATH", string(DEFAULT_DEPLOY_TOML));
    }

    function _isLocal(string memory network)
        internal
        pure
        returns (bool)
    {
        return keccak256(bytes(network)) == keccak256(bytes("local"));
    }

    function _chainIdToNetwork(uint256 chainId)
        internal
        pure
        returns (string memory)
    {
        if (chainId == 1)        return "mainnet";
        if (chainId == 11155111) return "sepolia";
        if (chainId == 137)      return "polygon";
        if (chainId == 42161)    return "arbitrum";
        if (chainId == 8453)     return "base";
        if (chainId == 84532)    return "base_sepolia";
        if (chainId == 31337)    return "local";
        revert DeployConfig__NetworkNotFound("unknown");
    }
}
