// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { InvoiceRefactoringHonkVerifier } from "./circuits/InvoiceRefactoringHonkVerifier.sol";
import { Stablecoin } from "./Stablecoin.sol";

event InvoiceFactored(
    bytes32 indexed invoiceCommitment,
    address indexed supplier,
    uint256 advanceAmount
);

/**
 * @title 
 * @notice - ZK InvoiceRefactoring Proof-triggered loan against an invoice
 */
contract InvoiceFactoring {
    InvoiceRefactoringHonkVerifier public invoiceRefactoringHonkVerifier;
    Stablecoin public stablecoin;

    mapping(bytes32 => bool) public usedNullifiers;
    mapping(bytes32 => address) public invoiceOwner;

    constructor(HonkVerifier _invoiceRefactoringHonkVerifier, Stablecoin _stablecoin) {
        invoiceRefactoringHonkVerifier = _invoiceRefactoringHonkVerifier;
        stablecoin = _stablecoin;
    }

    /**
     * @notice - Factor an invoice using a ZK proof 
     * @param zkProof 
     * @param invoiceCommitment 
     * @param nullifier 
     * @param advanceAmount 
     * @param supplier 
     */
    function factorInvoice(
        bytes calldata proof, 
        bytes32[] calldata publicInputs,
        bytes32 nullifier,
        uint256 advanceAmount,
        address supplier
    ) external {
        // 1. Verify a InvoiceRefactoringProof
        require(
            invoiceRefactoringHonkVerifier.verifyInvoiceRefactoringProof(proof, publicInputs),
            "Invalid ZK proof"
        );

        // 2. Lock invoice
        require(!usedNullifiers[nullifier], "Already factored");
        usedNullifiers[nullifier] = true;

        // 3. Record ownership
        invoiceOwner[publicInputs[0]] = msg.sender; // Factor

        // 4. Pay supplier
        stablecoin.transfer(supplier, advanceAmount);

        emit InvoiceFactored(publicInputs[0], supplier, advanceAmount);
    }
}


