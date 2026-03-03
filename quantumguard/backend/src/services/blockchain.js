// backend/src/services/blockchain.js
const { ethers } = require("ethers");
const QuantumGuardABI = require("../../abis/QuantumGuardDID.json");

let provider, wallet, contract;

const init = () => {
  if (contract) return;
  
  provider = new ethers.providers.JsonRpcProvider(
    process.env.POLYGON_RPC_URL || "https://rpc-amoy.polygon.technology"
  );
  
  wallet = new ethers.Wallet(process.env.BACKEND_PRIVATE_KEY, provider);
  
  contract = new ethers.Contract(
    process.env.QG_DID_ADDRESS,
    QuantumGuardABI,
    wallet
  );
};

// Gas options optimized for Polygon
const gasOpts = () => ({
  maxFeePerGas: ethers.utils.parseUnits("50", "gwei"),
  maxPriorityFeePerGas: ethers.utils.parseUnits("30", "gwei"),
});

const registerIdentity = async (ownerAddress, ipfsHash, validators, recoveryAddrs) => {
  init();
  // Backend submits on behalf of farmer (can also be done client-side)
  const tx = await contract.registerIdentity(
    ipfsHash,
    validators,
    recoveryAddrs,
    { ...gasOpts() }
  );
  return tx.wait();
};

const approveIdentity = async (did, validatorAddress) => {
  init();
  // In production, validator signs + submits themselves via frontend
  const tx = await contract.approveIdentity(did, { ...gasOpts() });
  return tx.wait();
};

const verifyIdentity = async (did) => {
  init();
  const result = await contract.verifyIdentity(did);
  return {
    active: result.active,
    ipfsHash: result.ipfsHash,
    creditHash: result.creditHash,
  };
};

const getIdentity = async (did) => {
  init();
  return contract.getIdentity(did);
};

const addLandRecord = async (did, photoHash, geoHash) => {
  init();
  const tx = await contract.addLandRecord(photoHash, geoHash, { ...gasOpts() });
  return tx.wait();
};

const verifyLandRecord = async (did, index, validatorAddress) => {
  init();
  const tx = await contract.verifyLandRecord(did, index, { ...gasOpts() });
  return tx.wait();
};

const updateCreditScore = async (did, newHash, institutionAddress) => {
  init();
  const tx = await contract.updateCreditScore(did, newHash, { ...gasOpts() });
  return tx.wait();
};

const getValidatorInfo = async (address) => {
  init();
  return contract.validatorInfo(address);
};

const stakeAsValidator = async (amount) => {
  init();
  const tx = await contract.stakeAsValidator({
    value: ethers.utils.parseEther(amount),
    ...gasOpts(),
  });
  return tx.wait();
};

module.exports = {
  registerIdentity,
  approveIdentity,
  verifyIdentity,
  getIdentity,
  addLandRecord,
  verifyLandRecord,
  updateCreditScore,
  getValidatorInfo,
  stakeAsValidator,
};
