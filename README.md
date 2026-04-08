# forge-secure-deploy

`forge-secure-deploy` is a lightweight Foundry package for writing safer, configuration-driven deployment scripts. It automatically enforces network configs, validates deployer balances, and requires explicit confirmations to prevent accidental mainnet deployments.

## Installation

```bash
forge install DevAyomi/forge-secure-deploy
```

**Note:** If your project relies on a `remappings.txt` file instead of Foundry's default path inference, make sure to add:
```text
forge-secure-deploy/=lib/forge-secure-deploy/
```

## Requirements
- Foundry installed
- Solidity `0.8.28` (or strictly compatible)
- A `deploy.toml` file in your project root

## Quick Start

### 1. Configuration
Run the interactive setup script to automatically generate your `deploy.toml` configuration:

```bash
sh lib/forge-secure-deploy/init.sh
```

*(Note: Never store private keys in `deploy.toml`. Use [Foundry Keystores](https://book.getfoundry.sh/reference/cast/cast-wallet-import).)*

### 2. Write Your Script
Inherit from `SecureDeploy` instead of `Script`. `startSecureBroadcast()` automatically reads your config, validates your setup, and begins the transaction broadcast.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SecureDeploy} from "forge-secure-deploy/src/SecureDeploy.sol";

contract DeployMyContract is SecureDeploy {
    function run() external {
        address deployer = startSecureBroadcast();

        // deploy active contracts here
        // new MyContract(deployer);

        stopSecureBroadcast();
    }
}
```

### 3. Deploy!

**Local Deployment:** (Requires no confirmation)
```bash
forge script script/DeployMyContract.s.sol:DeployMyContract --rpc-url http://127.0.0.1:8545 --broadcast
```

**Testnet Deployment:** (Requires `CONFIRM_DEPLOY=yes`)
```bash
NETWORK=sepolia \
CONFIRM_DEPLOY=yes \
forge script script/DeployMyContract.s.sol:DeployMyContract \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --account myWallet \
  --broadcast
```

**Mainnet Deployment:** (Requires `CONFIRM_DEPLOY=deploy_to_mainnet`)
```bash
NETWORK=mainnet \
CONFIRM_DEPLOY=deploy_to_mainnet \
forge script script/DeployMyContract.s.sol:DeployMyContract \
  --rpc-url "$MAINNET_RPC_URL" \
  --account coldWallet \
  --broadcast
```

## Environment Variables
- `NETWORK`: (Optional) Specifically target a network name (e.g. `sepolia`, `mainnet`, `polygon`). If omitted, it automatically infers based on `block.chainid`.
- `CONFIRM_DEPLOY`: Required safety string for non-local network broadcasts.
- `DEPLOY_TOML_PATH`: (Optional) Use a custom config file path.

## Preflight Checks (`SecureSetup`)
If you want to dry-run your configuration without broadcasting, use the built-in preflight script:
```bash
NETWORK=sepolia forge script lib/forge-secure-deploy/script/SecureSetup.s.sol:SecureSetup --rpc-url "$SEPOLIA_RPC_URL"
```
This prints the resolved setup, confirms balance limits, and shows exactly what confirmation string is required.

## License
MIT
