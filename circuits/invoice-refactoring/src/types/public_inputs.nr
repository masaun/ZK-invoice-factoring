// @notice - The PublicInputs struct, which store the public inputs for the ZK circuit
// @dev - "invoice_buyer_domain_hash": Hash of the buyer's domain (xxx@company.com)
// @dev - "credit_threshold": Minimum credit score required for invoice approval - To measure whether a buyer has ability to pay the invoice
// @dev - "invoice_merkle_root": The Merkle Root of the invoice commitments merkle tree
pub struct PublicInputs {
    pub minimum_threshold_of_credit_score: Field,
    pub nullifier: Field,
    pub invoice_merkle_root: Field
}