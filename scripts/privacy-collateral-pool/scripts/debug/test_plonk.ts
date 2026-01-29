import { Noir } from "@noir-lang/noir_js";
import { BarretenbergBackend } from "@aztec/bb.js";
import { getTreeAndStorage } from "../lib";
import circuit from "../../../../circuits/privacy-collateral-pool/target/privacy_collateral_pool.json";

const main = async () => {
  console.log("Testing with BarretenbergBackend (UltraPlonk)...");
  
  const noir = new Noir(circuit as any);
  const backend = new BarretenbergBackend(circuit.bytecode);

  const { storage, tree } = await getTreeAndStorage();
  const note = await storage.getNote();

  const noteCommitmentIndex = tree.indexOf(note.commitment);
  const merkleProof = tree.createProof(noteCommitmentIndex);

  const inputs = {
    value: note.value.toString(),
    secret: note.secret.toString(),
    nullifier: note.nullifier.toString(),
    new_secret: "789",
    new_nullifier: "321",
    withdrawAmount: "10",
    merkle_proof_length: merkleProof.siblings.length,
    merkle_proof_indices: merkleProof.pathIndices,
    merkle_proof_siblings: merkleProof.siblings.map(v => v.toString()),
    merkle_root: tree.root.toString(),
  };

  console.log("Executing circuit...");
  const { witness } = await noir.execute(inputs);
  console.log("✓ Circuit executed");

  console.log("Generating proof with BarretenbergBackend...");
  try {
    const proof = await backend.generateProof(witness);
    console.log("✓ Proof generated successfully!");
    console.log("Proof:", proof);
  } catch (error) {
    console.error("✗ Error:", error.message);
  }
};

main();
