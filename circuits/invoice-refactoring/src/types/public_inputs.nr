// @notice - The PublicInputs struct, which store the public inputs for the ZK circuit
// @dev - "buyer_domain_hash": Hash of the buyer's domain (xxx@company-domain.com)
// @dev - "credit_threshold": Minimum credit score required for invoice approval - To measure whether a buyer has ability to pay the invoice
pub struct PublicInputs {
    invoice_commitment: Field,
    buyer_pubkey: [Field; 2],
    buyer_domain_hash: Field,
    minimum_threshold_of_credit_score: Field,
    nullifier: Field
}