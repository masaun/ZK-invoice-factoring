use crate::{
    main,
    Invoice, 
    BuyerSolvency, 
    MerkleProofParameters, 
    //SanctionsCheck, 
    PrivateInputs, 
    libs::poseidon::{
        poseidon_hash_1, 
        poseidon_hash_2, 
        poseidon_hash_3, 
        poseidon_hash_4,
        poseidon_hash_5,
        poseidon_hash_6
    },

    // @dev -  Imports the Structs
    types::{
        //invoice::Invoice,
        public_inputs::PublicInputs
    }
};

use binary_merkle_root::binary_merkle_root;



// // @dev - The Invoice struct, which store the invoice details
// // @dev - "invoice_id": a unique identifier for the invoice, which is retrieved from the API of "Invoicing service" or "ERP systems" via zkTLS protocol.
// struct Invoice {
//     invoice_commitment: Field,
//     invoice_id: Field,
//     invoice_supplier_id: Field,
//     invoice_buyer_id: Field,
//     invoice_amount: Field,
//     invoice_due_date: Field,
//     invoice_acceptance_timestamp: Field,
//     //invoice_buyer_domain_hash: Field,
//     //invoice_buyer_pubkey: [Field; 2],
//     //invoice_buyer_signature: [Field; 2]
// }

// // @dev - The BuyerSolvency struct, which store the buyer's solvency details
// struct BuyerSolvency {
//     buyer_credit_score: Field
// }

// // @dev - The MerkleProofParameters struct, which store the merkle proof parameter of invoice commitment merkle proof in the invoice commitments merkle tree.
// struct MerkleProofParameters {
//     merkle_proof_length: u32,
//     merkle_proof_indices: [u1; 16],
//     merkle_proof_siblings: [Field; 16]
// }

// // @dev - The SanctionsCheck struct, which store the sanctions check details
// struct SanctionsCheck {
//     jurisdiction_code: Field,
//     allowed_jurisdiction_root: Field,
//     jurisdiction_merkle_proof: [Field; 32],
// }

// // @dev - The PrivateInputs struct, which store the private inputs for the ZK circuit
// struct PrivateInputs {
//     invoice: Invoice,
//     buyer_solvency: BuyerSolvency,
//     merkle_proof_parameters: MerkleProofParameters,
//     sanctions_check: SanctionsCheck,
//     secret: Field      // @dev - Salt to prevent pre-image attacks on commitment
// }



/**
 * @dev - Test for the main function to be successful.
 */
#[test]
fn test_main_success() {
    // ----- PUBLIC INPUTS -----  
    let nullifier = 0x1c453851a1197c5c17418a6fc27c15e1c857c39abd37bf4b4fbf2396d50111ad;
    let minimum_threshold_of_credit_score = 700;

    // ----- PRIVATE INPUTS (Invoice) -----
    let invoice_commitment = 0x1c1d5e7bf24c9c1a4f54ec2a282509e12cdc731c450db688693a4e0fe9617786;
    let invoice_id = 1001;
    let invoice_supplier_id = 5001;
    let invoice_buyer_id = 6001;
    let invoice_amount = 50000;
    let invoice_due_date = 1735689600; // Unix timestamp: Jan 1, 2025
    let invoice_acceptance_timestamp = 1704067200; // Unix timestamp: Jan 1, 2024

    // ----- PRIVATE INPUTS (Buyer Solvency) -----
    let buyer_credit_score = 750;
    
    // ----- PRIVATE INPUTS (Merkle proof parameters of invoices) -----
    let invoice_merkle_proof_length = 4;
    let invoice_merkle_proof_indices: [u1; 16] = [0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    let invoice_merkle_proof_siblings: [Field; 16] = [
        0x111, 0x222, 0x333, 0x444,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ];
    let invoice_merkle_root = 0x13d71b7e8100ee6ccb3c0228ada8585e4f8259d7a016191f7cd65342bc517530;
    
    // ----- PRIVATE INPUTS (Sanctions Check) -----
    // let jurisdiction_code = 840; // USA country code
    // let allowed_jurisdiction_root = 0x999888777666;
    // let jurisdiction_merkle_proof: [Field; 32] = [
    //     0x101, 0x202, 0x303, 0x404,
    //     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    //     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    //     0, 0, 0, 0
    // ];

    // ----- PRIVATE INPUTS (Others) -----
    let secret = 0x987654321fedcba;

    // @dev - Construct PublicInputs and PrivateInputs struct data
    let public_inputs = PublicInputs {
        nullifier,
        minimum_threshold_of_credit_score,
        invoice_merkle_root
    };
    
    let private_inputs = PrivateInputs {
        invoice: Invoice {
            invoice_commitment,
            invoice_id,
            invoice_supplier_id,
            invoice_buyer_id,
            invoice_amount,
            invoice_due_date,
            invoice_acceptance_timestamp
        },
        buyer_solvency: BuyerSolvency {
            buyer_credit_score
        },
        merkle_proof_parameters: MerkleProofParameters {
            invoice_merkle_proof_length,
            invoice_merkle_proof_indices,
            invoice_merkle_proof_siblings
        },
        // sanctions_check: SanctionsCheck {
        //     jurisdiction_code,
        //     allowed_jurisdiction_root,
        //     jurisdiction_merkle_proof
        // },
        secret
    };

    // @dev - Call the main function
    let (invoice_merkle_root, nullifier_hash) = main(public_inputs, private_inputs);

    // @dev - Check Constraint: the invoice commitment (hash)
    let computed_invoice_commitment = poseidon_hash_6(
        [
            invoice_id,
            invoice_supplier_id,
            invoice_buyer_id,
            invoice_amount,
            invoice_due_date,
            secret
        ]
    );
    println(f"computed_invoice_commitment: {computed_invoice_commitment}");
    assert(invoice_commitment == computed_invoice_commitment, "invalid invoice_commitment");

    // @dev - Check Constraint: a Merkle Root of the invoice commitments Merkele Tree (= Refactored-Invoice Commitments Merkle Tree)
    let computed_invoice_merkle_root = binary_merkle_root(
        poseidon_hash_2,
        invoice_commitment,
        invoice_merkle_proof_length,
        invoice_merkle_proof_indices,
        invoice_merkle_proof_siblings,
    );
    println(f"computed_invoice_merkle_root: {computed_invoice_merkle_root}");
    assert(invoice_merkle_root == computed_invoice_merkle_root, "merkle roots don't match");

    // @dev - Check Constraint: the nullifier_hash computation
    let computed_nullifier = poseidon_hash_3([invoice_commitment, computed_invoice_merkle_root, secret]);
    println(f"computed_nullifier: {computed_nullifier}");
    let computed_nullifier_hash = poseidon_hash_1([nullifier]);
    assert(nullifier_hash == computed_nullifier_hash, "invalid nullifier_hash");

}