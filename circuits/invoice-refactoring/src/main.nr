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
    invoice_commitment: Field,
    invoice_id: Field,
    invoice_supplier_id: Field,
    invoice_buyer_id: Field,
    invoice_amount: Field,
    invoice_due_date: Field,
    invoice_acceptance_timestamp: Field,
    //invoice_buyer_domain_hash: Field,
    //invoice_buyer_pubkey: [Field; 2],
    //invoice_buyer_signature: [Field; 2]
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
    let nullifier = public_inputs.nullifier;
    let minimum_threshold_of_credit_score = public_inputs.minimum_threshold_of_credit_score;

    // ----- PRIVATE INPUTS (Invoice) -----
    let invoice_commitment = private_inputs.invoice.invoice_commitment;
    let invoice_id = private_inputs.invoice.invoice_id;
    let invoice_supplier_id = private_inputs.invoice.invoice_supplier_id;
    let invoice_buyer_id = private_inputs.invoice.invoice_buyer_id;
    let invoice_amount = private_inputs.invoice.invoice_amount;
    let invoice_due_date = private_inputs.invoice.invoice_due_date;
    let invoice_acceptance_timestamp = private_inputs.invoice.invoice_acceptance_timestamp;

    // ----- PRIVATE INPUTS (Invoice - For a Buyer's RSA signature verification) -----
    //let invoice_buyer_domain_hash = private_inputs.invoice.invoice_buyer_domain_hash;
    //let invoice_buyer_signature = private_inputs.invoice.invoice_buyer_signature; // @dev - This Buyer's signature is used for signing the acceptance of the invoice on buyer side
    //let invoice_buyer_pubkey = private_inputs.invoice.invoice_buyer_pubkey;

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
            invoice_supplier_id,
            invoice_buyer_id,
            invoice_amount,
            invoice_due_date, // maturity_date
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

    // 3. Constraint: Acceptance freshness
    assert(invoice_acceptance_timestamp as u32 < invoice_due_date as u32);

    // 4. Constraint: Check the Buyer's solvency (i.e., credit score)
    assert(buyer_credit_score as u32 >= minimum_threshold_of_credit_score as u32, "insufficient credit score");

    // 5. Authenticate a Email about acceptance of the invoice from a Buyer's ERP system using zkEmail 
    // assert(verify_zk_email(
    //     zk_email_transcript_hash,
    //     buyer_email_domain_hash,
    //     expected_email_subject_hash,
    //     expected_email_body_hash
    // ));

    // 6. Constraint: Verify whether the Buyer signature on acceptance of the invoice is valid
    // [TODO]: RSA Key verification using Noir RSA library
    // [TODO]: DKIM signature verification using zkemail.nr library may be more realistic approach than RSA signature verification - Because retrieving Buyer's public key of Buyer's ERP from Buyer's ERP system may be pretty much challenging.
    //let computed_invoice_buyer_signature: [Field; 2] = [12345, 12345]; // TODO: Implement the actual signature verification
    //assert(invoice_buyer_signature == computed_invoice_buyer_signature, "invalid invoice buyer signature");

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

    // @dev - Check the nullifier computation
    let computed_nullifier = poseidon_hash_3([invoice_commitment, merkle_root, secret]);
    assert(nullifier == computed_nullifier, "invalid nullifier");

    // @dev - Compute a nullifier hash, which is stored on-chain, to prevent double factoring
    let nullifier_hash = poseidon_hash_1([nullifier]);

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