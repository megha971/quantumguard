# QuantumGuard — Decentralized Identity for Farmers

> Privacy-first, offline-capable digital identity platform powered by Polygon blockchain, community verification, and on-device biometrics.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         QUANTUMGUARD ARCHITECTURE                        │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌────────────┐
│  FARMER      │    │  VALIDATOR   │    │  BANK/INST.  │    │  ADMIN     │
│  Flutter App │    │  Flutter App │    │  REST Client │    │  Dashboard │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘    └─────┬──────┘
       │                   │                   │                   │
       │     OFFLINE-FIRST │                   │                   │
       │  AES-256 + Hive   │                   │                   │
       │                   │                   │                   │
       └───────────────────┴───────────────────┴───────────────────┘
                                     │
                                     ▼ JWT / API Key Auth
                           ┌─────────────────────┐
                           │   NODE.JS BACKEND    │
                           │   Express + JWT      │
                           │   Role-based Access  │
                           └──┬──────────┬────────┘
                              │          │
               ┌──────────────┘          └──────────────────┐
               ▼                                             ▼
      ┌────────────────┐                          ┌────────────────────┐
      │    MONGODB      │                          │    IPFS NETWORK    │
      │                │                          │  (Infura / Local)  │
      │  Users         │                          │                    │
      │  Approvals     │                          │  Encrypted Profile │
      │  CreditRecords │                          │  Land Photos       │
      │  Loans         │                          │  Credit Records    │
      │  LandRecords   │                          │                    │
      │  SyncQueue     │                          └────────────────────┘
      └────────────────┘                                     │
                                                    IPFS Hash│
               ┌─────────────────────────────────────────────┘
               ▼
      ┌────────────────────────────────────────────────────────────────┐
      │                    POLYGON BLOCKCHAIN                           │
      │                   (Amoy Testnet / Mainnet)                      │
      │                                                                 │
      │   ┌─────────────────────────┐   ┌──────────────────────┐       │
      │   │   QuantumGuardDID.sol   │   │     QGToken.sol       │       │
      │   │                         │   │                        │       │
      │   │  • Mint DID             │   │  • Validator Staking  │       │
      │   │  • Store IPFS Hash      │   │  • Slash Mechanism    │       │
      │   │  • 3 Validator Approvals│   │  • Reward System      │       │
      │   │  • Land Records         │   │                        │       │
      │   │  • Credit Score Hash    │   └──────────────────────┘       │
      │   │  • Emergency Recovery   │                                    │
      │   └─────────────────────────┘                                   │
      └────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                    ON-DEVICE (TFLite) — NEVER TRANSMITTED               │
│                                                                          │
│   Camera → FaceNet Model → Float Embedding → SHA-256 Hash → Stored      │
│   Fingerprint → LocalAuth API → Device-level verification               │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Demo Flow

```
1. FARMER REGISTERS
   └── Opens app → fills profile → captures selfie (TFLite hash)
       → scans fingerprint (LocalAuth) → nominates 3 validators
       └── If offline: queued locally (AES-256 encrypted Hive)
           If online:  uploads encrypted profile to IPFS → POST /api/identity/register

2. BLOCKCHAIN REGISTRATION
   └── Backend calls QuantumGuardDID.registerIdentity()
       → DID minted → status: "under_review"
       → Nominated validators notified via push notification

3. VALIDATOR APPROVAL
   └── Each validator opens dashboard → reviews identity document
       → taps Approve → backend calls contract.approveIdentity(did)
       └── After 3 approvals → contract auto-activates DID
           → Farmer notified: "Identity Active!"

4. FARMER APPLIES FOR LOAN
   └── Opens loan screen → selects bank + amount
       → Backend verifies active DID on-chain
       └── POST /api/credit/loans

5. BANK VERIFIES DID
   └── POST /api/institution/verify-did { did }
       → Calls contract.verifyIdentity(did)
       → Returns: active=true, ipfsHash, creditScore
       └── Bank fetches encrypted doc from IPFS → decrypts with shared key

6. LOAN APPROVED & CREDIT UPDATED
   └── Bank calls PUT /api/credit/loans/:id/status { status: "approved" }
       → Later: POST /api/credit/event { type: "loan_repaid" }
       → Credit score recalculated → uploaded to IPFS
       → contract.updateCreditScore(did, newIpfsHash) called
```

---

## Project Structure

```
quantumguard/
├── contracts/                    # Solidity smart contracts
│   ├── QuantumGuardDID.sol       # Main DID contract
│   ├── QGToken.sol               # Staking token
│   ├── hardhat.config.js
│   └── scripts/
│       └── deploy.js
│
├── backend/                      # Node.js + Express API
│   ├── src/
│   │   ├── app.js                # Entry point
│   │   ├── models/index.js       # MongoDB schemas
│   │   ├── routes/
│   │   │   ├── auth.js           # Wallet-based auth
│   │   │   ├── identity.js       # Registration, sync
│   │   │   ├── validator.js      # Approve/reject
│   │   │   ├── credit.js         # Loans, credit events
│   │   │   ├── institution.js    # DID verification
│   │   │   └── land.js           # Land records
│   │   ├── services/
│   │   │   ├── blockchain.js     # ethers.js wrapper
│   │   │   ├── ipfs.js           # IPFS upload/fetch
│   │   │   └── creditScore.js    # Score calculation
│   │   └── middleware/
│   │       └── auth.js           # JWT + RBAC
│   └── package.json
│
└── flutter/                      # Flutter mobile app
    ├── lib/
    │   ├── main.dart
    │   ├── screens/
    │   │   ├── farmer/
    │   │   │   ├── registration_screen.dart
    │   │   │   ├── qr_identity_screen.dart
    │   │   │   └── loan_application_screen.dart
    │   │   └── validator/
    │   │       └── validator_dashboard.dart
    │   └── services/
    │       ├── biometric_service.dart  # TFLite + LocalAuth
    │       └── offline_service.dart    # AES-256 + sync queue
    └── pubspec.yaml
```

---

## Deployment Steps

### 1. Prerequisites

```bash
# Install tools
npm install -g hardhat
dart pub global activate flutterfire_cli

# Clone repo
git clone https://github.com/your-org/quantumguard
cd quantumguard
```

### 2. Smart Contracts → Polygon Amoy Testnet

```bash
cd contracts
npm install

# Get test MATIC from: https://faucet.polygon.technology

# Configure .env
cp .env.example .env
# Fill: DEPLOYER_PRIVATE_KEY, POLYGONSCAN_API_KEY, POLYGON_AMOY_RPC

# Compile
npx hardhat compile

# Deploy to Amoy testnet
npx hardhat run scripts/deploy.js --network polygonAmoy

# Verify on Polygonscan
# (auto-runs via deploy script)

# Copy ABI to backend
cp artifacts/contracts/QuantumGuardDID.sol/QuantumGuardDID.json ../backend/abis/
```

### 3. Backend → Docker / Railway / Fly.io

```bash
cd backend
npm install
cp .env.example .env
# Fill all env vars (MongoDB URI, JWT secret, contract addresses, etc.)

# Local dev
npm run dev

# Production (Docker)
docker build -t quantumguard-backend .
docker run -p 3001:3001 --env-file .env quantumguard-backend

# Or Railway.app (one-click):
railway up
```

### 4. IPFS Node

```bash
# Option A: Infura IPFS (easiest)
# Register at infura.io → Create IPFS project → Copy keys to .env

# Option B: Self-hosted
docker run -d -p 5001:5001 ipfs/kubo:latest
```

### 5. Flutter App

```bash
cd flutter

# Get dependencies
flutter pub get

# Place TFLite FaceNet model:
# Download from: https://www.kaggle.com/datasets/heroankit/facenet-tflite
cp facenet.tflite assets/models/

# Android (release)
flutter build apk --release --split-per-abi

# iOS
flutter build ios --release

# Update API base URL in lib/services/api_service.dart:
# static const baseUrl = 'https://your-backend.railway.app';
```

### 6. Gas Optimization Notes

- Contracts use `uint64` for timestamps (saves ~20k gas vs uint256)
- Approval status packed in `mapping(uint256 => mapping(address => bool))`
- `viaIR: true` + optimizer enabled (200 runs)
- Events used instead of storage for audit trail where possible
- Estimated cost per DID registration: ~0.002 MATIC (~$0.001)

---

## Security Checklist

- [x] Biometric data never leaves device (TFLite on-device inference)
- [x] Only SHA-256 hash of biometric embedding transmitted
- [x] Identity PII AES-256 encrypted before IPFS upload
- [x] Blockchain stores only IPFS hashes, never raw data
- [x] JWT with 7-day expiry + refresh flow
- [x] Wallet signature-based authentication (no passwords)
- [x] Rate limiting on all API endpoints
- [x] Role-based access control (Farmer / Validator / Bank / Admin)
- [x] Validator staking + slashing for Sybil resistance
- [x] Multi-validator approval (minimum 3)
- [x] Emergency recovery with multi-validator signature
- [x] ReentrancyGuard on all payable functions
- [x] Offline-first with AES-256 encrypted local storage (Hive + FlutterSecureStorage)

---

## Environment Variables Reference

See `backend/.env.example` for full list. Critical ones:

| Variable | Description |
|---|---|
| `MONGODB_URI` | MongoDB Atlas connection string |
| `JWT_SECRET` | Min 32-char secret for JWT signing |
| `BACKEND_PRIVATE_KEY` | Wallet that submits on-chain txs |
| `QG_DID_ADDRESS` | Deployed QuantumGuardDID contract |
| `POLYGON_RPC_URL` | Polygon Amoy or Mainnet RPC |
| `IPFS_PROJECT_ID` | Infura IPFS project ID |
| `INSTITUTION_API_KEY` | API key for bank integrations |

---

## MongoDB Schemas Summary

| Collection | Purpose |
|---|---|
| `users` | Farmer/Validator/Bank profiles + encrypted profile |
| `identitydocs` | IPFS hash versioning |
| `validators` | Stake info, approval stats |
| `approvals` | Per-validator approval records |
| `creditrecords` | Scored events + IPFS hash |
| `loans` | Loan lifecycle management |
| `landrecords` | Geotagged land proofs |
| `syncqueues` | Offline action queue |

---

## API Endpoints Reference

```
POST   /api/auth/nonce/:address       Get signing nonce
POST   /api/auth/verify               Verify wallet signature → JWT

POST   /api/identity/register         Register new identity
GET    /api/identity/me               Get own identity
GET    /api/identity/:did             Public DID lookup
POST   /api/identity/sync             Offline sync

GET    /api/validator/queue           Pending approvals
POST   /api/validator/approve         Approve identity
POST   /api/validator/reject          Reject identity
GET    /api/validator/stats           Validator stats

GET    /api/credit/score/:did         Get credit score
POST   /api/credit/event              Report credit event
POST   /api/credit/loans              Apply for loan
PUT    /api/credit/loans/:id/status   Update loan status

POST   /api/institution/verify-did    Verify DID (OAuth-style)
POST   /api/institution/qr-verify     Verify QR token

POST   /api/land/submit               Submit land record
GET    /api/land/:did                 Get land records
POST   /api/land/verify/:id           Verify land record
```

---

*Built with ❤️ for farmers who deserve financial inclusion.*
