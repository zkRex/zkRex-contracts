// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;



// Import IMPLEMENTATIONS (Logic)
import {TREXFactory} from "../src/factory/TREXFactory.sol";
import {ClaimTopicsRegistry} from "../src/registry/implementation/ClaimTopicsRegistry.sol";
import {ITREXImplementationAuthority} from "../src/proxy/authority/ITREXImplementationAuthority.sol";
import {IdentityRegistryStorage} from "../src/registry/implementation/IdentityRegistryStorage.sol";
import {IdentityRegistry} from "../src/registry/implementation/IdentityRegistry.sol";
import {ModularCompliance} from "../src/compliance/modular/ModularCompliance.sol";
import {ZkTLSComplianceModule} from "../src/compliance/modular/modules/ZkTLSComplianceModule.sol";
import {IClaimIssuer} from "@onchain-id/solidity/contracts/interface/IClaimIssuer.sol";

// Import Authority
import {Script} from "forge-std/Script.sol";
// Make sure to import the struct definition if it's in an interface or library
import {TREXImplementationAuthority} from "../src/proxy/authority/TREXImplementationAuthority.sol";
import {IAFactory} from "../src/proxy/authority/IAFactory.sol";
import {Token} from "../src/token/Token.sol";
import {TrustedIssuersRegistry} from "../src/registry/implementation/TrustedIssuersRegistry.sol";

// OnchainID (Identity) factory stack
import {IdFactory} from "@onchain-id/solidity/contracts/factory/IdFactory.sol";
import {ImplementationAuthority as OIDImplementationAuthority} from "@onchain-id/solidity/contracts/proxy/ImplementationAuthority.sol";
import {Identity} from "@onchain-id/solidity/contracts/Identity.sol";

contract DeployAuthority is Script {

    function run() public {
        vm.startBroadcast();

        // 1. Deploy Logic Contracts (Implementations)
        // These are the "blueprints" that proxies will forward calls to
        Token tokenImpl = new Token();
        IdentityRegistry identityRegistryImpl = new IdentityRegistry();
        IdentityRegistryStorage identityStorageImpl = new IdentityRegistryStorage();
        ClaimTopicsRegistry claimTopicsImpl = new ClaimTopicsRegistry();
        TrustedIssuersRegistry trustedIssuersImpl = new TrustedIssuersRegistry();
        ModularCompliance modularComplianceImpl = new ModularCompliance();

        // 1b. Deploy OnchainID (Identity) stack for IdFactory
        // Deploy Identity implementation (as library) and its ImplementationAuthority
        Identity identityImpl = new Identity(msg.sender, true);
        OIDImplementationAuthority oidImplAuthority = new OIDImplementationAuthority(address(identityImpl));
        // Deploy the IdFactory pointing to the Identity ImplementationAuthority
        IdFactory oidFactory = new IdFactory(address(oidImplAuthority));

        // 2. Prepare the struct for the Authority Constructor
        // (Check your ITREXImplementationAuthority file for the exact struct definition)
        ITREXImplementationAuthority.TREXContracts memory contracts = ITREXImplementationAuthority.TREXContracts({
            tokenImplementation: address(tokenImpl),
            ctrImplementation: address(claimTopicsImpl),
            irImplementation: address(identityRegistryImpl),
            irsImplementation: address(identityStorageImpl),
            tirImplementation: address(trustedIssuersImpl),
            mcImplementation: address(modularComplianceImpl)
        });

        // 3. Deploy the Authority
        // Constructor params per TREXImplementationAuthority signature:
        // (bool referenceStatus, address trexFactory, address iaFactory)
        // The user prefers not to rely on .env. We deploy the reference IA with
        // trexFactory set to address(0) and let the owner set it later via setTREXFactory.
        // This matches the contract documentation allowing post-deployment setup.
        TREXImplementationAuthority authority = new TREXImplementationAuthority(true, address(0), address(0));

        // IMPORTANT: Set a current version on the reference IA before wiring the factory.
        // TREXFactory constructor validates that the IA has all implementations set on its
        // current version; otherwise it reverts with "invalid Implementation Authority".
        ITREXImplementationAuthority.Version memory v = ITREXImplementationAuthority.Version({
            major: 1,
            minor: 0,
            patch: 0
        });
        // Add implementations and set current version on the IA
        authority.addAndUseTREXVersion(v, contracts);

        // Deploy TREXFactory (requires IdFactory) and IAFactory, then wire both to the IA
        // 4. Deploy TREXFactory with the IA and the freshly deployed IdFactory
        TREXFactory factory = new TREXFactory(address(authority), address(oidFactory));

        // 5. Link the TREXFactory back to the IA (requires factory.getImplementationAuthority() == IA)
        authority.setTREXFactory(address(factory));

        // 6. Deploy IAFactory with the TREXFactory and link it back to the IA
        IAFactory iaFactory = new IAFactory(address(factory));
        authority.setIAFactory(address(iaFactory));

        // 7. Deploy the custom compliance module (zkTLS) and set its initial verifier
        // This module can be added to any ModularCompliance instance when deploying a token via TREXFactory
        // Example: pass address(zktlsModule) in TokenDetails.complianceModules and use setVerifier/callModuleFunction as needed
        ZkTLSComplianceModule zktlsModule = new ZkTLSComplianceModule(msg.sender);
        // Optionally, you can later grant another verifier EOA/contract the right to update proofs:
        // zktlsModule.setVerifier(<verifierAddress>);

        // 8. Register a claim topic and a custom issuer (deployer) with that topic
        // Note: This interacts with the implementation contracts directly; actual
        // registry data is stored in proxies deployed per token via TREXFactory.
        // This step is illustrative for local testing; production flows should
        // add topics/issuers on the deployed proxy instances.
        claimTopicsImpl.addClaimTopic(100);
        uint256[] memory topics = new uint256[](1);
        topics[0] = 100;
        trustedIssuersImpl.addTrustedIssuer(IClaimIssuer(msg.sender), topics);

    vm.stopBroadcast();
    }
}
