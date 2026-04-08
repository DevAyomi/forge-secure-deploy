// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DeployConfig} from "../src/DeployConfig.sol";
import {SecureDeploy} from "../src/SecureDeploy.sol";

contract SecureDeployConfigFixture is DeployConfig {
    string internal fixturePath;

    constructor(string memory path) {
        fixturePath = path;
    }

    function _deployTomlPath() internal view override returns (string memory) {
        return fixturePath;
    }
}

contract SecureDeployHarness is SecureDeploy {
    string internal fixturePath;
    string internal networkValue;
    string internal confirmValue;

    constructor(
        string memory path,
        string memory network,
        string memory confirm
    ) {
        fixturePath = path;
        networkValue = network;
        confirmValue = confirm;
    }

    function exposedStart() external returns (address) {
        return startSecureBroadcast();
    }

    function exposedStop() external {
        stopSecureBroadcast();
    }

    function exposedGetDeployer() external view returns (address) {
        return getDeployer();
    }

    function exposedGetNetwork() external view returns (string memory) {
        return getNetwork();
    }

    function exposedGetConfig()
        external
        view
        returns (DeployConfig.NetworkConfig memory)
    {
        return getConfig();
    }

    function exposedIsMainnet(string memory network)
        external
        pure
        returns (bool)
    {
        return _isMainnet(network);
    }

    function _newDeployConfig() internal override returns (DeployConfig) {
        return new SecureDeployConfigFixture(fixturePath);
    }

    function _networkEnv() internal view override returns (string memory) {
        return networkValue;
    }

    function _confirmEnv() internal view override returns (string memory) {
        return confirmValue;
    }
}

contract SecureDeployDefaultHarness is SecureDeploy {
    function exposedNewDeployConfigAddress() external returns (address) {
        return address(_newDeployConfig());
    }

    function exposedNetworkEnv() external view returns (string memory) {
        return _networkEnv();
    }

    function exposedConfirmEnv() external view returns (string memory) {
        return _confirmEnv();
    }
}

contract SecureDeployTest is Test {
    address internal constant SEPOLIA_DEPLOYER =
        0x1000000000000000000000000000000000000001;
    address internal constant MAINNET_DEPLOYER =
        0x2000000000000000000000000000000000000002;

    modifier withFixture(string memory path) {
        if (vm.exists(path)) {
            vm.removeFile(path);
        }

        _;

        if (vm.exists(path)) {
            vm.removeFile(path);
        }
    }

    function test_StartSecureBroadcastUsesNetworkEnvForLocal()
        public
        withFixture("test/securedeploy-local.toml")
    {
        string memory path = "test/securedeploy-local.toml";
        SecureDeployHarness harness = new SecureDeployHarness(path, "local", "");
        _writeDeployToml(path, _validDeployToml());

        address deployer = harness.exposedStart();
        DeployConfig.NetworkConfig memory networkConfig = harness.exposedGetConfig();

        assertEq(deployer, 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        assertEq(harness.exposedGetDeployer(), deployer);
        assertEq(harness.exposedGetNetwork(), "local");
        assertEq(networkConfig.keystoreName, "anvil");
        assertEq(networkConfig.rpcUrl, "http://127.0.0.1:8545");
        assertTrue(networkConfig.isLocal);

        harness.exposedStop();
    }

    function test_StartSecureBroadcastFallsBackToChainIdForTestnet()
        public
        withFixture("test/securedeploy-testnet.toml")
    {
        string memory path = "test/securedeploy-testnet.toml";
        SecureDeployHarness harness = new SecureDeployHarness(path, "", "yes");
        _writeDeployToml(path, _validDeployToml());
        vm.chainId(11155111);
        vm.deal(SEPOLIA_DEPLOYER, 0.01 ether);

        address deployer = harness.exposedStart();
        DeployConfig.NetworkConfig memory networkConfig = harness.exposedGetConfig();

        assertEq(deployer, SEPOLIA_DEPLOYER);
        assertEq(harness.exposedGetDeployer(), SEPOLIA_DEPLOYER);
        assertEq(harness.exposedGetNetwork(), "sepolia");
        assertEq(networkConfig.keystoreName, "hotWallet");
        assertEq(networkConfig.rpcUrl, "https://sepolia.example");
        assertFalse(networkConfig.isLocal);

        harness.exposedStop();
    }

    function test_StartSecureBroadcastRevertsForInsufficientBalance()
        public
        withFixture("test/securedeploy-balance.toml")
    {
        string memory path = "test/securedeploy-balance.toml";
        SecureDeployHarness harness = new SecureDeployHarness(path, "sepolia", "");
        _writeDeployToml(path, _validDeployToml());
        vm.deal(SEPOLIA_DEPLOYER, 0.009 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                SecureDeploy.SecureDeploy__InsufficientBalance.selector,
                SEPOLIA_DEPLOYER,
                0.009 ether,
                0.01 ether
            )
        );
        harness.exposedStart();
    }

    function test_StartSecureBroadcastRevertsForTestnetWithoutConfirmation()
        public
        withFixture("test/securedeploy-testnet-confirm.toml")
    {
        string memory path = "test/securedeploy-testnet-confirm.toml";
        SecureDeployHarness harness = new SecureDeployHarness(path, "sepolia", "no");
        _writeDeployToml(path, _validDeployToml());
        vm.deal(SEPOLIA_DEPLOYER, 0.01 ether);

        vm.expectRevert(SecureDeploy.SecureDeploy__DeploymentAborted.selector);
        harness.exposedStart();
    }

    function test_StartSecureBroadcastSucceedsForMainnetWithConfirmation()
        public
        withFixture("test/securedeploy-mainnet-success.toml")
    {
        string memory path = "test/securedeploy-mainnet-success.toml";
        SecureDeployHarness harness = new SecureDeployHarness(
            path,
            "mainnet",
            "deploy_to_mainnet"
        );
        _writeDeployToml(path, _validDeployToml());
        vm.deal(MAINNET_DEPLOYER, 0.01 ether);

        address deployer = harness.exposedStart();

        assertEq(deployer, MAINNET_DEPLOYER);
        assertEq(harness.exposedGetDeployer(), MAINNET_DEPLOYER);
        assertEq(harness.exposedGetNetwork(), "mainnet");

        harness.exposedStop();
    }

    function test_StartSecureBroadcastRevertsForMainnetWithoutConfirmation()
        public
        withFixture("test/securedeploy-mainnet-revert.toml")
    {
        string memory path = "test/securedeploy-mainnet-revert.toml";
        SecureDeployHarness harness = new SecureDeployHarness(path, "mainnet", "yes");
        _writeDeployToml(path, _validDeployToml());
        vm.deal(MAINNET_DEPLOYER, 0.01 ether);

        vm.expectRevert(SecureDeploy.SecureDeploy__DeploymentAborted.selector);
        harness.exposedStart();
    }

    function test_StartSecureBroadcastRevertsForUnknownFallbackChain()
        public
        withFixture("test/securedeploy-unknown.toml")
    {
        string memory path = "test/securedeploy-unknown.toml";
        SecureDeployHarness harness = new SecureDeployHarness(path, "", "");
        _writeDeployToml(path, _validDeployToml());
        vm.chainId(999);

        vm.expectRevert(
            abi.encodeWithSelector(
                DeployConfig.DeployConfig__NetworkNotFound.selector,
                "unknown"
            )
        );
        harness.exposedStart();
    }

    function test_IsMainnetReturnsExpectedValues() public {
        SecureDeployHarness harness = new SecureDeployHarness(
            "test/securedeploy-unused.toml",
            "",
            ""
        );

        assertTrue(harness.exposedIsMainnet("mainnet"));
        assertFalse(harness.exposedIsMainnet("sepolia"));
    }

    function test_DefaultHelpersUseEnvironmentAndConstructDeployConfig() public {
        SecureDeployDefaultHarness harness = new SecureDeployDefaultHarness();

        vm.setEnv("NETWORK", "base");
        vm.setEnv("CONFIRM_DEPLOY", "yes");

        assertEq(harness.exposedNetworkEnv(), "base");
        assertEq(harness.exposedConfirmEnv(), "yes");
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
                "sepolia = \"https://sepolia.example\"\n",
                "mainnet = \"https://mainnet.example\"\n"
            )
        );
    }
}
