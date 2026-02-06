# Arbitrum Sepolia Deployment Scripts

This directory contains scripts for deploying and verifying contracts on Arbitrum Sepolia testnet.

## 📁 Files

### Deployment Scripts
- **deploy.sh** - Deploy all main contracts (HonkVerifier, InvoiceRefactoringHonkVerifier, InvoiceFactoring)
- **deploy-mock-usdc.sh** - Deploy MockUSDC token for testing
- **Deploy.s.sol** - Solidity deployment script for main contracts
- **DeployMockUSDC.s.sol** - Solidity deployment script for MockUSDC

### Verification Scripts
- **verify-contracts.sh** - Verify main contracts on Arbiscan
- **verify-mock-usdc.sh** - Verify MockUSDC on Arbiscan

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

If automatic verification fails, use these scripts:

**Verify main contracts:**
```bash
./verify-contracts.sh <honk_verifier_addr> <invoice_refactoring_honk_verifier_addr> <invoice_factoring_addr>
```

**Verify MockUSDC:**
```bash
./verify-mock-usdc.sh <mock_usdc_addr>
```

The scripts will prompt for addresses if not provided as arguments.

## 📋 Script Features

All deployment scripts:
- ✅ Auto-detect contracts root directory (can run from anywhere)
- ✅ Load `.env` from contracts root
- ✅ Validate required environment variables
- ✅ Build contracts before deployment
- ✅ Support automatic Arbiscan verification
- ✅ Provide clear success/error messages
- ✅ Display deployment summary with addresses

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

# 3. Deploy main contracts
./deploy.sh
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
