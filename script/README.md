## DEX Deployment (Foundry Only)

The scripts in this directory deploy the minimal AMM stack: `ProtocolForwarder`, pool implementation, `PoolFactory`, and `Router`. Gauges, ve, and airdrop tooling are no longer part of this repository.

### Environment
1. Copy `.env.sample` to `.env` and set:
   - `PRIVATE_KEY_DEPLOY` – signer used during deployment.
   - `FEE_MANAGER` – address allowed to manage factory fees (optional, defaults to deployer).
   - `PAUSER` – address allowed to pause/update metadata (optional, defaults to deployer).
   - `WHSK` – deployed wrapped HSK contract address (required).
   - `STABLE_FEE` / `VOLATILE_FEE` – fee overrides in basis points (optional, defaults `5` / `30`).
   - `OUTPUT_FILENAME` – JSON written under `script/constants/output/` (optional, defaults `dex-latest.json`).

2. (Optional) Copy `script/constants/template.json` to a new file if you want to pre-store the same values for reproducibility or documentation.

### Deploy
```
forge script script/DeployDex.s.sol:DeployDex \
  --broadcast \
  --rpc-url $RPC_URL \
  -vvvv
```

### Output JSON
The script writes `script/constants/output/{OUTPUT_FILENAME}` with:
```json
{
  "Forwarder": "0x...",
  "PoolImplementation": "0x...",
  "PoolFactory": "0x...",
  "Router": "0x...",
  "WHSK": "0x...",
  "StableFee": 5,
  "VolatileFee": 30
}
```
Use these addresses for front-end configuration or further automation.
