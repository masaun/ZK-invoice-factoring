// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../../../src/circuits/honk-verifier/invoice-refactoring-honk-verifier/HonkVerifier.sol";
import "../../../src/circuits/InvoiceRefactoringHonkVerifier.sol";
import "../../../src/InvoiceFactoring.sol";
import "../../../src/mocks/MockUSDC.sol";

contract DeployScript is Script {

    function run() external {
        // Get the deployer's private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Get the USDC token address from environment variable (or use a default for testing)
        address usdcAddress = vm.envAddress("USDC_ADDRESS_MOCK_ON_ARBITRUM_SEPOLIA");
        //address usdcAddress = vm.envAddress("USDC_ADDRESS_OFFICIAL_ON_ARBITRUM_SEPOLIA");
        
        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy HonkVerifier (base verifier)
        console.log("Deploying HonkVerifier...");
        HonkVerifier honkVerifier = new HonkVerifier();
        console.log("HonkVerifier deployed at:", address(honkVerifier));

        // Step 2: Deploy InvoiceRefactoringHonkVerifier (wrapper)
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

        // Step 4: Mint 1,000,000 MockUSDC tokens
        console.log("\nMinting 1,000,000 MockUSDC...");
        MockUSDC usdc = MockUSDC(usdcAddress);
        uint256 mintAmount = 1000000 * 10**6; // 1 million USDC with 6 decimals
        usdc.mint(msg.sender, mintAmount);
        console.log("Minted 1,000,000 USDC to:", msg.sender);
        
        // Step 5: Approve and deposit USDC into InvoiceFactoring contract
        console.log("\nDepositing USDC into InvoiceFactoring contract...");
        usdc.approve(address(invoiceFactoring), mintAmount);
        invoiceFactoring.depositUSDC(mintAmount);
        console.log("Deposited 1,000,000 USDC into InvoiceFactoring contract");
        
        // Verify the deposit
        uint256 contractBalance = usdc.balanceOf(address(invoiceFactoring));
        console.log("InvoiceFactoring USDC balance:", contractBalance / 10**6, "USDC");

        vm.stopBroadcast();

        // Print deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("HonkVerifier:", address(honkVerifier));
        console.log("InvoiceRefactoringHonkVerifier:", address(invoiceRefactoringHonkVerifier));
        console.log("InvoiceFactoring:", address(invoiceFactoring));
        console.log("USDC Address:", usdcAddress);
        console.log("InvoiceFactoring USDC Balance:", contractBalance / 10**6, "USDC");
    }
}
