// backend/src/app.js
require("dotenv").config();
const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const morgan = require("morgan");

const authRoutes = require("./routes/auth");
const identityRoutes = require("./routes/identity");
const validatorRoutes = require("./routes/validator");
const creditRoutes = require("./routes/credit");
const institutionRoutes = require("./routes/institution");
const landRoutes = require("./routes/land");

const app = express();

// ─── Security Middleware ──────────────────────────────────────────────────
app.use(helmet());
app.use(cors({ origin: process.env.ALLOWED_ORIGINS?.split(",") || "*" }));
app.use(express.json({ limit: "10mb" }));
app.use(morgan("combined"));

// Rate limiting
const limiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 100 });
app.use("/api/", limiter);

// ─── Routes ──────────────────────────────────────────────────────────────
app.use("/api/auth",        authRoutes);
app.use("/api/identity",    identityRoutes);
app.use("/api/validator",   validatorRoutes);
app.use("/api/credit",      creditRoutes);
app.use("/api/institution", institutionRoutes);
app.use("/api/land",        landRoutes);

// Health check
app.get("/health", (req, res) => res.json({ status: "ok", timestamp: new Date() }));

// ─── Error Handler ────────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    error: process.env.NODE_ENV === "production" ? "Internal server error" : err.message,
  });
});

// ─── Database + Server ───────────────────────────────────────────────────
mongoose
  .connect(process.env.MONGODB_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  })
  .then(() => {
    console.log("MongoDB connected");
    const PORT = process.env.PORT || 3001;
    app.listen(PORT, () => console.log(`QuantumGuard API running on :${PORT}`));
  })
  .catch((err) => {
    console.error("DB connection failed:", err);
    process.exit(1);
  });

module.exports = app;
