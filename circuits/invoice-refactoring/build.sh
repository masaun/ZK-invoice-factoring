#!/bin/bash

# Extract version from Nargo.toml
VERSION=$(grep '^version = ' Nargo.toml | cut -d '"' -f 2)
echo "Circuit version: $VERSION"

# Clean previous build
rm -rf target

# Install Noir/Nargo
#echo "Install the Noir/Nargo v1.0.0-beta.18..."
#noirup --version 1.0.0-beta.18

# Align the Noir/Nargo version (v1.0.0-beta.18) and bb.js version (v3.0.0-nightly.20251104) of the local machine.
#echo "Install the bb.js version v3.0.0-nightly.20251104..."
#bbup --version 3.0.0-nightly.20251104 (Previous bb.js version: v0.87.0)

echo "Check the Noir/Nargo version of the local machine (This version is supposed to be v1.0.0-beta.18)..."
nargo -V

echo "Check the bb.js version of the local machine (This version is supposed to be v0.87.0)..."
bb --version

# Compile the ZK circuit
echo "Compiling circuit..."
if ! nargo compile; then
    echo "Compilation failed. Exiting..."
    exit 1
fi

echo "Gate count:"
bb gates -b target/invoice_refactoring.json | jq '.functions[0].circuit_size'

# Create version-specific directory to the frontend directory
#echo "Creating version-specific directory for version $VERSION to the frontend directory..."
#mkdir -p "../client-and-server/client/circuits/invoice-refactoring-$VERSION"
#mkdir -p "../app/circuits/invoice-refactoring-$VERSION"

# Create version-specific directory to the scripts directory
echo "Creating version-specific directory for version $VERSION to the scripts directory..."
mkdir -p "../../scripts/circuit-artifacts/invoice-refactoring/invoice-refactoring-$VERSION"

# Generate the verification key (vkey)
echo "Creating target/vk directory..."
mkdir -p "target/vk"

echo "Copying invoice-refactoring.json to ../../scripts/circuit-artifacts/invoice-refactoring/invoice-refactoring-$VERSION..."
cp target/invoice_refactoring.json "../../scripts/circuit-artifacts/invoice-refactoring/invoice-refactoring-$VERSION/invoice-refactoring.json"

echo "Generating a vkey (verification key)..."
bb write_vk -b ./target/invoice_refactoring.json -o ./target/vk --oracle_hash keccak   # bb.js v3.0.0-nightly.20251104
#bb write_vk -b ./target/invoice_refactoring.json -o ./target/vk --oracle_hash keccak  # bb.js v0.87.0 (Same with v3.0.0-nightly.20251104)

echo "Generating vk.json to ../../scripts/circuit-artifacts/invoice-refactoring/invoice-refactoring-$VERSION..."
node -e "const fs = require('fs'); fs.writeFileSync('../../scripts/circuit-artifacts/invoice-refactoring/invoice-refactoring-$VERSION/vk.json', JSON.stringify(Array.from(Uint8Array.from(fs.readFileSync('./target/vk/vk')))));"

echo "Generate a Solidity Verifier contract from the vkey..."
bb write_solidity_verifier -k ./target/vk/vk -o ./target/Verifier.sol

echo "Copy a Solidity Verifier contract-generated (Verifier.sol) into the ../..contracts/src/circuits/honk-verifier directory"
cp ./target/Verifier.sol ../../contracts/src/circuits/honk-verifier

echo "Rename the Verifier.sol with the HonkVerifier.sol in the ../../contracts/src/circuits/honk-verifier directory"
mv ../../contracts/src/circuits/honk-verifier/Verifier.sol ../../contracts/src/circuits/honk-verifier/InvoiceRefactoringHonkVerifier.sol
#mv ../contracts/src/circuits/honk-verifier/Verifier.sol ../contracts/src/circuits/honk-verifier/honk_vk.sol
echo "Done" 