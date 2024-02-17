struct NftData {
    inited: Bool;
    item_index: Int as uint64;
    collection: Address;
    owner: Address?;
    content: Cell?;
}

struct StakeInfo {
    lock_time: Int as uint64;
    unlock_time: Int as uint64;
    body: Int as coins;
    redeem: Int as coins;
}