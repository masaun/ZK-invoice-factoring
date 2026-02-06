#!/bin/bash

# Deploy contracts to Arbitrum Sepolia
# Usage: ./deploy.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}Deploying to Arbitrum Sepolia${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""

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

# Change to contracts root for forge commands
cd "$CONTRACTS_ROOT"

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
      --verifier-url https://api-sepolia.arbiscan.io/api \
      --watch
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
