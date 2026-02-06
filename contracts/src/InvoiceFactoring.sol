// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { InvoiceRefactoringHonkVerifier } from "./circuits/InvoiceRefactoringHonkVerifier.sol";
import { IToken } from "./interfaces/IToken.sol";

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
    IToken public usdc; // Using IToken.sol as USDC on Arbitrum Sepolia

    mapping(bytes32 => bool) public nullifierHashes;
    mapping(bytes32 => address) public factoredInvoiceOwners;

    constructor(InvoiceRefactoringHonkVerifier _invoiceRefactoringHonkVerifier, IToken _usdc) {
        invoiceRefactoringHonkVerifier = _invoiceRefactoringHonkVerifier;
        usdc = _usdc;
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
        uint256 advanceAmount,
        address invoiceSupplier
    ) external {
        // 1. Verify a InvoiceRefactoringProof
        require(
            invoiceRefactoringHonkVerifier.verifyInvoiceRefactoringProof(proof, publicInputs),
            "Invalid ZK proof"
        );

        // @dev - Construct variables from public inputs
        bytes32 invoiceMerkleTreeRoot = publicInputs[0];
        bytes32 nullifierHash = publicInputs[1]; // @dev - A nullifier hash of a factored-invoice

        // 2. Prevent double factoring using nullifier hash
        // @dev - Revert if the nullifier hash has already been used
        require(!nullifierHashes[nullifierHash], "A given invoice has already been factored");

        // @dev - If there is no previous usage, the nullifier hash is marked as "used". This means the invoice is marked as "factored"
        nullifierHashes[nullifierHash] = true;

        // 3. Record ownership of the factored-invoice
        factoredInvoiceOwners[invoiceMerkleTreeRoot] = msg.sender; // A owner of a factored-invoice, who is a invoice supplier, would be stored

        // 4. Pay an advance amount of fund to the invoice supplier in USDC
        usdc.transfer(invoiceSupplier, advanceAmount);

        emit InvoiceFactored(publicInputs[0], invoiceSupplier, advanceAmount);
    }
}


