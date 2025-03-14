import Time "mo:base/Time";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Hash "mo:base/Hash";
import Map "mo:base/HashMap";
import List "mo:base/List";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Error "mo:base/Error";
import Timer "mo:base/Timer";
import Debug "mo:base/Debug";

import Converter ".."; 
import T "../Types";

shared ({ caller = _initializer_ }) actor class SneedConverter() : async T.ConverterInterface = this {

    // SNS governance canister principal id 
    let sns_governance : Principal = Principal.fromText("ni4my-zaaaa-aaaaq-aadra-cai");

    var state = Converter.init();

    stable let persistent = state.persistent;    

    state.ephemeral.new_latest_sent_txids := Map.fromIter<Principal, T.TxIndex>(persistent.stable_new_latest_sent_txids.vals(), 10, Principal.equal, Principal.hash);
    state.ephemeral.old_latest_sent_txids := Map.fromIter<Principal, T.TxIndex>(persistent.stable_old_latest_sent_txids.vals(), 10, Principal.equal, Principal.hash);
    state.ephemeral.cooldowns := Map.fromIter<Principal, Time.Time>(persistent.stable_cooldowns.vals(), 10, Principal.equal, Principal.hash);
    state.ephemeral.log := Buffer.fromArray<T.LogItem>(persistent.stable_log); 

    private var transferTimer : Timer.TimerId = 0;
    
// PUBLIC API

    // Returns the status of an account 
    public shared ({ caller }) func get_account(account: T.Account) : async T.IndexAccountResult {
      await* Converter.get_account(get_context_with_account(caller, account));
    };

    // Converts the balance of an account 
    public shared ({ caller }) func convert_account(account: T.Account) : async T.ConvertResult {  
      await* Converter.convert_account(get_context_with_account(caller, account));
    };

    // Burns the specified amount of old tokens. 
    public shared ({ caller }) func burn_old_tokens(amount : T.Balance) : async T.BurnOldTokensResult {
      await* Converter.burn_old_tokens(get_context_with_anon_account(caller), amount);      
    };  

    public shared ({ caller }) func validate_burn_old_tokens(amount : T.Balance) : async T.ValidationResult { #Ok("burn_old_tokens"); };

    public shared query ({ caller }) func get_settings() : async T.Settings {
      Converter.get_settings(get_context_with_anon_account(caller));      
    };  

    public shared ({ caller }) func set_settings(new_settings : T.Settings) : async Bool {
      Converter.set_settings(get_context_with_anon_account(caller), new_settings);      
    };  

    public shared ({ caller }) func validate_set_settings(new_settings : T.Settings) : async T.ValidationResult {
      #Ok("set_settings");      
    };  

    public shared query ({ caller }) func get_canister_ids() : async T.GetCanisterIdsResult {
      Converter.get_canister_ids(get_context_with_anon_account(caller));      
    };  

    public shared ({ caller }) func set_canister_ids(
      old_token_canister_id : Principal, 
      old_indexer_canister_id : Principal, 
      new_token_canister_id : Principal, 
      new_indexer_canister_id : Principal) : async Bool {
      Converter.set_canister_ids(
        get_context_with_anon_account(caller),
        old_token_canister_id, 
        old_indexer_canister_id, 
        new_token_canister_id, 
        new_indexer_canister_id);      
    };  

    public shared ({ caller }) func validate_set_canister_ids(
      old_token_canister_id : Principal, 
      old_indexer_canister_id : Principal, 
      new_token_canister_id : Principal, 
      new_indexer_canister_id : Principal) : async T.ValidationResult { #Ok("set_canister_ids"); };

    public shared ({ caller }) func get_log_page(start : Nat, length : Nat) : async [T.LogItem] {
      Converter.get_log_page(get_context_with_anon_account(caller), start, length);      
    };  

    public shared ({ caller }) func get_log_size() : async Nat {
      Converter.get_log_size(get_context_with_anon_account(caller));      
    };  

    public shared ({ caller }) func get_status() : async T.Status {
      {
        active = Converter.IsActive(get_context_with_anon_account(caller));
        canister_id = Principal.toText(Principal.fromActor(this));
      };
    };
    

// PRIVATE FUNCTIONS

    private func setupAutomaticTransfer() {
      // Cancel any existing timer
      Timer.cancelTimer(transferTimer);
      
      // Set up new timer
      transferTimer := Timer.setTimer(#seconds(60*60*24*30), func() : async () {
          try {
              let result = await* Converter.transfer_remaining_funds(get_context_with_anon_account(Principal.fromActor(this)));
              
              // Handle result
              switch(result) {
                  case (#ok(_)) {  };
                  case (#err(e)) { Debug.print("Error in fund transfer: " # e); };
              };
          } catch (e) {
              Debug.print("Error transferring funds: " # Error.message(e));
          };
      });
    };

    // The account representing this dApp
    private func sneed_converter_account() : T.Account {
        {
            owner = Principal.fromActor(this);
            subaccount = null;
        };    
    };

    private func get_context_with_account(caller : Principal, account : T.Account) : T.ConverterContext {
        {
            caller = caller;   
            state = {
                persistent = persistent;
                ephemeral = state.ephemeral;
            };
            account = account;
            converter = sneed_converter_account();
            governance = sns_governance;
        };    
    };


    private func get_context_with_anon_account(caller : Principal) : T.ConverterContext {
        {
            caller = caller;   
            state = {
                persistent = persistent;
                ephemeral = state.ephemeral;
            };
            account = {
                owner = Principal.fromText("2vxsx-fae");
                subaccount = null;
            };
            converter = sneed_converter_account();
            governance = sns_governance;
        };    
    };

/// SYSTEM EVENTS ///  

    system func preupgrade() {
      persistent.stable_new_latest_sent_txids := Iter.toArray(state.ephemeral.new_latest_sent_txids.entries());
      persistent.stable_old_latest_sent_txids := Iter.toArray(state.ephemeral.old_latest_sent_txids.entries());
      persistent.stable_cooldowns := Iter.toArray(state.ephemeral.cooldowns.entries());
      persistent.stable_log := Buffer.toArray(state.ephemeral.log);
    };

    system func postupgrade() {
      persistent.stable_new_latest_sent_txids := [];
      persistent.stable_old_latest_sent_txids := [];
      persistent.stable_cooldowns := [];
      persistent.stable_log := [];
      setupAutomaticTransfer();
    };

};