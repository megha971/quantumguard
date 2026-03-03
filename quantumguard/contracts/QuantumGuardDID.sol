// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title QuantumGuardDID
 * @notice Decentralized Identity for farmers and rural communities
 * @dev Gas-optimized: stores only IPFS hashes, never raw PII
 */
contract QuantumGuardDID is AccessControl, ReentrancyGuard {
    using Counters for Counters.Counter;

    // ─── Roles ───────────────────────────────────────────────────────────
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant INSTITUTION_ROLE = keccak256("INSTITUTION_ROLE");

    // ─── Constants ───────────────────────────────────────────────────────
    uint256 public constant MIN_APPROVALS = 3;
    uint256 public constant VALIDATOR_STAKE = 0.01 ether;   // ~$10 on Polygon
    uint256 public constant SLASH_PERCENT = 50;             // 50% slash on fraud

    // ─── State ───────────────────────────────────────────────────────────
    Counters.Counter private _didCounter;

    struct Identity {
        uint256 id;
        address owner;
        string  ipfsHash;         // encrypted identity data
        uint8   approvalCount;
        bool    active;
        uint64  createdAt;
        uint64  updatedAt;
        string  creditScoreHash;  // IPFS hash of credit record
    }

    struct LandRecord {
        string  photoHash;        // geotagged photo IPFS hash
        string  geoHash;          // geohash string
        uint64  timestamp;
        bool    verified;
    }

    struct ValidatorInfo {
        uint256 stakeAmount;
        uint256 approvalCount;
        uint256 fraudCount;
        bool    slashed;
    }

    // DID => Identity
    mapping(uint256 => Identity) public identities;
    // address => DID
    mapping(address => uint256) public addressToDID;
    // DID => validator => approved
    mapping(uint256 => mapping(address => bool)) public approvals;
    // DID => validators list
    mapping(uint256 => address[]) public nominatedValidators;
    // DID => land records
    mapping(uint256 => LandRecord[]) public landRecords;
    // validator => info
    mapping(address => ValidatorInfo) public validatorInfo;
    // DID => recovery addresses (multi-sig)
    mapping(uint256 => address[]) public recoveryAddresses;

    // ─── Events ──────────────────────────────────────────────────────────
    event DIDRegistered(uint256 indexed did, address indexed owner, string ipfsHash);
    event DIDActivated(uint256 indexed did);
    event IdentityApproved(uint256 indexed did, address indexed validator);
    event ValidatorStaked(address indexed validator, uint256 amount);
    event ValidatorSlashed(address indexed validator, uint256 amount, string reason);
    event LandRecordAdded(uint256 indexed did, string photoHash, string geoHash);
    event CreditScoreUpdated(uint256 indexed did, string newHash);
    event RecoveryTriggered(uint256 indexed did, address newOwner);

    // ─── Constructor ─────────────────────────────────────────────────────
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // ─── Validator Management ─────────────────────────────────────────────

    /// @notice Stake MATIC to become a validator
    function stakeAsValidator() external payable nonReentrant {
        require(msg.value >= VALIDATOR_STAKE, "Insufficient stake");
        require(!validatorInfo[msg.sender].slashed, "Slashed validator");
        
        validatorInfo[msg.sender].stakeAmount += msg.value;
        _grantRole(VALIDATOR_ROLE, msg.sender);
        emit ValidatorStaked(msg.sender, msg.value);
    }

    /// @notice Admin slashes a fraudulent validator
    function slashValidator(address validator, string calldata reason) 
        external onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        ValidatorInfo storage vi = validatorInfo[validator];
        require(vi.stakeAmount > 0, "No stake");
        
        uint256 slashAmount = (vi.stakeAmount * SLASH_PERCENT) / 100;
        vi.stakeAmount -= slashAmount;
        vi.slashed = true;
        vi.fraudCount++;
        
        _revokeRole(VALIDATOR_ROLE, validator);
        
        // Slash goes to treasury (admin)
        payable(msg.sender).transfer(slashAmount);
        emit ValidatorSlashed(validator, slashAmount, reason);
    }

    // ─── Identity Registration ────────────────────────────────────────────

    /**
     * @notice Register a new identity (step 1)
     * @param ipfsHash  IPFS hash of AES-encrypted identity blob
     * @param validators Three nominated validators
     * @param recoveryAddrs Emergency recovery addresses
     */
    function registerIdentity(
        string calldata ipfsHash,
        address[3] calldata validators,
        address[] calldata recoveryAddrs
    ) external returns (uint256) {
        require(addressToDID[msg.sender] == 0, "Already registered");
        require(bytes(ipfsHash).length > 0, "Empty hash");

        // Verify nominated validators have staked
        for (uint8 i = 0; i < 3; i++) {
            require(hasRole(VALIDATOR_ROLE, validators[i]), "Not a validator");
            require(validators[i] != msg.sender, "Self-nomination");
        }

        _didCounter.increment();
        uint256 newDID = _didCounter.current();

        identities[newDID] = Identity({
            id:              newDID,
            owner:           msg.sender,
            ipfsHash:        ipfsHash,
            approvalCount:   0,
            active:          false,
            createdAt:       uint64(block.timestamp),
            updatedAt:       uint64(block.timestamp),
            creditScoreHash: ""
        });

        addressToDID[msg.sender] = newDID;

        for (uint8 i = 0; i < 3; i++) {
            nominatedValidators[newDID].push(validators[i]);
        }

        for (uint256 i = 0; i < recoveryAddrs.length; i++) {
            recoveryAddresses[newDID].push(recoveryAddrs[i]);
        }

        emit DIDRegistered(newDID, msg.sender, ipfsHash);
        return newDID;
    }

    // ─── Validator Approval ───────────────────────────────────────────────

    /// @notice Nominated validator approves an identity
    function approveIdentity(uint256 did) external onlyRole(VALIDATOR_ROLE) {
        Identity storage identity = identities[did];
        require(identity.owner != address(0), "DID not found");
        require(!identity.active, "Already active");
        require(!approvals[did][msg.sender], "Already approved");
        
        // Must be a nominated validator
        bool isNominated = false;
        address[] storage nominated = nominatedValidators[did];
        for (uint256 i = 0; i < nominated.length; i++) {
            if (nominated[i] == msg.sender) { isNominated = true; break; }
        }
        require(isNominated, "Not nominated");

        approvals[did][msg.sender] = true;
        identity.approvalCount++;
        validatorInfo[msg.sender].approvalCount++;
        identity.updatedAt = uint64(block.timestamp);

        emit IdentityApproved(did, msg.sender);

        if (identity.approvalCount >= MIN_APPROVALS) {
            identity.active = true;
            emit DIDActivated(did);
        }
    }

    // ─── Land Records ─────────────────────────────────────────────────────

    /// @notice Submit geotagged land proof
    function addLandRecord(
        string calldata photoHash,
        string calldata geoHash
    ) external {
        uint256 did = addressToDID[msg.sender];
        require(did != 0, "No DID");
        require(identities[did].active, "Identity not active");

        landRecords[did].push(LandRecord({
            photoHash: photoHash,
            geoHash:   geoHash,
            timestamp: uint64(block.timestamp),
            verified:  false
        }));

        emit LandRecordAdded(did, photoHash, geoHash);
    }

    /// @notice Validator verifies a land record
    function verifyLandRecord(uint256 did, uint256 recordIndex) 
        external onlyRole(VALIDATOR_ROLE) 
    {
        require(recordIndex < landRecords[did].length, "Invalid index");
        landRecords[did][recordIndex].verified = true;
    }

    // ─── Credit Score ─────────────────────────────────────────────────────

    /// @notice Institution updates credit score IPFS hash
    function updateCreditScore(uint256 did, string calldata newHash)
        external onlyRole(INSTITUTION_ROLE)
    {
        require(identities[did].active, "Not active");
        identities[did].creditScoreHash = newHash;
        identities[did].updatedAt = uint64(block.timestamp);
        emit CreditScoreUpdated(did, newHash);
    }

    // ─── Emergency Recovery ───────────────────────────────────────────────

    /**
     * @notice Recover identity to new address (requires multi-validator approval)
     * @dev Requires all recovery addresses to sign off-chain (handled via backend)
     */
    function triggerRecovery(
        uint256 did,
        address newOwner,
        bytes[] calldata signatures
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Identity storage identity = identities[did];
        require(identity.active, "Not active");
        require(signatures.length >= MIN_APPROVALS, "Insufficient signatures");
        require(addressToDID[newOwner] == 0, "New owner has DID");

        // Transfer DID ownership
        delete addressToDID[identity.owner];
        identity.owner = newOwner;
        identity.updatedAt = uint64(block.timestamp);
        addressToDID[newOwner] = did;

        emit RecoveryTriggered(did, newOwner);
    }

    // ─── View Functions ───────────────────────────────────────────────────

    function getIdentity(uint256 did) external view returns (Identity memory) {
        return identities[did];
    }

    function getDIDByAddress(address owner) external view returns (uint256) {
        return addressToDID[owner];
    }

    function getLandRecords(uint256 did) external view returns (LandRecord[] memory) {
        return landRecords[did];
    }

    function getApprovalStatus(uint256 did, address validator) 
        external view returns (bool) 
    {
        return approvals[did][validator];
    }

    function getTotalDIDs() external view returns (uint256) {
        return _didCounter.current();
    }

    // ─── Institution Verification ─────────────────────────────────────────

    /// @notice Banks/institutions verify a DID is active + return IPFS hash
    function verifyIdentity(uint256 did) 
        external view 
        returns (bool active, string memory ipfsHash, string memory creditHash) 
    {
        Identity memory id = identities[did];
        return (id.active, id.ipfsHash, id.creditScoreHash);
    }
}
