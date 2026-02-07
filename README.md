# ZK Invoice Refactoring

## Overview

- This project is still in progress.


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