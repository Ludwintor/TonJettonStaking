import "./structs.tact";

message DeployItem {
    owner: Address;
    stake_info: StakeInfo;
    content: Cell?;
    authority: Address;
}

// prove_ownership#04ded148 query_id:uint64 destination:MsgAddress 
// forward_payload:^Cell with_content:Bool = InternalMsgBody;

message(0x04ded148) ProveOwnership {
    query_id: Int as uint64;
    destination: Address;
    forward_payload: Cell;
    with_content: Bool;
}

// ownership_proof#0524c7ae query_id:uint64 item_index:uint256 owner:MsgAddress 
// forward_payload:^Cell revoked_at:uint64 content:(Maybe ^Cell) = InternalMsgBody;

message(0x0524c7ae) OwnershipProof {
    query_id: Int as uint64;
    item_index: Int as uint256;
    owner: Address;
    forward_payload: Cell;
    revoked_at: Int as uint64;
    content: Cell?;
}

message(0xc18e86d2) OwnershipProofBounced {
    query_id: Int as uint64;
}

// request_owner#d0c3bfea query_id:uint64 destination:MsgAddress 
// forward_payload:^Cell with_content:Bool = InternalMsgBody;

message(0xd0c3bfea) RequestOwner {
    query_id: Int as uint64;
    destination: Address;
    forward_payload: Cell;
    with_content: Bool;
}

// owner_info#0dd607e3 query_id:uint64 item_id:uint256 initiator:MsgAddress owner:MsgAddress 
// forward_payload:^Cell revoked_at:uint64 content:(Maybe ^Cell) = InternalMsgBody;

message(0x0dd607e3) OwnerInfo {
    query_id: Int as uint64;
    item_index: Int as uint256;
    initiator: Address;
    owner: Address;
    forward_payload: Cell;
    revoked_at: Int as uint64;
    content: Cell?;
}

message(0x2fcb26a2) GetStaticData { 
    query_id: Int as uint64;
}

message(0x8b771735) ReportStaticData{
    query_id: Int as uint64;
    item_index: Int;
    collection: Address;
}

// destroy#1f04537a query_id:uint64 = InternalMsgBody;
message(0x1f04537a) Destroy {
    query_id: Int as uint64;
}

// revoke#6f89f5e3 query_id:uint64 = InternalMsgBody;
message(0x6f89f5e3) Revoke {
    query_id: Int as uint64;
}

// take_excess#d136d3b3 query_id:uint64 = InternalMsgBody;
message(0xd136d3b3) TakeExcess {
    query_id: Int as uint64;
}

message(0xd53276db) Excesses {
    query_id: Int as uint64;
}