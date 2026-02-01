use binary_merkle_root::binary_merkle_root;
use poseidon::poseidon::bn254::{hash_1, hash_2, hash_3};

// returns the new state commitment after withdrawal, if 0 means whole value of the note is consumed
fn main(
    deposited_balance: Field,       // @dev - "deposited_balance": Current deposited-balance of user in the pool
    // --- Current nullifier and secret ---
    secret: Field,      // @dev - Salt to prevent pre-image attacks on commitment
    nullifier: Field,
    // --- New nullifier & secreat ---
    new_secret: Field,  // @dev - Salt to prevent pre-image attacks on commitment
    new_nullifier: Field,

    withdraw_amount: pub Field,  // @dev - Amount to be withdrawn from the pool

    // --- Merkle proof parameters ---
    merkle_proof_length: u32,
    merkle_proof_indices: [u1; 16],
    merkle_proof_siblings: [Field; 16],
    merkle_root: pub Field,
) -> pub [Field; 2] { // @dev - Return: [nullifier_hash, new_commitment or 0]
    // check balance is sufficient
    assert(
        (withdraw_amount == deposited_balance) | (withdraw_amount.lt(deposited_balance)),
        "withdraw amount exceeds balance",
    );

    let commitment = hash_3([deposited_balance, secret, nullifier]);
    // Calculate Merkle root.
    let _merkle_root = binary_merkle_root(
        hash_2,
        commitment,
        merkle_proof_length,
        merkle_proof_indices,
        merkle_proof_siblings,
    );

    assert(merkle_root == _merkle_root, "merkle roots don't match");

    // @dev - Calculate new deposited-balance of user in the pool - after withdrawal
    // @dev - "new_balance": New deposited-balance of user in the pool
    // @dev - "deposited_balance": Current deposited-balance of user in the pool
    let new_balance = deposited_balance - withdraw_amount;
    
    // @dev - "nullifier_hash": Hash of the "nullifier" to prevent double-spending
    let nullifier_hash = hash_1([nullifier]);

    if new_balance == 0 { // @dev - "new_balance == 0": New deposited-balance of user in the pool is equal to be "zero"
        [nullifier_hash, 0]
    } else {
        // return new state commitment
        [nullifier_hash, hash_3([new_balance, new_secret, new_nullifier])]
    }
}

#[test]
fn test_main() {
    // Uncomment to make test fail
    // main(1, 1);
}
