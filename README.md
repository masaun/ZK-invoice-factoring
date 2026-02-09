# ZK Invoice Factoring

## Overview

ZK Invoice Factoring is a privacy-preserving invoice factoring platform that leverages `zero-knowledge proof` to enable **suppliers** to access liquidity *without* `exposing sensitive business data` and `deposting any collateral`.

The system allows **suppliers** to prove that their invoices have been accepted by **buyers** without revealing confidential information to the **factoring company** such as invoice amounts, payment terms, or buyer identities.

### Key Features

- **Privacy-First**: Uses Noir ZK circuits to generate proofs of invoice acceptance while keeping sensitive data private
- **Trustless Verification**: Smart contracts verify ZK proofs on-chain without requiring trust in intermediaries
- **Data Protector Integration**: Optional integration with iExec TEE for enhanced data protection during proof generation
- **Enterprise Ready**: Designed to work with existing ERP systems and standard business workflows

### Use Case

Suppliers often need early access to cash tied up in unpaid invoices. Traditional invoice factoring requires sharing sensitive business information with third parties. 

This project solves that problem by:
1. Allowing suppliers to prove invoice acceptance using ZK proofs
2. Enabling smart contracts to verify these proofs on-chain
3. Facilitating instant liquidity provision without exposing confidential data and depositing any collateral.
4. Maintaining privacy for both suppliers and buyers throughout the process

<br>

## Tech Stack

- **ZK Circuit**: `Noir` (`v1.0.0-beta.18`)
   - ZK Circuit Library: `@aztec/bb.js` (`v3.0.0-devnet.6-patch.1`) & `@noir-lang/noir_js` (`v1.0.0-beta.18`)
   - Incremental Merkle Tree (`IMT`) Library: `@zk-kit/imt` (`v2.0.0-beta.8`) 

- **Smart Contract**: `Solidity`
- **Blockchain**: Arbitrum Sepolia Testnet

<br>

## Userflow

```bash
(1) Goods / Services
Supplier ─────────────────────────▶ Buyer
     │
     │ (2) Invoice
     ▼
Buyer ─────────────────────────────▶ Buyer ERP / AP
                                       │
                                       │ (3) Invoice Acceptance
                                       ▼
                              Buyer ERP (System of Record)
                                       │
                                       │ (4) Acceptance Artifact
                                       │     (API / EDI / Portal)
                                       ▼
                              Supplier ERP / Invoicing
                                       │
                                       │ (5) zkTLS Transcript
                                       ▼
                               Noir ZK Circuit (in this Invoice Factoring platform)
                                       │
                                       │ (6) ZK Proof
                                       ▼
                           Solidity Factoring Contract (in this Invoice Factoring platform)
                                       │
                                       │ (7) Liquidity
                                       ▼
                                   Supplier

(8) Invoice Paid at Maturity
Buyer ─────────────────────────────▶ Factor (SPV / Vault)
```

<br>

## Architecture

- The scope of this **Invoice Factoring** platform would deal with the **userflow** above from `(5)` to `(7)`  
```bash
┌──────────────┐
│ Buyer ERP    │
│ (System of   │
│  Record)     │
└───────┬──────┘
        │ (3) Acceptance event
        ▼
┌──────────────────────────┐
│ Acceptance Artifact      │
│ - Invoice ID             │
│ - Approval timestamp     │
│ - Buyer signature / ref │
└───────┬─────────────────┘
        │
        │ (4) Delivered to Supplier
        ▼
┌──────────────┐
│ Supplier ERP │
│ / Invoicing  │
└───────┬──────┘
        │
        │ (5) zkTLS proof input
        ▼
┌──────────────────────────┐
│ Noir ZK Circuit          │
│ - Verifies artifact      │
│ - Proves buyer approved  │
└──────────────────────────┘
        │
        │ (6) ZK Invoice Refactoring Proof input
        ▼
┌─────────────────────────────────────┐
│ Invoicing Factoring smart contract  │
└───────┬─────────────────────────────┘
        │
        │ (7) Trigger to pay an advance amount in USDC to Supplier
        ▼
┌──────────────┐
│ Supplier     │
└───────┬──────┘
```

<br>

## Deployed Contract Addresses (on `Arbitrum Sepolia`)

| Contract Name | Address | Network | Explorer |
|--------------|---------|---------|----------|
| HonkVerifier | `0x00ED53B614f877b08a3611138e52dF6a47415572` | Arbitrum Sepolia | [View on Explorer](https://sepolia.arbiscan.io/address/0x00ED53B614f877b08a3611138e52dF6a47415572) |
| InvoiceRefactoringHonkVerifier | `0xE87206330Fa28E7d75D5C910B9D88286D9267839` | Arbitrum Sepolia | [View on Explorer](https://sepolia.arbiscan.io/address/0xE87206330Fa28E7d75D5C910B9D88286D9267839) |
| InvoiceFactoring | `0x86Dea1F4E3f86ccE7EeE32e6AD4bca66F3879f8D` | Arbitrum Sepolia | [View on Explorer](https://sepolia.arbiscan.io/address/0x86Dea1F4E3f86ccE7EeE32e6AD4bca66F3879f8D) |
| MockUSDC | `0x2d159141C3Badf038216E59089D0151CB2692dCc` | Arbitrum Sepolia | [View on Explorer](https://sepolia.arbiscan.io/address/0x2d159141C3Badf038216E59089D0151CB2692dCc) |

<br>

## DEMO Video

- https://www.loom.com/share/054dc11102a741289d08b5c505fed7af


<br>

## Installation

## Noir ZK circuit

- Circuit Test
```bash
cd circuits/invoice-refactoring

sh circuit_test.sh
```

<br>

- Circuit Artifacts & Solidity Verifier generation
```bash
cd circuits/invoice-refactoring

sh build.sh
```

<br>

### Smart Contract

1. **Install dependencies**:
```bash
cd contracts
forge install
```

2. **Compile contracts**:
```bash
forge build
```

3. **Run tests**:
```bash
forge test
```

4. **Deploy on Arbitrum Sepolia**:
```bash
cd contracts/scripts/deployments/arbitrum-sepolia

sh deploy.sh
```

<br>

## Run the e2e script

- Install the node modules with the `bun` CLI
```bash
cd scripts/invoice-refactoring

bun install
```

<br>

- Normal e2e script (without the Data Protector of iExec TEE)
```bash
cd scripts/invoice-refactoring
bun run e2e
```

<br>

- e2e script with the Data Protector of iExec TEE
```bash
cd scripts/invoice-refactoring
bun run e2e:iExec-TEE-DataProtector
```

<br>

## References

- Noir ZK circuit
  - [Noir Documentation](https://noir-lang.org/)
  - [Barretenberg Documentation](https://aztecprotocol.github.io/barretenberg/)
  - `noir-examples/solidity-example`
    - `js/generate-proof.ts` (How to use the `verifierTarget: "evm"`): https://github.com/noir-lang/noir-examples/blob/master/solidity-example/js/generate-proof.ts#L16


- iExec TEE - Deta Protector
  - Step-by-Step Guide to Building on iExec
    https://vigorous-station-f66.notion.site/Step-by-Step-Guide-to-Building-on-iExec-284df2792faa808b93b9ee9ebfc8b3a7

  - iexec-nextjs-starter
    https://github.com/iExecBlockchainComputing/iexec-nextjs-starter

  - dataProtector
    https://docs.iex.ec/references/dataProtector/getting-started

