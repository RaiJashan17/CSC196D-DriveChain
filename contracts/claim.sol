// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract claim {
    // Set current user to owner
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }
    constructor() {
        owner = msg.sender;

        _tierCap[1]  = 1000;
        _tierCap[2]  = 5000;
        _tierCap[3]  = 10000;
        _tierCap[4]  = 25000;
        _tierCap[5]  = 50000;
        _tierCap[6]  = 100000;
        _tierCap[7]  = 250000;
        _tierCap[8]  = 1000000;
        _tierCap[9]  = 5000000;
        _tierCap[10] = 10000000;
    }
    // Enums
    enum Status {
        Submitted,          // 0
        SeverityProposed,   // 1
        SeverityFinalized,  // 2
        QuoteSubmitted,     // 3
        PayoutApproved,     // 4
        Denied,             // 5
        Paid,               // 6
        Closed              // 7
    }

    enum IncidentType { 
        Collision,       // 0
        Theft,           // 1
        Vandalism,       // 2
        Weather,         // 3
        Other            // 4
    }    

    // Parameters of Claim
    struct Claim {
        // Core identifiers
        bytes8  claimCode;
        address claimant;
        uint64  createdAt;

        // Parties & roles
        address adjuster;
        address shop;
        address payee;

        // Status & timestamps
        Status  status;
        uint64  submittedAt;
        uint64  severityProposedAt;
        uint64  severityFinalizedAt;
        uint64  quoteSubmittedAt;
        uint64  approvedAt;
        uint64  paidAt;
        uint64  closedAt;

        // Incident metadata
        uint64       incidentAt;
        string       incidentAddress;
        string       description;
        IncidentType incidentType;

        // AI severity proposal
        uint8   aiTier;        
        uint128 aiCapAmount;   
        bytes32 aiProofRef;
        address aiSigner;

        // Adjuster decision
        uint128 finalCapAmount;
        bytes32 adjusterNotesRef;
        bool    isCapLocked;

        // Repair quote
        uint128 quoteAmount;
        bytes32 quoteRef;

        // Payout planning & settlement
        uint128 approvedAmount;
        uint256 escrowId;
        bool    payoutToShop;
        bytes32 payoutTxRef;
    }   

    mapping(bytes8 => Claim) private _claims;
    mapping(bytes8 => bool)  private _usedCodes;
    mapping(uint8 => uint128) private _tierCap;

    event ClaimSubmitted(
        bytes8  indexed claimCode,
        address indexed claimant,
        uint64 incidentAt,
        string incidentAddress,
        string description,
        IncidentType incidentType
    );
    event AdjusterAssigned(bytes8 indexed claimCode, address indexed adjuster);
    event SeverityProposed(bytes8 indexed claimCode, uint8 aiTier, uint128 aiCapAmount, address indexed aiSigner, bytes32 aiProofRef);
    event SeverityFinalized(bytes8 indexed claimCode, uint128 finalCapAmount, address indexed adjuster, bytes32 notesRef, bool locked);
    event QuoteSubmitted(bytes8 indexed claimCode, address indexed shop, uint128 quoteAmount, bytes32 quoteRef, address quoteCurrency);
    event PayoutApproved(bytes8 indexed claimCode, address indexed payee, uint128 approvedAmount, address payoutCurrency, uint256 escrowId, bool toShop);
    event ClaimDenied(bytes8 indexed claimCode, uint8 reasonCode);
    event ClaimPaid(bytes8 indexed claimCode, address indexed payee, uint128 amount, bytes32 payoutTxRef);
    event ClaimClosed(bytes8 indexed claimCode);

    function setTierCap(uint8 tier, uint128 cap) external onlyOwner {
        require(tier >= 1 && tier <= 10, "tier out of range");
        require(cap > 0, "cap=0");
        _tierCap[tier] = cap;
    }

    function getTierCap(uint8 tier) external view returns (uint128) {
        require(tier >= 1 && tier <= 10, "tier out of range");
        return _tierCap[tier];
    }

    function setAdjuster(bytes8 claimCode, address adjuster) external onlyOwner {
        Claim storage c = _claims[claimCode];
        require(c.claimCode != bytes8(0), "no such claim");
        c.adjuster = adjuster;
        emit AdjusterAssigned(claimCode, adjuster);
    }

    function createClaim(
        bytes8       claimCode,
        uint64       incidentAt,
        string calldata incidentAddress,
        string calldata description,
        IncidentType incidentType
    ) external onlyOwner returns (bytes8) {
        require(_isValidClaimCode(claimCode), "invalid code");
        require(!_usedCodes[claimCode], "code already used");
        _usedCodes[claimCode] = true;

        Claim storage c = _claims[claimCode];

        c.claimCode = claimCode;
        c.claimant  = owner;
        c.createdAt = uint64(block.timestamp);

        c.status      = Status.Submitted;
        c.submittedAt = uint64(block.timestamp);

        c.incidentAt      = incidentAt;
        c.incidentAddress = incidentAddress;
        c.description     = description;
        c.incidentType    = incidentType;

        // For demo, you play all parties
        c.adjuster = owner;
        c.shop     = owner;
        c.payee    = owner;

        emit ClaimSubmitted(claimCode, c.claimant, incidentAt, incidentAddress, description, incidentType);
        return claimCode;
    }

    function proposeSeverity(
        bytes8  claimCode,
        uint8   aiTier,
        bytes32 aiProofRef
    ) external onlyOwner {
        Claim storage c = _claims[claimCode];
        require(c.claimCode != bytes8(0), "no such claim");
        require(c.status == Status.Submitted || c.status == Status.SeverityProposed, "bad status");
        require(aiTier >= 1 && aiTier <= 10, "tier out of range");

        uint128 cap = _tierCap[aiTier];
        require(cap > 0, "cap not set");

        c.aiTier      = aiTier;
        c.aiCapAmount = cap;
        c.aiProofRef  = aiProofRef;
        c.aiSigner    = owner;
        c.severityProposedAt = uint64(block.timestamp);
        c.status = Status.SeverityProposed;

        emit SeverityProposed(claimCode, aiTier, cap, owner, aiProofRef);
    }

    function adjusterConfirmSeverity(
        bytes8  claimCode,
        uint128 finalCapAmount,
        bytes32 notesRef,
        bool    lockCap
    ) external onlyOwner {
        Claim storage c = _claims[claimCode];
        require(c.claimCode != bytes8(0), "no such claim");
        require(c.status == Status.SeverityProposed || c.status == Status.SeverityFinalized, "bad status");
        require(finalCapAmount > 0, "cap=0");
        require(finalCapAmount <= c.aiCapAmount, "final cap > AI cap");

        c.finalCapAmount      = finalCapAmount;
        c.adjusterNotesRef    = notesRef;
        c.severityFinalizedAt = uint64(block.timestamp);
        c.status              = Status.SeverityFinalized;

        if (lockCap) c.isCapLocked = true;

        emit SeverityFinalized(claimCode, finalCapAmount, c.adjuster, notesRef, lockCap);
    }

    function submitRepairQuote(
        bytes8  claimCode,
        uint128 quoteAmount,
        bytes32 quoteRef,
        address quoteCurrency
    ) external onlyOwner {
        Claim storage c = _claims[claimCode];
        require(c.claimCode != bytes8(0), "no such claim");
        require(c.status == Status.SeverityFinalized || c.status == Status.QuoteSubmitted, "bad status");
        require(quoteAmount > 0, "quote=0");

        if (c.shop == address(0)) c.shop = owner;

        c.quoteAmount      = quoteAmount;
        c.quoteRef         = quoteRef;
        c.quoteCurrency    = quoteCurrency;
        c.quoteSubmittedAt = uint64(block.timestamp);
        c.status           = Status.QuoteSubmitted;

        emit QuoteSubmitted(claimCode, c.shop, quoteAmount, quoteRef, quoteCurrency);
    }

    function approvePayout(
        bytes8  claimCode,
        address payee,
        uint128 amount,
        address payoutCurrency,
        uint256 escrowId,
        bool    payoutToShop
    ) external onlyOwner {
        Claim storage c = _claims[claimCode];
        require(c.claimCode != bytes8(0), "no such claim");
        require(c.status == Status.QuoteSubmitted, "bad status");
        require(amount > 0, "amount=0");
        require(amount <= c.finalCapAmount, "over final cap");
        require(amount <= c.quoteAmount, "over quote");

        c.approvedAmount = amount;
        c.payoutCurrency = payoutCurrency;
        c.escrowId       = escrowId;
        c.payoutToShop   = payoutToShop;
        c.payee          = payee == address(0) ? owner : payee;
        c.approvedAt     = uint64(block.timestamp);
        c.status         = Status.PayoutApproved;

        emit PayoutApproved(claimCode, c.payee, amount, payoutCurrency, escrowId, payoutToShop);
    }

    function markPaid(bytes8 claimCode, bytes32 payoutTxRef) external onlyOwner {
        Claim storage c = _claims[claimCode];
        require(c.claimCode != bytes8(0), "no such claim");
        require(c.status == Status.PayoutApproved, "bad status");

        c.payoutTxRef = payoutTxRef;
        c.paidAt      = uint64(block.timestamp);
        c.status      = Status.Paid;

        emit ClaimPaid(claimCode, c.payee, c.approvedAmount, payoutTxRef);
    }

    function denyClaim(bytes8 claimCode, uint8 reasonCode) external onlyOwner {
        Claim storage c = _claims[claimCode];
        require(c.claimCode != bytes8(0), "no such claim");
        require(
            c.status == Status.Submitted ||
            c.status == Status.SeverityProposed ||
            c.status == Status.SeverityFinalized ||
            c.status == Status.QuoteSubmitted,
            "too late"
        );
        c.status = Status.Denied;
        emit ClaimDenied(claimCode, reasonCode);
    }

    function closeClaim(bytes8 claimCode) external onlyOwner {
        Claim storage c = _claims[claimCode];
        require(c.claimCode != bytes8(0), "no such claim");
        require(c.status == Status.Paid || c.status == Status.Denied, "must be Paid or Denied");
        c.closedAt = uint64(block.timestamp);
        c.status   = Status.Closed;
        emit ClaimClosed(claimCode);
    }

    function getClaim(bytes8 claimCode) external view returns (Claim memory) {
        return _claims[claimCode];
    }
    function getStatus(bytes8 claimCode) external view returns (Status) {
        return _claims[claimCode].status;
    }

    function claimCodeToString(bytes8 code) external pure returns (string memory) {
        bytes memory out = new bytes(8);
        for (uint256 i = 0; i < 8; i++) {
            out[i] = code[i];
        }
        return string(out);
    }

    // Enforces [A–Z][0–9]{7}
    function _isValidClaimCode(bytes8 code) internal pure returns (bool) {
        if (code == bytes8(0)) return false;
        // First char: 'A'(65) .. 'Z'(90)
        bytes1 c0 = code[0];
        if (c0 < 0x41 || c0 > 0x5A) return false;
        // Next 7: '0'(48) .. '9'(57)
        for (uint256 i = 1; i < 8; i++) {
            bytes1 d = code[i];
            if (d < 0x30 || d > 0x39) return false;
        }
        return true;
    }

}
