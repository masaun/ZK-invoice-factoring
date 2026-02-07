# E2E Test for Invoice Factoring on Arbitrum Sepolia

## Overview

This e2e test demonstrates the complete invoice factoring flow on Arbitrum Sepolia testnet:

1. **Create Test Invoice** - Generate sample invoice data
2. **Build Merkle Tree** - Create invoice commitment and Merkle proof
3. **Generate ZK Proof** - Prove invoice validity and buyer creditworthiness
4. **Verify Proof Locally** - Test proof before sending on-chain
5. **Deposit USDC** - Factoring company deposits funds to contract
6. **Factor Invoice** - Submit proof and receive advance payment
7. **Verify Results** - Confirm supplier received payment

## Running the Test

```bash
cd scripts/invoice-refactoring
bun run e2e
```

## ⚠️ Common Issue: Proof Verification Failure

### Symptoms

```
❌ Transaction failed!
Error signature: 0x59895a53 (InvalidProof)
Local verification: PASSED ✅
On-chain verification: FAILED ❌
```

### Root Cause

The deployed verifier contract on Arbitrum Sepolia was compiled from an **older version** of the circuit, but you're generating proofs with a **newer circuit artifact**. This mismatch causes on-chain verification to fail even though local verification passes.

### Solution

You need to redeploy the contracts with the updated verifier:

#### Step 1: Rebuild the Circuit

```bash
cd circuits/invoice-refactoring
./build.sh
```

This will:
- Compile the Noir circuit
- Generate a new `Verifier.sol` file
- Copy it to `contracts/src/circuits/honk-verifier/invoice-refactoring-honk-verifier/HonkVerifier.sol`

#### Step 2: Redeploy Contracts

```bash
cd contracts
forge script script/Deploy.s.sol \
  --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

Or if you use a deployment script:

```bash
cd contracts
./deploy.sh
```

#### Step 3: Update Contract Addresses

After deployment, update the addresses in `contracts/.env`:

```env
HONK_VERIFIER_CONTRACT_ADDRESS="<new address>"
INVOICE_REFACTORING_HONK_VERIFIER_CONTRACT_ADDRESS="<new address>"
INVOICE_FACTORING_CONTRACT_ADDRESS="<new address>"
```

#### Step 4: Run E2E Test Again

```bash
cd scripts/invoice-refactoring
bun run e2e
```

## Architecture

### ZK Prover Libraries

- `lib/zk-prover/zk-prover.ts` - Proof generation using Noir and Barretenberg
- `lib/zk-utils/incremental-merkle-tree/` - Merkle tree utilities
- `lib/zk-utils/poseidon/` - Poseidon hash functions

### Smart Contracts

- `InvoiceFactoring.sol` - Main contract for invoice factoring
- `InvoiceRefactoringHonkVerifier.sol` - Wrapper for Honk verifier
- `HonkVerifier.sol` - Base Honk proof verifier (generated from circuit)

### Configuration

Contract addresses and RPC URLs are loaded from `contracts/.env`:

```env
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
INVOICE_FACTORING_CONTRACT_ADDRESS=0x...
USDC_ADDRESS_MOCK_ON_ARBITRUM_SEPOLIA=0x...
PRIVATE_KEY=0x...
```

## Expected Output

When successful:

```
🎉 E2E Test Completed Successfully!
======================================================================

Summary:
  - Invoice factored: $50,000
  - Advance payment: 40000.0 USDC (80%)
  - Supplier received: 40000.0 USDC
  - Transaction hash: 0x...
  - Block explorer: https://sepolia.arbiscan.io/tx/0x...
```

## Debugging

If you encounter issues:

1. **Check local verification** - If this fails, there's an issue with proof generation
2. **Check on-chain verification** - If local passes but on-chain fails, redeploy contracts
3. **Check USDC balance** - Ensure the factoring contract has sufficient USDC
4. **Check gas limits** - Proof verification is gas-intensive

## Technical Details

- **Circuit**: `circuits/invoice-refactoring/src/main.nr`
- **Proof System**: UltraHonk (via Barretenberg)
- **Network**: Arbitrum Sepolia
- **Token**: Mock USDC (6 decimals)

## Notes

- The script uses randomized invoice secrets, so each run generates a different proof
- The advance amount is set to 80% of the invoice amount by default
- Local proof verification runs before submitting to ensure proof validity
- The script handles USDC deposits automatically if the contract balance is insufficient
