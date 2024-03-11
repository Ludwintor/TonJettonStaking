import "./messages.tact";
import "./structs.tact";

contract SbtItem {
    const MIN_STORAGE: Int = ton("0.03");

    inited: Bool;
    item_index: Int as uint64;
    collection: Address;
    owner: Address?;
    stake_info: StakeInfo?;
    content: Cell?;
    authority: Address?;
    revoked_at: Int as uint64;

    init(collection: Address, item_index: Int) {
        self.inited = false;
        self.collection = collection;
        self.item_index = item_index;
        self.owner = null;
        self.stake_info = null;
        self.content = null;
        self.authority = null;
        self.revoked_at = 0;
    }

    receive(msg: DeployItem) {
        require(!self.inited, "Already initiated");
        require(self.collection == sender(), "Not an origin collection");
        self.inited = true;
        self.owner = msg.owner;
        self.stake_info = msg.stake_info;
        self.content = msg.content;
        self.authority = msg.authority;
        self.revoked_at = 0;
    }

    receive(msg: ProveOwnership) {
        require(self.inited, "Not initiated");
        require(sender() == self.owner, "Not an owner");
        let content: Cell? = null;
        if (msg.with_content) {
            content = (self.stake_info!!).toCell();
        }
        send(SendParameters{
            to: msg.destination,
            value: 0,
            mode: SendRemainingValue,
            body: OwnershipProof {
                query_id: msg.query_id,
                item_index: self.item_index,
                owner: self.owner!!,
                forward_payload: msg.forward_payload,
                revoked_at: self.revoked_at,
                content: content
            }.toCell()
        });
        self.exit_without_saving();
    }

    receive(msg: RequestOwner) {
        require(self.inited, "Not initiated");
        let content: Cell? = null;
        if (msg.with_content) {
            content = (self.stake_info!!).toCell();
        }
        send(SendParameters{
            to: msg.destination,
            value: 0,
            mode: SendRemainingValue,
            body: OwnerInfo {
                query_id: msg.query_id,
                item_index: self.item_index,
                initiator: sender(),
                owner: self.owner!!,
                forward_payload: msg.forward_payload,
                revoked_at: self.revoked_at,
                content: content
            }.toCell()
        });
        self.exit_without_saving();
    }

    // dont want to give opportunity to destroy it
    //receive(msg: Destroy) {
    //    require(self.inited, "Not initiated");
    //    require(sender() == self.owner, "Not an owner");
    //    self.owner = null;
    //    self.authority = null;
    //    send(SendParameters{
    //        to: sender(),
    //        value: 0,
    //        bounce: false,
    //        mode: SendRemainingBalance + SendDestroyIfZero,
    //        body: Excesses {
    //            query_id: msg.query_id
    //        }.toCell()
    //    });
    //}

    receive(msg: Revoke) {
        require(self.inited, "Not initiated");
        require(sender() == self.authority, "Not an authority");
        require(self.revoked_at == 0, "Already revoked");
        self.revoked_at = now();
        send(SendParameters{
            to: self.owner!!, // not an authority cuz in staking contract revoke inited by owner
            value: 0,
            bounce: false,
            mode: SendRemainingBalance + SendDestroyIfZero, // and destroy
            body: Excesses {
                query_id: msg.query_id
            }.toCell()
        });
    }

    receive(msg: TakeExcess) {
        require(self.inited, "Not initiated");
        require(sender() == self.owner, "Not an owner");
        nativeReserve(self.MIN_STORAGE, 2);
        send(SendParameters{
            to: self.owner!!,
            value: 0,
            bounce: false,
            mode: SendRemainingBalance,
            body: Excesses {
                query_id: msg.query_id
            }.toCell()
        });
        self.exit_without_saving();
    }

    receive(msg: GetStaticData) {
        require(self.inited, "Not initiated");
        send(SendParameters{
            to: sender(),
            value: 0,
            mode: SendRemainingValue,
            body: ReportStaticData {
                query_id: msg.query_id,
                item_index: self.item_index,
                collection: self.collection
            }.toCell()
        });
        self.exit_without_saving();
    }

    bounced(msg: bounced<OwnershipProof>) {
        send(SendParameters{
            to: self.owner!!,
            value: 0,
            mode: SendRemainingValue,
            body: OwnershipProofBounced {
                query_id: msg.query_id
            }.toCell()
        });
        self.exit_without_saving();
    }

    inline fun exit_without_saving() {
        commit();
        throw(0);
    }

    get fun get_nft_data(): NftData {
        return NftData {
            inited: self.inited,
            item_index: self.item_index,
            collection: self.collection,
            owner: self.owner,
            content: self.content
        };
    }

    get fun get_authority(): Address? {
        return self.authority;
    }

    get fun get_revoked_time(): Int {
        return self.revoked_at;
    }

    get fun get_stake_info(): StakeInfo {
        return self.stake_info!!;
    }
}