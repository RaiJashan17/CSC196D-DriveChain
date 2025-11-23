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

    }

    // ===== Enums =====
    enum Status {
        Submitted,          
        SeveritySubmitted,  
        QuoteSubmitted,     
        PayoutApproved,     
        Denied,             
        Paid            
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
        uint64  severitySubmittedAt;
        uint64  quoteSubmittedAt;
        uint64  approvedAt;
        uint64  paidAt;

        // Incident metadata
        uint64       incidentAt;
        string       incidentAddress;
        string       description;
        IncidentType incidentType;

        // Adjuster decision
        uint128 finalCapAmount;
        string  adjusterNotes;

        // Repair quote
        uint128 quoteAmount;
        string  quoteRef;

        // Payout planning & settlement
        uint128 approvedAmount;
        bool    payoutToShop;
    }   

    mapping(bytes8 => ClaimData) private _claims;
    mapping(bytes8 => bool)  private _usedCodes;

    // --- Payout mode & payment tracking (added) ---
    // 0 = ToShopWithTopUp (insurer -> shop up to approvedAmount; claimant tops up remainder to shop)
    // 1 = ToClaimant (insurer -> claimant up to approvedAmount)
    mapping(bytes8 => uint8) public payoutMode;

    // Partial payments tracking
    mapping(bytes8 => uint128) public insurerPaidToShop;
    mapping(bytes8 => uint128) public claimantTopUpPaid;
    mapping(bytes8 => uint128) public insurerPaidToClaimant;

    event PayoutModeSet(bytes8 indexed claimCode, uint8 mode);
    event PaymentReceived(bytes8 indexed claimCode, address indexed from, string role, uint128 amount, address indexed to);


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
    event SeveritySubmitted(bytes8 indexed claimCode, uint128 finalCapAmount, address indexed adjuster, string adjusterNotes);
    event QuoteSubmitted(bytes8 indexed claimCode, address indexed shop, uint128 quoteAmount, string quoteRef);
    event PayoutApproved(bytes8 indexed claimCode, address indexed payee, uint128 approvedAmount, bool toShop);
    event ClaimDenied(bytes8 indexed claimCode, string reason);
    event ClaimPaid(bytes8 indexed claimCode, address indexed payee, uint128 amount);

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
    modifier onlyShopOrAdmin(bytes8 claimCode) {
        ClaimData storage c = _claims[claimCode];
        require(msg.sender == c.shop || msg.sender == owner, "not shop/admin");
        _;
    }

    function setPolicyRegistry(address policyRegistry) external onlyAdmin {
        policy = IPolicyReader(policyRegistry);
    }

    function setAdjuster(bytes8 claimCode, address adjuster) external onlyExisting(claimCode) {
        require(adjuster != address(0), "zero adjuster");
        _claims[claimCode].adjuster = adjuster;
        emit AdjusterAssigned(claimCode, adjuster);
    }

    function setShop(bytes8 claimCode, address shop) external onlyExisting(claimCode) {
        require(shop != address(0), "zero shop");
        ClaimData storage c = _claims[claimCode];
        require(
            c.status == Status.SeveritySubmitted
            || c.status == Status.QuoteSubmitted, 
            "too late to set shop"
        );
        c.shop = shop;
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

    function adjusterConfirmSeverity(
        bytes8  claimCode,
        uint128 finalCapAmount,
        string calldata adjusterNotes
    ) external onlyAdjusterOrAdmin(claimCode) onlyExisting(claimCode) {
        ClaimData storage c = _claims[claimCode];
        require(
            c.status == Status.Submitted || c.status == Status.SeveritySubmitted, 
            "waiting for submission"
        );
        require(finalCapAmount > 0, "cap=0");

        c.finalCapAmount      = finalCapAmount;
        c.adjusterNotes       = adjusterNotes;
        c.severitySubmittedAt = uint64(block.timestamp);
        c.status              = Status.SeveritySubmitted;

        emit SeveritySubmitted(claimCode, finalCapAmount, c.adjuster, adjusterNotes);
    }

    // Shop submits repair quote
    function submitRepairQuote(
        bytes8  claimCode,
        uint128 quoteAmount,
        string calldata quoteRef
    ) external onlyShopOrAdmin(claimCode) onlyExisting(claimCode) {
        ClaimData storage c = _claims[claimCode];
        require(
            c.status == Status.SeveritySubmitted || c.status == Status.QuoteSubmitted, 
            "waiting for adjuster submission"
        );
        require(quoteAmount > 0, "quote=0");

        c.quoteAmount      = quoteAmount;
        c.quoteRef         = quoteRef;
        c.quoteSubmittedAt = uint64(block.timestamp);
        c.status           = Status.QuoteSubmitted;

        emit QuoteSubmitted(claimCode, c.shop, quoteAmount, quoteRef);
    }

    // Adjuster (or admin) approves payout
    function approvePayout(
        bytes8  claimCode,
        address payee,
        uint128 amount,
        bool    payoutToShop
    ) external onlyAdjusterOrAdmin(claimCode) onlyExisting(claimCode) {
        ClaimData storage c = _claims[claimCode];
        require(c.status == Status.QuoteSubmitted, "waiting for quote");
        require(amount > 0, "amount=0");
        require(amount <= c.finalCapAmount, "over final cap");
        require(amount <= c.quoteAmount, "over quote");
        require(amount <= c.policyMaxCoverage, "over policy coverage");

        require(c.policyDeductible <= amount, "below deductible");
        amount = amount - c.policyDeductible;

        c.approvedAmount = amount;
        c.payoutToShop   = payoutToShop;
        c.payee          = payee == address(0) ? c.claimant : payee;
        c.approvedAt     = uint64(block.timestamp);
        c.status         = Status.PayoutApproved;

        emit PayoutApproved(claimCode, c.payee, amount, payoutToShop);
    }

    // Admin records payment settlement tx/hash
    
    /// @notice Sets payout mode for a claim.
    /// 0 = insurer pays approvedAmount to shop, claimant tops up remainder to shop
    /// 1 = insurer pays approvedAmount to claimant (no on-chain shop payment)
    function setPayoutMode(bytes8 claimCode, uint8 mode)
        external
        onlyExisting(claimCode)
    {
        require(mode == 0 || mode == 1, "invalid mode");
        ClaimData storage c = _claims[claimCode];
        require(msg.sender == c.claimant, "only claimant");
        require(c.status == Status.PayoutApproved, "not payout-approved");
        // Disallow switching after payments started
        require(
            insurerPaidToShop[claimCode] == 0 &&
            claimantTopUpPaid[claimCode] == 0 &&
            insurerPaidToClaimant[claimCode] == 0,
            "payments started"
        );
        payoutMode[claimCode] = mode;
        emit PayoutModeSet(claimCode, mode);
    }


    /// @notice Final settlement step after approvePayout set approvedAmount = min(quoteAmount, finalCapAmount).
    /// Modes:
    ///   0 (default): insurer pays approvedAmount -> shop; claimant pays (quoteAmount - approvedAmount) -> shop
    ///   1: insurer pays approvedAmount -> claimant
    /// Supports partial payments; marks claim Paid when obligations are fully met.
    function markPaid(bytes8 claimCode)
        external
        payable
        onlyExisting(claimCode)
    {
        ClaimData storage c = _claims[claimCode];
        require(c.status == Status.PayoutApproved, "not payout-approved");
        require(c.approvedAmount > 0, "approvedAmount not set");
        require(msg.value > 0, "no ETH sent");
        require(c.shop != address(0), "shop not set");

        uint8 mode = payoutMode[claimCode]; // 0 or 1

        if (mode == 0) {
            // Mode 0: insurer -> shop up to approvedAmount; claimant -> shop the remainder
            uint128 insurerOwesToShop  = c.approvedAmount;
            uint128 claimantOwesToShop = (c.quoteAmount > c.approvedAmount)
                ? (c.quoteAmount - c.approvedAmount) : 0;

            if (msg.sender == owner) {
                uint128 remaining = insurerOwesToShop - insurerPaidToShop[claimCode];
                require(remaining > 0, "insurer done");
                uint128 toApply = uint128(msg.value);
                require(toApply <= remaining, "excess insurer payment");

                // EFFECTS
                insurerPaidToShop[claimCode] += toApply;

                // INTERACTION
                (bool ok, ) = c.shop.call{value: toApply}("");
                require(ok, "shop transfer failed");

                emit PaymentReceived(claimCode, msg.sender, "insurer->shop", toApply, c.shop);
            } else if (msg.sender == c.claimant) {
                require(claimantOwesToShop > 0, "no claimant top-up required");
                uint128 remaining = claimantOwesToShop - claimantTopUpPaid[claimCode];
                require(remaining > 0, "claimant done");
                uint128 toApply = uint128(msg.value);
                require(toApply <= remaining, "excess claimant payment");

                // EFFECTS
                claimantTopUpPaid[claimCode] += toApply;

                // INTERACTION
                (bool ok, ) = c.shop.call{value: toApply}("");
                require(ok, "shop transfer failed");

                emit PaymentReceived(claimCode, msg.sender, "claimant->shop", toApply, c.shop);
            } else {
                revert("sender not allowed");
            }

            // Close when both sides (if any) are complete
            bool insurerDone  = insurerPaidToShop[claimCode]  >= insurerOwesToShop;
            bool claimantDone = (claimantOwesToShop == 0) || (claimantTopUpPaid[claimCode] >= claimantOwesToShop);
            if (insurerDone && claimantDone) {
                c.paidAt = uint64(block.timestamp);
                c.status = Status.Paid;
                emit ClaimPaid(claimCode, c.shop, c.approvedAmount);
            }
        } else {
            // Mode 1: insurer -> claimant up to approvedAmount
            require(msg.sender == owner, "only insurer in mode 1");

            uint128 remaining = c.approvedAmount - insurerPaidToClaimant[claimCode];
            require(remaining > 0, "insurer already paid claimant");
            uint128 toApply = uint128(msg.value);
            require(toApply <= remaining, "excess insurer payment");

            // EFFECTS
            insurerPaidToClaimant[claimCode] += toApply;

            // INTERACTION
            (bool ok, ) = c.claimant.call{value: toApply}("");
            require(ok, "claimant transfer failed");

            emit PaymentReceived(claimCode, msg.sender, "insurer->claimant", toApply, c.claimant);

            if (insurerPaidToClaimant[claimCode] >= c.approvedAmount) {
                c.paidAt = uint64(block.timestamp);
                c.status = Status.Paid;
                emit ClaimPaid(claimCode, c.claimant, c.approvedAmount);
            }
        }
    }

    // Adjuster or admin can deny before payout approval
    function denyClaim(bytes8 claimCode, string calldata reason) external onlyAdjusterOrAdmin(claimCode) onlyExisting(claimCode) {
        ClaimData storage c = _claims[claimCode];
        require(
            c.status == Status.Submitted ||
            c.status == Status.SeveritySubmitted ||
            c.status == Status.QuoteSubmitted,
            "too late"
        );
        c.status = Status.Denied;
        emit ClaimDenied(claimCode, reason);
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
