import "@stdlib/ownable";
import "./messages.tact";
import "./structs.tact";
import "./../sbt/sbt_item.tact";
import "./../sbt/messages.tact";

// storage#_ owner:MsgAddress
//           jetton_wallet:MsgAddress
//           next_item_index:uint64
//           reward_supply:coins
//           balance:coins
//           ^[collection_content:^Cell common_content:^Cell]
//           = Storage;

contract Staking with OwnableTransferable {
    const MIN_STORAGE: Int = ton("0.1");
    const MIN_MINT_GAS: Int = ton("0.05");
    const MIN_UNSTAKE_GAS: Int = ton("0.1");
    const REVOKE_GAS: Int = ton("0.02");
    const UNSTAKE_GAS: Int = ton("0.03");
    const MIN_STAKE_AMOUNT: Int = 100 * pow(10, 5);
    const HUNDRED_PERCENT: Int = 10000000000; // 100.00000000%
    //const MAX_PERCENT: Int = 3000000000; // 30.00000000%
    const MAX_PERCENT: Int = 10000000000; // 100.00000000% (test)
    const MIN_PERCENT: Int = 100000000; // 1.00000000%
    //const BASE_REWARD_SUPPLY: Int = 1000000 * pow(10, 5); // 1M jettons with decimal 5
    const BASE_REWARD_SUPPLY: Int = 100000 * pow(10, 5); // 100k jettons with decimal 5 (test)
    //const MIN_LOCKUP: Int = 604800; // 7 days
    const MIN_LOCKUP: Int = 60; // 1 minute (test)
    const MAX_LOCKUP: Int = 31536000; // 1 year
    const ONE_YEAR: Int = 31536000; // 1 year
    const DEV_FEE: Int = 100000000; // 1.00000000%

    owner: Address;
    jetton_wallet: Address?;
    next_item_index: Int as uint64;
    reward_supply: Int as coins;
    balance: Int as coins;
    dev_fee_balance: Int as coins;
    content: Cell;

    init(owner: Address, content: Cell) {
        self.owner = owner;
        self.jetton_wallet = null;
        self.next_item_index = 0;
        self.reward_supply = 0;
        self.balance = 0;
        self.dev_fee_balance = 0;
        self.content = content;
    }

    receive(msg: Deploy) {
        require(self.jetton_wallet == null, "Already initiated");
        self.jetton_wallet = msg.jetton_wallet;
    }

    receive(msg: ChangeContent) {
        self.requireOwner();
        self.content = msg.new_content;
    }

    receive(msg: TakeExcess) {
        self.requireOwner();
        nativeReserve(self.MIN_STORAGE, 2);
        send(SendParameters{
            to: self.owner,
            value: 0,
            mode: SendRemainingBalance,
            body: Excesses {
                query_id: msg.query_id
            }.toCell()
        });
        self.exit_without_saving();
    }

    receive(msg: TakeDevFee) {
        self.requireOwner();
        self.send_jettons(msg.query_id, self.dev_fee_balance, sender(), self.jetton_wallet!!, 0, SendRemainingValue, null);
        self.dev_fee_balance = 0;
    }

    // accept jettons for staking. 
    // forward_payload donate#6e872bd4
    //                 stake#18f2907e lockup_time:uint64
    // (if donate flag set, lock period can be omitted)
    receive(msg: JettonNotify) {
        let ctx: Context = context();
        let msg_value: Int = ctx.value;
        let forward_payload: Slice = msg.forward_payload;
        if (ctx.sender != self.jetton_wallet || msg_value < self.MIN_MINT_GAS || 
            forward_payload.empty() || forward_payload.loadUint(1) == 0) {
            self.send_jettons(msg.query_id, msg.amount, msg.from, ctx.sender, 0, SendRemainingValue, null);
            self.exit_without_saving();
        }
        let payload: Slice = forward_payload.loadRef().beginParse();
        if (payload.bits() < 32) {
            self.send_jettons(msg.query_id, msg.amount, msg.from, ctx.sender, 0, SendRemainingValue, null);
            self.exit_without_saving();
        }
        let op: Int = payload.loadUint(32);
        if (op == DONATE_OP) { // donate to reward pool
            self.reward_supply = self.reward_supply + msg.amount;
            self.balance = self.balance + msg.amount;
            send(SendParameters{
                to: msg.from,
                value: 0,
                bounce: false,
                mode: SendRemainingValue,
                body: Excesses {
                    query_id: msg.query_id
                }.toCell()
            });
            return;
        }

        if (op != STAKE_OP || payload.bits() < 64 || msg.amount < self.MIN_STAKE_AMOUNT ) {
            self.send_jettons(msg.query_id, msg.amount, msg.from, ctx.sender, 0, SendRemainingValue, null);
            self.exit_without_saving();
        }
        let lockup_time: Int = payload.loadUint(64);
        lockup_time = max(min(lockup_time, self.MAX_LOCKUP), self.MIN_LOCKUP);

        let reward_percent: Int = self.MAX_PERCENT;
        if (self.reward_supply < self.BASE_REWARD_SUPPLY) {
            reward_percent = self.MAX_PERCENT * self.reward_supply / self.BASE_REWARD_SUPPLY;
        }

        if (reward_percent < self.MIN_PERCENT) {
            self.send_jettons(msg.query_id, msg.amount, msg.from, ctx.sender, 0, SendRemainingValue, "Reward pool exausted".asComment());
            self.exit_without_saving();
        }
        let reward_factor: Int = reward_percent * lockup_time / self.ONE_YEAR;
        let reward: Int = msg.amount * reward_factor / self.HUNDRED_PERCENT;
        reward = min(reward, self.reward_supply);
        let dev_fee: Int = reward * self.DEV_FEE / self.HUNDRED_PERCENT;
        self.reward_supply = self.reward_supply - reward;
        self.balance = self.balance + msg.amount;
        self.dev_fee_balance = self.dev_fee_balance + dev_fee;

        let now_time: Int = now();
        let stake_info: StakeInfo = StakeInfo {
            lock_time: now_time,
            unlock_time: now_time + lockup_time,
            body: msg.amount,
            redeem: msg.amount + reward - dev_fee
        };
        let content: StringBuilder = beginString();
        content.append(self.next_item_index.toString());
        content.append(".json");
        let deploy_message: DeployItem = DeployItem {
            owner: msg.from,
            stake_info: stake_info,
            content: content.toCell(),
            authority: myAddress()
        };
        self.mint_sbt(self.next_item_index, deploy_message);
        self.next_item_index = self.next_item_index + 1;
    }

    // owner requested unstake
    receive(msg: OwnershipProof) {
        let ctx: Context = context();
        let sbt: Address = self.get_nft_address_by_index(msg.item_index);
        require(ctx.sender == sbt, "SBT from another collection");
        require(msg.revoked_at == 0, "SBT revoked");
        require(msg.content != null, "No content provided");
        let content: Slice = (msg.content!!).beginParse();
        content.loadUint(64); // skip lock_time
        let unlock_time: Int = content.loadUint(64); // unlock_time
        require(now() >= unlock_time, "Lockup period is not over");
        content.loadCoins(); // skip body
        let redeem: Int = content.loadCoins(); // redeem
        send(SendParameters{
            to: sbt,
            value: self.REVOKE_GAS,
            mode: SendPayGasSeparately,
            body: Revoke {
                query_id: msg.query_id
            }.toCell()
        });
        let msg_value: Int = ctx.value - self.UNSTAKE_GAS - self.REVOKE_GAS - ctx.readForwardFee();
        self.send_jettons(msg.query_id, redeem, msg.owner, self.jetton_wallet!!, msg_value, 0, "Unstake".asComment());
        self.balance = self.balance - redeem;
    }

    fun get_sbt_item_init(index: Int): StateInit {
        return initOf SbtItem(myAddress(), index);
    }

    fun mint_sbt(item_index: Int, deploy_message: DeployItem) {
        let nft_init: StateInit = self.get_sbt_item_init(item_index);
        let nft_address: Address = contractAddress(nft_init);
        send(SendParameters{
            to: nft_address,
            value: 0,
            mode: SendRemainingValue,
            code: nft_init.code,
            data: nft_init.data,
            body: deploy_message.toCell()
        });
    }

    inline fun exit_without_saving() {
        commit();
        throw(0);
    }

    fun send_jettons(query_id: Int, jetton_amount: Int, destination: Address, jetton_address: Address, value: Int, mode: Int, payload: Cell?) {
        let forward_payload: Cell? = null;
        if (payload == null) {
            forward_payload = beginCell().storeUint(0, 1).endCell();
        } else {
            forward_payload = beginCell().storeUint(1, 1).storeRef(payload!!).endCell();
        }
        send(SendParameters{
            to: jetton_address,
            value: value,
            bounce: false,
            mode: mode,
            body: JettonTransfer {
                query_id: query_id,
                amount: jetton_amount,
                destination: destination,
                response_destination: destination,
                custom_payload: beginCell().storeUint(0, 1).endCell(),
                forward_ton_amount: 1,
                forward_payload: (forward_payload!!).asSlice()
            }.toCell()
        });
    }

    get fun get_collection_data(): CollectionData {
        let content: Slice = self.content.beginParse(); // for some reason inlining `self.content.beginParse().loadRef()` returns error when compiling from fc
        return CollectionData {
            next_item_index: self.next_item_index,
            content: content.loadRef(), // we need to send only collection meta without common meta
            owner: self.owner
        };
    }

    get fun get_nft_address_by_index(index: Int): Address {
        let init_state: StateInit = self.get_sbt_item_init(index);
        return contractAddress(init_state);
    }

    get fun get_nft_content(index: Int, individual_content: Cell): Cell {
        let content: Slice = self.content.beginParse();
        content.loadRef(); // skip collection meta, next is common meta
        let result: StringBuilder = beginString();
        result.append(content.loadRef().beginParse().asString());
        result.append(individual_content.beginParse().asString());
        return beginCell()
                .storeUint(0x01, 8) // off-chain content flag
                .storeRef(result.toCell())
                .endCell();
    }

    get fun get_staking_info(): StakingInfo {
        return StakingInfo {
            reward_supply: self.reward_supply,
            balance: self.balance,
            base_reward_supply: self.BASE_REWARD_SUPPLY,
            min_stake: self.MIN_STAKE_AMOUNT,
            max_percent: self.MAX_PERCENT,
            min_percent: self.MIN_PERCENT,
            max_lockup: self.MAX_LOCKUP,
            min_lockup: self.MIN_LOCKUP
        };
    }
}