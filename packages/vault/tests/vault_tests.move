#[test_only]
module legato_vault_addr::vault_tests {

    use std::features;
    use std::signer;

    use aptos_std::bls12381;
    use aptos_std::stake;
    use aptos_std::vector;

    use aptos_framework::account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::reconfiguration;
    use aptos_framework::delegation_pool as dp;
    use aptos_framework::timestamp;
    use aptos_framework::primary_fungible_store;

    use legato_vault_addr::vault;
    use legato_vault_addr::mock_validator;

    #[test_only]
    const EPOCH_DURATION: u64 = 86400;

    #[test_only]
    const ONE_APT: u64 = 100000000; // 1x10**8

    #[test_only]
    const LOCKUP_CYCLE_SECONDS: u64 = 3600;

    #[test_only]
    const DELEGATION_POOLS: u64 = 11;

    #[test_only]
    const MODULE_EVENT: u64 = 26;
 
    #[test_only]
    const OPERATOR_BENEFICIARY_CHANGE: u64 = 39;

    #[test_only]
    const COMMISSION_CHANGE_DELEGATION_POOL: u64 = 42;

    #[test_only]
    const COIN_TO_FUNGIBLE_ASSET_MIGRATION: u64 = 60;

    #[test(deployer = @legato_vault_addr, aptos_framework = @aptos_framework, validator_1 = @0x1111, validator_2 = @0x2222, user_1 = @0xbeef, user_2 = @0xfeed, user_3 = @0x8888, user_4 = @9999)]
    fun test_mint_redeem(deployer: &signer, aptos_framework: &signer, validator_1: &signer, validator_2: &signer, user_1: &signer, user_2: &signer, user_3: &signer, user_4: &signer) {

        initialize_for_test(aptos_framework);

        mock_validator::init_module_for_testing(deployer);
        vault::init_module_for_testing(deployer);

        // Prepare test accounts
        create_test_accounts( deployer, validator_1, validator_2, user_1, user_2);

        // Set commission fees: 10% for validator_1 and 4% for validator_2
        mock_validator::new_pool( signer::address_of(validator_1), 10, 100 );
        mock_validator::new_pool( signer::address_of(validator_2), 4, 100 );

        // Add the validators to the whitelist.
        vault::attach_pool(deployer,  signer::address_of(validator_1));
        vault::attach_pool(deployer,  signer::address_of(validator_2));

        // Mint APT tokens for validators and alice
        stake::mint(validator_1, 100 * ONE_APT);
        stake::mint(validator_2, 200 * ONE_APT); 
        stake::mint(user_1, 20 * ONE_APT); 
        stake::mint(user_2, 20 * ONE_APT); 

        // Stake APT tokens to validators
        mock_validator::stake( validator_1, signer::address_of(validator_1), 100 * ONE_APT);
        mock_validator::stake( validator_2, signer::address_of(validator_2), 200 * ONE_APT); 

        // Mint VAULT tokens by staking APT
        vault::mint( user_1, 20 * ONE_APT);
        vault::mint( user_2, 20 * ONE_APT);

        // Check the VAULT token balance for both users
        let metadata = vault::get_vault_metadata(); 
        assert!( (primary_fungible_store::balance( signer::address_of(user_1), metadata )) == 19_99999000, 2); // 19.999 VAULT
        assert!( (primary_fungible_store::balance( signer::address_of(user_2), metadata )) == 20_00000000, 3); // 20 VAULT

        // Fast forward 100 days to simulate staking duration
        let i:u64=1;  
        while(i <= 100) 
        {
            timestamp::fast_forward_seconds(EPOCH_DURATION);
            end_epoch();
            i=i+1; // Incrementing the counter
        };

        // Top up rewards for both validators
        stake::mint(deployer, 100 * ONE_APT);
        mock_validator::topup_rewards( deployer, signer::address_of(validator_1) );
        mock_validator::topup_rewards( deployer, signer::address_of(validator_2) );

        // User 2 requests to redeem VAULT tokens
        vault::request_redeem( user_2, 10_00000000 );

        // Wait for another 3 days to complete the redemption process 
        i=1;  
        while(i <= 3) 
        {
            timestamp::fast_forward_seconds(EPOCH_DURATION);
            end_epoch();
            i=i+1; // Incrementing the counter
        };

        // Fulfill the redemption request
        vault::fulfil_request();

        // Check the APT balance after redemption 
        assert!(coin::balance<AptosCoin>(signer::address_of(user_2)) == 10_19363765, 4 );  // User 2 received 10.19 APT
    }


    #[test_only]
    public fun create_test_accounts(
        deployer: &signer,
        validator_1: &signer,
        validator_2: &signer,
        user_1: &signer,
        user_2: &signer
    ) {
        account::create_account_for_test(signer::address_of(deployer)); 
        account::create_account_for_test(signer::address_of(validator_1));
        account::create_account_for_test(signer::address_of(validator_2)); 
        account::create_account_for_test(signer::address_of(user_1)); 
        account::create_account_for_test(signer::address_of(user_2)); 
        account::create_account_for_test( vault::get_config_object_address() ); 
        account::create_account_for_test( mock_validator::get_config_object_address() ); 
    }

    #[test_only]
    public fun initialize_for_test( aptos_framework: &signer) {
        initialize_for_test_custom(
            aptos_framework,
            100 * ONE_APT,
            10000 * ONE_APT,
            LOCKUP_CYCLE_SECONDS,
            true,
            1,
            1000,
            1000000
        );
    }

    #[test_only]
    public fun end_epoch() {
        stake::end_epoch();
        reconfiguration::reconfigure_for_test_custom();
    }

    // Convenient function for setting up the mock system
    #[test_only]
    public fun initialize_for_test_custom(
        aptos_framework: &signer,
        minimum_stake: u64,
        maximum_stake: u64,
        recurring_lockup_secs: u64,
        allow_validator_set_change: bool,
        rewards_rate_numerator: u64,
        rewards_rate_denominator: u64,
        voting_power_increase_limit: u64
    ) {
        account::create_account_for_test(signer::address_of(aptos_framework));
        
        features::change_feature_flags_for_testing(aptos_framework, vector[
            COIN_TO_FUNGIBLE_ASSET_MIGRATION,
            DELEGATION_POOLS,
            MODULE_EVENT,
            OPERATOR_BENEFICIARY_CHANGE,
            COMMISSION_CHANGE_DELEGATION_POOL
        ], vector[ ]);

        reconfiguration::initialize_for_test(aptos_framework);
        stake::initialize_for_test_custom(
            aptos_framework,
            minimum_stake,
            maximum_stake,
            recurring_lockup_secs,
            allow_validator_set_change,
            rewards_rate_numerator,
            rewards_rate_denominator,
            voting_power_increase_limit
        );
    }

}