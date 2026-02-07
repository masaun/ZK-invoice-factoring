import { getIncrementalMerkleTree } from "../lib/zk-utils/incremental-merkle-tree/index.ts";
import { generateProof, generateRandomInt, createInvoiceCommitment, type Invoice } from "../lib/zk-prover/zk-prover.ts";

/**
 * @notice - Unit script to generate a ZK Invoice Refactoring Proof for the ZK invoice refactoring circuit (main.nr)
 */
const main = async () => {
  // Create a test invoice
  const invoice: Invoice = {
    invoice_id: 12345,
    invoice_supplier_id: 67890,
    invoice_buyer_id: 11111,
    invoice_amount: 50000,  // $50,000
    invoice_due_date: Math.floor(Date.now() / 1000) + 2592000, // 30 days from now
    invoice_acceptance_timestamp: Math.floor(Date.now() / 1000), // Current timestamp
    secret: generateRandomInt()
  };
  
  // Create invoice commitment
  const invoiceCommitment = createInvoiceCommitment(invoice);
  console.log("Invoice commitment:", invoiceCommitment.toString(16));
  
  // Create tree with the invoice commitment
  const { imTree } = await getIncrementalMerkleTree([invoiceCommitment]);
  console.log("Merkle root:", imTree.root.toString(16));

  // Generate proof with credit score verification
  const minimumCreditScore = 600;
  const buyerCreditScore = 750;
  
  console.log("\nGenerating ZK proof for invoice refactoring...");
  const { proof, publicInputs } = await generateProof(
    invoice,
    imTree,
    minimumCreditScore,
    buyerCreditScore
  );

  console.log("\n✅ Proof generated successfully!");
  console.log("Public inputs:", publicInputs);
  console.log("\nProof length:", proof.length, "bytes");
};

main().catch(console.error);
