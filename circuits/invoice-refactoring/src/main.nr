mod tests;
mod types;

use std::hash::pedersen_hash;
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
    sanctions_check: SanctionsCheck,
}

/**
 * @notice - ZK circuit in Noir for the Invoice Refactoring
 * @dev - This ZK proof generation request is supposed to be initiated from (or be claimed by) the Supplier side
 * @dev - We assume that a Supplier already received an invoice acceptance (from a Buyer) via Supplier's ERP system or Email (sent from a Buyer's ERP system)
 */
fn main(
    public_inputs: PublicInputs,
    private_inputs: PrivateInputs,
) {
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
    let invoice_buyer_signature = private_inputs.invoice.invoice_buyer_signature;

    // ----- PRIVATE INPUTS (Buyer Solvency) -----
    let buyer_credit_score = private_inputs.buyer_solvency.buyer_credit_score;

    // ----- PRIVATE INPUTS (Sanctions Check) -----
    let jurisdiction_code = private_inputs.sanctions_check.jurisdiction_code;
    let allowed_jurisdiction_root = private_inputs.sanctions_check.allowed_jurisdiction_root;
    let jurisdiction_merkle_proof = private_inputs.sanctions_check.jurisdiction_merkle_proof;


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
    // assert(
    //     schnorr_verify(
    //         buyer_pubkey,
    //         invoice_commitment,
    //         invoice_buyer_signature
    //     )
    // );

    // 3. Credit threshold
    // assert(buyer_credit_score >= minimum_threshold_of_credit_score);

    // 4. Jurisdiction allowlist
    // assert(
    //     merkle_verify(
    //         allowed_jurisdiction_root,
    //         jurisdiction_merkle_proof,
    //         jurisdiction_code
    //     )
    // );

    // 5. Prevent double factoring (= @dev - Merkle Tree of nuillifiers may be needed + The Merkle Root of nullifiers should be stored into on-chain and passed as public input of this ZK circuit)
    // assert(is_nullifier_unused(nullifier));
}

