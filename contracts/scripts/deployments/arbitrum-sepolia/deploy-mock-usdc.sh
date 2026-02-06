#!/bin/bash

# Deploy and verify MockUSDC on Arbitrum Sepolia
# Usage: ./deploy-mock-usdc.sh [--verify-only] [mock_usdc_address]

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Parse arguments
VERIFY_ONLY=false
if [ "$1" = "--verify-only" ]; then
    VERIFY_ONLY=true
    shift
fi

MOCK_USDC_ADDRESS=$1

# Get the contracts root directory (3 levels up from this script)
CONTRACTS_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

# Check .env
if [ ! -f "$CONTRACTS_ROOT/.env" ]; then
    echo -e "${RED}Error: .env file not found at $CONTRACTS_ROOT/.env${NC}"
    echo "Please create a .env file based on .env.example in the contracts directory"
    exit 1
fi

source "$CONTRACTS_ROOT/.env"

# Change to contracts root for forge commands
cd "$CONTRACTS_ROOT"

if [ "$VERIFY_ONLY" = true ]; then
    # ============================================
    # VERIFICATION ONLY MODE
    # ============================================
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}Verifying MockUSDC on Arbiscan Sepolia${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo ""

    # Validate
    if [ -z "$ARBISCAN_API_KEY" ]; then
        echo -e "${RED}Error: ARBISCAN_API_KEY not set in .env${NC}"
        echo "Get your API key from: https://arbiscan.io/apis"
        exit 1
    fi

    # Get address from argument, env, or user input
    if [ -z "$MOCK_USDC_ADDRESS" ]; then
        # No argument provided, try to use env variable
        if [ -n "$USDC_ADDRESS_MOCK_ON_ARBITRUM_SEPOLIA" ] && [ "$USDC_ADDRESS_MOCK_ON_ARBITRUM_SEPOLIA" != "0x0000000000000000000000000000000000000000" ]; then
            MOCK_USDC_ADDRESS="$USDC_ADDRESS_MOCK_ON_ARBITRUM_SEPOLIA"
        else
            # Prompt user for address
            echo -e "${YELLOW}Enter MockUSDC contract address:${NC}"
            read MOCK_USDC_ADDRESS
        fi
    fi

    echo ""
    echo -e "${YELLOW}Verifying MockUSDC at $MOCK_USDC_ADDRESS...${NC}"
    forge verify-contract \
      --rpc-url arbitrum_sepolia \
      --etherscan-api-key "$ARBISCAN_API_KEY" \
      --verifier-url https://api-sepolia.arbiscan.io/api \
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

else
    # ============================================
    # DEPLOYMENT MODE
    # ============================================
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}Deploying MockUSDC to Arbitrum Sepolia${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo ""

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
    
    if [ -z "$ARBISCAN_API_KEY" ]; then
        echo ""
        echo -e "${YELLOW}Tip: To verify MockUSDC manually, run:${NC}"
        echo "./deploy-mock-usdc.sh --verify-only <mock_usdc_address>"
    fi
fi
