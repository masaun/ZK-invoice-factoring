import { IMT } from "@zk-kit/imt";
import { poseidon_hash_1, poseidon_hash_2, poseidon_hash_3, poseidon_hash_6 } from "../zk-utils/poseidon/poseidon.ts";
import { TREE_DEPTH } from "../zk-utils/constants.ts";
import { getIndexOfLeaf, createIncrementalMerkleProof, getIncrementalMerkleRoot } from "../zk-utils/incremental-merkle-tree/incremental-merkle-tree.ts";
import { Noir } from "@noir-lang/noir_js";
import { Barretenberg, UltraHonkBackend, type ProofData } from "@aztec/bb.js";
import circuitArtifact from "../../../circuit-artifacts/invoice-refactoring/invoice-refactoring-0.0.1/invoice-refactoring.json";

export * from "../zk-utils/constants.ts";

// Types for Invoice Refactoring
export interface Invoice {
  invoice_id: number;
  invoice_supplier_id: number;
  invoice_buyer_id: number;
  invoice_amount: number;
  invoice_due_date: number;
  invoice_acceptance_timestamp: number;
  secret: number;
}

export interface InvoiceCommitment {
  commitment: bigint;
  invoice: Invoice;
}

export const generateRandomInt = () => {
  return Math.floor(Math.random() * 1000000);
};

export const generateRandomField = () => {
  return BigInt(Math.floor(Math.random() * Number.MAX_SAFE_INTEGER));
};

/**
 * Creates an invoice commitment hash
 */
export const createInvoiceCommitment = (invoice: Invoice): bigint => {
  return poseidon_hash_6([
    invoice.invoice_id,
    invoice.invoice_supplier_id,
    invoice.invoice_buyer_id,
    invoice.invoice_amount,
    invoice.invoice_due_date,
    invoice.secret
  ]);
};

/**
 * Generates a ZK proof for invoice refactoring
 * @param invoice - The invoice to refactor
 * @param tree - The Merkle tree containing invoice commitments
 * @param minimumCreditScore - Minimum credit score threshold (default: 600)
 * @param buyerCreditScore - The buyer's credit score
 */
export const generateProof = async (
  invoice: Invoice,
  tree: IMT,
  minimumCreditScore: number = 600,
  buyerCreditScore: number = 700
): Promise<{ proof: ProofData; publicInputs: any }> => {
  const noir = new Noir(circuitArtifact as any);
  const api = await Barretenberg.new();
  const backend = new UltraHonkBackend(circuitArtifact.bytecode, api);

  // Create invoice commitment
  const invoiceCommitment = createInvoiceCommitment(invoice);
  
  // Get merkle proof
  const invoiceCommitmentIndex = await getIndexOfLeaf(tree, invoiceCommitment);
  const merkleProof = await createIncrementalMerkleProof(tree, invoiceCommitmentIndex);

  // Create nullifier to prevent double factoring
  const merkleRoot = await getIncrementalMerkleRoot(tree);
  const nullifier = poseidon_hash_3([invoiceCommitment, merkleRoot, invoice.secret]);
  const nullifierHash = poseidon_hash_1([nullifier]);

  // Prepare circuit inputs
  const circuitInputs = {
    public_inputs: {
      invoice_merkle_root: merkleRoot.toString(),
      nullifier_hash: nullifierHash.toString()
    },
    private_inputs: {
      invoice: {
        invoice_commitment: invoiceCommitment.toString(),
        invoice_id: invoice.invoice_id.toString(),
        invoice_supplier_id: invoice.invoice_supplier_id.toString(),
        invoice_buyer_id: invoice.invoice_buyer_id.toString(),
        invoice_amount: invoice.invoice_amount.toString(),
        invoice_due_date: invoice.invoice_due_date.toString(),
        invoice_acceptance_timestamp: invoice.invoice_acceptance_timestamp.toString()
      },
      buyer_solvency: {
        buyer_credit_score: buyerCreditScore.toString(),
        minimum_threshold_of_credit_score: minimumCreditScore.toString()
      },
      merkle_proof_parameters: {
        invoice_merkle_proof_length: merkleProof.siblings.length,
        invoice_merkle_proof_indices: merkleProof.pathIndices,
        invoice_merkle_proof_siblings: merkleProof.siblings.map(v => v.toString())
      },
      sanctions_check: {
        jurisdiction_code: "0",
        allowed_jurisdiction_root: "0",
        jurisdiction_merkle_proof: Array(32).fill("0")
      },
      nullifier: nullifier.toString(),
      secret: invoice.secret.toString()
    }
  };

  const { witness } = await noir.execute(circuitInputs);
  const { proof, publicInputs } = await backend.generateProof(witness);

  return {
    proof,
    publicInputs
  };
};

export const verifyProof = async (proof: ProofData, publicInputs: any) => {
  const api = await Barretenberg.new();
  const backend = new UltraHonkBackend(circuitArtifact.bytecode, api);

  return await backend.verifyProof({ proof, publicInputs });
};
