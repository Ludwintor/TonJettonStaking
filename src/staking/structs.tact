struct CollectionData {
    next_item_index: Int as uint64;
    content: Cell;
    owner: Address;
}

struct RoyaltyParams {
    factor: Int as uint16;
    base: Int as uint16;
    destination: Address;
}

struct StakingInfo {
    reward_supply: Int as coins;
    balance: Int as coins;
    base_reward_supply: Int as coins;
    min_stake: Int as coins;
    max_percent: Int as uint64;
    min_percent: Int as uint64;
    max_lockup: Int as uint64;
    min_lockup: Int as uint64;
}