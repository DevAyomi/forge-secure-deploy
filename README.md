# forge-secure-deploy

`forge-secure-deploy` is a small Foundry package for writing safer deployment scripts.

It gives you two building blocks:

- `DeployConfig`: reads network-specific deployment settings from `deploy.toml`
- `SecureDeploy`: a base script contract that adds config loading, balance checks, network confirmation, and broadcast startup

It also includes:

- `SecureSetup`: a preflight script that validates and prints the resolved deployment setup before you broadcast

The goal is simple: make it harder to deploy with the wrong account, wrong network, or missing confirmation.

## What It Does

When you build a deploy script on top of `SecureDeploy`, the deployment flow becomes:

1. Resolve the target network from `NETWORK` or the current chain ID
2. Load the network config from `deploy.toml`
3. Print a deployment summary
4. Check the deployer balance on non-local networks
5. Require an explicit confirmation for testnet or mainnet
6. Start Foundry broadcast with the configured deployer address

## Package Layout

```text
.
├── src/
│   ├── DeployConfig.sol
│   └── SecureDeploy.sol
├── script/
│   └── SecureSetup.s.sol
├── test/
│   ├── DeployConfig.t.sol
│   └── SecureDeploy.t.sol
├── deploy.toml.example
└── foundry.toml
```

## Requirements

- Foundry installed
- Solidity `0.8.28`
- A `deploy.toml` file in the project root, or a custom path provided through `DEPLOY_TOML_PATH`

Install Foundry if needed:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Installation

If you want to use this as a package in another Foundry repo:

```bash
forge install DevAyomi/forge-secure-deploy
```

**Note:** If your project relies on a `remappings.txt` file instead of Foundry's default path inference, make sure to add the following line to it:
```text
forge-secure-deploy/=lib/forge-secure-deploy/
```

Then import it in your scripts:

```solidity
import {SecureDeploy} from "forge-secure-deploy/src/SecureDeploy.sol";
```

If you are working directly in this repository, the package is already set up.

## Configuration

The package reads deployment metadata from `deploy.toml`.

Start from the template:

```bash
cp deploy.toml.example deploy.toml
```

Example file:

```toml
[accounts]
local        = "anvil"
sepolia      = "myWallet"
mainnet      = "coldWallet"
polygon      = "myWallet"
arbitrum     = "myWallet"
base         = "myWallet"
base_sepolia = "myWallet"

[addresses]
local        = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
sepolia      = "0xYOUR_SEPOLIA_DEPLOYER_ADDRESS"
mainnet      = "0xYOUR_MAINNET_DEPLOYER_ADDRESS"
polygon      = "0xYOUR_POLYGON_DEPLOYER_ADDRESS"
arbitrum     = "0xYOUR_ARBITRUM_DEPLOYER_ADDRESS"
base         = "0xYOUR_BASE_DEPLOYER_ADDRESS"
base_sepolia = "0xYOUR_BASE_SEPOLIA_DEPLOYER_ADDRESS"

[rpc]
local        = "http://127.0.0.1:8545"
sepolia      = "${SEPOLIA_RPC_URL}"
mainnet      = "${MAINNET_RPC_URL}"
polygon      = "${POLYGON_RPC_URL}"
arbitrum     = "${ARBITRUM_RPC_URL}"
base         = "${BASE_RPC_URL}"
base_sepolia = "${BASE_SEPOLIA_RPC_URL}"
```

### Config Fields

- `[accounts]`: Foundry keystore names
- `[addresses]`: deployer addresses associated with those keystores
- `[rpc]`: optional network RPC URLs

### Important Notes

- `deploy.toml` should not contain private keys
- Keystore names should map to entries in your Foundry keystore directory
- Local deployments are special-cased and use Anvil defaults
- Missing `rpc` entries are allowed and resolve to an empty string

## Environment Variables

The package uses these environment variables:

- `NETWORK`: optional explicit target network, like `sepolia` or `mainnet`
- `CONFIRM_DEPLOY`: required for non-local deployments
- `DEPLOY_TOML_PATH`: optional custom path to a config file
- `SEPOLIA_RPC_URL`, `MAINNET_RPC_URL`, `POLYGON_RPC_URL`, `ARBITRUM_RPC_URL`, `BASE_RPC_URL`, `BASE_SEPOLIA_RPC_URL`: referenced by `foundry.toml` and `deploy.toml`

Confirmation rules:

- Local: no confirmation required
- Testnet or non-mainnet live network: `CONFIRM_DEPLOY=yes`
- Mainnet: `CONFIRM_DEPLOY=deploy_to_mainnet`

## How Network Resolution Works

`SecureDeploy` resolves the target network in this order:

1. Use `NETWORK` if it is set
2. Otherwise map `block.chainid` to a known network name

Supported chain IDs:

- `1` -> `mainnet`
- `11155111` -> `sepolia`
- `137` -> `polygon`
- `42161` -> `arbitrum`
- `8453` -> `base`
- `84532` -> `base_sepolia`
- `31337` -> `local`

## Using `SecureDeploy`

Create your deployment script by inheriting from `SecureDeploy` instead of `Script`.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SecureDeploy} from "forge-secure-deploy/src/SecureDeploy.sol";

contract DeployMyContract is SecureDeploy {
    function run() external {
        address deployer = startSecureBroadcast();

        // deploy contracts here
        // new MyContract(deployer);

        stopSecureBroadcast();
    }
}
```

### What `startSecureBroadcast()` Does

- Instantiates `DeployConfig`
- Resolves the active network
- Loads `DeployConfig.NetworkConfig`
- Prints a summary to the console
- Enforces a minimum balance of `0.01 ether` for non-local deployments
- Requires the correct confirmation value
- Starts `vm.startBroadcast(deployer)`

### What `stopSecureBroadcast()` Does

- Stops broadcast
- Prints a completion summary

### Available Internal Helpers

After `startSecureBroadcast()`, your script can also use:

- `getDeployer()`
- `getNetwork()`
- `getConfig()`

## Using `SecureSetup`

`SecureSetup` is the package preflight script.

It does not broadcast transactions. Instead, it:

- resolves the active network from `NETWORK` or `block.chainid`
- loads the matching `DeployConfig.NetworkConfig`
- prints the keystore, deployer, chain ID, RPC status, and balance
- prints the confirmation string required for the target network
- reports whether the deployer balance meets the `0.01 ether` minimum used by `SecureDeploy`

Run it like this:

```bash
NETWORK=sepolia forge script script/SecureSetup.s.sol:SecureSetup --rpc-url "$SEPOLIA_RPC_URL"
```

Or let it infer the network from the connected chain:

```bash
forge script script/SecureSetup.s.sol:SecureSetup --rpc-url http://127.0.0.1:8545
```

## Using `DeployConfig` Directly

You can also read config manually from Solidity scripts or tests.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {DeployConfig} from "forge-secure-deploy/src/DeployConfig.sol";

contract Example {
    function readSepolia() external view returns (DeployConfig.NetworkConfig memory) {
        DeployConfig config = new DeployConfig();
        return config.getNetworkConfig("sepolia");
    }
}
```

`DeployConfig.NetworkConfig` contains:

```solidity
struct NetworkConfig {
    string network;
    string keystoreName;
    address deployer;
    string rpcUrl;
    bool isLocal;
}
```

## Keystore Setup

This package expects you to use Foundry keystores rather than hardcoding private keys.

Example:

```bash
cast wallet import myWallet --interactive
cast wallet list
```

Make sure the keystore name in `deploy.toml` matches the name you imported.

## Common Commands

Build the project:

```bash
forge build
```

Run the tests:

```bash
forge test
```

Check coverage:

```bash
forge coverage
```

Format Solidity files:

```bash
forge fmt
```

Start a local Anvil node:

```bash
anvil
```

## Deployment Examples

### Local Deployment

```bash
anvil
forge script script/DeployMyContract.s.sol:DeployMyContract --rpc-url http://127.0.0.1:8545 --broadcast
```

Because `chainid == 31337`, the package resolves the network as `local` and skips confirmation.

### Sepolia Deployment

```bash
NETWORK=sepolia \
CONFIRM_DEPLOY=yes \
forge script script/DeployMyContract.s.sol:DeployMyContract \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --account myWallet \
  --broadcast
```

### Mainnet Deployment

```bash
NETWORK=mainnet \
CONFIRM_DEPLOY=deploy_to_mainnet \
forge script script/DeployMyContract.s.sol:DeployMyContract \
  --rpc-url "$MAINNET_RPC_URL" \
  --account coldWallet \
  --broadcast
```

## Safety Checks

`SecureDeploy` currently enforces:

- explicit network resolution
- config-backed deployer selection
- balance check for non-local deployments
- mandatory human confirmation for live networks
- stricter confirmation string for mainnet

## Errors

### `DeployConfig`

- `DeployConfig__NetworkNotFound(string)`
- `DeployConfig__MissingDeployToml()`
- `DeployConfig__MissingAddress(string)`
- `DeployConfig__MissingKeystoreName(string)`

### `SecureDeploy`

- `SecureDeploy__DeploymentAborted()`
- `SecureDeploy__InsufficientBalance(address,uint256,uint256)`

## Testing

The package includes full coverage for the current contract surface.

Run:

```bash
forge test
forge coverage
```

Current status:

- 100% line coverage
- 100% statement coverage
- 100% branch coverage
- 100% function coverage

## Foundry Configuration

The current `foundry.toml` uses:

- `solc = "0.8.28"`
- `fs_permissions = [{ access = "read-write", path = "./" }]`

The filesystem permission is required because `DeployConfig` reads from `deploy.toml`, and the tests create temporary TOML fixtures.

## Advanced Usage

### Custom Config Path

If you want to use a different config file:

```bash
DEPLOY_TOML_PATH=deploy.prod.toml forge script ...
```

### Extending the Base Contracts

Both `DeployConfig` and `SecureDeploy` expose small overridable hooks for advanced use cases and testing:

- `DeployConfig._deployTomlPath()`
- `SecureDeploy._newDeployConfig()`
- `SecureDeploy._networkEnv()`
- `SecureDeploy._confirmEnv()`

`SecureSetup` also exposes small overridable hooks for advanced use cases and testing:

- `SecureSetup._newDeployConfig()`
- `SecureSetup._networkEnv()`
- `SecureSetup._resolveEnv()`

## Limitations

- The package only recognizes the chain IDs hardcoded in `DeployConfig`
- The minimum balance check is fixed at `0.01 ether`
- This package validates addresses and keystore names, but it does not verify that the selected Foundry account is unlocked or funded beyond the balance check

## Recommended Workflow

1. Create or import your Foundry keystore
2. Copy `deploy.toml.example` to `deploy.toml`
3. Fill in account names, addresses, and RPC references
4. Write your deploy script by inheriting from `SecureDeploy`
5. Run `forge test`
6. Deploy locally first
7. Deploy to testnet with `CONFIRM_DEPLOY=yes`
8. Deploy to mainnet only with `CONFIRM_DEPLOY=deploy_to_mainnet`

## License

MIT
