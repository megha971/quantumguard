// backend/src/routes/land.js
const router = require("express").Router();
const multer = require("multer");
const { authenticate, requireRole } = require("../middleware/auth");
const { LandRecord, User } = require("../models");
const ipfsService = require("../services/ipfs");
const blockchainService = require("../services/blockchain");

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

// POST /api/land/submit  — farmer submits geotagged photo
router.post("/submit", authenticate, requireRole("farmer"), upload.single("photo"), async (req, res) => {
  try {
    const { geoHash, lat, lng, areaAcres, cropType } = req.body;
    const user = req.user;

    if (!user.did || user.status !== "active") {
      return res.status(400).json({ error: "Active DID required" });
    }

    if (!req.file) return res.status(400).json({ error: "Photo required" });

    // Upload photo to IPFS
    const photoHash = await ipfsService.uploadBuffer(req.file.buffer, req.file.mimetype);

    // Save to MongoDB
    const record = await LandRecord.create({
      userId: user._id,
      did: user.did,
      photoHash,
      geoHash,
      coordinates: { lat: parseFloat(lat), lng: parseFloat(lng) },
      areaAcres: parseFloat(areaAcres) || null,
      cropType,
    });

    // Submit on-chain
    const tx = await blockchainService.addLandRecord(user.did, photoHash, geoHash);
    
    // Get index from event
    const blockchainIndex = tx.events?.LandRecordAdded ? 0 : null;
    await LandRecord.findByIdAndUpdate(record._id, { txHash: tx.transactionHash, blockchainIndex });

    res.json({ success: true, photoHash, txHash: tx.transactionHash, recordId: record._id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/land/:did
router.get("/:did", authenticate, async (req, res) => {
  try {
    const records = await LandRecord.find({ did: parseInt(req.params.did) }).sort("-createdAt");
    res.json({ records });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/land/verify/:id  — validator verifies a land record
router.post("/verify/:id", authenticate, requireRole("validator", "admin"), async (req, res) => {
  try {
    const record = await LandRecord.findById(req.params.id);
    if (!record) return res.status(404).json({ error: "Record not found" });

    // Verify on-chain
    const tx = await blockchainService.verifyLandRecord(record.did, record.blockchainIndex, req.user.walletAddress);

    await LandRecord.findByIdAndUpdate(record._id, {
      verified: true,
      verifiedBy: req.user.walletAddress,
      verifiedAt: new Date(),
      txHash: tx.transactionHash,
    });

    res.json({ success: true, txHash: tx.transactionHash });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
