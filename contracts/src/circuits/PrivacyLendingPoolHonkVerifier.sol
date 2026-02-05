// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { HonkVerifier } from "./honk-verifier/privacy-lending-pool-honk-verifier/HonkVerifier.sol";

contract PrivacyLendingPoolHonkVerifier is HonkVerifier {
    HonkVerifier public verifier;

    constructor(address _verifier) {
        verifier = HonkVerifier(_verifier);
    }

    function verifyPrivacyLendingPoolProof(
        bytes calldata proof, 
        bytes32[] calldata publicInputs
    ) external view returns (bool) {
        bool isValidProof = verifier.verify(proof, publicInputs);
        require(isValidProof, "Invalid ZK proof in Honk Verifier");
        return isValidProof;
    }
}
