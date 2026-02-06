# Arbitrum Sepolia Deployment Scripts

This directory contains scripts for deploying and verifying contracts on Arbitrum Sepolia testnet.

## 📁 Files

### Deployment Scripts
- **deploy.sh** - Deploy and verify all main contracts (HonkVerifier, InvoiceRefactoringHonkVerifier, InvoiceFactoring)
  - Run normally to deploy: `./deploy.sh`
  - Run with `--verify-only` flag to verify already deployed contracts
- **deploy-mock-usdc.sh** - Deploy and verify MockUSDC token for testing
  - Run normally to deploy: `./deploy-mock-usdc.sh`
  - Run with `--verify-only` flag to verify already deployed MockUSDC
- **Deploy.s.sol** - Solidity deployment script for main contracts
- **DeployMockUSDC.s.sol** - Solidity deployment script for MockUSDC

## 🚀 Quick Start

### 1. Setup Environment

From the contracts root directory:
```bash
cd ../../../  # Go to contracts root
cp .env.example .env
# Edit .env with your values
```

Required in `.env`:
- `PRIVATE_KEY` - Your wallet private key (without 0x)
- `ARBITRUM_SEPOLIA_RPC_URL` - RPC endpoint
- `USDC_ADDRESS` - USDC token address (or deploy MockUSDC)
- `ARBISCAN_API_KEY` - (Optional) For automatic verification

### 2. Get Test ETH

Visit: https://faucet.arbitrum.io/

### 3. Deploy MockUSDC (Optional)

```bash
./deploy-mock-usdc.sh
```

Update `USDC_ADDRESS` in `.env` with the deployed address.

### 4. Deploy Main Contracts

```bash
./deploy.sh
```

This deploys:
1. HonkVerifier
2. InvoiceRefactoringHonkVerifier
3. InvoiceFactoring

## 🔍 Verification

### Automatic Verification

If `ARBISCAN_API_KEY` is set in `.env`, contracts will be automatically verified during deployment.

### Manual Verification

If automatic verification fails, you can run the same scripts in verify-only mode:

**Verify main contracts:**
```bash
# Interactive (prompts for addresses)
./deploy.sh --verify-only

# Or with addresses as arguments
./deploy.sh --verify-only <honk_verifier_addr> <invoice_refactoring_honk_verifier_addr> <invoice_factoring_addr>
```

**Verify MockUSDC:**
```bash
# Interactive (prompts for address)
./deploy-mock-usdc.sh --verify-only

# Or with address as argument
./deploy-mock-usdc.sh --verify-only <mock_usdc_addr>
```

## 📋 Script Features

All scripts support dual modes:
- **Deployment mode** (default): Deploy contracts with optional automatic verification
- **Verification mode** (`--verify-only` flag): Verify already deployed contracts

Features:
- ✅ Auto-detect contracts root directory (can run from anywhere)
- ✅ Load `.env` from contracts root
- ✅ Validate required environment variables
- ✅ Build contracts before deployment
- ✅ Support automatic Arbiscan verification during deployment
- ✅ Interactive verification with address prompts
- ✅ Provide clear success/error messages
- ✅ Display deployment/verification summary with Arbiscan links

## 🌐 Arbiscan Links

After deployment, view your contracts:
- Explorer: https://sepolia.arbiscan.io/
- Contract: https://sepolia.arbiscan.io/address/YOUR_ADDRESS

## 🛠️ Troubleshooting

### "Insufficient funds"
→ Get more testnet ETH from https://faucet.arbitrum.io/

### "Verification failed"
→ Use manual verification scripts with explicit addresses

### ".env file not found"
→ Ensure `.env` exists in the contracts root directory (3 levels up)

### Import path errors
→ All imports are relative to contracts root directory

## 📝 Examples

**Deploy everything:**
```bash
# 1. Deploy MockUSDC
./deploy-mock-usdc.sh
# Copy MockUSDC address

# 2. Update .env
echo "USDC_ADDRESS=0x..." >> ../../../.env
 (if automatic verification failed):**
```bash
./deploy.sh --verify-only
```

**Verify after deployment:**
```bash
./verify-contracts.sh \
  0xHonkVerifierAddress \
  0xInvoiceRefactoringHonkVerifierAddress \
  0xInvoiceFactoringAddress
```

## 🔗 Related Documentation

- [Foundry Book](https://book.getfoundry.sh/)
- [Arbiscan API](https://docs.arbiscan.io/)
- [Arbitrum Documentation](https://docs.arbitrum.io/)
