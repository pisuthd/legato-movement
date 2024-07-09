// Test Dynamic Weighted DEX

#[test_only]
module legato_addr::amm_tests {

    use std::string::utf8;
    use std::signer;

    use aptos_framework::account;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::object::{  Object };
    use aptos_framework::fungible_asset::{ Metadata };


    use legato_addr::token_factory;
    use legato_addr::amm::{Self};

    // When setting up a 50/50 pool of ~$100k
    // Initial allocation at 1 LEGATO = 0.001 USDC
    const LEGATO_AMOUNT_50_50: u64  = 50000000_00000000; // 50,000,000 LEGATO
    const USDC_AMOUNT_50_50: u64 = 50000_000000; // 50,000 USDC

    // Initial allocation at 1 XYZ = 50,000 USDC
    const USDC_AMOUNT_90_10: u64 = 10000_000000;  // 10% at 10,000 USDC
    const XYZ_AMOUNT_90_10: u64 = 180_000_000; // 90% at 1.8 XYZ

    // Registering pools
    #[test(deployer = @legato_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_register_pools(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);
    }

    // Swapping tokens
    #[test(deployer = @legato_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_swap_usdc_for_xyz(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);

        let user_address = signer::address_of(user);

        mint_usdc( lp_provider, user_address, 100_000000 ); // 100 USDC
        amm::swap(user, metadata_usdc(), metadata_xyz(), 100_000000, 1 );

        assert!( primary_fungible_store::balance( user_address, metadata_xyz()) == 197_906 , 1 ); // 0.00197906 XBTC at a rate of 1 BTC = 52405 USDT
    }

    #[test(deployer = @legato_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_swap_xyz_for_usdc(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);

        let user_address = signer::address_of(user);

        mint_xyz( lp_provider, user_address, 100000 ); // 0.001 XBTC
        amm::swap(user, metadata_xyz(), metadata_usdc(), 100000, 1 );

        assert!( primary_fungible_store::balance( user_address, metadata_usdc()) == 49_613272 , 1 ); // 49.613272 USDC at a rate of 1 BTC = 51465 USDT
    }

    #[test(deployer = @legato_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_swap_usdc_for_legato(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);

        let user_address = signer::address_of(user);

        mint_usdc( lp_provider, user_address, 250_000000 ); // 250 USDC
        amm::swap(user,  metadata_usdc() , metadata_legato() , 250_000000, 1 );

        assert!( primary_fungible_store::balance( user_address, metadata_legato()) == 247518_59598004 , 1 ); // 247,518 LEGATO at a rate of 0.001010028 LEGATO/USDC
    }

    #[test(deployer = @legato_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_swap_legato_for_usdc(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);

        let user_address = signer::address_of(user);
 
        mint_legato( lp_provider, user_address,  100000_00000000); // 100,000 LEGATO 
        amm::swap(user,  metadata_legato() ,  metadata_usdc(), 100000_00000000, 1 );

        assert!( primary_fungible_store::balance( user_address,  metadata_usdc() ) == 99_302388 , 1 ); // 99.3 USDC at a rate of 0.00099302 LEGATO/USDC
    }

    #[test(deployer = @legato_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_remove_liquidity(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);

        let lp_provider_address = signer::address_of(lp_provider);

        mint_usdc( lp_provider, lp_provider_address,  5000_000000); // 5000 USDC
        mint_xyz( lp_provider, lp_provider_address,  15000000); // 0.15 XYZ

        amm::add_liquidity(
            lp_provider,
            metadata_usdc(),
            metadata_xyz(),
            5000_000000,
            1,
            15000000,
            1
        );

        let lp_metadata =  amm::get_lp_metadata( metadata_usdc(), metadata_xyz() );
        let lp_balance =  primary_fungible_store::balance( lp_provider_address,lp_metadata );

        amm::remove_liquidity(
            lp_provider,
            metadata_usdc(),
            metadata_xyz(),
            lp_balance
        );
        
    }

    #[test_only]
    public fun register_pools(deployer: &signer, lp_provider: &signer, user: &signer) {
        
        token_factory::init_module_for_testing(deployer);
        amm::init_module_for_testing(deployer);    

        let lp_provider_address = signer::address_of(lp_provider);

        deploy_tokens(lp_provider);

        // USDC
        mint_usdc( lp_provider, lp_provider_address, USDC_AMOUNT_50_50+USDC_AMOUNT_90_10 );

        // LEGATO 
        mint_legato( lp_provider, lp_provider_address, LEGATO_AMOUNT_50_50 );

        // XYZ
        mint_xyz( lp_provider, lp_provider_address, XYZ_AMOUNT_90_10 );

        // Setup a 50/50 pool

        amm::register_pool(
            deployer,
            metadata_usdc(),
            metadata_legato(),
            5000,
            5000
        );

        amm::add_liquidity(
            lp_provider,
            metadata_usdc(),
            metadata_legato(),
            USDC_AMOUNT_50_50,
            1,
            LEGATO_AMOUNT_50_50,
            1
        );

        // Setup a 10/90 pool

        amm::register_pool(
            deployer,
            metadata_usdc(),
            metadata_xyz(),
            1000,
            9000
        );

        amm::add_liquidity(
            lp_provider,
            metadata_usdc(),
            metadata_xyz(),
            USDC_AMOUNT_90_10,
            1,
            XYZ_AMOUNT_90_10,
            1
        );

    }

    #[test_only]
    public fun deploy_tokens(lp_provider: &signer) {

        token_factory::deploy_new_token(
            lp_provider,
            utf8(b"Mock USDC Tokens"),
            utf8(b"USDC"),
            0,
            6,
            utf8(b"http://example.com/favicon.ico"),
            utf8(b"http://example.com")
        );

        token_factory::deploy_new_token(
            lp_provider,
            utf8(b"Mock Legato Tokens"),
            utf8(b"LEGATO"),
            0,
            8,
            utf8(b"http://example.com/favicon.ico"),
            utf8(b"http://example.com")
        );

        token_factory::deploy_new_token(
            lp_provider,
            utf8(b"Mock XYZ Tokens"),
            utf8(b"XYZ"),
            0,
            8,
            utf8(b"http://example.com/favicon.ico"),
            utf8(b"http://example.com")
        );

    }

    #[test_only]
    public fun mint_usdc(lp_provider: &signer, recipient: address, amount: u64) {
        token_factory::mint( lp_provider, 0,  recipient , amount );
    }

    #[test_only]
    public fun mint_legato(lp_provider: &signer, recipient: address, amount: u64) {
        token_factory::mint( lp_provider, 1,  recipient , amount );
    }

    #[test_only]
    public fun mint_xyz(lp_provider: &signer, recipient: address, amount: u64) {
        token_factory::mint( lp_provider, 2,  recipient , amount );
    }

     #[test_only]
    public fun metadata_usdc() : Object<Metadata> {
        token_factory::token_metadata_from_id(0)
    }

    #[test_only]
    public fun metadata_legato() : Object<Metadata> {
        token_factory::token_metadata_from_id(1)
    }

    #[test_only]
    public fun metadata_xyz() : Object<Metadata> {
        token_factory::token_metadata_from_id(2)
    }

}