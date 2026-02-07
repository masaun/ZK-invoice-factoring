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
 * @dev - This contract owner/operator is a "Factoring Company" that provides invoice factoring services to "Suppliers"
 * @dev - This contract allows a "Supplier" to factor their invoice using a valid ZK InvoiceRefactoring Proof - so that the "Supplier" can receive an advance amount of funds in USDC before their original invoice due date.
 * @dev - This contract allows a "Buyer" to pay the "Factoring Company" (= the contract owner/operator) the original invoice amount in USDC at the original invoice due date.
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
     * @notice - Factor a given invoice using a ZK InvoiceRefactoring Proof
     * @dev - A "Supplier" would call this function to factor a given invoice - so that the "Supplier" can receive an advance amount of funds in USDC before their original invoice due date
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

        // 4. Pay an advance amount of funds to the invoice supplier in USDC
        usdc.transfer(invoiceSupplier, advanceAmount);

        emit InvoiceFactored(publicInputs[0], invoiceSupplier, advanceAmount);
    }

    /**
     * @notice - A "Buyer" would call this function to pay the original invoice amount in USDC
     */
    function payOriginalInvoiceAmount(uint256 originalInvoiceAmount) external {
        // @dev - Implementation would be added in the future
        usdc.transferFrom(msg.sender, address(this), originalInvoiceAmount);
    }

    /**
     * @notice - A "Factoring Company" would deposit USDC into this contract for paying an advance amount of funds to invoice suppliers
     */
    function depositUSDC(uint256 amount) external {
        // @dev - This caller must be a factoring company.
        usdc.transferFrom(msg.sender, address(this), amount);
    }

    // /**
    //  * @notice - A "Factoring Company" would deposit USDC into this contract for paying an advance amount of funds to invoice suppliers
    //  */
    // function depositUSDCIntoContract(uint256 amount) external {
    //     require(msg.sender == owner()), "Only the contract can call this function");
    //     // @dev - This caller must be a factoring company.
    //     usdc.transferFrom(msg.sender, address(this), amount);
    // }

    // /**
    //  * @notice - A "Factoring Company" would withdraw USDC from this contract
    //  */
    // function withdrawUSDCFromContract(uint256 amount) external {
    //     require(msg.sender == owner()), "Only the contract can call this function");
    //     usdc.transferFrom(address(this), msg.sender, amount);
    // }
}


