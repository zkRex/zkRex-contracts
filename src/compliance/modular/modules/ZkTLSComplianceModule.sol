// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./AbstractModule.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IZkTLSRegistry {
    function isVerified(address user) external view returns (bool);
}

contract ZkTLSComplianceModule is AbstractModule, Ownable {

    /// @dev Mapping to store verification status (could also point to an external registry)
    mapping(address => bool) public hasValidProof;
    
    /// @dev Address authorized to update proofs (e.g. the contract receiving the zkTLS proof)
    address public proofVerifier;

    event ProofUpdated(address indexed user, bool status);
    event VerifierUpdated(address indexed newVerifier);

    constructor(address _proofVerifier) Ownable(msg.sender) {
        proofVerifier = _proofVerifier;
    }

    modifier onlyVerifier() {
        require(msg.sender == proofVerifier, "Only verifier can update");
        _;
    }

    function setVerifier(address _newVerifier) external onlyOwner {
        proofVerifier = _newVerifier;
        emit VerifierUpdated(_newVerifier);
    }

    // Call this function when the zkTLS proof is successfully verified
    function updateVerificationStatus(address _user, bool _status) external onlyVerifier {
        hasValidProof[_user] = _status;
        emit ProofUpdated(_user, _status);
    }

    /**
     * @dev See {IModule-moduleCheck}.
     * Validates that both the sender and receiver have valid zkTLS proofs (or just sender/receiver depending on your logic).
     */
    function moduleCheck(
        address _from,
        address _to,
        uint256 /*_value*/,
        address /*_compliance*/
    ) external view override returns (bool) {
        // Example: Both parties must have verified external account balances via zkTLS
        // You might want to skip check for 0x0 address (minting/burning)
        if (_from == address(0) || _to == address(0)) {
            return true;
        }
        
        return hasValidProof[_from] && hasValidProof[_to];
    }

    function moduleTransferAction(
        address /*_from*/,
        address /*_to*/,
        uint256 /*_value*/
    ) external override {}

    function moduleMintAction(
        address /*_to*/,
        uint256 /*_value*/
    ) external override {}

    function moduleBurnAction(
        address /*_from*/,
        uint256 /*_value*/
    ) external override {}

    // Allow any ModularCompliance instance to bind by default.
    function canComplianceBind(address /*_compliance*/) external pure override returns (bool) {
        return true;
    }
    
    // This module is plug & play (no extra initialization required when binding)
    function isPlugAndPlay() external pure override returns (bool) {
        return true;
    }
    
    function name() external pure override returns (string memory) {
        return "ZkTLSComplianceModule";
    }
}
