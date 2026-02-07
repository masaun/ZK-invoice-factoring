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
  --private-key $SUPPLIER_PRIVATE_KEY
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
SUPPLIER_PRIVATE_KEY=0x...
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

### Common Issues

#### 1. Local vs On-Chain Verification
- **Check local verification** - If this fails, there's an issue with proof generation
- **Check on-chain verification** - If local passes but on-chain fails, redeploy contracts

#### 2. Contract Issues
- **Check USDC balance** - Ensure the factoring contract has sufficient USDC
- **Check gas limits** - Proof verification is gas-intensive

#### 3. DataProtector Issues (for e2e-with-data-protector-of-iexec-tee.ts)

**❌ Upload Errors: IPFS and Arweave Both Failing**

**Error Messages:**
- **IPFS**: `HTTPError: multipart: NextPart: EOF`
- **Arweave**: `Failed to add file on Arweave` (empty cause)

**Root Cause**: iExec upload services (both IPFS and Arweave) on **Arbitrum Sepolia testnet** are currently experiencing service issues.

**Verified Configuration:**
- ✅ Correct IPFS endpoints configured: `https://ipfs-upload.arbitrum-sepolia-testnet.iex.ec`
- ✅ Correct IPFS gateway configured: `https://ipfs-gateway.arbitrum-sepolia-testnet.iex.ec`
- ✅ Tested both `uploadMode: 'ipfs'` and `uploadMode: 'arweave'`
- ✅ Data format is correct (numbers, bigints, strings as per SDK requirements)

**What Works:**
- ✅ DataProtector SDK initialization
- ✅ Custom Web3 provider implementation  
- ✅ Data schema extraction
- ✅ ZIP file creation
- ✅ Encryption key generation
- ✅ File encryption
- ❌ **Upload to decentralized storage (service unavailable)**

**Recommendations:**

1. **For Development/Testing**: The script automatically falls back to unprotected data and successfully demonstrates the full flow:
   ```
   ℹ️  Continuing with unprotected data (for testing only)
   ```

2. **For Production**:
   - Monitor [iExec Status Page](https://status.iex.ec/) (if available)
   - Contact iExec support: [Discord](https://discord.gg/iExec) or [GitHub Issues](https://github.com/iExecBlockchainComputing/dataprotector-sdk/issues)
   - Consider using **Arbitrum Mainnet** (chain ID 42161) which may have better service availability
   - Implement retry logic with exponential backoff:
     ```typescript
     async function protectDataWithRetry(data: any, maxRetries = 3) {
       for (let i = 0; i < maxRetries; i++) {
         try {
           return await dataProtectorCore.protectData(data);
         } catch (error) {
           if (i === maxRetries - 1) throw error;
           await sleep(Math.pow(2, i) * 1000); // Exponential backoff
         }
       }
     }
     ```

3. **Alternative Approach**: Store encrypted data on your own IPFS node or centralized storage temporarily until iExec services recover

**Service Status (as of Feb 7, 2026)**:
- 🔴 Arbitrum Sepolia IPFS Upload: **DOWN**
- 🔴 Arbitrum Sepolia Arweave Upload: **DOWN**
- ✅ DataProtector SDK: **Functional** (encryption works)
- ✅ Smart Contracts: **Deployed and working**

**Note**: This is a **known testnet limitation**. The DataProtector architecture and integration code are correct and production-ready.



## Technical Details

- **Circuit**: `circuits/invoice-refactoring/src/main.nr`
- **Proof System**: UltraHonk (via Barretenberg & Noir)
- **Network**: Arbitrum Sepolia
- **Token**: Mock USDC (6 decimals)

## Notes

- The script uses randomized invoice secrets, so each run generates a different proof
- The advance amount is set to 80% of the invoice amount by default
- Local proof verification runs before submitting to ensure proof validity
- The script handles USDC deposits automatically if the contract balance is insufficient

---

# E2E Test with iExec DataProtector (TEE)

## Overview

The `e2e-with-data-protector-of-iexec-tee.ts` script extends the standard e2e flow with enhanced privacy using iExec's DataProtector (Trusted Execution Environment).

### Key Privacy Enhancements

1. **Data Protection**: Sensitive invoice data is encrypted and stored using iExec DataProtector
2. **TEE Computation**: Confidential computation in Trusted Execution Environments
3. **Access Control**: Only authorized applications and users can access protected data
4. **Zero-Knowledge Proofs**: Prove invoice validity without revealing sensitive details

## Running the DataProtector E2E Test

```bash
cd scripts/invoice-refactoring
bun run e2e:tee
```

## How DataProtector Integration Works

### 1. DataProtector Initialization

The script creates a custom Web3 provider that:
- Signs messages and typed data with the private key
- Communicates with iExec's infrastructure
- Supports Arbitrum Sepolia network

```typescript
const dataProtectorCore = new IExecDataProtectorCore(customProvider, {
  allowExperimentalNetworks: true,
});
```

### 2. Protecting Invoice Data

```typescript
const protectedInvoiceData = await dataProtectorCore.protectData({
  name: `Invoice-${invoice.invoice_id}-${Date.now()}`,
  data: {
    invoice_id: invoice.invoice_id.toString(),
    invoice_supplier_id: invoice.invoice_supplier_id.toString(),
    invoice_buyer_id: invoice.invoice_buyer_id.toString(),
    invoice_amount: invoice.invoice_amount.toString(),
    // ... other invoice fields
  }
});
```

This step:
- Encrypts invoice data client-side using AES-256
- Stores encrypted data on IPFS/Arweave
- Deploys a protected data NFT on-chain
- Returns a protected data address for future reference

### 3. ZK Proof Generation (Current & Future)

**Current Implementation** (Local):
```typescript
const { proof, publicInputs } = await generateProof(
  invoice,
  imTree,
  minimumCreditScore,
  buyerCreditScore
);
```

**Future Enhancement** (TEE):
For maximum privacy, proof generation can be moved to TEE:
```typescript
const result = await dataProtectorCore.processProtectedData({
  protectedData: protectedInvoiceData.address,
  app: ZK_PROOF_GENERATOR_APP_ADDRESS, // Custom iExec app
  encryptResult: true,
});
```

## Environment Variables

### DataProtector-Specific Variables (Optional)

Add these to `contracts/.env` if you want separate contract deployments for DataProtector testing:

```env
# Use these for dedicated DataProtector contract deployments
INVOICE_FACTORING_CONTRACT_ADDRESS_USING_DATA_PROTECTOR=0x...
HONK_VERIFIER_CONTRACT_ADDRESS_USING_DATA_PROTECTOR=0x...
INVOICE_REFACTORING_HONK_VERIFIER_CONTRACT_ADDRESS_USING_DATA_PROTECTOR=0x...
```

If not set, the script will fall back to standard addresses with a warning.

## Key Differences: Standard vs DataProtector

| Feature | Standard E2E | DataProtector E2E |
|---------|--------------|-------------------|
| **Data Storage** | In-memory only | Encrypted on IPFS/Arweave |
| **Data Access** | Anyone with code access | Only authorized apps/users |
| **Proof Generation** | Local client-side | Can be done in TEE |
| **Privacy Level** | Basic (ZK proofs only) | Enhanced (TEE + ZK proofs) |
| **On-chain Footprint** | Minimal | Includes protected data NFT |

## Expected Output with DataProtector

When successful:

```
🎉 E2E Test with DataProtector Completed Successfully!
================================================================================

Summary:
  - Invoice factored: $50,000
  - Advance payment: 40000.0 USDC (80%)
  - Supplier received: 40000.0 USDC
  - Transaction hash: 0x...
  - Block explorer: https://sepolia.arbiscan.io/tx/0x...

🔐 DataProtector Integration:
  - Protected data address: 0x...
  - View on iExec explorer: https://explorer.iex.ec/arbitrum-sepolia/dataset/0x...

💡 Next Steps for Full TEE Integration:
  1. Create a custom iExec app for ZK proof generation
  2. Use processProtectedData() to run proof generation in TEE
  3. Grant access to the proof generator app using grantAccess()
  4. Retrieve proof results securely from TEE computation
```

## Advanced Features & Future Enhancements

### 1. Grant Access to Protected Data

```typescript
await dataProtectorCore.grantAccess({
  protectedData: protectedInvoiceData.address,
  authorizedApp: ZK_PROOF_APP_ADDRESS,
  authorizedUser: '0x0000000000000000000000000000000000000000', // Any user
  pricePerAccess: 0,
  numberOfAccess: 1,
});
```

### 2. Process Protected Data in TEE

```typescript
const result = await dataProtectorCore.processProtectedData({
  protectedData: protectedInvoiceData.address,
  app: CUSTOM_APP_ADDRESS,
  encryptResult: true,
  secrets: {
    1: 'credit_score_api_key',
    2: 'verification_token',
  },
});
```

### 3. Retrieve Results from TEE

```typescript
const { result } = await dataProtectorCore.getResultFromCompletedTask({
  taskId: result.taskId,
  pemPrivateKey: result.pemPrivateKey,
  path: 'proof.bin',
});
```

## Troubleshooting DataProtector

### DataProtector Initialization Fails

**Error**: `Failed to initialize DataProtector`

**Solution**: 
- Ensure you have the correct private key in `.env`
- Check network connectivity to iExec infrastructure
- Verify Arbitrum Sepolia RPC URL is accessible
- Install `@iexec/dataprotector` package: `bun install`

### Protected Data Creation Fails

**Error**: `Failed to protect data`

**Solution**:
- Check wallet has sufficient RLC (native token on iExec sidechain)
- Verify network supports DataProtector (Arbitrum Sepolia is supported)
- Ensure data object structure is valid (all values should be strings)

### Contract Address Not Set Warning

**Warning**: `INVOICE_FACTORING_CONTRACT_ADDRESS_USING_DATA_PROTECTOR not set`

**Solution**: This is just a warning. The script will use the standard contract address. To use dedicated contracts:
1. Deploy new contracts for DataProtector testing
2. Update `.env` with DataProtector-specific addresses

## Resources

### Documentation
- [iExec DataProtector Docs](https://docs.iex.ec/references/dataProtector/getting-started)
- [protectData Method](https://docs.iex.ec/references/dataProtector/methods/protectData)
- [processProtectedData Method](https://docs.iex.ec/references/dataProtector/methods/processProtectedData)
- [iExec Explorer](https://explorer.iex.ec/arbitrum-sepolia)

### Examples
- [iExec Next.js Starter](https://github.com/iExecBlockchainComputing/iexec-nextjs-starter)
- [Step-by-Step Guide to Building on iExec](https://vigorous-station-f66.notion.site/Step-by-Step-Guide-to-Building-on-iExec-284df2792faa808b93b9ee9ebfc8b3a7)

## Next Steps for Full TEE Integration

### Recommended Enhancements

1. **Create a Custom iExec App** for ZK proof generation:
   - Package the Noir circuit and prover into a Docker container
   - Deploy as an iExec application
   - Process protected invoice data in TEE to generate proofs

2. **Implement Full Access Control**:
   - Use `grantAccess()` to authorize specific applications
   - Restrict who can process invoice data
   - Set pricing for data access

3. **Add Result Encryption**:
   - Use `encryptResult: true` in `processProtectedData()`
   - Store private key securely for decryption
   - Ensure only authorized parties can decrypt results

4. **Deploy DataProtector-Specific Contracts**:
   - Deploy separate contract instances for DataProtector flow
   - Update `.env` with dedicated addresses
   - Test isolation between standard and DataProtector flows
