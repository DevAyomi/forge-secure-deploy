// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DeployConfig} from "../src/DeployConfig.sol";
import {SecureSetup} from "../script/SecureSetup.s.sol";

contract SecureSetupConfigFixture is DeployConfig {
    string internal fixturePath;

    constructor(string memory path) {
        fixturePath = path;
    }

    function _deployTomlPath() internal view override returns (string memory) {
        return fixturePath;
    }
}

contract SecureSetupHarness is SecureSetup {
    string internal fixturePath;
    string internal networkValue;
    bool internal shouldResolveRpc;
    string internal resolvedRpcValue;

    constructor(
        string memory path,
        string memory network,
        bool canResolveRpc,
        string memory rpcValue
    ) {
        fixturePath = path;
        networkValue = network;
        shouldResolveRpc = canResolveRpc;
        resolvedRpcValue = rpcValue;
    }

    function exposedResolveConfig()
        external
        returns (DeployConfig.NetworkConfig memory)
    {
        return _resolveConfig();
    }

    function exposedTryResolveRpcUrl(string memory rpcUrl)
        external
        returns (string memory, bool)
    {
        return _tryResolveRpcUrl(rpcUrl);
    }

    function exposedIsMainnet(string memory network)
        external
        pure
        returns (bool)
    {
        return _isMainnet(network);
    }

    function _newDeployConfig() internal override returns (DeployConfig) {
        return new SecureSetupConfigFixture(fixturePath);
    }

    function _networkEnv() internal view override returns (string memory) {
        return networkValue;
    }

    function _resolveEnv(string memory)
        internal
        override
        view
        returns (string memory)
    {
        require(shouldResolveRpc, "RPC_RESOLVE_FAILED");
        return resolvedRpcValue;
    }
}

contract SecureSetupDefaultHarness is SecureSetup {
    function exposedNewDeployConfigAddress() external returns (address) {
        return address(_newDeployConfig());
    }

    function exposedNetworkEnv() external view returns (string memory) {
        return _networkEnv();
    }

    function exposedResolveEnv(string memory value)
        external
        returns (string memory)
    {
        return _resolveEnv(value);
    }
}

contract SecureSetupTest is Test {
    modifier withFixture(string memory path) {
        if (vm.exists(path)) {
            vm.removeFile(path);
        }

        _;

        if (vm.exists(path)) {
            vm.removeFile(path);
        }
    }

    function test_RunUsesExplicitNetworkForLocal()
        public
        withFixture("test/securesetup-local.toml")
    {
        string memory path = "test/securesetup-local.toml";
        SecureSetupHarness harness = new SecureSetupHarness(
            path,
            "local",
            true,
            "http://127.0.0.1:8545"
        );
        _writeDeployToml(path, _validDeployToml());

        DeployConfig.NetworkConfig memory config = harness.run();

        assertEq(config.network, "local");
        assertEq(config.keystoreName, "anvil");
        assertEq(config.rpcUrl, "http://127.0.0.1:8545");
        assertTrue(config.isLocal);
    }

    function test_RunFallsBackToChainId()
        public
        withFixture("test/securesetup-chainid.toml")
    {
        string memory path = "test/securesetup-chainid.toml";
        SecureSetupHarness harness = new SecureSetupHarness(
            path,
            "",
            true,
            "https://sepolia.resolved"
        );
        _writeDeployToml(path, _validDeployToml());
        vm.chainId(11155111);

        DeployConfig.NetworkConfig memory config = harness.run();

        assertEq(config.network, "sepolia");
        assertEq(config.keystoreName, "hotWallet");
        assertFalse(config.isLocal);
    }

    function test_RunHandlesMainnetWithSufficientBalance()
        public
        withFixture("test/securesetup-mainnet-run.toml")
    {
        string memory path = "test/securesetup-mainnet-run.toml";
        SecureSetupHarness harness = new SecureSetupHarness(
            path,
            "mainnet",
            true,
            "https://mainnet.resolved"
        );
        _writeDeployToml(path, _validDeployToml());
        vm.deal(0x2000000000000000000000000000000000000002, 0.01 ether);

        DeployConfig.NetworkConfig memory config = harness.run();

        assertEq(config.network, "mainnet");
        assertEq(config.keystoreName, "coldWallet");
    }

    function test_RunAllowsUnresolvedRpcPlaceholders()
        public
        withFixture("test/securesetup-rpc-unresolved.toml")
    {
        string memory path = "test/securesetup-rpc-unresolved.toml";
        SecureSetupHarness harness = new SecureSetupHarness(path, "sepolia", false, "");
        _writeDeployToml(path, _validDeployToml());

        DeployConfig.NetworkConfig memory config = harness.run();

        assertEq(config.network, "sepolia");
        assertEq(config.rpcUrl, "${SEPOLIA_RPC_URL}");
    }

    function test_RunAllowsMissingRpcConfig()
        public
        withFixture("test/securesetup-rpc-missing.toml")
    {
        string memory path = "test/securesetup-rpc-missing.toml";
        SecureSetupHarness harness = new SecureSetupHarness(path, "sepolia", true, "");
        _writeDeployToml(path, _tomlWithoutRpc());

        DeployConfig.NetworkConfig memory config = harness.run();

        assertEq(config.network, "sepolia");
        assertEq(config.rpcUrl, "");
    }

    function test_ResolveConfigUsesExplicitNetwork()
        public
        withFixture("test/securesetup-explicit.toml")
    {
        string memory path = "test/securesetup-explicit.toml";
        SecureSetupHarness harness = new SecureSetupHarness(path, "mainnet", true, "https://mainnet.resolved");
        _writeDeployToml(path, _validDeployToml());

        DeployConfig.NetworkConfig memory config = harness.exposedResolveConfig();

        assertEq(config.network, "mainnet");
        assertEq(config.keystoreName, "coldWallet");
    }

    function test_TryResolveRpcUrlReturnsResolvedValue()
        public
        withFixture("test/securesetup-rpc-resolved.toml")
    {
        SecureSetupHarness harness = new SecureSetupHarness(
            "test/securesetup-rpc-resolved.toml",
            "local",
            true,
            "https://resolved.example"
        );

        (string memory rpcUrl, bool resolved) =
            harness.exposedTryResolveRpcUrl("${SEPOLIA_RPC_URL}");

        assertEq(rpcUrl, "https://resolved.example");
        assertTrue(resolved);
    }

    function test_TryResolveRpcUrlReturnsFalseForEmptyConfig()
        public
        withFixture("test/securesetup-rpc-empty.toml")
    {
        SecureSetupHarness harness = new SecureSetupHarness(
            "test/securesetup-rpc-empty.toml",
            "local",
            true,
            "https://resolved.example"
        );

        (string memory rpcUrl, bool resolved) = harness.exposedTryResolveRpcUrl("");

        assertEq(rpcUrl, "");
        assertFalse(resolved);
    }

    function test_IsMainnetReturnsExpectedValues()
        public
        withFixture("test/securesetup-mainnet.toml")
    {
        SecureSetupHarness harness = new SecureSetupHarness(
            "test/securesetup-mainnet.toml",
            "local",
            true,
            ""
        );

        assertTrue(harness.exposedIsMainnet("mainnet"));
        assertFalse(harness.exposedIsMainnet("base"));
    }

    function test_DefaultHelpersUseEnvironmentAndDeployConfig() public {
        SecureSetupDefaultHarness harness = new SecureSetupDefaultHarness();

        vm.setEnv("NETWORK", "base");
        vm.setEnv("SEPOLIA_RPC_URL", "https://sepolia.default");

        assertEq(harness.exposedNetworkEnv(), "base");
        assertEq(harness.exposedResolveEnv("${SEPOLIA_RPC_URL}"), "https://sepolia.default");
        assertTrue(harness.exposedNewDeployConfigAddress() != address(0));
    }

    function _writeDeployToml(string memory path, string memory content) internal {
        if (vm.exists(path)) {
            vm.removeFile(path);
        }

        vm.writeFile(path, content);
    }

    function _validDeployToml() internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "[accounts]\n",
                "sepolia = \"hotWallet\"\n",
                "mainnet = \"coldWallet\"\n",
                "\n",
                "[addresses]\n",
                "sepolia = \"0x1000000000000000000000000000000000000001\"\n",
                "mainnet = \"0x2000000000000000000000000000000000000002\"\n",
                "\n",
                "[rpc]\n",
                "sepolia = \"${SEPOLIA_RPC_URL}\"\n",
                "mainnet = \"${MAINNET_RPC_URL}\"\n"
            )
        );
    }

    function _tomlWithoutRpc() internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "[accounts]\n",
                "sepolia = \"hotWallet\"\n",
                "\n",
                "[addresses]\n",
                "sepolia = \"0x1000000000000000000000000000000000000001\"\n"
            )
        );
    }
}
