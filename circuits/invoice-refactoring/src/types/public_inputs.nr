pub struct PublicInputs {
    invoice_commitment: Field,
    buyer_pubkey: [Field; 2],
    credit_threshold: Field,
    nullifier: Field
}