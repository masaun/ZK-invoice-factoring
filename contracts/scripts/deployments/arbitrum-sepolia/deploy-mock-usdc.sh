#!/bin/bash

# Deploy MockUSDC to Arbitrum Sepolia
# Usage: ./deploy-mock-usdc.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}Deploying MockUSDC to Arbitrum Sepolia${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""

# Get the contracts root directory (3 levels up from this script)
CONTRACTS_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

# Check .env
if [ ! -f "$CONTRACTS_ROOT/.env" ]; then
    echo -e "${RED}Error: .env file not found at $CONTRACTS_ROOT/.env${NC}"
    echo "Please create a .env file based on .env.example in the contracts directory"
    exit 1
fi

source "$CONTRACTS_ROOT/.env"

# Validate
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}Error: PRIVATE_KEY not set${NC}"
    exit 1
fi

if [ -z "$ARBITRUM_SEPOLIA_RPC_URL" ]; then
    echo -e "${RED}Error: ARBITRUM_SEPOLIA_RPC_URL not set${NC}"
    exit 1
fi

echo -e "${YELLOW}Building contracts...${NC}"

# Change to contracts root for forge commands
cd "$CONTRACTS_ROOT"

forge build

echo ""
echo -e "${YELLOW}Deploying MockUSDC...${NC}"

if [ -n "$ARBISCAN_API_KEY" ]; then
    forge script scripts/deployments/arbitrum-sepolia/DeployMockUSDC.s.sol:DeployMockUSDC \
      --rpc-url arbitrum_sepolia \
      --broadcast \
      --verify \
      --etherscan-api-key "$ARBISCAN_API_KEY" \
      --verifier-url https://api-sepolia.arbiscan.io/api
else
    forge script scripts/deployments/arbitrum-sepolia/DeployMockUSDC.s.sol:DeployMockUSDC \
      --rpc-url arbitrum_sepolia \
      --broadcast
fi

echo ""
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}MockUSDC Deployment Complete!${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Copy the MockUSDC address from the output above"
echo "2. Update USDC_ADDRESS in your .env file"
echo "3. Run ./deploy.sh to deploy the main contracts"
