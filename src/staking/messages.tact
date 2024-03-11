const DONATE_OP: Int = 0x6e872bd4;
const STAKE_OP: Int = 0x18f2907e;

message(0x1) Deploy {
    jetton_wallet: Address;
}

message(0x2) TakeDevFee {
    query_id: Int as uint64;
}

message(0x3) ChangeContent {
    new_content: Cell;
}

message(0xf8a7ea5) JettonTransfer {
    query_id: Int as uint64;
    amount: Int as coins;
    destination: Address;
    response_destination: Address?;
    custom_payload: Cell?;
    forward_ton_amount: Int as coins;
    forward_payload: Slice as remaining;
}

message(0x7362d09c) JettonNotify {
    query_id: Int as uint64;
    amount: Int as coins;
    from: Address;
    forward_payload: Slice as remaining;
}