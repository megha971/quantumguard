// backend/src/routes/identity.js
const router = require("express").Router();
const multer = require("multer");
const { authenticate, requireRole } = require("../middleware/auth");
const { User, IdentityDoc, SyncQueue } = require("../models");
const ipfsService = require("../services/ipfs");
const blockchainService = require("../services/blockchain");
const { encryptData, decryptData } = require("../utils/crypto");

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } });

// POST /api/identity/register
// Step 1: Upload encrypted identity + trigger blockchain registration
router.post("/register", authenticate, upload.single("document"), async (req, res) => {
  try {
    const { encryptedProfile, nominatedValidators, recoveryAddresses, biometricHash } = req.body;

    if (!encryptedProfile || !nominatedValidators) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    const validators = JSON.parse(nominatedValidators);
    const recovery = JSON.parse(recoveryAddresses || "[]");

    if (validators.length < 3) {
      return res.status(400).json({ error: "Minimum 3 validators required" });
    }

    // Upload encrypted profile to IPFS
    const ipfsHash = await ipfsService.uploadJSON({
      encryptedProfile,
      timestamp: Date.now(),
      version: 1,
    });

    // Update user profile
    const user = await User.findByIdAndUpdate(
      req.user._id,
      {
        encryptedProfile,
        ipfsHash,
        biometricHash: biometricHash || null,
        biometricVerified: !!biometricHash,
        nominatedValidators: validators,
        recoveryAddresses: recovery,
        status: "under_review",
      },
      { new: true }
    );

    // Create IdentityDoc
    await IdentityDoc.create({
      userId: user._id,
      ipfsHash,
      version: 1,
    });

    // Register on blockchain
    const tx = await blockchainService.registerIdentity(
      user.walletAddress,
      ipfsHash,
      validators,
      recovery
    );

    // Update DID from tx receipt
    const did = tx.events?.DIDRegistered?.returnValues?.did;
    if (did) {
      await User.findByIdAndUpdate(user._id, { did: parseInt(did) });
    }

    res.json({
      success: true,
      ipfsHash,
      txHash: tx.transactionHash,
      did,
      status: "under_review",
    });
  } catch (err) {
    console.error("Registration error:", err);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/identity/me
router.get("/me", authenticate, async (req, res) => {
  try {
    const user = req.user;
    res.json({
      id: user._id,
      walletAddress: user.walletAddress,
      did: user.did,
      status: user.status,
      ipfsHash: user.ipfsHash,
      approvalCount: user.approvalCount,
      nominatedValidators: user.nominatedValidators,
      biometricVerified: user.biometricVerified,
      createdAt: user.createdAt,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/identity/:did
// Public endpoint for DID lookup
router.get("/:did", async (req, res) => {
  try {
    const did = parseInt(req.params.did);
    const result = await blockchainService.verifyIdentity(did);
    
    res.json({
      did,
      active: result.active,
      ipfsHash: result.ipfsHash,
      creditScoreHash: result.creditHash,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/identity/sync
// Offline sync: process queued actions from mobile
router.post("/sync", authenticate, async (req, res) => {
  try {
    const { actions, deviceId } = req.body;
    const results = [];

    for (const action of actions || []) {
      const queueItem = await SyncQueue.create({
        userId: req.user._id,
        deviceId,
        action: action.type,
        payload: action.payload,
        status: "pending",
      });
      results.push({ id: queueItem._id, action: action.type });
    }

    // Process sync queue asynchronously
    processSyncQueue(req.user._id);

    await User.findByIdAndUpdate(req.user._id, {
      lastSyncAt: new Date(),
      pendingSync: false,
    });

    res.json({ synced: results.length, items: results });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/identity/update-ipfs
// Update IPFS hash (e.g. after profile update)
router.put("/update", authenticate, async (req, res) => {
  try {
    const { encryptedProfile } = req.body;
    
    if (req.user.status !== "active") {
      return res.status(400).json({ error: "Identity not active" });
    }

    const ipfsHash = await ipfsService.uploadJSON({ encryptedProfile, timestamp: Date.now(), version: 2 });
    
    await User.findByIdAndUpdate(req.user._id, { encryptedProfile, ipfsHash });

    res.json({ success: true, ipfsHash });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Internal: process pending sync queue
async function processSyncQueue(userId) {
  const pending = await SyncQueue.find({ userId, status: "pending" }).limit(50);
  for (const item of pending) {
    try {
      item.status = "processing";
      item.attempts++;
      await item.save();

      // Handle different action types
      switch (item.action) {
        case "addLandRecord":
          await blockchainService.addLandRecord(item.payload.did, item.payload.photoHash, item.payload.geoHash);
          break;
        case "approveIdentity":
          // handled by validator route
          break;
        default:
          console.warn("Unknown sync action:", item.action);
      }

      item.status = "done";
      item.processedAt = new Date();
      await item.save();
    } catch (err) {
      item.status = "failed";
      item.error = err.message;
      await item.save();
    }
  }
}

module.exports = router;
