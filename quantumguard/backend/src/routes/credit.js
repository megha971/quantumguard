// backend/src/routes/credit.js
const router = require("express").Router();
const { authenticate, requireRole } = require("../middleware/auth");
const { CreditRecord, Loan, User } = require("../models");
const blockchainService = require("../services/blockchain");
const ipfsService = require("../services/ipfs");
const creditService = require("../services/creditScore");

// GET /api/credit/score/:did
router.get("/score/:did", authenticate, async (req, res) => {
  try {
    const did = parseInt(req.params.did);
    const record = await CreditRecord.findOne({ did });
    if (!record) return res.status(404).json({ error: "No credit record" });
    res.json({ did, score: record.creditScore, events: record.events, lastUpdated: record.lastUpdated });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/credit/event  — institution reports a credit event
router.post("/event", authenticate, requireRole("bank", "admin"), async (req, res) => {
  try {
    const { did, type, amount, currency, description, txHash } = req.body;

    let record = await CreditRecord.findOne({ did });
    if (!record) {
      const user = await User.findOne({ did });
      if (!user) return res.status(404).json({ error: "DID not found" });
      record = await CreditRecord.create({ userId: user._id, did, creditScore: 500, events: [] });
    }

    record.events.push({ type, amount, currency, date: new Date(), institutionId: req.user.walletAddress, description, txHash });
    record.creditScore = creditService.recalculate(record.events);
    record.lastUpdated = new Date();

    // Upload updated record to IPFS
    const ipfsHash = await ipfsService.uploadJSON({ did, score: record.creditScore, events: record.events });
    record.ipfsHash = ipfsHash;
    await record.save();

    // Update on-chain credit hash
    await blockchainService.updateCreditScore(did, ipfsHash, req.user.walletAddress);

    res.json({ success: true, newScore: record.creditScore, ipfsHash });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/credit/loans/:did
router.get("/loans/:did", authenticate, async (req, res) => {
  try {
    const loans = await Loan.find({ did: parseInt(req.params.did) }).sort("-createdAt");
    res.json({ loans });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/credit/loans  — farmer applies for loan
router.post("/loans", authenticate, requireRole("farmer"), async (req, res) => {
  try {
    const { amount, currency, purpose, term, institutionId } = req.body;
    const user = req.user;

    if (!user.did || user.status !== "active") {
      return res.status(400).json({ error: "Active DID required for loan application" });
    }

    const creditRecord = await CreditRecord.findOne({ did: user.did });
    const loan = await Loan.create({
      farmerId: user._id,
      did: user.did,
      institutionId,
      amount, currency, purpose, term,
      creditScoreAtApplication: creditRecord?.creditScore || 0,
      status: "submitted",
    });

    res.json({ success: true, loanId: loan._id, status: "submitted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/credit/loans/:id/status  — bank approves/rejects loan
router.put("/loans/:id/status", authenticate, requireRole("bank", "admin"), async (req, res) => {
  try {
    const { status, approvedAmount, interestRate, notes } = req.body;
    const loan = await Loan.findByIdAndUpdate(
      req.params.id,
      { status, approvedAmount, interestRate, notes, ...(status === "disbursed" ? { disbursedAt: new Date() } : {}) },
      { new: true }
    );
    if (!loan) return res.status(404).json({ error: "Loan not found" });
    res.json({ success: true, loan });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

// ─── Institution Routes ────────────────────────────────────────────────────
// backend/src/routes/institution.js — separate file content follows:
