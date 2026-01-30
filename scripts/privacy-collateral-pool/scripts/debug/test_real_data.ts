import { Noir } from "@noir-lang/noir_js";
import { getTreeAndStorage } from "../lib";
import { poseidon3, poseidon1 } from "poseidon-lite";
import circuit from "../../../../circuits/privacy-collateral-pool/target/privacy_collateral_pool.json";

const main = async () => {
  const { storage, tree } = await getTreeAndStorage();
  const note = await storage.getNote();

  if (!note) {
    throw new Error("Note not found");
  }

  console.log("Note:", note);
  console.log("Tree root:", tree.root.toString());
  console.log("Note commitment:", note.commitment.toString());

  const noteCommitmentIndex = tree.indexOf(note.commitment);
  console.log("Note commitment index:", noteCommitmentIndex);

  const merkleProof = tree.createProof(noteCommitmentIndex);
  console.log("Merkle proof siblings length:", merkleProof.siblings.length);

  // Verify commitment calculation
  const calculatedCommitment = poseidon3([note.value, note.secret, note.nullifier]);
  console.log("Calculated commitment:", calculatedCommitment.toString());
  console.log("Stored commitment:", note.commitment.toString());
  console.log("Commitments match:", calculatedCommitment === note.commitment);

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

  console.log("\nExecuting circuit...");
  const noir = new Noir(circuit as any);
  
  try {
    const { witness } = await noir.execute(inputs);
    console.log("✓ Circuit executed successfully!");
  } catch (error) {
    console.error("✗ Error:", error.message);
  }
};

main();
