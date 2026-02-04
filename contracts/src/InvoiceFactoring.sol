// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { HonkVerifier } from "./HonkVerifier.sol";
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
    HonkVerifier public verifier;
    Stablecoin public stablecoin;

    mapping(bytes32 => bool) public usedNullifiers;
    mapping(bytes32 => address) public invoiceOwner;

    constructor(HonkVerifier _verifier, Stablecoin _stablecoin) {
        verifier = _verifier;
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
        bytes calldata zkProof,
        bytes32 invoiceCommitment,
        bytes32 nullifier,
        uint256 advanceAmount,
        address supplier
    ) external {
        // 1. Verify ZK proof
        require(
            verifier.verifyProof(zkProof, invoiceCommitment, nullifier),
            "Invalid ZK proof"
        );

        // 2. Lock invoice
        require(!usedNullifiers[nullifier], "Already factored");
        usedNullifiers[nullifier] = true;

        // 3. Record ownership
        invoiceOwner[invoiceCommitment] = msg.sender; // Factor

        // 4. Pay supplier
        stablecoin.transfer(supplier, advanceAmount);

        emit InvoiceFactored(invoiceCommitment, supplier, advanceAmount);
    }
}


