import { Noir } from "@noir-lang/noir_js";
import { generateProof, getTreeAndStorage, verifyProof } from "../lib";
import { Barretenberg } from "@aztec/bb.js";

const main = async () => {
  console.log("Step 1: Getting tree and storage...");
  const { storage, tree } = await getTreeAndStorage();
  console.log("✓ Tree and storage loaded");

  console.log("\nStep 2: Getting note...");
  const note = await storage.getNote();
  if (!note) {
    throw new Error("Note not found");
  }
  console.log("✓ Note found:", note);

  console.log("\nStep 3: Generating proof...");
  try {
    const { proof, newNote } = await generateProof(note, tree, 10);
    console.log("✓ Proof generated successfully");
    console.log("Public inputs:", proof.publicInputs);
  } catch (error) {
    console.error("✗ Error generating proof:", error);
    throw error;
  }
};

main();
