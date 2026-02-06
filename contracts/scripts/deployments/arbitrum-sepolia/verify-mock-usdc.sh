#!/bin/bash

# Verify MockUSDC on Arbiscan Sepolia
# Usage: ./verify-mock-usdc.sh <mock_usdc_address>

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}Verifying MockUSDC on Arbiscan Sepolia${NC}"
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

# Parse arguments
MOCK_USDC_ADDRESS=$1

if [ -z "$MOCK_USDC_ADDRESS" ]; then
    echo -e "${YELLOW}Enter MockUSDC contract address:${NC}"
    read MOCK_USDC_ADDRESS
fi

# Change to contracts root
cd "$CONTRACTS_ROOT"

echo ""
echo -e "${YELLOW}Verifying MockUSDC at $MOCK_USDC_ADDRESS...${NC}"
forge verify-contract \
  --rpc-url arbitrum_sepolia \
  --etherscan-api-key "$ARBISCAN_API_KEY" \
  --verifier-url https://api-sepolia.arbiscan.io/api \
  --watch \
  "$MOCK_USDC_ADDRESS" \
  src/mocks/MockUSDC.sol:MockUSDC \
  || echo -e "${YELLOW}MockUSDC verification failed or already verified${NC}"

echo ""
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}Verification Complete!${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""
echo "Check contract on Arbiscan:"
echo "https://sepolia.arbiscan.io/address/$MOCK_USDC_ADDRESS"
