// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Policy {
    struct PolicyData {
        uint256 id;
        address holder;        
        uint128  effectiveAt;   
        uint128  expiresAt;     
        uint128 maxCoverage;   
        uint128 deductible;    
        bool    active;        
        string  details;       
    }

    uint256 private _nextId = 1;
    mapping(uint256 => PolicyData) private _policies;

    event PolicyCreated(
        uint256 indexed policyId,
        address indexed holder,
        uint128 effectiveAt,
        uint128 expiresAt,
        uint128 maxCoverage,
        uint128 deductible,
        string details
    );
    event PolicyUpdated(
        uint256 indexed policyId,
        uint128 effectiveAt,
        uint128 expiresAt,
        uint128 maxCoverage,
        uint128 deductible,
        bool active,
        string details
    );
    event PolicyActiveSet(uint256 indexed policyId, bool active);

    /// Create a new policy
    function createPolicy(
        uint128  effectiveAt,
        uint128  expiresAt,
        uint128 maxCoverage,
        uint128 deductible,
        string calldata details
    ) external returns (uint256 policyId) {
        require(effectiveAt < expiresAt, "bad time range");
        policyId = _nextId++;
        _policies[policyId] = PolicyData({
            id: policyId,
            holder: msg.sender,
            effectiveAt: effectiveAt,
            expiresAt: expiresAt,
            maxCoverage: maxCoverage,
            deductible: deductible,
            active: true,
            details: details
        });
        emit PolicyCreated(policyId, msg.sender, effectiveAt, expiresAt, maxCoverage, deductible, details);
    }

    /// Holder can update most fields.
    function updatePolicy(
        uint256 policyId,
        uint128  effectiveAt,
        uint128  expiresAt,
        uint128 maxCoverage,
        uint128 deductible,
        string calldata details
    ) external {
        PolicyData storage p = _policies[policyId];
        require(p.id != 0, "no such policy");
        require(msg.sender == p.holder, "not holder");
        require(effectiveAt < expiresAt, "bad time range");
        p.effectiveAt = effectiveAt;
        p.expiresAt   = expiresAt;
        p.maxCoverage = maxCoverage;
        p.deductible  = deductible;
        p.details     = details;
        emit PolicyUpdated(policyId, effectiveAt, expiresAt, maxCoverage, deductible, p.active, details);
    }

    /// Holder can set active flag (e.g., cancel/restore).
    function setActive(uint256 policyId, bool active) external {
        PolicyData storage p = _policies[policyId];
        require(p.id != 0, "no such policy");
        require(msg.sender == p.holder, "not holder");
        p.active = active;
        emit PolicyActiveSet(policyId, active);
    }

    function getPolicy(uint256 policyId)
        external
        view
        returns (
            address holder,
            uint128  effectiveAt,
            uint128  expiresAt,
            uint128 maxCoverage,
            uint128 deductible,
            bool    active,
            string memory details
        )
    {
        PolicyData storage p = _policies[policyId];
        require(p.id != 0, "no such policy");
        return (p.holder, p.effectiveAt, p.expiresAt, p.maxCoverage, p.deductible, p.active, p.details);
    }

    function isPolicyActiveAt(uint256 policyId, uint128 ts) external view returns (bool) {
        PolicyData storage p = _policies[policyId];
        require(p.id != 0, "no such policy");
        return ts >= p.effectiveAt && ts <= p.expiresAt;
    }
}
