import { getTreeAndStorage } from "../lib";

const main = async () => {
  const { storage, tree } = await getTreeAndStorage();
  const note = await storage.getNote();
  
  if (!note) {
    throw new Error("Note not found");
  }

  const noteCommitmentIndex = tree.indexOf(note.commitment);
  const merkleProof = tree.createProof(noteCommitmentIndex);

  console.log("Note commitment index:", noteCommitmentIndex);
  console.log("Merkle proof siblings length:", merkleProof.siblings.length);
  console.log("Merkle proof pathIndices:", merkleProof.pathIndices);
  console.log("Merkle proof pathIndices type:", typeof merkleProof.pathIndices[0]);
  console.log("Tree root:", tree.root.toString());
  
  // Test the inputs format
  const inputs = {
    value: note.value,
    secret: note.secret,
    nullifier: note.nullifier,
    new_secret: 123,
    new_nullifier: 456,
    withdrawAmount: 10,
    merkle_proof_length: merkleProof.siblings.length,
    merkle_proof_indices: merkleProof.pathIndices,
    merkle_proof_siblings: merkleProof.siblings.map(v => v.toString()),
    merkle_root: tree.root.toString(),
  };

  console.log("\nInputs:", JSON.stringify(inputs, null, 2));
};

main();
