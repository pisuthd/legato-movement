// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// This is a mock validator staking system cloned from Aptos 
// to use internally for Legato vault during Battle of Olympus Hackathon

module legato_vault_addr::mock_validator {


    use std::vector;
    use std::signer;

    use aptos_framework::timestamp;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::coin::{Self}; 
    
    use aptos_std::table::{Self, Table};
    use aptos_std::fixed_point64::{Self, FixedPoint64};
    use aptos_std::math_fixed64::{Self};

    // ======== Constants ========

    const DEFAULT_APY: u128 = 1291272085159668613; // 7% in fixed-point
    const MIN_APT_TO_STAKE: u64 = 100000000; // 1 APT
    const EPOCH_DURATION: u64 = 86400;

    // ======== Errors ========

    const ERR_DUPLICATED_POOL: u64 = 1;
    const ERR_INVALID_POOL: u64 = 2;
    const ERR_TOO_LOW: u64 = 3;
    const ERR_TOO_EARLY: u64 = 4;
    const ERR_INVALID_USER: u64 = 5;
    const ERR_INSUFFICIENT_AMOUNT: u64 = 6;

    // Each pool may need to be periodically topped up with rewards by the admin.
    // The last timestamp is used to calculate the amount that needs to be topped up.
    struct Pool has store {
        commission_rate: FixedPoint64, // Commission rate for this pool
        staking_table: Table<address, u64>, // Maps staker addresses to their staking amounts
        total_amount: u64, // Total staked amount without rewards
        total_amount_with_rewards: u64, // Total staked amount including rewards
        last_topped_up: u64 // Timestamp of the last reward top-up for this pool
    }

    // Global state of the mock staking system
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct MockGlobal has key {
        pools: Table<address, Pool>, // Stores all pools mapped by validator addresses
        system_reward_rate: FixedPoint64, // System APR
        extend_ref: ExtendRef 
    }

    // Constructor
    fun init_module(sender: &signer) {

        let constructor_ref = object::create_object(signer::address_of(sender));
        let extend_ref = object::generate_extend_ref(&constructor_ref);

        move_to(sender, MockGlobal {
            pools: table::new<address, Pool>(),
            extend_ref,
            system_reward_rate: fixed_point64::create_from_raw_value(DEFAULT_APY ) // default is 7% APY
        });

    }


    public entry fun new_pool(validator_address: address, commission_rate_numerator: u128, commission_rate_denominator: u128) acquires MockGlobal {
        let global = borrow_global_mut<MockGlobal>(@legato_vault_addr);
        assert!( !table::contains( &global.pools, validator_address), ERR_DUPLICATED_POOL );

        let pool = Pool {
            commission_rate: fixed_point64::create_from_rational(commission_rate_numerator, commission_rate_denominator ),
            staking_table: table::new<address, u64>(),
            total_amount: 0,
            total_amount_with_rewards: 0,
            last_topped_up: timestamp::now_seconds()
        };

        table::add(
            &mut global.pools,
            validator_address,
            pool
        );

    }

    public entry fun update_system_reward_rate( system_reward_rate_numerator: u128, system_reward_rate_denominator: u128) acquires MockGlobal {
        let global = borrow_global_mut<MockGlobal>(@legato_vault_addr);
        global.system_reward_rate = fixed_point64::create_from_rational(system_reward_rate_numerator, system_reward_rate_denominator);
    }

    // stake
    public entry fun stake(sender: &signer, validator_address: address, input_amount: u64) acquires MockGlobal {
        assert!(coin::balance<AptosCoin>(signer::address_of(sender)) >= input_amount, ERR_INSUFFICIENT_AMOUNT);
        assert!(input_amount >= MIN_APT_TO_STAKE, ERR_TOO_LOW);

        let global = borrow_global_mut<MockGlobal>(@legato_vault_addr);
        assert!( table::contains( &global.pools, validator_address), ERR_INVALID_POOL );

        let global_object_signer = object::generate_signer_for_extending(&global.extend_ref);

        let pool = table::borrow_mut( &mut global.pools, validator_address);

        // Attaches to object 
        let input_coin = coin::withdraw<AptosCoin>(sender, input_amount);
        if (!coin::is_account_registered<AptosCoin>(signer::address_of(&global_object_signer))) {
            coin::register<AptosCoin>(&global_object_signer);
        };

        coin::deposit(signer::address_of(&global_object_signer), input_coin);

        // Update the total_amount
        pool.total_amount = pool.total_amount+input_amount;
        pool.total_amount_with_rewards = pool.total_amount_with_rewards+input_amount;

        // Update the table
        if (!table::contains(&pool.staking_table, signer::address_of(sender))) { 
            table::add(
                &mut pool.staking_table,
                signer::address_of(sender),
                input_amount
            );
        } else {
            *table::borrow_mut( &mut pool.staking_table, signer::address_of(sender) ) = *table::borrow( &pool.staking_table, signer::address_of(sender) )+input_amount;
        };

    }

    // unstake
    public entry fun unstake(sender: &signer, validator_address: address, unstake_amount: u64) acquires MockGlobal {
        assert!(unstake_amount >= MIN_APT_TO_STAKE, ERR_TOO_LOW);
        
        let global = borrow_global_mut<MockGlobal>(@legato_vault_addr);
        assert!( table::contains( &global.pools, validator_address), ERR_INVALID_POOL );

        let global_object_signer = object::generate_signer_for_extending(&global.extend_ref);

        let pool = table::borrow_mut( &mut global.pools, validator_address);
        assert!( table::contains(&pool.staking_table, signer::address_of(sender)), ERR_INVALID_USER);

        let pricipal_amount = *table::borrow(  &pool.staking_table, signer::address_of(sender) );
        let multiplier = fixed_point64::create_from_rational( (pool.total_amount_with_rewards as u128), (pool.total_amount as u128) );

        let staked_amount = ( fixed_point64::multiply_u128( (pricipal_amount as u128), multiplier  ) as u64 );
        assert!(staked_amount >= unstake_amount, ERR_INSUFFICIENT_AMOUNT);

        let withdrawn_coin = coin::withdraw<AptosCoin>(&global_object_signer, unstake_amount);
        coin::deposit( signer::address_of(sender) , withdrawn_coin);

        // Update the total_amount
        let multiplier_2 = fixed_point64::create_from_rational( (pool.total_amount as u128), (pool.total_amount_with_rewards as u128) );
        let unstake_principal = ( fixed_point64::multiply_u128( (unstake_amount as u128), multiplier_2  ) as u64 );

        pool.total_amount_with_rewards = if ( pool.total_amount_with_rewards >= unstake_amount ) {
            pool.total_amount_with_rewards-unstake_amount
        } else {
            0
        };

        pool.total_amount = if ( pool.total_amount >= unstake_principal ) {
            pool.total_amount-unstake_amount
        } else {
            0
        };

    }


    // topup_rewards
    public entry fun topup_rewards(sender: &signer, validator_address: address) acquires MockGlobal {
        let global = borrow_global_mut<MockGlobal>(@legato_vault_addr);
        assert!( table::contains( &global.pools, validator_address), ERR_INVALID_POOL );

        let global_object_signer = object::generate_signer_for_extending(&global.extend_ref);

        let pool = table::borrow_mut( &mut global.pools, validator_address);
        assert!( pool.total_amount >= MIN_APT_TO_STAKE, ERR_TOO_LOW );
        assert!( timestamp::now_seconds() >= pool.last_topped_up+EPOCH_DURATION, ERR_TOO_EARLY );

        let time = fixed_point64::create_from_rational( ((timestamp::now_seconds()-pool.last_topped_up) as u128), 31556926 );

        // Calculate rt (rate * time)
        let rt = math_fixed64::mul_div( global.system_reward_rate, time, fixed_point64::create_from_u128(1));
        let multiplier = math_fixed64::exp(rt);

        let after_amount = ( fixed_point64::multiply_u128( (pool.total_amount as u128), multiplier  ) as u64 );
        let only_rewards = after_amount-pool.total_amount;

        pool.total_amount_with_rewards = pool.total_amount_with_rewards+only_rewards;

        // Attaches to object 
        let input_coin = coin::withdraw<AptosCoin>(sender, only_rewards);
        if (!coin::is_account_registered<AptosCoin>(signer::address_of(&global_object_signer))) {
            coin::register<AptosCoin>(&global_object_signer);
        };

        coin::deposit(signer::address_of(&global_object_signer), input_coin);
    }

    #[view]    
    public fun get_config_object_address(): address acquires MockGlobal {
        let config = borrow_global_mut<MockGlobal>(@legato_vault_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        signer::address_of(&config_object_signer)
    }

    #[view]
    public fun get_staked(validator_address: address, user_address: address): u64 acquires MockGlobal {
        let global = borrow_global_mut<MockGlobal>(@legato_vault_addr);
        assert!( table::contains( &global.pools, validator_address), ERR_INVALID_POOL );

        let pool = table::borrow( &global.pools, validator_address);
        assert!( table::contains(&pool.staking_table, user_address), ERR_INVALID_USER);

        let pricipal_amount = *table::borrow(  &pool.staking_table, user_address );
        let multiplier = fixed_point64::create_from_rational( (pool.total_amount_with_rewards as u128), (pool.total_amount as u128) );

        ( fixed_point64::multiply_u128( (pricipal_amount as u128), multiplier  ) as u64 )
    }

    // ======== Internal Functions =========

    #[test_only]
    public fun init_module_for_testing(deployer: &signer) {
        init_module(deployer)
    }

}