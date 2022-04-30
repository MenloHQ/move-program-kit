/// MPK20 is a standard for creating, minting, and transferring fungible and non-fungible tokens.
module MPK::MPK20 {
    use Std::Errors;
    use Std::Signer;
    use AptosFramework::Table::{Self, Table};

    /// Error codes
    const EINSUFFICIENT_BALANCE: u64 = 0;
    const EALREADY_HAS_BALANCE: u64 = 1;
    const EBALANCE_NOT_PUBLISHED: u64 = 2;
    const EALREADY_DELEGATED: u64 = 3;
    const EDELEGATION_NOT_FOUND: u64 = 4;

    /// The scaling factor's precision. (10^12)
    const SCALING_FACTOR_PRECISION: u64 = 1000000000000;

    /// One who can own Coins.
    struct Owner has key {
        /// Number of Coins owned by the user.
        balances: Table<address, u64>,
    }

    /// One who can mint Coins.
    struct Minter has key {
        /// Amount of coins that the account can mint.
        allowances: Table<address, u64>,
    }

    /// One who can add and remove minters.
    /// There may only be one of these per Coin.
    struct Progenitor has key, store, drop {
        /// The address of the mint (coin).
        mint: address
    }

    /// Holds the metadata of a Coin.
    struct Mint has key {
        /// The total unscaled supply of the Coin.
        total_supply_unscaled: u64,
        /// Number of decimals that the Coin has.
        decimals: u8,
        /// Used for rebasing supply.
        /// Scaling factor is multiplied by 10^12.
        scaling_factor: u64,
    }

    // --------------------------------
    // Progenitor
    // --------------------------------

    /// Creates a new Mint.
    public fun initialize_mint(
        account: &signer,
        // Number of decimals that the Coin has.
        decimals: u8
    ) {
        let mint_address = Signer::address_of(account);
        assert!(
            !exists<Mint>(mint_address),
            Errors::already_published(EALREADY_HAS_BALANCE)
        );
        assert!(
            !exists<Progenitor>(mint_address),
            Errors::already_published(EALREADY_HAS_BALANCE)
        );
        move_to(account, Mint {
            total_supply_unscaled: 0,
            decimals,
            scaling_factor: SCALING_FACTOR_PRECISION,
        });

        // The initial progenitor is the Mint itself.
        move_to(account, Progenitor {
            mint: mint_address
        });
    }

    /// Updates a minter with the specified allowance.
    public fun set_mint_allowance(
        progenitor: &signer,
        mint: address,
        minter: address,
        allowance: u64
    ) acquires Progenitor, Minter {
        let progenitor_info = borrow_global<Progenitor>(Signer::address_of(progenitor));
        assert!(
            progenitor_info.mint == mint,
            Errors::requires_capability(EDELEGATION_NOT_FOUND)
        );

        assert!(exists<Minter>(minter), Errors::already_published(EALREADY_HAS_BALANCE));
        let allowances = &mut borrow_global_mut<Minter>(minter).allowances;

        if (Table::contains(allowances, &mint)) {
            let allowance_ref = Table::borrow_mut(allowances, &mint);
            *allowance_ref = allowance;
        } else {
            Table::add(allowances, &mint, allowance);
        }
    }

    /// Drops the Progenitor privilege, preventing mint allowances from being modified.
    public fun drop_progenitor(progenitor: &signer) acquires Progenitor {
        move_from<Progenitor>(Signer::address_of(progenitor));
    }

    // --------------------------------
    // Owner/Minter
    // --------------------------------

    /// Publish an empty balance resource under `account`'s address. This function must be called before
    /// minting or transferring to the account.
    public fun initialize_balances(account: &signer) {
        assert!(!exists<Owner>(Signer::address_of(account)), Errors::already_published(EALREADY_HAS_BALANCE));
        move_to(account, Owner { balances: Table::new() });
    }

    /// Publish an empty balance resource under `account`'s address. This function must be called before
    /// minting or transferring to the account.
    public fun initialize_minter(account: &signer) {
        assert!(!exists<Minter>(Signer::address_of(account)), Errors::already_published(EALREADY_HAS_BALANCE));
        move_to(account, Minter { allowances: Table::new() });
    }

    /// Transfers `amount` of coins from `from` to `to`.
    public fun transfer(
        from: &signer,
        mint: address,
        to: address,
        amount: u64
    ) acquires Owner {
        balance_sub_internal(mint, Signer::address_of(from), amount);
        balance_add_internal(mint, to, amount);
    }

    /// Mint coins to an address.
    public fun mint_to(
        minter: &signer,
        mint: address,
        to: address,
        amount: u64
    ) acquires Minter, Mint, Owner {
        let allowances = &mut borrow_global_mut<Minter>(Signer::address_of(minter)).allowances;
        let allowance_ref = Table::borrow_mut(allowances, &mint);

        let supply_ref = &mut borrow_global_mut<Mint>(mint).total_supply_unscaled;

        // Subtract from the allowance of the minter.
        *allowance_ref = *allowance_ref - amount;

        // Update the total supply and the balance of the recipient.
        balance_add_internal(mint, to, amount);
        *supply_ref = *supply_ref + amount;
    }

    /// Burn coins.
    public fun burn(from: &signer, mint: address, amount: u64) acquires Owner, Mint {
        let supply_ref = &mut borrow_global_mut<Mint>(mint).total_supply_unscaled;

        balance_sub_internal(mint, Signer::address_of(from), amount);
        *supply_ref = *supply_ref - amount;
    }

    fun balance_sub_internal(
        mint: address,
        owner: address,
        amount: u64
    ) acquires Owner {
        let owner_balances = &mut borrow_global_mut<Owner>(owner).balances;
        // We cannot subtract balance if the balance doesn't exist.
        assert!(
            Table::contains(owner_balances, &mint),
            Errors::already_published(EALREADY_HAS_BALANCE)
        );

        let owner_balance_ref = Table::borrow_mut(owner_balances, &mint);
        *owner_balance_ref = *owner_balance_ref - amount;
    }

    fun balance_add_internal(
        mint: address,
        owner: address,
        amount: u64
    ) acquires Owner {
        let owner_balances = &mut borrow_global_mut<Owner>(owner).balances;
        if (Table::contains(owner_balances, &mint)) {
            let owner_balance_ref = Table::borrow_mut(owner_balances, &mint);
            *owner_balance_ref = *owner_balance_ref + amount;
        } else {
            Table::add(owner_balances, &mint, amount);
        }
    }

    // --------------------------------
    // Mint getters
    // --------------------------------

    public fun scale_amount(
        unscaled_amount: u64,
        scaling_factor: u64
    ): u64 {
        (((unscaled_amount as u128) * (scaling_factor as u128) / (Self::SCALING_FACTOR_PRECISION as u128)) as u64)
    }

    /// Get the current total supply of the coin, unscaled.
    public fun total_supply(mint: address): u64 acquires Mint {
        borrow_global<Mint>(mint).total_supply_unscaled
    }

    /// Get the current scaling factor of the coin.
    public fun scaling_factor(mint: address): u64 acquires Mint {
        borrow_global<Mint>(mint).scaling_factor
    }

    // --------------------------------
    // Owner getters
    // --------------------------------

    /// Returns the balance of `owner` for the `mint`.
    public fun balance_of(mint: address, owner: address): u64 acquires Owner {
        assert!(exists<Owner>(owner), Errors::not_published(EBALANCE_NOT_PUBLISHED));
        let owner_balances = &borrow_global<Owner>(owner).balances;
        if (Table::contains(owner_balances, &mint)) {
            let balance: &u64 = Table::borrow(owner_balances, &mint);
            *balance
        } else {
            0
        }
    }

    // --------------------------------
    // Scripts
    // --------------------------------

    /// Transfer Coins.
    public(script) fun do_transfer(
        from: signer,
        mint: address,
        to: address,
        amount: u64
    ) acquires Owner {
        transfer(&from, mint, to, amount);
    }

    /// Mint coins with capability.
    public(script) fun do_mint_to(
        minter: signer,
        mint: address,
        to: address,
        amount: u64
    ) acquires Minter, Mint, Owner
    {
        mint_to(&minter, mint, to, amount);
    }

    /// Burn coins.
    public(script) fun do_burn(
        from: signer,
        mint: address,
        amount: u64
    ) acquires Owner, Mint {
        burn(&from, mint, amount);
    }
}
