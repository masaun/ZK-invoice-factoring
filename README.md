# ZK Invoice Refactoring

## Overview

- This project is still in progress.

<br>

## Tech Stack

- **ZK Circuit**: `Noir` (`v1.0.0-beta.18`)
   - ZK Circuit Library: `@aztec/bb.js` (`v3.0.0-devnet.6-patch.1`) & `@noir-lang/noir_js` (`v1.0.0-beta.18`)
   - Incremental Merkle Tree (`IMT`) Library: `@zk-kit/imt` (`v2.0.0-beta.8`) 

- **Smart Contract**: `Solidity`
- **Blockchain**: Arbitrum Sepolia Testnet

<br>

## Architecture

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
```

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
                               Noir ZK Circuit
                                       │
                                       │ (6) ZK Proof
                                       ▼
                           Solidity Factoring Contract
                                       │
                                       │ (7) Liquidity
                                       ▼
                                   Supplier

(8) Invoice Paid at Maturity
Buyer ─────────────────────────────▶ Factor (SPV / Vault)
```


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

## Run the e2e script

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