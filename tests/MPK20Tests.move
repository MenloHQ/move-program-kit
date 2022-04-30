#[test_only]
module MPK::MPK20Tests {
    use Std::Signer;
    use MPK::MPK20::Self;

    #[test(mint = @0x1, owner = @0x2)]
    fun successful_initialize_mint(mint: signer, owner: signer) {
        MPK20::initialize_mint(&mint, 6);
        MPK20::initialize_balances(&owner);
    }

    #[test(mint = @0x1, minter = @0x2, from = @0x3, to = @0x4)]
    fun successful_transfer(
        mint: signer,
        minter: signer,
        from: signer,
        to: signer
    ) {

        let mint_addr = Signer::address_of(&mint);
        let from_addr = Signer::address_of(&from);
        let to_addr = Signer::address_of(&to);

        MPK20::initialize_mint(&mint, 6);
        MPK20::initialize_minter(&minter);
        MPK20::initialize_balances(&from);
        MPK20::initialize_balances(&to);

        MPK20::set_mint_allowance(
            &mint,
            Signer::address_of(&mint),
            Signer::address_of(&minter),
            100
        );

        MPK20::mint_to(
            &minter,
            mint_addr,
            Signer::address_of(&from),
            100
        );
        assert!(MPK20::balance_of(mint_addr, from_addr) == 100, 0);
        assert!(MPK20::balance_of(mint_addr, to_addr) == 0, 0);

        MPK20::transfer(
            &from,
            Signer::address_of(&mint),
            Signer::address_of(&to),
            100
        );
        assert!(MPK20::balance_of(mint_addr, from_addr) == 0, 0);
        assert!(MPK20::balance_of(mint_addr, to_addr) == 100, 0);

        MPK20::burn(
            &to,
            mint_addr,
            100
        );
        assert!(MPK20::balance_of(mint_addr, from_addr) == 0, 0);
        assert!(MPK20::balance_of(mint_addr, to_addr) == 0, 0);
    }
}