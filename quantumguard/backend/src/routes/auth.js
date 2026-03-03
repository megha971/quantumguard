// backend/src/routes/auth.js
const router = require("express").Router();
const jwt = require("jsonwebtoken");
const { ethers } = require("ethers");
const { User } = require("../models");

// GET /api/auth/nonce/:address
// Returns a nonce for the wallet to sign
router.get("/nonce/:address", async (req, res) => {
  try {
    const address = req.params.address.toLowerCase();
    const nonce = Math.floor(Math.random() * 1000000).toString();
    
    // Store nonce temporarily (use Redis in production)
    await User.findOneAndUpdate(
      { walletAddress: address },
      { $set: { _nonce: nonce, _nonceExpiry: Date.now() + 300000 } },
      { upsert: true, new: true }
    );

    res.json({ nonce, message: `Sign this nonce to authenticate: ${nonce}` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/auth/verify
// Verify wallet signature and return JWT
router.post("/verify", async (req, res) => {
  try {
    const { address, signature, nonce } = req.body;
    if (!address || !signature || !nonce) {
      return res.status(400).json({ error: "Missing fields" });
    }

    const normalizedAddress = address.toLowerCase();

    // Verify signature
    const message = `Sign this nonce to authenticate: ${nonce}`;
    const recoveredAddress = ethers.utils.verifyMessage(message, signature);
    
    if (recoveredAddress.toLowerCase() !== normalizedAddress) {
      return res.status(401).json({ error: "Invalid signature" });
    }

    // Find/create user
    let user = await User.findOne({ walletAddress: normalizedAddress });
    if (!user) {
      user = await User.create({ walletAddress: normalizedAddress });
    }

    // Clear nonce
    user._nonce = undefined;
    user._nonceExpiry = undefined;
    await user.save();

    const token = jwt.sign(
      { userId: user._id, role: user.role, address: normalizedAddress },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    res.json({
      token,
      user: {
        id: user._id,
        walletAddress: user.walletAddress,
        did: user.did,
        role: user.role,
        status: user.status,
      },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/auth/refresh
router.post("/refresh", async (req, res) => {
  try {
    const { token } = req.body;
    const decoded = jwt.verify(token, process.env.JWT_SECRET, { ignoreExpiration: true });
    
    // Only refresh if within 30 days of expiry
    const now = Math.floor(Date.now() / 1000);
    if (now - decoded.exp > 30 * 24 * 3600) {
      return res.status(401).json({ error: "Token too old to refresh" });
    }

    const user = await User.findById(decoded.userId);
    if (!user) return res.status(401).json({ error: "User not found" });

    const newToken = jwt.sign(
      { userId: user._id, role: user.role, address: user.walletAddress },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    res.json({ token: newToken });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
