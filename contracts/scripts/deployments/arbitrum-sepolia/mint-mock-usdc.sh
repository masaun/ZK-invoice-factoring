#!/bin/bash

# Mint MockUSDC tokens on Arbitrum Sepolia
# Usage: ./mint-mock-usdc.sh [amount_in_usdc]
#   Example: ./mint-mock-usdc.sh 1000000  (mints 1 million USDC)

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get the contracts root directory (3 levels up from this script)
CONTRACTS_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

# Check .env
if [ ! -f "$CONTRACTS_ROOT/.env" ]; then
    echo -e "${RED}Error: .env file not found at $CONTRACTS_ROOT/.env${NC}"
    echo "Please create a .env file with USDC_ADDRESS_MOCK_ON_ARBITRUM_SEPOLIA set"
    exit 1
fi

source "$CONTRACTS_ROOT/.env"

# Validate environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}Error: PRIVATE_KEY not set in .env${NC}"
    exit 1
fi

if [ -z "$ARBITRUM_SEPOLIA_RPC_URL" ]; then
    echo -e "${RED}Error: ARBITRUM_SEPOLIA_RPC_URL not set in .env${NC}"
    exit 1
fi

if [ -z "$USDC_ADDRESS_MOCK_ON_ARBITRUM_SEPOLIA" ] || [ "$USDC_ADDRESS_MOCK_ON_ARBITRUM_SEPOLIA" = "0x0000000000000000000000000000000000000000" ]; then
    echo -e "${RED}Error: USDC_ADDRESS_MOCK_ON_ARBITRUM_SEPOLIA not set in .env${NC}"
    echo "Please deploy MockUSDC first using ./deploy-mock-usdc.sh"
    exit 1
fi

# Parse amount argument (optional)
if [ -n "$1" ]; then
    # Convert to amount with 6 decimals
    MINT_AMOUNT=$(echo "$1 * 1000000" | bc)
    export MINT_AMOUNT
    echo -e "${YELLOW}Custom mint amount: $1 USDC${NC}"
else
    echo -e "${YELLOW}Using default mint amount: 1,000,000 USDC${NC}"
fi

# Change to contracts root for forge commands
cd "$CONTRACTS_ROOT"

echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}Minting MockUSDC on Arbitrum Sepolia${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""
echo "MockUSDC Address: $USDC_ADDRESS_MOCK_ON_ARBITRUM_SEPOLIA"
echo ""

# Run the mint script
forge script scripts/deployments/arbitrum-sepolia/MintMockUSDC.s.sol:MintMockUSDC \
  --rpc-url arbitrum_sepolia \
  --broadcast \
  -vvv

echo ""
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}Minting Complete!${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""
echo "View transaction on Arbiscan:"
echo "https://sepolia.arbiscan.io/address/$USDC_ADDRESS_MOCK_ON_ARBITRUM_SEPOLIA"
