// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IPolicyReader {
    function getPolicy(uint256 policyId)
        external
        view
        returns (
            address holder,
            uint64  effectiveAt,
            uint64  expiresAt,
            uint128 maxCoverage,
            uint128 deductible,
            bool    active,
            string memory details
        );
    function isPolicyActiveAt(uint256 policyId, uint64 ts) external view returns (bool);
}

contract Claim {
    address public owner;
    IPolicyReader public policy; // policy registry/reader contract

    modifier onlyAdmin() {
        require(msg.sender == owner, "not admin");
        _;
    }

    constructor(address policyRegistry) {
        owner = msg.sender;
        policy = IPolicyReader(policyRegistry);

        // _tierCap[1]  = 1000;
        // _tierCap[2]  = 5000;
        // _tierCap[3]  = 10000;
        // _tierCap[4]  = 25000;
        // _tierCap[5]  = 50000;
        // _tierCap[6]  = 100000;
        // _tierCap[7]  = 250000;
        // _tierCap[8]  = 1000000;
        // _tierCap[9]  = 5000000;
        // _tierCap[10] = 10000000;
    }

    // ===== Enums =====
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

    struct ClaimData {
        // Core identifiers
        bytes8  claimCode;
        address claimant;
        uint64  createdAt;

        // Policy snapshot (at creation)
        uint256 policyId;
        address policyHolder;
        uint64  policyEffectiveAt;
        uint64  policyExpiresAt;
        uint128 policyMaxCoverage;
        uint128 policyDeductible;
        string  policyDetails;

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
        // uint8   aiTier;        
        // uint128 aiCapAmount;   
        // string  aiNotes;

        // Adjuster decision
        uint128 finalCapAmount;
        string  adjusterNotes;
        bool    isCapLocked;

        // Repair quote
        uint128 quoteAmount;
        string  quoteRef;
        address quoteCurrency;

        // Payout planning & settlement
        uint128 approvedAmount;
        address payoutCurrency;
        uint256 escrowId;
        bool    payoutToShop;
        bytes32 payoutTxRef;
    }   

    mapping(bytes8 => ClaimData) private _claims;
    mapping(bytes8 => bool)  private _usedCodes;
    mapping(uint8 => uint128) private _tierCap;

    event ClaimSubmitted(
        bytes8  indexed claimCode,
        address indexed claimant,
        uint64 incidentAt,
        string incidentAddress,
        string description,
        IncidentType incidentType,
        uint256 indexed policyId
    );
    event AdjusterAssigned(bytes8 indexed claimCode, address indexed adjuster);
    event ShopAssigned(bytes8 indexed claimCode, address indexed shop);
    // event SeverityProposed(bytes8 indexed claimCode, uint8 aiTier, uint128 aiCapAmount, string aiNotes);
    event SeverityFinalized(bytes8 indexed claimCode, uint128 finalCapAmount, address indexed adjuster, string adjusterNotes, bool locked);
    event QuoteSubmitted(bytes8 indexed claimCode, address indexed shop, uint128 quoteAmount, string quoteRef, address quoteCurrency);
    event PayoutApproved(bytes8 indexed claimCode, address indexed payee, uint128 approvedAmount, address payoutCurrency, uint256 escrowId, bool toShop);
    event ClaimDenied(bytes8 indexed claimCode, uint8 reasonCode);
    event ClaimPaid(bytes8 indexed claimCode, address indexed payee, uint128 amount, bytes32 payoutTxRef);
    event ClaimClosed(bytes8 indexed claimCode);

    modifier onlyExisting(bytes8 claimCode) {
        require(_claims[claimCode].claimCode != bytes8(0), "no such claim");
        _;
    }
    modifier onlyClaimant(bytes8 claimCode) {
        require(msg.sender == _claims[claimCode].claimant, "not claimant");
        _;
    }
    modifier onlyAdjuster(bytes8 claimCode) {
        require(msg.sender == _claims[claimCode].adjuster, "not adjuster");
        _;
    }
    modifier onlyShop(bytes8 claimCode) {
        require(msg.sender == _claims[claimCode].shop, "not shop");
        _;
    }
    modifier onlyAdjusterOrAdmin(bytes8 claimCode) {
        ClaimData storage c = _claims[claimCode];
        require(msg.sender == c.adjuster || msg.sender == owner, "not adjuster/admin");
        _;
    }
    modifier onlyShopOrClaimant(bytes8 claimCode) {
        ClaimData storage c = _claims[claimCode];
        require(msg.sender == c.shop || msg.sender == c.claimant, "not shop/claimant");
        _;
    }

    function setPolicyRegistry(address policyRegistry) external onlyAdmin {
        policy = IPolicyReader(policyRegistry);
    }

    // function setTierCap(uint8 tier, uint128 cap) external onlyAdmin {
    //     require(tier >= 1 && tier <= 10, "tier out of range");
    //     require(cap > 0, "cap=0");
    //     _tierCap[tier] = cap;
    // }

    // function getTierCap(uint8 tier) external view returns (uint128) {
    //     require(tier >= 1 && tier <= 10, "tier out of range");
    //     return _tierCap[tier];
    // }

    function setAdjuster(bytes8 claimCode, address adjuster) external onlyAdmin onlyExisting(claimCode) {
        require(adjuster != address(0), "zero adjuster");
        _claims[claimCode].adjuster = adjuster;
        emit AdjusterAssigned(claimCode, adjuster);
    }

    function setShop(bytes8 claimCode, address shop) external onlyClaimant(claimCode) onlyExisting(claimCode) {
        require(shop != address(0), "zero shop");
        ClaimData storage c = _claims[claimCode];
        require(
            c.status == Status.Submitted || 
            c.status == Status.SeverityProposed || 
            c.status == Status.SeverityFinalized, 
            "too late to set shop"
        );
        c.shop = shop;
        emit ShopAssigned(claimCode, shop);
    }

    function adminSetShop(bytes8 claimCode, address shop) external onlyAdmin onlyExisting(claimCode) {
        require(shop != address(0), "zero shop");
        _claims[claimCode].shop = shop;
        emit ShopAssigned(claimCode, shop);
    }

    /// Create a claim and bind it to a policy.
    function createClaim(
        bytes8       claimCode,
        uint256      policyId,
        uint64       incidentAt,
        string calldata incidentAddress,
        string calldata description,
        IncidentType incidentType
    ) external returns (bytes8) {
        require(_isValidClaimCode(claimCode), "invalid code");
        require(!_usedCodes[claimCode], "code already used");
        _usedCodes[claimCode] = true;

        (
            address holder,
            uint64  effectiveAt,
            uint64  expiresAt,
            uint128 maxCoverage,
            uint128 deductible,
            bool    active,
            string memory details
        ) = policy.getPolicy(policyId);

        require(active, "policy inactive");
        require(msg.sender == holder, "not policy holder");
        require(incidentAt >= effectiveAt && incidentAt <= expiresAt, "incident outside policy window");

        ClaimData storage c = _claims[claimCode];

        c.claimCode = claimCode;
        c.claimant  = msg.sender;
        c.createdAt = uint64(block.timestamp);

        c.policyId          = policyId;
        c.policyHolder      = holder;
        c.policyEffectiveAt = effectiveAt;
        c.policyExpiresAt   = expiresAt;
        c.policyMaxCoverage = maxCoverage;
        c.policyDeductible  = deductible;
        c.policyDetails     = details;

        c.status      = Status.Submitted;
        c.submittedAt = uint64(block.timestamp);

        c.incidentAt      = incidentAt;
        c.incidentAddress = incidentAddress;
        c.description     = description;
        c.incidentType    = incidentType;

        emit ClaimSubmitted(claimCode, c.claimant, incidentAt, incidentAddress, description, incidentType, policyId);
        return claimCode;
    }

    // Adjuster or admin proposes AI severity
    // function proposeSeverity(
    //     bytes8  claimCode,
    //     uint8   aiTier,
    //     string calldata aiNotes
    // ) external onlyAdjusterOrAdmin(claimCode) onlyExisting(claimCode) {
    //     ClaimData storage c = _claims[claimCode];
    //     require(
    //         c.status == Status.Submitted || c.status == Status.SeverityProposed, 
    //         "bad status"
    //     );
    //     require(aiTier >= 1 && aiTier <= 10, "tier out of range");

    //     uint128 cap = _tierCap[aiTier];
    //     require(cap > 0, "cap not set");

    //     c.aiTier      = aiTier;
    //     c.aiCapAmount = cap;
    //     c.aiNotes     = aiNotes;
    //     c.severityProposedAt = uint64(block.timestamp);
    //     c.status = Status.SeverityProposed;

    //     emit SeverityProposed(claimCode, aiTier, cap, aiNotes);
    // }

    // Adjuster finalizes severity (cannot exceed AI cap)
    function adjusterConfirmSeverity(
        bytes8  claimCode,
        uint128 finalCapAmount,
        string calldata adjusterNotes,
        bool    lockCap
    ) external onlyAdjuster(claimCode) onlyExisting(claimCode) {
        ClaimData storage c = _claims[claimCode];
        require(
            c.status == Status.SeverityProposed || c.status == Status.SeverityFinalized, 
            "bad status"
        );
        require(finalCapAmount > 0, "cap=0");
        // require(finalCapAmount <= c.aiCapAmount, "final cap > AI cap");

        c.finalCapAmount      = finalCapAmount;
        c.adjusterNotes       = adjusterNotes;
        c.severityFinalizedAt = uint64(block.timestamp);
        c.status              = Status.SeverityFinalized;

        if (lockCap) c.isCapLocked = true;

        emit SeverityFinalized(claimCode, finalCapAmount, c.adjuster, adjusterNotes, lockCap);
    }

    // Shop submits repair quote
    function submitRepairQuote(
        bytes8  claimCode,
        uint128 quoteAmount,
        string calldata quoteRef,
        address quoteCurrency
    ) external onlyShopOrClaimant(claimCode) onlyExisting(claimCode) {
        ClaimData storage c = _claims[claimCode];
        require(
            c.status == Status.SeverityFinalized || c.status == Status.QuoteSubmitted, 
            "bad status"
        );
        require(quoteAmount > 0, "quote=0");

        c.quoteAmount      = quoteAmount;
        c.quoteRef         = quoteRef;
        c.quoteCurrency    = quoteCurrency;
        c.quoteSubmittedAt = uint64(block.timestamp);
        c.status           = Status.QuoteSubmitted;

        emit QuoteSubmitted(claimCode, c.shop, quoteAmount, quoteRef, quoteCurrency);
    }

    // Adjuster (or admin) approves payout
    function approvePayout(
        bytes8  claimCode,
        address payee,
        uint128 amount,
        address payoutCurrency,
        uint256 escrowId,
        bool    payoutToShop
    ) external onlyAdjusterOrAdmin(claimCode) onlyExisting(claimCode) {
        ClaimData storage c = _claims[claimCode];
        require(c.status == Status.QuoteSubmitted, "bad status");
        require(amount > 0, "amount=0");
        require(amount <= c.finalCapAmount, "over final cap");
        require(amount <= c.quoteAmount, "over quote");
        require(amount <= c.policyMaxCoverage, "over policy coverage");

        // If you want to *automatically* apply deductible:
        // require(c.policyDeductible <= amount, "below deductible");
        // amount = amount - c.policyDeductible;

        c.approvedAmount = amount;
        c.payoutCurrency = payoutCurrency;
        c.escrowId       = escrowId;
        c.payoutToShop   = payoutToShop;
        c.payee          = payee == address(0) ? c.claimant : payee;
        c.approvedAt     = uint64(block.timestamp);
        c.status         = Status.PayoutApproved;

        emit PayoutApproved(claimCode, c.payee, amount, payoutCurrency, escrowId, payoutToShop);
    }

    // Admin records payment settlement tx/hash
    function markPaid(bytes8 claimCode, bytes32 payoutTxRef) external onlyAdmin onlyExisting(claimCode) {
        ClaimData storage c = _claims[claimCode];
        require(c.status == Status.PayoutApproved, "bad status");

        c.payoutTxRef = payoutTxRef;
        c.paidAt      = uint64(block.timestamp);
        c.status      = Status.Paid;

        emit ClaimPaid(claimCode, c.payee, c.approvedAmount, payoutTxRef);
    }

    // Adjuster or admin can deny before payout approval
    function denyClaim(bytes8 claimCode, uint8 reasonCode) external onlyAdjusterOrAdmin(claimCode) onlyExisting(claimCode) {
        ClaimData storage c = _claims[claimCode];
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

    // Admin closes after Paid or Denied
    function closeClaim(bytes8 claimCode) external onlyAdmin onlyExisting(claimCode) {
        ClaimData storage c = _claims[claimCode];
        require(c.status == Status.Paid || c.status == Status.Denied, "must be Paid or Denied");
        c.closedAt = uint64(block.timestamp);
        c.status   = Status.Closed;
        emit ClaimClosed(claimCode);
    }

    function getClaim(bytes8 claimCode) external view returns (ClaimData memory) {
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
        bytes1 c0 = code[0];
        if (c0 < 0x41 || c0 > 0x5A) return false;
        for (uint256 i = 1; i < 8; i++) {
            bytes1 d = code[i];
            if (d < 0x30 || d > 0x39) return false;
        }
        return true;
    }

    function transferOwnership(address newOwner) external onlyAdmin {
        require(newOwner != address(0), "zero owner");
        owner = newOwner;
    }
}
