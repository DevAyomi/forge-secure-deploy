// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DeployConfig} from "../src/DeployConfig.sol";

contract DeployConfigHarness is DeployConfig {
    string internal fixturePath;

    constructor(string memory path) {
        fixturePath = path;
    }

    function exposedReadKeystoreName(string memory network)
        external
        view
        returns (string memory)
    {
        return _readKeystoreName(network);
    }

    function exposedReadDeployerAddress(string memory network)
        external
        view
        returns (address)
    {
        return _readDeployerAddress(network);
    }

    function exposedReadRpcUrl(string memory network)
        external
        view
        returns (string memory)
    {
        return _readRpcUrl(network);
    }

    function exposedAssertDeployTomlExists() external view {
        _assertDeployTomlExists();
    }

    function exposedIsLocal(string memory network)
        external
        pure
        returns (bool)
    {
        return _isLocal(network);
    }

    function exposedChainIdToNetwork(uint256 chainId)
        external
        pure
        returns (string memory)
    {
        return _chainIdToNetwork(chainId);
    }

    function _deployTomlPath() internal view override returns (string memory) {
        return fixturePath;
    }
}

contract DeployConfigDefaultPathHarness is DeployConfig {
    function exposedDeployTomlPath() external view returns (string memory) {
        return _deployTomlPath();
    }
}

contract DeployConfigTest is Test {
    address internal constant SEPOLIA_DEPLOYER =
        0x1000000000000000000000000000000000000001;
    address internal constant MAINNET_DEPLOYER =
        0x2000000000000000000000000000000000000002;
    address internal constant POLYGON_DEPLOYER =
        0x3000000000000000000000000000000000000003;
    address internal constant ARBITRUM_DEPLOYER =
        0x4000000000000000000000000000000000000004;
    address internal constant BASE_DEPLOYER =
        0x5000000000000000000000000000000000000005;
    address internal constant BASE_SEPOLIA_DEPLOYER =
        0x6000000000000000000000000000000000000006;

    modifier withFixture(string memory path) {
        if (vm.exists(path)) {
            vm.removeFile(path);
        }

        _;

        if (vm.exists(path)) {
            vm.removeFile(path);
        }
    }

    function test_GetNetworkConfigReturnsLocalConfig()
        public
        withFixture("test/deployconfig-local.toml")
    {
        string memory path = "test/deployconfig-local.toml";
        DeployConfigHarness config = new DeployConfigHarness(path);
        _writeDeployToml(path, _validDeployToml());

        DeployConfig.NetworkConfig memory networkConfig = config.getNetworkConfig("local");

        assertEq(networkConfig.network, "local");
        assertEq(networkConfig.keystoreName, "anvil");
        assertEq(
            networkConfig.deployer,
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        );
        assertEq(networkConfig.rpcUrl, "http://127.0.0.1:8545");
        assertTrue(networkConfig.isLocal);
    }

    function test_GetNetworkConfigReturnsLiveNetworkConfig()
        public
        withFixture("test/deployconfig-live.toml")
    {
        string memory path = "test/deployconfig-live.toml";
        DeployConfigHarness config = new DeployConfigHarness(path);
        _writeDeployToml(path, _validDeployToml());

        DeployConfig.NetworkConfig memory networkConfig = config.getNetworkConfig("sepolia");

        assertEq(networkConfig.network, "sepolia");
        assertEq(networkConfig.keystoreName, "hotWallet");
        assertEq(networkConfig.deployer, SEPOLIA_DEPLOYER);
        assertEq(networkConfig.rpcUrl, "https://sepolia.example");
        assertFalse(networkConfig.isLocal);
    }

    function test_GetConfigUsesCurrentChainId()
        public
        withFixture("test/deployconfig-current-chain.toml")
    {
        string memory path = "test/deployconfig-current-chain.toml";
        DeployConfigHarness config = new DeployConfigHarness(path);
        _writeDeployToml(path, _validDeployToml());
        vm.chainId(11155111);

        DeployConfig.NetworkConfig memory networkConfig = config.getConfig();

        assertEq(networkConfig.network, "sepolia");
        assertEq(networkConfig.keystoreName, "hotWallet");
        assertEq(networkConfig.deployer, SEPOLIA_DEPLOYER);
        assertEq(networkConfig.rpcUrl, "https://sepolia.example");
        assertFalse(networkConfig.isLocal);
    }

    function test_ReadKeystoreNameReturnsValue()
        public
        withFixture("test/deployconfig-keystore-value.toml")
    {
        string memory path = "test/deployconfig-keystore-value.toml";
        DeployConfigHarness config = new DeployConfigHarness(path);
        _writeDeployToml(path, _validDeployToml());

        assertEq(config.exposedReadKeystoreName("mainnet"), "coldWallet");
    }

    function test_ReadKeystoreNameRevertsWhenMissing()
        public
        withFixture("test/deployconfig-keystore-missing.toml")
    {
        string memory path = "test/deployconfig-keystore-missing.toml";
        DeployConfigHarness config = new DeployConfigHarness(path);
        _writeDeployToml(
            path,
            string(
                abi.encodePacked(
                    "[accounts]\n",
                    "mainnet = \"coldWallet\"\n",
                    "\n",
                    "[addresses]\n",
                    "sepolia = \"0x1000000000000000000000000000000000000001\"\n"
                )
            )
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                DeployConfig.DeployConfig__MissingKeystoreName.selector,
                "sepolia"
            )
        );
        config.exposedReadKeystoreName("sepolia");
    }

    function test_ReadKeystoreNameRevertsWhenEmpty()
        public
        withFixture("test/deployconfig-keystore-empty.toml")
    {
        string memory path = "test/deployconfig-keystore-empty.toml";
        DeployConfigHarness config = new DeployConfigHarness(path);
        _writeDeployToml(
            path,
            string(
                abi.encodePacked(
                    "[accounts]\n",
                    "sepolia = \"\"\n",
                    "\n",
                    "[addresses]\n",
                    "sepolia = \"0x1000000000000000000000000000000000000001\"\n"
                )
            )
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                DeployConfig.DeployConfig__MissingKeystoreName.selector,
                "sepolia"
            )
        );
        config.exposedReadKeystoreName("sepolia");
    }

    function test_ReadDeployerAddressReturnsValue()
        public
        withFixture("test/deployconfig-address-value.toml")
    {
        string memory path = "test/deployconfig-address-value.toml";
        DeployConfigHarness config = new DeployConfigHarness(path);
        _writeDeployToml(path, _validDeployToml());

        assertEq(config.exposedReadDeployerAddress("base"), BASE_DEPLOYER);
    }

    function test_ReadDeployerAddressRevertsWhenMissing()
        public
        withFixture("test/deployconfig-address-missing.toml")
    {
        string memory path = "test/deployconfig-address-missing.toml";
        DeployConfigHarness config = new DeployConfigHarness(path);
        _writeDeployToml(
            path,
            string(
                abi.encodePacked(
                    "[accounts]\n",
                    "sepolia = \"hotWallet\"\n",
                    "\n",
                    "[addresses]\n",
                    "mainnet = \"0x2000000000000000000000000000000000000002\"\n"
                )
            )
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                DeployConfig.DeployConfig__MissingAddress.selector,
                "sepolia"
            )
        );
        config.exposedReadDeployerAddress("sepolia");
    }

    function test_ReadDeployerAddressRevertsWhenZero()
        public
        withFixture("test/deployconfig-address-zero.toml")
    {
        string memory path = "test/deployconfig-address-zero.toml";
        DeployConfigHarness config = new DeployConfigHarness(path);
        _writeDeployToml(
            path,
            string(
                abi.encodePacked(
                    "[accounts]\n",
                    "sepolia = \"hotWallet\"\n",
                    "\n",
                    "[addresses]\n",
                    "sepolia = \"0x0000000000000000000000000000000000000000\"\n"
                )
            )
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                DeployConfig.DeployConfig__MissingAddress.selector,
                "sepolia"
            )
        );
        config.exposedReadDeployerAddress("sepolia");
    }

    function test_ReadRpcUrlReturnsValue()
        public
        withFixture("test/deployconfig-rpc-value.toml")
    {
        string memory path = "test/deployconfig-rpc-value.toml";
        DeployConfigHarness config = new DeployConfigHarness(path);
        _writeDeployToml(path, _validDeployToml());

        assertEq(config.exposedReadRpcUrl("arbitrum"), "https://arbitrum.example");
    }

    function test_ReadRpcUrlReturnsEmptyStringWhenValueIsEmpty()
        public
        withFixture("test/deployconfig-rpc-empty.toml")
    {
        string memory path = "test/deployconfig-rpc-empty.toml";
        DeployConfigHarness config = new DeployConfigHarness(path);
        _writeDeployToml(
            path,
            string(
                abi.encodePacked(
                    "[accounts]\n",
                    "sepolia = \"hotWallet\"\n",
                    "\n",
                    "[addresses]\n",
                    "sepolia = \"0x1000000000000000000000000000000000000001\"\n",
                    "\n",
                    "[rpc]\n",
                    "sepolia = \"\"\n"
                )
            )
        );

        assertEq(config.exposedReadRpcUrl("sepolia"), "");
    }

    function test_ReadRpcUrlReturnsEmptyStringWhenMissing()
        public
        withFixture("test/deployconfig-rpc-missing.toml")
    {
        string memory path = "test/deployconfig-rpc-missing.toml";
        DeployConfigHarness config = new DeployConfigHarness(path);
        _writeDeployToml(
            path,
            string(
                abi.encodePacked(
                    "[accounts]\n",
                    "sepolia = \"hotWallet\"\n",
                    "\n",
                    "[addresses]\n",
                    "sepolia = \"0x1000000000000000000000000000000000000001\"\n"
                )
            )
        );

        assertEq(config.exposedReadRpcUrl("sepolia"), "");
    }

    function test_AssertDeployTomlExistsRevertsWhenMissing()
        public
        withFixture("test/deployconfig-missing.toml")
    {
        DeployConfigHarness config = new DeployConfigHarness("test/deployconfig-missing.toml");

        vm.expectRevert(DeployConfig.DeployConfig__MissingDeployToml.selector);
        config.exposedAssertDeployTomlExists();
    }

    function test_AssertDeployTomlExistsRevertsWhenEmpty()
        public
        withFixture("test/deployconfig-empty.toml")
    {
        string memory path = "test/deployconfig-empty.toml";
        DeployConfigHarness config = new DeployConfigHarness(path);
        _writeDeployToml(path, "");

        vm.expectRevert(DeployConfig.DeployConfig__MissingDeployToml.selector);
        config.exposedAssertDeployTomlExists();
    }

    function test_IsLocalReturnsExpectedValues() public {
        DeployConfigHarness config = new DeployConfigHarness("test/deployconfig-unused.toml");

        assertTrue(config.exposedIsLocal("local"));
        assertFalse(config.exposedIsLocal("sepolia"));
    }

    function test_ChainIdToNetworkReturnsAllKnownNetworks() public {
        DeployConfigHarness config = new DeployConfigHarness("test/deployconfig-unused.toml");

        assertEq(config.exposedChainIdToNetwork(1), "mainnet");
        assertEq(config.exposedChainIdToNetwork(11155111), "sepolia");
        assertEq(config.exposedChainIdToNetwork(137), "polygon");
        assertEq(config.exposedChainIdToNetwork(42161), "arbitrum");
        assertEq(config.exposedChainIdToNetwork(8453), "base");
        assertEq(config.exposedChainIdToNetwork(84532), "base_sepolia");
        assertEq(config.exposedChainIdToNetwork(31337), "local");
    }

    function test_ChainIdToNetworkRevertsForUnknownChain() public {
        DeployConfigHarness config = new DeployConfigHarness("test/deployconfig-unused.toml");

        vm.expectRevert(
            abi.encodeWithSelector(
                DeployConfig.DeployConfig__NetworkNotFound.selector,
                "unknown"
            )
        );
        config.exposedChainIdToNetwork(999);
    }

    function test_DeployTomlPathUsesEnvOverride() public {
        DeployConfigDefaultPathHarness config = new DeployConfigDefaultPathHarness();

        vm.setEnv("DEPLOY_TOML_PATH", "test/deployconfig-env.toml");

        assertEq(config.exposedDeployTomlPath(), "test/deployconfig-env.toml");
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
                "polygon = \"polygonWallet\"\n",
                "arbitrum = \"arbWallet\"\n",
                "base = \"baseWallet\"\n",
                "base_sepolia = \"baseSepoliaWallet\"\n",
                "\n",
                "[addresses]\n",
                "sepolia = \"0x1000000000000000000000000000000000000001\"\n",
                "mainnet = \"0x2000000000000000000000000000000000000002\"\n",
                "polygon = \"0x3000000000000000000000000000000000000003\"\n",
                "arbitrum = \"0x4000000000000000000000000000000000000004\"\n",
                "base = \"0x5000000000000000000000000000000000000005\"\n",
                "base_sepolia = \"0x6000000000000000000000000000000000000006\"\n",
                "\n",
                "[rpc]\n",
                "sepolia = \"https://sepolia.example\"\n",
                "mainnet = \"https://mainnet.example\"\n",
                "polygon = \"https://polygon.example\"\n",
                "arbitrum = \"https://arbitrum.example\"\n",
                "base = \"https://base.example\"\n",
                "base_sepolia = \"https://base-sepolia.example\"\n"
            )
        );
    }
}
