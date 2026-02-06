#!/bin/bash

# Verify contracts on Arbiscan Sepolia
# Usage: ./verify-contracts.sh <honk_verifier_address> <invoice_refactoring_honk_verifier_address> <invoice_factoring_address>

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}Verifying Contracts on Arbiscan Sepolia${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""

# Get the contracts root directory (3 levels up from this script)
CONTRACTS_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

# Check .env
if [ ! -f "$CONTRACTS_ROOT/.env" ]; then
    echo -e "${RED}Error: .env file not found at $CONTRACTS_ROOT/.env${NC}"
    exit 1
fi

source "$CONTRACTS_ROOT/.env"

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

# Parse arguments
HONK_VERIFIER_ADDRESS=$1
INVOICE_REFACTORING_HONK_VERIFIER_ADDRESS=$2
INVOICE_FACTORING_ADDRESS=$3
USDC_ADDRESS=${4:-$USDC_ADDRESS}

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

# Change to contracts root
cd "$CONTRACTS_ROOT"

echo ""
echo -e "${YELLOW}Verifying HonkVerifier at $HONK_VERIFIER_ADDRESS...${NC}"
forge verify-contract \
  --rpc-url arbitrum_sepolia \
  --etherscan-api-key "$ARBISCAN_API_KEY" \
  --verifier-url https://api-sepolia.arbiscan.io/api \
  --watch \
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
  --watch \
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
  --watch \
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
