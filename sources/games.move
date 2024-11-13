module credentials::certifications {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::linked_table::{Self, LinkedTable};
    use std::string::String;
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    // Error codes
    const ENotAuthorized: u64 = 0;
    const EInstitutionNotFound: u64 = 1;
    const ECertificateNotFound: u64 = 2;
    const EInvalidCredential: u64 = 3;
    const EAlreadyVerified: u64 = 4;
    const EExpiredCredential: u64 = 5;

    // Core structs
    struct Platform has key {
        id: UID,
        admin: address,
        revenue: Balance<SUI>,
        verification_fee: u64
    }

    struct Institution has key {
        id: UID,
        name: String,
        address: address,
        credentials: LinkedTable<String, Credential>,
        reputation_score: u64,
        verified: bool
    }

    struct Credential has key, store {
        id: UID,
        title: String,
        description: String,
        issuer: address,
        issue_date: u64,
        expiry_date: Option<u64>,
        metadata: LinkedTable<String, String>,
        revoked: bool
    }

    struct CredentialHolder has key {
        id: UID,
        holder: address,
        credentials: LinkedTable<String, Certificate>,
        verifications: LinkedTable<String, Verification>
    }

    struct Certificate has key, store {
        id: UID,
        credential_id: ID,
        holder: address,
        issued_by: address,
        issue_date: u64,
        achievement_data: LinkedTable<String, String>
    }

    struct Verification has store {
        verifier: address,
        verification_date: u64,
        valid_until: u64,
        verification_notes: String
    }

    // Initialize platform
    fun init(ctx: &mut TxContext) {
        let platform = Platform {
            id: object::new(ctx),
            admin: tx_context::sender(ctx),
            revenue: balance::zero(),
            verification_fee: 100 // Base fee in SUI
        };
        transfer::share_object(platform);
    }

    // Register new institution
    public fun register_institution(
        platform: &Platform,
        name: String,
        ctx: &mut TxContext
    ) {
        let institution = Institution {
            id: object::new(ctx),
            name,
            address: tx_context::sender(ctx),
            credentials: linked_table::new(ctx),
            reputation_score: 0,
            verified: false
        };
        transfer::transfer(institution, tx_context::sender(ctx));
    }

    // Create new credential type
    public fun create_credential(
        institution: &mut Institution,
        title: String,
        description: String,
        expiry_period: Option<u64>,
        ctx: &mut TxContext
    ) {
        assert!(institution.address == tx_context::sender(ctx), ENotAuthorized);
        
        let credential = Credential {
            id: object::new(ctx),
            title,
            description,
            issuer: institution.address,
            issue_date: tx_context::epoch(ctx),
            expiry_date: expiry_period,
            metadata: linked_table::new(ctx),
            revoked: false
        };

        linked_table::push_back(&mut institution.credentials, title, credential);
    }

    // Issue certificate to holder
    public fun issue_certificate(
        institution: &Institution,
        credential_title: String,
        holder_address: address,
        achievement_data: LinkedTable<String, String>,
        ctx: &mut TxContext
    ) {
        assert!(institution.address == tx_context::sender(ctx), ENotAuthorized);
        let credential = linked_table::borrow(&institution.credentials, credential_title);
        
        let certificate = Certificate {
            id: object::new(ctx),
            credential_id: object::id(credential),
            holder: holder_address,
            issued_by: institution.address,
            issue_date: tx_context::epoch(ctx),
            achievement_data
        };

        // Transfer to holder
        transfer::transfer(certificate, holder_address);
    }

    // Verify certificate
    public fun verify_certificate(
        platform: &mut Platform,
        certificate: &Certificate,
        notes: String,
        valid_period: u64,
        payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let payment_value = coin::value(&payment);
        assert!(payment_value >= platform.verification_fee, EInvalidCredential);
        
        let verification = Verification {
            verifier: tx_context::sender(ctx),
            verification_date: tx_context::epoch(ctx),
            valid_until: tx_context::epoch(ctx) + valid_period,
            verification_notes: notes
        };

        // Process payment
        let payment_balance = coin::into_balance(payment);
        balance::join(&mut platform.revenue, payment_balance);

        // Store verification (would need to be adapted to actual implementation)
        // This is simplified for demonstration
    }

    // View certificate details
    public fun view_certificate(certificate: &Certificate): (address, address, u64) {
        (certificate.holder, certificate.issued_by, certificate.issue_date)
    }

    // Revoke credential
    public fun revoke_credential(
        institution: &mut Institution,
        credential_title: String,
        ctx: &mut TxContext
    ) {
        assert!(institution.address == tx_context::sender(ctx), ENotAuthorized);
        let credential = linked_table::borrow_mut(&mut institution.credentials, credential_title);
        credential.revoked = true;
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }
}