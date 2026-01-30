import { Noir } from "@noir-lang/noir_js";
import { UltraHonkBackend, type ProofData } from "@aztec/bb.js";
import { getTreeAndStorage } from "../lib";
import { poseidon3 } from "poseidon-lite";
import circuit from "../../../../circuits/privacy-collateral-pool/target/privacy_collateral_pool.json";

const main = async () => {
  console.log("Step 1: Loading circuit and backend...");
  const noir = new Noir(circuit as any);
  const backend = new UltraHonkBackend(circuit.bytecode);
  console.log("✓ Circuit and backend loaded");

  console.log("\nStep 2: Getting tree and storage...");
  const { storage, tree } = await getTreeAndStorage();
  const note = await storage.getNote();
  console.log("✓ Got note and tree");

  console.log("\nStep 3: Preparing inputs...");
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
  console.log("✓ Inputs prepared");

  console.log("\nStep 4: Executing circuit...");
  try {
    const { witness } = await noir.execute(inputs);
    console.log("✓ Circuit executed, witness generated");
    console.log("Witness length:", witness.length);

    console.log("\nStep 5: Generating proof...");
    try {
      const proof = await backend.generateProof(witness);
      console.log("✓ Proof generated successfully!");
      console.log("Proof publicInputs:", proof.publicInputs);
    } catch (error) {
      console.error("✗ Error generating proof:", error.message);
      console.error("Full error:", error);
      throw error;
    }
  } catch (error) {
    console.error("✗ Error executing circuit:", error.message);
    throw error;
  }
};

main();
