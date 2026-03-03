// backend/src/models/index.js
const mongoose = require("mongoose");
const { Schema } = mongoose;

// ─── User / Farmer ────────────────────────────────────────────────────────
const UserSchema = new Schema(
  {
    walletAddress:  { type: String, required: true, unique: true, lowercase: true },
    did:            { type: Number, default: null },          // on-chain DID id
    role:           { type: String, enum: ["farmer", "validator", "bank", "admin"], default: "farmer" },
    
    // Encrypted off-chain profile (AES-256 encrypted blob)
    encryptedProfile: { type: String },
    ipfsHash:         { type: String },                       // points to full encrypted doc
    
    // Biometric status (no raw biometrics stored)
    biometricHash:    { type: String },                       // hash of device biometric token
    biometricVerified:{ type: Boolean, default: false },
    
    // Identity status
    status: {
      type: String,
      enum: ["pending", "under_review", "active", "suspended", "rejected"],
      default: "pending",
    },
    approvalCount: { type: Number, default: 0 },
    nominatedValidators: [{ type: String }],                  // wallet addresses
    
    // Offline sync
    lastSyncAt:   { type: Date },
    pendingSync:  { type: Boolean, default: false },
    
    // Push notifications
    fcmToken: { type: String },
    
    // Recovery
    recoveryAddresses: [{ type: String }],
  },
  { timestamps: true }
);

// ─── Identity Document ────────────────────────────────────────────────────
const IdentityDocSchema = new Schema(
  {
    userId:     { type: Schema.Types.ObjectId, ref: "User", required: true },
    did:        { type: Number },
    ipfsHash:   { type: String, required: true },
    encryptedData: { type: String },                          // cached decrypted (server-side only, for sync)
    version:    { type: Number, default: 1 },
    checksum:   { type: String },
  },
  { timestamps: true }
);

// ─── Validator ────────────────────────────────────────────────────────────
const ValidatorSchema = new Schema(
  {
    userId:       { type: Schema.Types.ObjectId, ref: "User", required: true },
    walletAddress:{ type: String, required: true, unique: true },
    stakeAmount:  { type: String, default: "0" },             // in wei (string for bignum)
    isActive:     { type: Boolean, default: true },
    isSlashed:    { type: Boolean, default: false },
    
    totalApprovals: { type: Number, default: 0 },
    totalRejections:{ type: Number, default: 0 },
    fraudCount:     { type: Number, default: 0 },
    
    region:       { type: String },
    languages:    [{ type: String }],
    specialization: { type: String },                          // crops, livestock, fishery
  },
  { timestamps: true }
);

// ─── Approval Request ─────────────────────────────────────────────────────
const ApprovalSchema = new Schema(
  {
    did:           { type: Number, required: true },
    farmerAddress: { type: String, required: true },
    validatorAddress:{ type: String, required: true },
    
    status: {
      type: String,
      enum: ["pending", "approved", "rejected"],
      default: "pending",
    },
    
    notes:         { type: String },
    reviewedAt:    { type: Date },
    txHash:        { type: String },                          // on-chain approval tx
    
    // Supporting documents reviewed
    documentsReviewed: [{ type: String }],
  },
  { timestamps: true }
);

// ─── Credit Record ─────────────────────────────────────────────────────────
const CreditRecordSchema = new Schema(
  {
    userId:     { type: Schema.Types.ObjectId, ref: "User", required: true },
    did:        { type: Number, required: true },
    
    creditScore:{ type: Number, min: 300, max: 850 },
    ipfsHash:   { type: String },                             // on-chain pointer

    events: [
      {
        type:      { type: String, enum: ["loan_taken", "loan_repaid", "loan_default", "crop_sale", "land_verified"] },
        amount:    { type: Number },
        currency:  { type: String, default: "INR" },
        date:      { type: Date },
        institutionId: { type: String },
        description: { type: String },
        txHash:    { type: String },
      },
    ],
    
    lastUpdated: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

// ─── Loan Application ─────────────────────────────────────────────────────
const LoanSchema = new Schema(
  {
    farmerId:     { type: Schema.Types.ObjectId, ref: "User", required: true },
    did:          { type: Number, required: true },
    institutionId:{ type: String, required: true },
    
    amount:       { type: Number, required: true },
    currency:     { type: String, default: "INR" },
    purpose:      { type: String },
    term:         { type: Number },                           // months
    
    status: {
      type: String,
      enum: ["submitted", "under_review", "approved", "rejected", "disbursed", "repaid", "defaulted"],
      default: "submitted",
    },
    
    creditScoreAtApplication: { type: Number },
    interestRate:  { type: Number },
    approvedAmount:{ type: Number },
    disbursedAt:   { type: Date },
    dueDate:       { type: Date },
    repaidAt:      { type: Date },
    
    documents:    [{ type: String }],                         // IPFS hashes
    notes:        { type: String },
  },
  { timestamps: true }
);

// ─── Land Record ──────────────────────────────────────────────────────────
const LandRecordSchema = new Schema(
  {
    userId:     { type: Schema.Types.ObjectId, ref: "User", required: true },
    did:        { type: Number, required: true },
    
    photoHash:  { type: String, required: true },             // IPFS hash
    geoHash:    { type: String, required: true },
    coordinates:{ lat: Number, lng: Number },
    areaAcres:  { type: Number },
    cropType:   { type: String },
    
    verified:   { type: Boolean, default: false },
    verifiedBy: { type: String },                             // validator address
    verifiedAt: { type: Date },
    txHash:     { type: String },                             // on-chain record tx
    
    blockchainIndex: { type: Number },                        // index in contract array
  },
  { timestamps: true }
);

// ─── Sync Queue (offline-first support) ───────────────────────────────────
const SyncQueueSchema = new Schema(
  {
    userId:     { type: Schema.Types.ObjectId, ref: "User" },
    deviceId:   { type: String, required: true },
    action:     { type: String, required: true },             // e.g. "register", "approve", "addLand"
    payload:    { type: Schema.Types.Mixed },
    status:     { type: String, enum: ["pending", "processing", "done", "failed"], default: "pending" },
    attempts:   { type: Number, default: 0 },
    error:      { type: String },
    processedAt:{ type: Date },
  },
  { timestamps: true }
);

// ─── Exports ──────────────────────────────────────────────────────────────
module.exports = {
  User:         mongoose.model("User", UserSchema),
  IdentityDoc:  mongoose.model("IdentityDoc", IdentityDocSchema),
  Validator:    mongoose.model("Validator", ValidatorSchema),
  Approval:     mongoose.model("Approval", ApprovalSchema),
  CreditRecord: mongoose.model("CreditRecord", CreditRecordSchema),
  Loan:         mongoose.model("Loan", LoanSchema),
  LandRecord:   mongoose.model("LandRecord", LandRecordSchema),
  SyncQueue:    mongoose.model("SyncQueue", SyncQueueSchema),
};
