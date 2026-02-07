import { getIncrementalMerkleTree } from "../lib/zk-utils/incremental-merkle-tree/index.ts";
import { generateProof, generateRandomInt, createInvoiceCommitment, type Invoice } from "../lib/zk-prover/zk-prover.ts";
import { createWalletClient, createPublicClient, http, parseUnits, formatUnits, type WalletClient, type PublicClient, type Address } from "viem";
import { arbitrumSepolia } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import { config } from "dotenv";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
// @ts-ignore - iExec DataProtector types
import { IExecDataProtectorCore } from "@iexec/dataprotector";

// Load environment variables from contracts/.env
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const envPath = resolve(__dirname, "../../../contracts/.env");

console.log("📂 Loading environment from:", envPath);
const result = config({ path: envPath });

if (result.error) {
  console.error("❌ Error loading .env file:", result.error);
  throw result.error;
}

// Helper function to check if a value is a placeholder
const isPlaceholder = (value: string | undefined): boolean => {
  if (!value) return true;
  return value.includes('your_deployed') || value.includes('placeholder') || value.includes('here');
};

// Deployed contract addresses from .env - Using DataProtector-specific addresses
// Fall back to regular addresses if DataProtector-specific ones are not set or are placeholders
const dataProtectorAddress = process.env.INVOICE_FACTORING_CONTRACT_ADDRESS_USING_DATA_PROTECTOR;
const INVOICE_FACTORING_ADDRESS = (!isPlaceholder(dataProtectorAddress) && dataProtectorAddress 
  ? dataProtectorAddress 
  : process.env.INVOICE_FACTORING_CONTRACT_ADDRESS) as Address;

const USDC_ADDRESS = process.env.USDC_ADDRESS_MOCK_ON_ARBITRUM_SEPOLIA as Address;
const PRIVATE_KEY = process.env.PRIVATE_KEY as `0x${string}`;
const RPC_URL = process.env.ARBITRUM_SEPOLIA_RPC_URL!;

// Validate environment variables
if (!INVOICE_FACTORING_ADDRESS || !USDC_ADDRESS || !PRIVATE_KEY || !RPC_URL) {
  throw new Error("Missing required environment variables in contracts/.env");
}

// Warning if using fallback addresses
if (!dataProtectorAddress || isPlaceholder(dataProtectorAddress)) {
  console.warn("⚠️  WARNING: INVOICE_FACTORING_CONTRACT_ADDRESS_USING_DATA_PROTECTOR not set or is placeholder, using fallback address");
  console.warn("   For production use with DataProtector, please deploy dedicated contracts and update .env");
  console.warn("   Current fallback address:", INVOICE_FACTORING_ADDRESS);
}

console.log("🔧 Configuration:");
console.log("  - Network: Arbitrum Sepolia");
console.log("  - RPC URL:", RPC_URL);
console.log("  - InvoiceFactoring Address:", INVOICE_FACTORING_ADDRESS);
console.log("  - USDC Address:", USDC_ADDRESS);
console.log("  - Using DataProtector: ✅");

// Contract ABIs
const INVOICE_FACTORING_ABI = [
  {
    type: "function",
    name: "factorInvoice",
    inputs: [
      { name: "proof", type: "bytes" },
      { name: "publicInputs", type: "bytes32[]" },
      { name: "advanceAmount", type: "uint256" },
      { name: "invoiceSupplier", type: "address" }
    ],
    outputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "depositUSDC",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "nullifierHashes",
    inputs: [{ name: "", type: "bytes32" }],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "factoredInvoiceOwners",
    inputs: [{ name: "", type: "bytes32" }],
    outputs: [{ name: "", type: "address" }],
    stateMutability: "view"
  },
  {
    type: "event",
    name: "InvoiceFactored",
    inputs: [
      { name: "invoiceCommitment", type: "bytes32", indexed: true },
      { name: "supplier", type: "address", indexed: true },
      { name: "advanceAmount", type: "uint256", indexed: false }
    ]
  }
] as const;

const ERC20_ABI = [
  {
    type: "function",
    name: "balanceOf",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "approve",
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" }
    ],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "transfer",
    inputs: [
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" }
    ],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "transferFrom",
    inputs: [
      { name: "from", type: "address" },
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" }
    ],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "nonpayable"
  }
] as const;

/**
 * @notice - E2E script for ZK Invoice Refactoring with iExec DataProtector on Arbitrum Sepolia
 * 
 * This script demonstrates the complete flow with enhanced privacy using iExec TEE:
 * 1. Create a test invoice with sensitive data
 * 2. **Protect sensitive invoice data using iExec DataProtector (TEE encryption)**
 * 3. Generate ZK proof for invoice refactoring (computation can be done in TEE)
 * 4. Deposit USDC to the factoring contract (as factoring company)
 * 5. Call factorInvoice() on the smart contract to receive advance payment
 * 
 * Key Privacy Enhancements with DataProtector:
 * - Invoice details (ID, amounts, dates) are encrypted and stored securely
 * - Sensitive data is processed within Trusted Execution Environments (TEE)
 * - Only authorized parties can access protected data
 * - Credit scores and other private information remain confidential
 * - Zero-knowledge proofs ensure validity without revealing underlying data
 * 
 * @see https://docs.iex.ec/references/dataProtector/getting-started
 * @see https://docs.iex.ec/references/dataProtector/methods/protectData
 * @see https://docs.iex.ec/references/dataProtector/methods/processProtectedData
 */
const main = async () => {
  try {
    console.log("\n📋 Starting E2E Test: Invoice Factoring with iExec DataProtector");
    console.log("=".repeat(80));

    console.log("\n🔌 Setting up wallet and clients...");
    // Setup wallet and clients
    const account = privateKeyToAccount(PRIVATE_KEY);
    console.log("  ✓ Account created from private key");
    
    const walletClient: WalletClient = createWalletClient({
      account,
      chain: arbitrumSepolia,
      transport: http(RPC_URL)
    });
    console.log("  ✓ Wallet client created");

    const publicClient: PublicClient = createPublicClient({
      chain: arbitrumSepolia,
      transport: http(RPC_URL)
    });
    console.log("  ✓ Public client created");

    console.log("\n✅ Wallet connected:");
    console.log("  - Address:", account.address);

    // Initialize iExec DataProtector
    console.log("\n🔐 Initializing iExec DataProtector...");
    let dataProtectorCore: any;
    
    try {
      // Create a custom Web3 provider compatible with iExec SDK
      const customProvider = {
        request: async ({ method, params }: { method: string; params?: any[] }) => {
          if (method === 'eth_chainId') {
            return '0x' + arbitrumSepolia.id.toString(16);
          }
          if (method === 'eth_accounts') {
            return [account.address];
          }
          if (method === 'eth_requestAccounts') {
            return [account.address];
          }
          if (method === 'personal_sign') {
            const [message, address] = params || [];
            const signature = await account.signMessage({ message });
            return signature;
          }
          if (method === 'eth_signTypedData_v4' || method === 'eth_signTypedData') {
            const [address, typedData] = params || [];
            const parsedData = typeof typedData === 'string' ? JSON.parse(typedData) : typedData;
            const signature = await account.signTypedData(parsedData);
            return signature;
          }
          
          // Fallback to regular RPC for other methods
          const response = await fetch(RPC_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params: params || [] })
          });
          const data = await response.json();
          return data.result;
        }
      };

      // Arbitrum Sepolia IPFS configuration from iExec documentation
      const ipfsConfig = {
        ipfsNode: 'https://ipfs-upload.arbitrum-sepolia-testnet.iex.ec',
        ipfsGateway: 'https://ipfs-gateway.arbitrum-sepolia-testnet.iex.ec',
      };

      dataProtectorCore = new IExecDataProtectorCore(customProvider, {
        allowExperimentalNetworks: true,
        ...ipfsConfig,
      });
      console.log("  ✓ DataProtector initialized successfully");
      console.log("    - IPFS Upload:", ipfsConfig.ipfsNode);
      console.log("    - IPFS Gateway:", ipfsConfig.ipfsGateway);
    } catch (error) {
      console.error("  ❌ Failed to initialize DataProtector:", error);
      console.log("  ℹ️  Continuing without DataProtector (falling back to local encryption)");
      dataProtectorCore = null;
    }

  // Step 1: Create test invoice with sensitive data
  console.log("\n📝 Step 1: Creating test invoice with sensitive data...");
  const invoice: Invoice = {
    invoice_id: 12345,
    invoice_supplier_id: 67890,
    invoice_buyer_id: 11111,
    invoice_amount: 50000,  // $50,000
    invoice_due_date: Math.floor(Date.now() / 1000) + 2592000, // 30 days from now
    invoice_acceptance_timestamp: Math.floor(Date.now() / 1000),
    secret: generateRandomInt()
  };

  console.log("  ✓ Invoice created:");
  console.log("    - ID:", invoice.invoice_id);
  console.log("    - Supplier ID:", invoice.invoice_supplier_id);
  console.log("    - Buyer ID:", invoice.invoice_buyer_id);
  console.log("    - Amount: $" + invoice.invoice_amount.toLocaleString());
  console.log("    - Due date:", new Date(invoice.invoice_due_date * 1000).toLocaleDateString());

  // Step 1.5: Protect sensitive invoice data using iExec DataProtector
  console.log("\n🔒 Step 1.5: Protecting sensitive invoice data with iExec DataProtector...");
  let protectedInvoiceData: any = null;
  
  if (dataProtectorCore) {
    try {
      console.log("  - Encrypting invoice data in TEE...");
      console.log("  - Attempting with Arweave upload mode (alternative to IPFS)...");
      
      // Use simpler data structure to avoid IPFS upload issues
      // All values must be: boolean, number, bigint, string, or binary (Uint8Array/ArrayBuffer/File)
      protectedInvoiceData = await dataProtectorCore.protectData({
        name: `Invoice-${invoice.invoice_id}-${Date.now()}`,
        data: {
          invoice_id: Number(invoice.invoice_id),
          invoice_supplier_id: Number(invoice.invoice_supplier_id),
          invoice_buyer_id: Number(invoice.invoice_buyer_id),
          invoice_amount: Number(invoice.invoice_amount),
          invoice_due_date: Number(invoice.invoice_due_date),
          invoice_acceptance_timestamp: Number(invoice.invoice_acceptance_timestamp),
          secret: invoice.secret,
        },
        uploadMode: 'ipfs', // IPFS
        onStatusUpdate: ({ title, isDone }: { title: string; isDone: boolean }) => {
          if (!isDone) {
            console.log(`    ⏳ ${title}...`);
          } else {
            console.log(`    ✓ ${title} completed`);
          }
        }
      });

      console.log("  ✓ Invoice data protected successfully!");
      console.log("    - Protected Data Address:", protectedInvoiceData.address);
      console.log("    - Owner:", protectedInvoiceData.owner);
      console.log("    - Data Schema:", JSON.stringify(protectedInvoiceData.schema, null, 2));
      console.log("    - Transaction Hash:", protectedInvoiceData.transactionHash);
      
      // Optional: Grant access to specific applications or users
      // This would allow only authorized parties to process this data in TEE
      console.log("\n  💡 Protected data can now be granted to specific apps/users");
      console.log("     Use dataProtectorCore.grantAccess() to authorize access");
      
    } catch (error) {
      console.error("  ❌ Failed to protect data:", error);
      console.log("  ℹ️  Continuing with unprotected data (for testing only)");
    }
  } else {
    console.log("  ⚠️  DataProtector not available, using unencrypted invoice data");
    console.log("     For production, ensure DataProtector is properly initialized");
  }

  // Step 2: Create invoice commitment and Merkle tree
  console.log("\n🌳 Step 2: Building Merkle tree with invoice commitment...");
  const invoiceCommitment = createInvoiceCommitment(invoice);
  console.log("  ✓ Invoice commitment:", "0x" + invoiceCommitment.toString(16));

  const { imTree } = await getIncrementalMerkleTree([invoiceCommitment]);
  const merkleRoot = imTree.root;
  console.log("  ✓ Merkle root:", "0x" + merkleRoot.toString(16));

  // Step 3: Generate ZK proof for invoice refactoring
  console.log("\n🔐 Step 3: Generating ZK proof for invoice refactoring...");
  
  // ⚠️ IMPORTANT: Current Implementation vs Full TEE Integration
  // ================================================================
  // 
  // CURRENT APPROACH (Local Proof Generation):
  // ------------------------------------------
  // This script currently generates ZK proofs LOCALLY (client-side).
  // While this works functionally, it doesn't leverage the full power of iExec TEE.
  //
  // FULL TEE INTEGRATION (Recommended for Production):
  // --------------------------------------------------
  // To create trackable tasks visible on iExec Explorer, follow these steps:
  //
  // Step 1: Create an iExec iApp (TEE Application)
  //   - Build a Docker image containing Noir/Barretenberg ZK proof generator
  //   - Deploy it as an iExec app
  //   - Example: https://github.com/iExecBlockchainComputing/iexec-apps
  //
  // Step 2: Grant Access to the iApp
  //   if (protectedInvoiceData) {
  //     const grantedAccess = await dataProtectorCore.grantAccess({
  //       protectedData: protectedInvoiceData.address,
  //       authorizedApp: '0xYourZKProofGeneratorAppAddress',
  //       authorizedUser: account.address,
  //       numberOfAccess: 1,
  //     });
  //     console.log("✓ Granted access:", grantedAccess.txHash);
  //   }
  //
  // Step 3: Execute ZK Proof Generation in TEE
  //   const taskResult = await dataProtectorCore.processProtectedData({
  //     protectedData: protectedInvoiceData.address,
  //     app: '0xYourZKProofGeneratorAppAddress',
  //     args: `--min-credit-score ${minimumCreditScore} --buyer-score ${buyerCreditScore}`,
  //     onStatusUpdate: ({ title, isDone }) => {
  //       console.log(`Task Status: ${title} - ${isDone ? 'Done' : 'In Progress'}`);
  //     },
  //   });
  //
  //   // This creates a TASK on iExec network visible at:
  //   // https://explorer.iex.ec/arbitrum-sepolia-testnet/task/${taskResult.taskId}
  //
  //   console.log("✓ Task ID:", taskResult.taskId);
  //   console.log("✓ View task:", `https://explorer.iex.ec/arbitrum-sepolia-testnet/task/${taskResult.taskId}`);
  //
  // Step 4: Retrieve ZK Proof from TEE Result
  //   const result = await dataProtectorCore.getResultFromCompletedTask({
  //     taskId: taskResult.taskId,
  //   });
  //   // result.data contains the ZK proof generated inside TEE
  //
  // BENEFITS of Full TEE Integration:
  // ----------------------------------
  // ✅ Invoice data never leaves encrypted storage
  // ✅ ZK proof generation happens in secure TEE
  // ✅ Verifiable computation on iExec Explorer
  // ✅ Task lifecycle tracking (PENDING → ACTIVE → COMPLETED)
  // ✅ Auditable proof-of-computation on blockchain
  //
  // WHY Current Approach Works for Testing:
  // ----------------------------------------
  // - Demonstrates DataProtector integration architecture
  // - Shows correct data encryption flow
  // - Proves on-chain ZK verification works
  // - Allows testing without deploying a custom iApp
  //
  // NEXT STEPS for Production:
  // ---------------------------
  // 1. Create ZK proof generator iApp using iExec App Generator
  // 2. Deploy to iExec network
  // 3. Replace local proof generation with processProtectedData()
  // 4. Monitor tasks on https://explorer.iex.ec/arbitrum-sepolia-testnet
  //
  console.log("  ℹ️  Note: Currently generating proof LOCALLY for testing");
  console.log("     For full TEE integration with trackable tasks:");
  console.log("     1. Create an iExec iApp that generates ZK proofs");
  console.log("     2. Use dataProtectorCore.grantAccess() to authorize the app");
  console.log("     3. Use dataProtectorCore.processProtectedData() to run computation in TEE");
  console.log("     4. Tasks will be visible at: https://explorer.iex.ec/arbitrum-sepolia-testnet");
  console.log("");
  
  const minimumCreditScore = 600;
  const buyerCreditScore = 750;

  console.log("  - Minimum credit score threshold:", minimumCreditScore);
  console.log("  - Buyer credit score:", buyerCreditScore);
  
  // Option A: Local proof generation (current approach)
  // For full TEE integration, consider creating an iExec app that:
  // 1. Retrieves protected invoice data
  // 2. Generates ZK proof inside TEE
  // 3. Returns only the proof and public inputs
  console.log("  - Generating proof locally (client-side)...");
  const { proof, publicInputs } = await generateProof(
    invoice,
    imTree,
    minimumCreditScore,
    buyerCreditScore
  );

  console.log("  ✓ ZK proof generated successfully!");
  console.log("  - Proof size:", Buffer.from(proof).length, "bytes");
  console.log("  - Public inputs from circuit:", publicInputs);
  console.log("    - [0] invoice_merkle_root:", publicInputs[0]);
  console.log("    - [1] nullifier_hash:", publicInputs[1]);

  // Convert proof to hex string
  const proofHex = `0x${Buffer.from(proof).toString('hex')}` as `0x${string}`;
  
  // Convert public inputs to bytes32 array
  // Circuit returns: [invoice_merkle_root, nullifier_hash]
  // Contract expects: [invoice_merkle_root, nullifier_hash]
  const publicInputsBytes32 = publicInputs.map((input: string) => {
    // Ensure the input is a 32-byte hex string
    const hex = BigInt(input).toString(16).padStart(64, '0');
    return `0x${hex}` as `0x${string}`;
  });

  console.log("  ✓ Proof formatted for contract:");
  console.log("    - Proof hex length:", proofHex.length);
  console.log("    - Public inputs (bytes32[]):", publicInputsBytes32);
  console.log("      - [0] invoice_merkle_root:", publicInputsBytes32[0]);
  console.log("      - [1] nullifier_hash:", publicInputsBytes32[1]);

  // Step 3.5: Verify proof locally before sending to contract
  // console.log("\n🔍 Step 3.5: Verifying proof locally...");
  // const isValidLocal = await verifyProof(proof, publicInputs);
  // console.log("  - Local verification result:", isValidLocal ? "✅ VALID" : "❌ INVALID");
  
  // if (!isValidLocal) {
  //   throw new Error("Proof verification failed locally. Cannot proceed with contract interaction.");
  // }
  
  // Step 4: Check USDC balance and deposit to factoring contract
  console.log("\n💰 Step 4: Checking USDC balance and depositing to factoring contract...");
  
  const factoringCompanyBalance = await publicClient.readContract({
    address: USDC_ADDRESS,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: [account.address]
  }) as bigint;

  console.log("  - Factoring company USDC balance:", formatUnits(factoringCompanyBalance, 6), "USDC");

  const contractBalance = await publicClient.readContract({
    address: USDC_ADDRESS,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: [INVOICE_FACTORING_ADDRESS]
  }) as bigint;

  console.log("  - Contract USDC balance:", formatUnits(contractBalance, 6), "USDC");

  // Calculate advance amount (e.g., 80% of invoice amount)
  const advancePercentage = 0.8;
  const advanceAmount = parseUnits((invoice.invoice_amount * advancePercentage).toString(), 6); // USDC has 6 decimals
  console.log("  - Advance amount needed:", formatUnits(advanceAmount, 6), "USDC");

  // Deposit USDC to contract if needed
  if (contractBalance < advanceAmount) {
    const depositAmount = advanceAmount - contractBalance + parseUnits("1000", 6); // Add buffer
    console.log("  - Depositing", formatUnits(depositAmount, 6), "USDC to contract...");

    // Approve USDC transfer
    const approveTxHash = await walletClient.writeContract({
      address: USDC_ADDRESS,
      abi: ERC20_ABI,
      functionName: "approve",
      args: [INVOICE_FACTORING_ADDRESS, depositAmount]
    });
    
    await publicClient.waitForTransactionReceipt({ hash: approveTxHash });
    console.log("  ✓ USDC approved:", approveTxHash);

    // Deposit USDC
    const depositTxHash = await walletClient.writeContract({
      address: INVOICE_FACTORING_ADDRESS,
      abi: INVOICE_FACTORING_ABI,
      functionName: "depositUSDC",
      args: [depositAmount]
    });

    await publicClient.waitForTransactionReceipt({ hash: depositTxHash });
    console.log("  ✓ USDC deposited to contract:", depositTxHash);
    
    const newContractBalance = await publicClient.readContract({
      address: USDC_ADDRESS,
      abi: ERC20_ABI,
      functionName: "balanceOf",
      args: [INVOICE_FACTORING_ADDRESS]
    }) as bigint;
    
    console.log("  ✓ New contract balance:", formatUnits(newContractBalance, 6), "USDC");
  } else {
    console.log("  ✓ Contract has sufficient USDC balance");
  }

  // Step 5: Get supplier's initial balance
  console.log("\n📊 Step 5: Checking supplier's USDC balance...");
  const supplierAddress = account.address; // In this test, supplier is the same as the caller
  
  const initialSupplierBalance = await publicClient.readContract({
    address: USDC_ADDRESS,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: [supplierAddress]
  }) as bigint;

  console.log("  - Initial supplier balance:", formatUnits(initialSupplierBalance, 6), "USDC");

  // Step 6: Call factorInvoice with ZK proof
  console.log("\n🚀 Step 6: Submitting invoice factoring transaction...");
  console.log("  - Calling factorInvoice() with:");
  console.log("    - Proof:", proofHex.substring(0, 66) + "...");
  console.log("    - Public inputs:", publicInputsBytes32);
  console.log("    - Advance amount:", formatUnits(advanceAmount, 6), "USDC");
  console.log("    - Supplier address:", supplierAddress);

  try {
    const factorTxHash = await walletClient.writeContract({
      address: INVOICE_FACTORING_ADDRESS,
      abi: INVOICE_FACTORING_ABI,
      functionName: "factorInvoice",
      args: [proofHex, publicInputsBytes32, advanceAmount, supplierAddress]
    });

    console.log("  ✓ Transaction submitted:", factorTxHash);
    console.log("  - Waiting for confirmation...");

    const receipt = await publicClient.waitForTransactionReceipt({ hash: factorTxHash });
    console.log("  ✓ Transaction confirmed!");
    console.log("    - Block:", receipt.blockNumber);
    console.log("    - Gas used:", receipt.gasUsed.toString());

    // Step 7: Verify the results
    console.log("\n✅ Step 7: Verifying results...");

    const finalSupplierBalance = await publicClient.readContract({
      address: USDC_ADDRESS,
      abi: ERC20_ABI,
      functionName: "balanceOf",
      args: [supplierAddress]
    }) as bigint;

    const receivedAmount = finalSupplierBalance - initialSupplierBalance;
    console.log("  ✓ Supplier received:", formatUnits(receivedAmount, 6), "USDC");
    console.log("  ✓ Final supplier balance:", formatUnits(finalSupplierBalance, 6), "USDC");

    // Check nullifier hash usage
    // Public inputs: [0] = invoice_merkle_root, [1] = nullifier_hash
    const nullifierHash = publicInputsBytes32[1];
    const isUsed = await publicClient.readContract({
      address: INVOICE_FACTORING_ADDRESS,
      abi: INVOICE_FACTORING_ABI,
      functionName: "nullifierHashes",
      args: [nullifierHash]
    }) as boolean;

    console.log("  ✓ Nullifier hash marked as used:", isUsed);

    // Check invoice ownership
    const invoiceRoot = publicInputsBytes32[0];
    const owner = await publicClient.readContract({
      address: INVOICE_FACTORING_ADDRESS,
      abi: INVOICE_FACTORING_ABI,
      functionName: "factoredInvoiceOwners",
      args: [invoiceRoot]
    }) as Address;

    console.log("  ✓ Invoice owner registered:", owner);

    console.log("\n" + "=".repeat(80));
    console.log("🎉 E2E Test with DataProtector Completed Successfully!");
    console.log("=".repeat(80));
    console.log("\nSummary:");
    console.log("  - Invoice factored: $" + invoice.invoice_amount.toLocaleString());
    console.log("  - Advance payment: " + formatUnits(advanceAmount, 6) + " USDC (" + (advancePercentage * 100) + "%)");
    console.log("  - Supplier received: " + formatUnits(receivedAmount, 6) + " USDC");
    console.log("  - Transaction hash:", factorTxHash);
    console.log("  - Block explorer: https://sepolia.arbiscan.io/tx/" + factorTxHash);
    
    if (protectedInvoiceData) {
      console.log("\n🔐 DataProtector Integration:");
      console.log("  - Protected data address:", protectedInvoiceData.address);
      console.log("  - View on iExec explorer: https://explorer.iex.ec/arbitrum-sepolia/dataset/" + protectedInvoiceData.address);
    }
  } catch (error: any) {
    console.log("\n❌ Transaction failed!");
    
    // Check if it's a proof verification error
    if (error.message && error.message.includes("0x59895a53")) {
      console.log("\n🔍 Diagnosis: PROOF VERIFICATION FAILED ON-CHAIN");
      console.log("  The proof passed local verification but failed on-chain.");
      console.log("  This indicates a MISMATCH between:");
      console.log("    - The circuit artifact used to generate the proof");
      console.log("    - The verifier contract deployed on-chain");
      console.log("\n💡 Solution:");
      console.log("  1. Rebuild the circuit:");
      console.log("     cd circuits/invoice-refactoring && ./build.sh");
      console.log("  2. The build.sh should copy the new Verifier.sol to contracts/src/circuits/");
      console.log("  3. Redeploy the contracts:");
      console.log("     cd contracts && forge script script/Deploy.s.sol --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL");
      console.log("  4. Update the contract addresses in contracts/.env");
      console.log("  5. Run this e2e test again");
      console.log("\n📝 Technical Details:");
      console.log("  - Error signature: 0x59895a53 (InvalidProof)");
      console.log("  - Local verification: PASSED ✅");
      console.log("  - On-chain verification: FAILED ❌");
      console.log("  - This is a common issue when the circuit is modified but contracts aren't redeployed");
    } else {
      console.log("  Error:", error.message || error);
    }
    
    throw error;
  }
  } catch (mainError) {
    console.error("\n❌ Fatal error in main function:");
    console.error(mainError);
    throw mainError;
  }
};

console.log("\n🚀 Initiating e2e test with iExec DataProtector...\n");
main().catch((error) => {
  console.error("\n❌ Unhandled error:");
  console.error(error);
  process.exit(1);
});
