// backend/src/routes/institution.js
// OAuth-style DID verification for banks/institutions
const router = require("express").Router();
const jwt = require("jsonwebtoken");
const { authenticate, requireRole } = require("../middleware/auth");
const blockchainService = require("../services/blockchain");
const { User, CreditRecord } = require("../models");

/**
 * POST /api/institution/verify-did
 * Banks call this to verify a farmer's identity
 * Returns sanitized identity proof without raw PII
 */
router.post("/verify-did", async (req, res) => {
  try {
    // Institutions use a separate API key header
    const apiKey = req.headers["x-api-key"];
    if (!apiKey || apiKey !== process.env.INSTITUTION_API_KEY) {
      return res.status(401).json({ error: "Invalid API key" });
    }

    const { did } = req.body;
    if (!did) return res.status(400).json({ error: "DID required" });

    // Verify on-chain
    const chainResult = await blockchainService.verifyIdentity(parseInt(did));
    
    if (!chainResult.active) {
      return res.status(404).json({ error: "DID not active or not found" });
    }

    // Get credit record
    const creditRecord = await CreditRecord.findOne({ did: parseInt(did) });

    // Generate short-lived verification token
    const verificationToken = jwt.sign(
      { did, verified: true, timestamp: Date.now() },
      process.env.JWT_SECRET,
      { expiresIn: "1h" }
    );

    res.json({
      verified: true,
      did,
      ipfsHash: chainResult.ipfsHash,          // institution can fetch & decrypt if they have key
      creditScoreHash: chainResult.creditHash,
      creditScore: creditRecord?.creditScore || null,
      activeSince: null,                         // omit PII
      verificationToken,
      expiresIn: 3600,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/institution/qr-verify
// Verify a QR-code scanned from farmer's phone
router.post("/qr-verify", async (req, res) => {
  try {
    const apiKey = req.headers["x-api-key"];
    if (!apiKey || apiKey !== process.env.INSTITUTION_API_KEY) {
      return res.status(401).json({ error: "Invalid API key" });
    }

    const { token } = req.body;
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    const chainResult = await blockchainService.verifyIdentity(decoded.did);

    res.json({
      verified: chainResult.active,
      did: decoded.did,
      timestamp: decoded.iat,
    });
  } catch (err) {
    res.status(401).json({ error: "Invalid or expired token" });
  }
});

module.exports = router;
