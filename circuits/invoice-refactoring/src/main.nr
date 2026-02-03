mod tests;
mod libs;
mod types;

use binary_merkle_root::binary_merkle_root;

use libs::poseidon::{
    poseidon_hash_1, 
    poseidon_hash_2, 
    poseidon_hash_3, 
    poseidon_hash_4,
    poseidon_hash_5,
    poseidon_hash_6
};
//use std::hash::pedersen_hash;

//use std::schnorr::schnorr_verify;

// @dev -  Imports the Structs
use types::{
    //invoice::Invoice,
    public_inputs::PublicInputs
};


// @dev - The Invoice struct, which store the invoice details
// @dev - "invoice_id": a unique identifier for the invoice, which is retrieved from the API of "Invoicing service" or "ERP systems" via zkTLS protocol.
struct Invoice {
    invoice_id: Field,
    invoice_amount: Field,
    invoice_due_date: Field,
    invoice_acceptance_timestamp: Field,
    invoice_buyer_id: Field,
    invoice_buyer_signature: [Field; 2]
}

// @dev - The BuyerSolvency struct, which store the buyer's solvency details
struct BuyerSolvency {
    buyer_credit_score: Field
}

// @dev - The MerkleProofParameters struct, which store the merkle proof parameter of invoice commitment merkle proof in the invoice commitments merkle tree.
struct MerkleProofParameters {
    merkle_proof_length: u32,
    merkle_proof_indices: [u1; 16],
    merkle_proof_siblings: [Field; 16]
}

// @dev - The SanctionsCheck struct, which store the sanctions check details
struct SanctionsCheck {
    jurisdiction_code: Field,
    allowed_jurisdiction_root: Field,
    jurisdiction_merkle_proof: [Field; 32],
}

// @dev - The PrivateInputs struct, which store the private inputs for the ZK circuit
struct PrivateInputs {
    invoice: Invoice,
    buyer_solvency: BuyerSolvency,
    merkle_proof_parameters: MerkleProofParameters,
    sanctions_check: SanctionsCheck,
    secret: Field      // @dev - Salt to prevent pre-image attacks on commitment
}

/**
 * @notice - ZK circuit in Noir for the Invoice Refactoring
 * @dev - This ZK proof generation request is supposed to be initiated from (or be claimed by) the Supplier side
 * @dev - We assume that a Supplier already received an invoice acceptance (from a Buyer) via Supplier's ERP system or Email (sent from a Buyer's ERP system)
 */
fn main(
    public_inputs: PublicInputs,
    private_inputs: PrivateInputs
) -> pub (Field, Field) {
    // ----- PUBLIC INPUTS -----  
    let invoice_commitment = public_inputs.invoice_commitment;
    let buyer_pubkey = public_inputs.buyer_pubkey;
    let buyer_domain_hash = public_inputs.buyer_domain_hash;
    let nullifier = public_inputs.nullifier;
    let minimum_threshold_of_credit_score = public_inputs.minimum_threshold_of_credit_score;

    // ----- PRIVATE INPUTS (Invoice) -----
    let invoice_id = private_inputs.invoice.invoice_id;
    let invoice_amount = private_inputs.invoice.invoice_amount;
    let invoice_due_date = private_inputs.invoice.invoice_due_date;
    let invoice_acceptance_timestamp = private_inputs.invoice.invoice_acceptance_timestamp;
    let invoice_buyer_id = private_inputs.invoice.invoice_buyer_id;
    let invoice_buyer_signature = private_inputs.invoice.invoice_buyer_signature; // @dev - This Buyer's signature is used for signing the acceptance of the invoice on buyer side

    // ----- PRIVATE INPUTS (Buyer Solvency) -----
    let buyer_credit_score = private_inputs.buyer_solvency.buyer_credit_score;

    // --- Merkle proof parameters of invoices ---
    let merkle_proof_length = private_inputs.merkle_proof_parameters.merkle_proof_length;
    let merkle_proof_indices = private_inputs.merkle_proof_parameters.merkle_proof_indices;
    let merkle_proof_siblings = private_inputs.merkle_proof_parameters.merkle_proof_siblings;
    let merkle_root = public_inputs.merkle_root;

    // ----- PRIVATE INPUTS (Sanctions Check) -----
    let jurisdiction_code = private_inputs.sanctions_check.jurisdiction_code;
    let allowed_jurisdiction_root = private_inputs.sanctions_check.allowed_jurisdiction_root;
    let jurisdiction_merkle_proof = private_inputs.sanctions_check.jurisdiction_merkle_proof;

    // ----- PRIVATE INPUTS (Others) -----
    let secret = private_inputs.secret;


    // 1. Constraint: new invoice commitment (to be refactored)
    let computed_invoice_commitment = poseidon_hash_6(
        [
            invoice_id,
            invoice_amount,
            invoice_due_date, // maturity_date
            invoice_buyer_id,
            nullifier,
            secret
        ]
    );
    assert(invoice_commitment == computed_invoice_commitment, "invalid invoice commitment");

    // 2. Add a new invoice commitment to the invoice commitments Merkele Tree (= Refactored-Invoice Commitments Merkle Tree)
    // 2. Constraint: a Merkle Root of the invoice commitments Merkele Tree (= Refactored-Invoice Commitments Merkle Tree)
    let computed_merkle_root = binary_merkle_root(
        poseidon_hash_2,
        invoice_commitment,
        merkle_proof_length,
        merkle_proof_indices,
        merkle_proof_siblings,
    );
    assert(merkle_root == computed_merkle_root, "merkle roots don't match");

    // 3. Constraint: Check a Buyer's acceptance of the invoice (on Supplier's ERP system or Supplier's Email by checking Email domain and Email subject/content using zkEmail)
    let computed_invoice_buyer_signature: [Field; 2] = [12345, 12345]; // TOOD
    assert(computed_invoice_buyer_signature == invoice_buyer_signature, "invalid invoice buyer signature");

    // 4. Constraint: Acceptance freshness
    assert(invoice_acceptance_timestamp as u32 < invoice_due_date as u32);

    // @dev - However, this step 4 should be done off-chain via zkTLS protocol
    // @dev - Thus, this step 4 should not be included in this Noir ZK circuit
    // 
    // 5. Verify whether the Supplier's ERP system received the invoice acceptance from the Buyer's ERP system
    // verify_invoice_acceptance_on_supplier_erp(
    //     zk_tls_proof_public_inputs,
    //     buyer_domain_hash,
    //     invoice_buyer_signature
    // );

    // 6. Authentic Buyer Email about acceptance of the invoice
    // assert(verify_zk_email(
    //     zk_email_transcript_hash,
    //     buyer_email_domain_hash,
    //     expected_email_subject_hash,
    //     expected_email_body_hash
    // ));

    // 7. Sanctions check (OFAC check)
    // assert(verify_merkle_proof(
    //     jurisdiction_code,
    //     allowed_jurisdiction_root,
    //     jurisdiction_merkle_proof
    // ));


    // @dev - This could be checked on-chain. Thus, this step 6 may not be necessary in this Noir ZK circuit
    // @dev - On the other hand, the "Merkle Inclusion" check can be done here in this Noir ZK circuit
    //
    // 8. Prevent double factoring
    // assert(is_nullifier_unused(nullifier));

    // @dev - Compute a nullifier hash to prevent double factoring
    let nullifier_hash = poseidon_hash_2([nullifier, secret]);

    // @dev - Return the nullifier hash and "new" invoice commitment 
    (nullifier_hash, invoice_commitment)
}



/**
 * @notice - Merkle inclusion verification function using Merkle Root and Merkle Tree
 */
fn is_nullifier_unused(nullifier: Field) -> bool {
    let nullifier_hash = poseidon_hash_1([nullifier]);

    // [TODO]: Check the Merkle inclusion verification function using Merkle Root and Merkle Tree
    let is_merkle_included = true;
    is_merkle_included
}


/**
 * @notice - Verify the Buyer's acceptance of the invoice on Supplier's ERP system via zkTLS protocol
 * @dev - This function is a placeholder for the actual implementation of zkTLS verification
 */
// fn verify_invoice_acceptance_on_supplier_erp(
//     zk_tls_proof_public_inputs: Field,
//     buyer_domain_hash: Field,
//     invoice_buyer_signature: [Field; 2]
// ) {
//     // TODO: Implement the verification logic using signature verification
// }