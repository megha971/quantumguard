// backend/src/routes/validator.js
const router = require("express").Router();
const { authenticate, requireRole } = require("../middleware/auth");
const { User, Validator, Approval } = require("../models");
const blockchainService = require("../services/blockchain");

// GET /api/validator/queue  — pending approvals for this validator
router.get("/queue", authenticate, requireRole("validator", "admin"), async (req, res) => {
  try {
    const pending = await Approval.find({
      validatorAddress: req.user.walletAddress,
      status: "pending",
    }).populate("farmerAddress");

    // Enrich with on-chain status
    const enriched = await Promise.all(
      pending.map(async (a) => {
        const identity = await blockchainService.getIdentity(a.did).catch(() => null);
        return { ...a.toObject(), onChain: identity };
      })
    );

    res.json({ queue: enriched });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/validator/approve
router.post("/approve", authenticate, requireRole("validator", "admin"), async (req, res) => {
  try {
    const { did, notes } = req.body;

    // Record approval
    const approval = await Approval.findOneAndUpdate(
      { did, validatorAddress: req.user.walletAddress },
      { status: "approved", notes, reviewedAt: new Date() },
      { upsert: true, new: true }
    );

    // Submit on-chain approval
    const tx = await blockchainService.approveIdentity(did, req.user.walletAddress);
    approval.txHash = tx.transactionHash;
    await approval.save();

    // Update farmer approval count
    await User.findOneAndUpdate(
      { did },
      { $inc: { approvalCount: 1 } }
    );

    res.json({ success: true, txHash: tx.transactionHash });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/validator/reject
router.post("/reject", authenticate, requireRole("validator", "admin"), async (req, res) => {
  try {
    const { did, reason } = req.body;

    await Approval.findOneAndUpdate(
      { did, validatorAddress: req.user.walletAddress },
      { status: "rejected", notes: reason, reviewedAt: new Date() },
      { upsert: true, new: true }
    );

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/validator/stats
router.get("/stats", authenticate, requireRole("validator", "admin"), async (req, res) => {
  try {
    const stats = await Validator.findOne({ walletAddress: req.user.walletAddress });
    const chainInfo = await blockchainService.getValidatorInfo(req.user.walletAddress);
    res.json({ db: stats, onChain: chainInfo });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
