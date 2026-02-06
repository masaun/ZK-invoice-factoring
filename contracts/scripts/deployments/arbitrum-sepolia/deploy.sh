#!/bin/bash

# Deploy and verify contracts on Arbitrum Sepolia
# Usage: ./deploy.sh [--verify-only] [honk_verifier_addr] [invoice_refactoring_honk_verifier_addr] [invoice_factoring_addr]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
VERIFY_ONLY=false
if [ "$1" = "--verify-only" ]; then
    VERIFY_ONLY=true
    shift
fi

HONK_VERIFIER_ADDRESS=$1
INVOICE_REFACTORING_HONK_VERIFIER_ADDRESS=$2
INVOICE_FACTORING_ADDRESS=$3

# Get the contracts root directory (3 levels up from this script)
CONTRACTS_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

# Check if .env file exists
if [ ! -f "$CONTRACTS_ROOT/.env" ]; then
    echo -e "${RED}Error: .env file not found at $CONTRACTS_ROOT/.env${NC}"
    echo "Please create a .env file based on .env.example in the contracts directory"
    exit 1
fi

# Load environment variables
source "$CONTRACTS_ROOT/.env"

# Change to contracts root for forge commands
cd "$CONTRACTS_ROOT"

if [ "$VERIFY_ONLY" = true ]; then
    # ============================================
    # VERIFICATION ONLY MODE
    # ============================================
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}Verifying Contracts on Arbiscan Sepolia${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo ""

    # Validate
    if [ -z "$ARBISCAN_API_KEY" ]; then
        echo -e "${RED}Error: ARBISCAN_API_KEY not set in .env${NC}"
        echo "Get your API key from: https://arbiscan.io/apis"
        exit 1
    fi

    if [ -z "$ARBITRUM_SEPOLIA_RPC_URL" ]; then
        echo -e "${RED}Error: ARBITRUM_SEPOLIA_RPC_URL not set in .env${NC}"
        exit 1
    fi

    # Get addresses interactively if not provided
    if [ -z "$HONK_VERIFIER_ADDRESS" ]; then
        echo -e "${YELLOW}Enter HonkVerifier contract address:${NC}"
        read HONK_VERIFIER_ADDRESS
    fi

    if [ -z "$INVOICE_REFACTORING_HONK_VERIFIER_ADDRESS" ]; then
        echo -e "${YELLOW}Enter InvoiceRefactoringHonkVerifier contract address:${NC}"
        read INVOICE_REFACTORING_HONK_VERIFIER_ADDRESS
    fi

    if [ -z "$INVOICE_FACTORING_ADDRESS" ]; then
        echo -e "${YELLOW}Enter InvoiceFactoring contract address:${NC}"
        read INVOICE_FACTORING_ADDRESS
    fi

    if [ -z "$USDC_ADDRESS" ]; then
        echo -e "${YELLOW}Enter USDC token address:${NC}"
        read USDC_ADDRESS
    fi

    echo ""
    echo -e "${YELLOW}Verifying HonkVerifier at $HONK_VERIFIER_ADDRESS...${NC}"
    forge verify-contract \
      --rpc-url arbitrum_sepolia \
      --etherscan-api-key "$ARBISCAN_API_KEY" \
      --verifier-url https://api-sepolia.arbiscan.io/api \
      "$HONK_VERIFIER_ADDRESS" \
      src/circuits/honk-verifier/invoice-refactoring-honk-verifier/HonkVerifier.sol:HonkVerifier \
      || echo -e "${YELLOW}HonkVerifier verification failed or already verified${NC}"

    echo ""
    echo -e "${YELLOW}Verifying InvoiceRefactoringHonkVerifier at $INVOICE_REFACTORING_HONK_VERIFIER_ADDRESS...${NC}"
    forge verify-contract \
      --rpc-url arbitrum_sepolia \
      --etherscan-api-key "$ARBISCAN_API_KEY" \
      --verifier-url https://api-sepolia.arbiscan.io/api \
      --constructor-args $(cast abi-encode "constructor(address)" "$HONK_VERIFIER_ADDRESS") \
      "$INVOICE_REFACTORING_HONK_VERIFIER_ADDRESS" \
      src/circuits/InvoiceRefactoringHonkVerifier.sol:InvoiceRefactoringHonkVerifier \
      || echo -e "${YELLOW}InvoiceRefactoringHonkVerifier verification failed or already verified${NC}"

    echo ""
    echo -e "${YELLOW}Verifying InvoiceFactoring at $INVOICE_FACTORING_ADDRESS...${NC}"
    forge verify-contract \
      --rpc-url arbitrum_sepolia \
      --etherscan-api-key "$ARBISCAN_API_KEY" \
      --verifier-url https://api-sepolia.arbiscan.io/api \
      --constructor-args $(cast abi-encode "constructor(address,address)" "$INVOICE_REFACTORING_HONK_VERIFIER_ADDRESS" "$USDC_ADDRESS") \
      "$INVOICE_FACTORING_ADDRESS" \
      src/InvoiceFactoring.sol:InvoiceFactoring \
      || echo -e "${YELLOW}InvoiceFactoring verification failed or already verified${NC}"

    echo ""
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}Verification Process Complete!${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo ""
    echo "Check contracts on Arbiscan:"
    echo "HonkVerifier: https://sepolia.arbiscan.io/address/$HONK_VERIFIER_ADDRESS"
    echo "InvoiceRefactoringHonkVerifier: https://sepolia.arbiscan.io/address/$INVOICE_REFACTORING_HONK_VERIFIER_ADDRESS"
    echo "InvoiceFactoring: https://sepolia.arbiscan.io/address/$INVOICE_FACTORING_ADDRESS"

else
    # ============================================
    # DEPLOYMENT MODE
    # ============================================
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}Deploying to Arbitrum Sepolia${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo ""

    # Validate required variables
    if [ -z "$PRIVATE_KEY" ]; then
        echo -e "${RED}Error: PRIVATE_KEY not set in .env${NC}"
        exit 1
    fi

    if [ -z "$ARBITRUM_SEPOLIA_RPC_URL" ]; then
        echo -e "${RED}Error: ARBITRUM_SEPOLIA_RPC_URL not set in .env${NC}"
        exit 1
    fi

    if [ -z "$USDC_ADDRESS" ] || [ "$USDC_ADDRESS" = "0x0000000000000000000000000000000000000000" ]; then
        echo -e "${YELLOW}Warning: USDC_ADDRESS not set or is zero address${NC}"
        echo "You may need to deploy a mock token first"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    echo -e "${YELLOW}Building contracts...${NC}"
    forge build

    echo ""
    echo -e "${YELLOW}Deploying contracts...${NC}"

    # Deploy with or without verification
    if [ -n "$ARBISCAN_API_KEY" ]; then
        echo "Verification enabled"
        forge script scripts/deployments/arbitrum-sepolia/Deploy.s.sol:DeployScript \
          --rpc-url arbitrum_sepolia \
          --broadcast \
          --verify \
          --etherscan-api-key "$ARBISCAN_API_KEY" \
          --verifier-url https://api-sepolia.arbiscan.io/api
    else
        echo "Verification disabled (no ARBISCAN_API_KEY)"
        forge script scripts/deployments/arbitrum-sepolia/Deploy.s.sol:DeployScript \
          --rpc-url arbitrum_sepolia \
          --broadcast
    fi

    echo ""
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo ""
    echo "Check the output above for deployed contract addresses"
    echo "You can view them on Arbiscan: https://sepolia.arbiscan.io/"
    
    if [ -z "$ARBISCAN_API_KEY" ]; then
        echo ""
        echo -e "${YELLOW}Tip: To verify contracts manually, run:${NC}"
        echo "./deploy.sh --verify-only <honk_verifier> <invoice_refactoring_honk_verifier> <invoice_factoring>"
    fi
fi
