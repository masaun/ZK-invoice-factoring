# Quick Deployment Guide

## Setup (One-time)

1. **Copy environment template:**
   ```bash
   cd contracts
   cp .env.example .env
   ```

2. **Edit `.env` file with your values:**
   - `PRIVATE_KEY`: Your wallet private key (without 0x prefix)
   - `ARBITRUM_SEPOLIA_RPC_URL`: https://sepolia-rollup.arbitrum.io/rpc
   - `USDC_ADDRESS`: USDC token address (or deploy a mock token)
   - `ARBISCAN_API_KEY`: (Optional) For contract verification

3. **Get testnet ETH:**
   - Visit: https://faucet.arbitrum.io/
   - Request Arbitrum Sepolia ETH

## Deploy

### Option 1: Using the deployment script (Recommended)
```bash
cd contracts
./deploy.sh
```

### Option 2: Using forge directly
```bash
cd contracts
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url arbitrum_sepolia \
  --broadcast \
  --verify
```

### Option 3: Without verification
```bash
cd contracts
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url arbitrum_sepolia \
  --broadcast
```

## What Gets Deployed

The deployment script will deploy 3 contracts in order:

1. **HonkVerifier** - ZK proof verification contract
2. **InvoiceRefactoringHonkVerifier** - Invoice-specific verifier wrapper
3. **InvoiceFactoring** - Main invoice factoring contract

## After Deployment

Save the deployed contract addresses shown in the console output. You'll see:

```
=== Deployment Summary ===
HonkVerifier: 0x...
InvoiceRefactoringHonkVerifier: 0x...
InvoiceFactoring: 0x...
USDC Address: 0x...
```

View your contracts on Arbiscan:
https://sepolia.arbiscan.io/address/YOUR_CONTRACT_ADDRESS

## Common Issues

**"Insufficient funds"** → Get more Arbitrum Sepolia ETH from faucet

**"USDC_ADDRESS not set"** → Deploy a mock ERC20 or get a testnet USDC address

**Verification failed** → Run manual verification or wait and retry

For detailed troubleshooting, see [DEPLOYMENT.md](./DEPLOYMENT.md)
