import { Noir } from "@noir-lang/noir_js";
import circuit from "../../../../circuits/privacy-collateral-pool/target/privacy_collateral_pool.json";

const main = async () => {
  console.log("Creating Noir instance...");
  const noir = new Noir(circuit as any);
  console.log("✓ Noir instance created");

  // Create a simple test case
  const simpleInputs = {
    value: "100",
    secret: "123",
    nullifier: "456",
    new_secret: "789",
    new_nullifier: "321",
    withdrawAmount: "10",
    merkle_proof_length: 1,
    merkle_proof_indices: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    merkle_proof_siblings: ["0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"],
    merkle_root: "0",
  };

  console.log("\nExecuting circuit with simple inputs...");
  console.log("Inputs:", JSON.stringify(simpleInputs, null, 2));
  
  try {
    const { witness } = await noir.execute(simpleInputs);
    console.log("✓ Circuit executed successfully!");
    console.log("Witness length:", witness.length);
  } catch (error) {
    console.error("✗ Error executing circuit:", error);
    console.error("Error message:", error.message);
    console.error("Error stack:", error.stack);
  }
};

main();
