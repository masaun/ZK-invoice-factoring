// @notice - The PublicOutputs struct, which store the public outputs for the ZK circuit
pub struct PublicOutputs {
    pub invoice_merkle_root: Field,
    pub nullifier_hash: Field,  // @dev - Hash of the raw nullifier to prevent double factoring
}