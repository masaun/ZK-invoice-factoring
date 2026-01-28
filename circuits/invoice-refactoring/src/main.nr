mod tests;
use std::hash::pedersen_hash;
use std::schnorr::schnorr_verify;

// @dev - The Invoice struct, which store the invoice details
// @dev - "invoice_id": a unique identifier for the invoice, which is retrieved from the ERP system via zkTLS protocol.
pub struct Invoice {
    invoice_id: Field,
    amount: Field,
    due_date: Field,
    buyer_id: Field,
}

/**
 * @notice - ZK circuit in Noir for the Invoice Refactoring
 */
fn main(
    // PUBLIC
    invoice_commitment: pub Field,
    buyer_pubkey: pub [Field; 2],
    credit_threshold: pub Field,
    nullifier: pub Field,

    // PRIVATE
    invoice: Invoice,
    buyer_signature: [Field; 2],
    buyer_credit_score: Field,
    jurisdiction_code: Field,
    allowed_jurisdiction_root: Field,
    jurisdiction_merkle_proof: [Field; 32],
) {
    // 1. Invoice commitment
    let computed_commitment = pedersen_hash(
        [
            invoice.invoice_id,
            invoice.amount,
            invoice.due_date,
            invoice.buyer_id,
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

