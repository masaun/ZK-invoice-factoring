mod tests;
mod types;

use std::hash::pedersen_hash;
use std::schnorr::schnorr_verify;

// @dev -  Imports the Structs
use types::{
    invoice::Invoice,
    public_inputs::PublicInputs
};

// @dev - The PrivateInputs struct, which store the private inputs for the ZK circuit
struct PrivateInputs {
    invoice: Invoice,
    buyer_signature: [Field; 2],
    buyer_credit_score: Field,
    jurisdiction_code: Field,
    allowed_jurisdiction_root: Field,
    jurisdiction_merkle_proof: [Field; 32],
}



/**
 * @notice - ZK circuit in Noir for the Invoice Refactoring
 */
fn main(
    public_inputs: PublicInputs,
    private_inputs: PrivateInputs,
) {
    // ----- PUBLIC INPUTS -----  
    let invoice_commitment = public_inputs.invoice_commitment;
    let buyer_pubkey = public_inputs.buyer_pubkey;
    let nullifier = public_inputs.nullifier;
    let credit_threshold = public_inputs.credit_threshold;

    // ----- PRIVATE INPUTS -----
    let invoice_id = private_inputs.invoice.invoice_id;
    let invoice_amount = private_inputs.invoice.amount;
    let invoice_due_date = private_inputs.invoice.due_date;
    let invoice_buyer_id = private_inputs.invoice.buyer_id;
    let buyer_signature = private_inputs.buyer_signature;
    let buyer_credit_score = private_inputs.buyer_credit_score;
    let jurisdiction_code = private_inputs.jurisdiction_code;
    let allowed_jurisdiction_root = private_inputs.allowed_jurisdiction_root;
    let jurisdiction_merkle_proof = private_inputs.jurisdiction_merkle_proof;



    // 1. Invoice commitment
    let computed_commitment = pedersen_hash(
        [
            invoice_id,
            invoice_amount,
            invoice_due_date,
            invoice_buyer_id,
        ]
    );
    assert(computed_commitment == invoice_commitment);

    // 2. Buyer acceptance signature
    assert(
        schnorr_verify(
            buyer_pubkey,
            invoice_commitment,
            buyer_signature
        )
    );

    // 3. Credit threshold
    assert(buyer_credit_score >= credit_threshold);

    // 4. Jurisdiction allowlist
    assert(
        merkle_verify(
            allowed_jurisdiction_root,
            jurisdiction_merkle_proof,
            jurisdiction_code
        )
    );

    // 5. Prevent double factoring (= @dev - Merkle Tree of nuillifiers may be needed + The Merkle Root of nullifiers should be stored into on-chain and passed as public input of this ZK circuit)
    assert(is_nullifier_unused(nullifier));
}

