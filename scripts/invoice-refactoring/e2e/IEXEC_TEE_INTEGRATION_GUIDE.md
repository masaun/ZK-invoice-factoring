# iExec TEE Integration Guide

## Current Status

### What Works ✅

The `e2e-with-data-protector-of-iexec-tee.ts` script successfully demonstrates:

1. **DataProtector SDK Integration**
   - ✅ Custom Web3 provider implementation for viem compatibility
   - ✅ Correct IPFS endpoints configured for Arbitrum Sepolia
   - ✅ Data encryption workflow (EXTRACT_DATA_SCHEMA → CREATE_ZIP_FILE → CREATE_ENCRYPTION_KEY → ENCRYPT_FILE)

2. **Invoice Factoring Flow**
   - ✅ ZK proof generation (local)
   - ✅ On-chain proof verification
   - ✅ USDC token transfers
   - ✅ Complete E2E transaction flow

### What's Missing ❌

**No tasks are created on iExec Explorer** because the script doesn't use `processProtectedData()`.

**Current approach**: Generates ZK proofs **locally** (client-side)
**Required approach**: Generate ZK proofs **inside TEE** using `processProtectedData()`

## Why Tasks Don't Appear on iExec Explorer

### Current Flow (No Tasks Created)
```typescript
// 1. Protect data ✅
const protectedData = await dataProtectorCore.protectData({...});

// 2. Generate proof locally ❌ (not in TEE)
const proof = await generateProof(invoice);

// 3. Submit to blockchain ✅
await factorInvoice(proof);
```

**Result**: No iExec task created → Nothing visible on Explorer

### Required Flow (Creates Trackable Tasks)
```typescript
// 1. Protect data ✅
const protectedData = await dataProtectorCore.protectData({...});

// 2. Grant access to iApp ✅
await dataProtectorCore.grantAccess({
  protectedData: protectedData.address,
  authorizedApp: zkProofGeneratorAppAddress,
});

// 3. Execute computation in TEE ✅ (creates task!)
const result = await dataProtectorCore.processProtectedData({
  protectedData: protectedData.address,
  app: zkProofGeneratorAppAddress,
  onStatusUpdate: ({ title }) => console.log(`Task: ${title}`),
});
// ✅ Task created! Visible at: https://explorer.iex.ec/arbitrum-sepolia-testnet/task/${result.taskId}

// 4. Retrieve ZK proof from TEE
const proofData = await dataProtectorCore.getResultFromCompletedTask({
  taskId: result.taskId,
});

// 5. Submit to blockchain ✅
await factorInvoice(proofData.proof);
```

**Result**: iExec task created → Visible on Explorer with full lifecycle tracking

## Step-by-Step Implementation Guide

### Step 1: Create a ZK Proof Generator iApp

An **iApp** is a Docker-based application that runs inside iExec's Trusted Execution Environment (TEE).

#### 1.1 Project Structure
```bash
zk-proof-generator-iapp/
├── Dockerfile
├── src/
│   ├── app.py                    # Main application
│   ├── zk_prover.py              # Noir + Barretenberg integration
│   └── requirements.txt
├── circuits/
│   └── invoice_refactoring.json  # Compiled Noir circuit
└── iexec.json                    # iExec app configuration
```

#### 1.2 Sample Dockerfile
```dockerfile
FROM python:3.11-slim

# Install Barretenberg prover
RUN apt-get update && apt-get install -y curl
RUN curl -L https://github.com/AztecProtocol/barretenberg/releases/download/barretenberg-v0.x.x/bb -o /usr/local/bin/bb
RUN chmod +x /usr/local/bin/bb

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY src/ /app/
COPY circuits/ /app/circuits/

WORKDIR /app
CMD ["python", "app.py"]
```

#### 1.3 Sample Application (app.py)
```python
import os
import json
import subprocess
from iexec_dataprotector_deserializer import IExecDataProtectorDeserializer

def main():
    # Read protected invoice data
    deserializer = IExecDataProtectorDeserializer()
    
    invoice_id = deserializer.getValue('invoice_id', 'number')
    invoice_supplier_id = deserializer.getValue('invoice_supplier_id', 'number')
    invoice_buyer_id = deserializer.getValue('invoice_buyer_id', 'number')
    invoice_amount = deserializer.getValue('invoice_amount', 'number')
    invoice_due_date = deserializer.getValue('invoice_due_date', 'number')
    invoice_acceptance_timestamp = deserializer.getValue('invoice_acceptance_timestamp', 'number')
    secret = deserializer.getValue('secret', 'i128')
    
    # Get arguments
    args = os.environ.get('IEXEC_ARGS', '').split()
    min_credit_score = int(next(args[args.index('--min-credit-score') + 1]))
    buyer_credit_score = int(next(args[args.index('--buyer-score') + 1]))
    
    # Prepare proof inputs
    inputs = {
        'invoice_id': str(invoice_id),
        'invoice_supplier_id': str(invoice_supplier_id),
        'invoice_buyer_id': str(invoice_buyer_id),
        'invoice_amount': str(invoice_amount),
        'invoice_due_date': str(invoice_due_date),
        'invoice_acceptance_timestamp': str(invoice_acceptance_timestamp),
        'secret': str(secret),
        'min_credit_score': str(min_credit_score),
        'buyer_credit_score': str(buyer_credit_score),
    }
    
    # Write Prover.toml
    with open('/app/circuits/Prover.toml', 'w') as f:
        for key, value in inputs.items():
            f.write(f'{key} = "{value}"\n')
    
    # Generate ZK proof using Barretenberg
    result = subprocess.run([
        'bb', 'prove',
        '-b', '/app/circuits/invoice_refactoring.json',
        '-w', '/app/circuits/Prover.toml',
        '-o', '/tmp/proof'
    ], capture_output=True)
    
    if result.returncode != 0:
        raise Exception(f"Proof generation failed: {result.stderr}")
    
    # Read proof and public inputs
    with open('/tmp/proof', 'rb') as f:
        proof_bytes = f.read()
    
    with open('/tmp/public_inputs.json', 'r') as f:
        public_inputs = json.load(f)
    
    # Write results to IEXEC_OUT
    output_dir = os.environ['IEXEC_OUT']
    os.makedirs(output_dir, exist_ok=True)
    
    result_data = {
        'proof': proof_bytes.hex(),
        'publicInputs': public_inputs,
    }
    
    with open(f'{output_dir}/result.json', 'w') as f:
        json.dump(result_data, f)
    
    # Required: Create computed.json
    computed = {
        'deterministic-output-path': f'{output_dir}/result.json'
    }
    
    with open(f'{output_dir}/computed.json', 'w') as f:
        json.dump(computed, f)
    
    print("✓ ZK proof generated successfully in TEE!")

if __name__ == '__main__':
    main()
```

#### 1.4 Deploy the iApp
```bash
# Install iExec SDK
npm install -g iexec

# Initialize iApp
iexec app init

# Build Docker image
docker build -t zk-proof-generator .

# Push to Docker Hub
docker tag zk-proof-generator username/zk-proof-generator:latest
docker push username/zk-proof-generator:latest

# Deploy to iExec
iexec app deploy --chain 421614  # Arbitrum Sepolia

# Output: App deployed at 0xYourAppAddress
```

### Step 2: Update e2e Script to Use processProtectedData()

Replace the local proof generation section with:

```typescript
// Step 3: Generate ZK proof in TEE (instead of locally)
console.log("\n🔐 Step 3: Generating ZK proof in iExec TEE...");

if (!protectedInvoiceData) {
  throw new Error("Protected data is required for TEE execution");
}

// Your deployed iApp address
const ZK_PROOF_GENERATOR_APP = '0xYourDeployedAppAddress';

// Grant access to the iApp
console.log("  - Granting access to ZK proof generator iApp...");
const grantedAccess = await dataProtectorCore.grantAccess({
  protectedData: protectedInvoiceData.address,
  authorizedApp: ZK_PROOF_GENERATOR_APP,
  authorizedUser: account.address,
  numberOfAccess: 1,
});
console.log("  ✓ Access granted:", grantedAccess.txHash);

// Execute proof generation in TEE
console.log("  - Executing ZK proof generation in TEE...");
const taskResult = await dataProtectorCore.processProtectedData({
  protectedData: protectedInvoiceData.address,
  app: ZK_PROOF_GENERATOR_APP,
  args: `--min-credit-score ${minimumCreditScore} --buyer-score ${buyerCreditScore}`,
  onStatusUpdate: ({ title, isDone }) => {
    if (!isDone) {
      console.log(`    ⏳ ${title}...`);
    } else {
      console.log(`    ✓ ${title} completed`);
    }
  },
});

console.log("  ✓ Task created!");
console.log("    - Task ID:", taskResult.taskId);
console.log("    - View on Explorer:", `https://explorer.iex.ec/arbitrum-sepolia-testnet/task/${taskResult.taskId}`);

// Retrieve proof from TEE result
console.log("  - Retrieving ZK proof from TEE...");
const proofData = await dataProtectorCore.getResultFromCompletedTask({
  taskId: taskResult.taskId,
});

const proof = proofData.result.proof;
const publicInputs = proofData.result.publicInputs;

console.log("  ✓ ZK proof retrieved from TEE successfully!");
```

### Step 3: Monitor on iExec Explorer

Once `processProtectedData()` is called, you can track the task at:

**https://explorer.iex.ec/arbitrum-sepolia-testnet**

Search by:
- **Task ID**: `taskResult.taskId`
- **Deal ID**: `taskResult.dealId`
- **Protected Data Address**: `protectedInvoiceData.address`

**Task Lifecycle**:
1. `PENDING` - Task created, waiting for worker
2. `ACTIVE` - Worker executing in TEE
3. `COMPLETED` - ZK proof generated, results uploaded
4. `FAILED` - Execution error (check logs)

## Benefits of Full TEE Integration

| Aspect | Local Generation (Current) | TEE Execution (Required) |
|--------|---------------------------|-------------------------|
| **Privacy** | Invoice data exposed to client | Data never leaves encrypted storage |
| **Auditability** | No on-chain record of computation | Full task lifecycle on blockchain |
| **Verification** | Trust client to generate proof | Verifiable TEE attestation |
| **Tracking** | No visibility | Real-time status on Explorer |
| **Compliance** | Client-side trust required | Hardware-enforced TEE guarantees |

## Troubleshooting

### Task Fails with "Missing IEXEC_IN or IEXEC_OUT"
**Cause**: App doesn't check required environment variables
**Fix**: Add validation in app.py:
```python
if not os.environ.get('IEXEC_IN') or not os.environ.get('IEXEC_OUT'):
    print("ERROR: Missing IEXEC_IN or IEXEC_OUT")
    sys.exit(1)
```

### Task Timeout
**Cause**: ZK proof generation takes too long
**Fix**: 
- Use appropriate task category (e.g., XL instead of S)
- Optimize circuit size
- Use faster proving system

### "Dataset Type Unmatching"
**Cause**: Protected data schema doesn't match app expectations
**Fix**: Ensure data types in `protectData()` match what deserializer expects

## Reference Links

- **iExec Explorer**: https://explorer.iex.ec/arbitrum-sepolia-testnet
- **Build iApp**: https://docs.iex.ec/guides/build-iapp/build-&-test
- **Deploy iApp**: https://docs.iex.ec/guides/build-iapp/deploy-&-run
- **DataProtector**: https://docs.iex.ec/references/dataProtector
- **processProtectedData**: https://docs.iex.ec/guides/use-iapp/run-iapp-with-ProtectedData
- **Debugging**: https://docs.iex.ec/guides/build-iapp/debugging
- **Deserializer**: https://docs.iex.ec/references/iapp-generator/deserializer

## Summary

**Current Status**: 
- ✅ DataProtector integration implemented correctly
- ✅ Data encryption works
- ❌ No TEE execution (local proof generation only)
- ❌ No tasks visible on iExec Explorer

**To Complete**:
1. Create ZK proof generator iApp (Docker + Python + Barretenberg)
2. Deploy iApp to iExec network
3. Replace local proof generation with `processProtectedData()`
4. Tasks will appear on https://explorer.iex.ec/arbitrum-sepolia-testnet

This will provide full end-to-end privacy with verifiable computation!
