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
    IPolicyReader public policy;

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
        ClaimantToShop,            
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
        address payable claimant;
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
        address payable shop;
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
    }   

    mapping(bytes8 => ClaimData) private _claims;
    mapping(bytes8 => bool)  private _usedCodes;

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
    event PayoutApproved(bytes8 indexed claimCode, address indexed payee, uint128 approvedAmount);
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

    function setShop(bytes8 claimCode, address payable shop) external onlyExisting(claimCode) {
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
        require(incidentAt >= effectiveAt && incidentAt <= expiresAt, "incident outside policy window");

        ClaimData storage c = _claims[claimCode];

        c.claimCode = claimCode;
        c.claimant  = payable(msg.sender);
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

    function approvePayout(
        bytes8  claimCode,
        address payee,
        uint128 amount
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
        c.payee          = payee == address(0) ? c.claimant : payee;
        c.approvedAt     = uint64(block.timestamp);
        c.status         = Status.PayoutApproved;

        emit PayoutApproved(claimCode, c.payee, amount);
    }

    function markPaid(bytes8 claimCode, address payable to) external payable {
        ClaimData storage c = _claims[claimCode];
        require(to != msg.sender, "cannot pay to self");
        require(c.status == Status.PayoutApproved 
        || c.status == Status.ClaimantToShop, "wrong timing");
        
        if(msg.sender == _claims[claimCode].claimant){
            require(c.status == Status.PayoutApproved, "waiting for approval (CLAIMANT PAYING)");
            require(to == _claims[claimCode].shop, "claimant can only pay to shop");
            emit ClaimPaid(claimCode, msg.sender, (_claims[claimCode].approvedAmount - _claims[claimCode].approvedAmount));
            c.status = Status.ClaimantToShop;
        } 
        else if(msg.sender == _claims[claimCode].adjuster && to == _claims[claimCode].shop){
            require(c.status == Status.ClaimantToShop, "waiting for claimant to pay");
            emit ClaimPaid(claimCode, msg.sender, _claims[claimCode].approvedAmount);
            c.paidAt = uint64(block.timestamp);
            c.status = Status.Paid;
        } 
        else if(msg.sender == _claims[claimCode].adjuster && to == _claims[claimCode].claimant){
            require(c.status == Status.PayoutApproved, "waiting for approval (ADJUSTER PAYING)");
            emit ClaimPaid(claimCode, msg.sender, _claims[claimCode].approvedAmount);
            c.paidAt = uint64(block.timestamp);
            c.status = Status.Paid;

        } else {
            require(0==1, "invalid sender/receiver pair");
        }

        require(to != address(0), "to=0");
        (bool ok, ) = to.call{value: msg.value}("");
        require(ok, "transfer failed");
    }

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
}
