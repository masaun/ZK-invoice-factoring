// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../../../src/circuits/honk-verifier/invoice-refactoring-honk-verifier/HonkVerifier.sol";
import "../../../src/circuits/InvoiceRefactoringHonkVerifier.sol";
import "../../../src/InvoiceFactoring.sol";

contract DeployScript is Script {

    function run() external {
        // Get the deployer's private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Get the USDC token address from environment variable (or use a default for testing)
        address usdcAddress = vm.envAddress("USDC_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy HonkVerifier
        console.log("Deploying HonkVerifier...");
        HonkVerifier honkVerifier = new HonkVerifier();
        console.log("HonkVerifier deployed at:", address(honkVerifier));

        // Step 2: Deploy InvoiceRefactoringHonkVerifier
        console.log("Deploying InvoiceRefactoringHonkVerifier...");
        InvoiceRefactoringHonkVerifier invoiceRefactoringHonkVerifier = new InvoiceRefactoringHonkVerifier(
            address(honkVerifier)
        );
        console.log("InvoiceRefactoringHonkVerifier deployed at:", address(invoiceRefactoringHonkVerifier));

        // Step 3: Deploy InvoiceFactoring
        console.log("Deploying InvoiceFactoring...");
        InvoiceFactoring invoiceFactoring = new InvoiceFactoring(
            invoiceRefactoringHonkVerifier,
            IToken(usdcAddress)
        );
        console.log("InvoiceFactoring deployed at:", address(invoiceFactoring));

        vm.stopBroadcast();

        // Print deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("HonkVerifier:", address(honkVerifier));
        console.log("InvoiceRefactoringHonkVerifier:", address(invoiceRefactoringHonkVerifier));
        console.log("InvoiceFactoring:", address(invoiceFactoring));
        console.log("USDC Address:", usdcAddress);
    }
}
