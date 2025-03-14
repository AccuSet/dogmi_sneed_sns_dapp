import { dogmi_sneed_dapp_backend } from "../../declarations/dogmi_sneed_dapp_backend";
import { Principal } from "@dfinity/principal";

var d8 = Number(100000000);

function toJsonString(o) {
  return JSON.stringify(o, (key, value) =>
      typeof value === 'bigint'
          ? value.toString()
          : value // return everything else unchanged
  );
}

function getSubaccount() {
  var result = new Uint8Array(32);
  var arr_sub = new Uint8Array(32);
  var cnt = 0;

  var st_sub = document.getElementById("subaccount").value.toString();

  if (st_sub && st_sub.length > 0) {
    if (st_sub.indexOf(',') < 0) { st_sub += ','; }
    var arr = st_sub.split(',');

    for (var i = 0; i < arr.length; i++) {
      var st_val = arr[i];
      if (st_val) {

        st_val = st_val.trim();

        if (st_val.length > 0) {

          var i_val = parseInt(st_val);

          if (i_val) {
            if (i_val >= 0 && i_val <= 255) {
              arr_sub[cnt++] = i_val;
              if (cnt >= 32) {
                alert("Subaccount values out of range: A maximum of 32 values between 0 and 255 is allowed as a comma separated list."); 
                return -1; 
                //break;
              }
            } else { alert("Subaccount value out of range: " + i_val + ". Values must be between 0 and 255."); return -1; }
          }  
        }
      }
    }

    if (cnt > 0) { result = arr_sub; }

  }

  var sub = []; 
  sub[0] = arr_sub; 
  result = sub;

  return result;
}

document.getElementById("convert").addEventListener("click", async (e) => {
  e.preventDefault();
  const button = e.target;

  const acct = document.getElementById("account").value.toString();
  const subaccount = getSubaccount(); 
  if (subaccount && subaccount < 1) {
    return false;
  }
  
  let account = {
    "owner" : Principal.fromText(acct),
    "subaccount" : subaccount
  };

  button.setAttribute("disabled", true);

  document.getElementById("result").innerHTML = "<img src='loading-gif.gif' class='loading-gif' />";

  const result = await dogmi_sneed_dapp_backend.convert_account(account);

  const ok = result["Ok"];
  if (ok) {

    const txid = ok;
    // const url = "https://dashboard.internetcomputer.org/sns/zxeu2-7aaaa-aaaaq-aaafa-cai/transaction/" + txid;
    // const link = "<a href='" + url + "' target='_blank'>" + txid + "</a>"
    document.getElementById("result").innerHTML = "Converted";

  } else {

    const err = result["Err"];

    if (err) {

      if (err["OnCooldown"]) {

        document.getElementById("result").innerHTML = "This function is on cooldown, please return in an hour.";

      } else if (err["StaleIndexer"]) {

        document.getElementById("result").innerHTML = "The transaction indexer is not up to date. Please try again in a while.";

      } else {

        document.getElementById("result").innerHTML = toJsonString(result);
  
      }

    } else {

      document.getElementById("result").innerHTML = toJsonString(result);

    }
  
  }

});


document.querySelector("form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const button = e.target.querySelector("button");

  const acct = document.getElementById("account").value.toString();
  const subaccount = getSubaccount(); 
  if (subaccount && subaccount < 1) {
    return false;
  }

  let account = {
    "owner" : Principal.fromText(acct),
    "subaccount" : subaccount
  };

  button.setAttribute("disabled", true);

  document.getElementById("balance").innerHTML = "<img src='loading-gif.gif' class='loading-gif'/>";

  const result = await dogmi_sneed_dapp_backend.get_account(account);
    
  const ok = result["Ok"];
  if (ok) {

    const balance_d8 = ok["new_total_balance_d8"];
    var balance = 0;

    if (balance_d8 > 0) {

      balance = Number(balance_d8) / d8;
      document.getElementById("convert").removeAttribute("disabled");

    }

    document.getElementById("balance").innerHTML = `Old(non-SNS) DOGMI : ${toJsonString((balance)*(10000))}
        <br>
                                                     New(SNS) DOGMI(Convertable) : ${toJsonString(balance)}`;

  } else {

    document.getElementById("balance").innerHTML = toJsonString(result);

  }

  button.removeAttribute("disabled");

  return false;
});

// Countdown duration (30 days in milliseconds)
const COUNTDOWN_DURATION = 30 * 24 * 60 * 60 * 1000;

// Set the countdown start date (current date)
const countdownStartDate = new Date();
const countdownEndDate = new Date(countdownStartDate.getTime() + COUNTDOWN_DURATION);

// Function to update the countdown timer
function updateCountdown() {
  const currentTime = new Date();
  const timeDifference = countdownEndDate - currentTime;
  
  // Check if countdown has ended
  if (timeDifference <= 0) {
    document.getElementById('countdown-timer').innerHTML = "<span class='expired'>EXPIRED</span>";
    return;
  }
  
  // Calculate days, hours, minutes, and seconds
  const days = Math.floor(timeDifference / (1000 * 60 * 60 * 24));
  const hours = Math.floor((timeDifference % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
  const minutes = Math.floor((timeDifference % (1000 * 60 * 60)) / (1000 * 60));
  const seconds = Math.floor((timeDifference % (1000 * 60)) / 1000);
  
  // Update the countdown display
  document.getElementById('countdown-timer').innerHTML = 
    `<span class="countdown-value">${days}</span> days, 
     <span class="countdown-value">${hours}</span> hours, 
     <span class="countdown-value">${minutes}</span> minutes`;
}

// Initialize countdown and update it every minute
document.addEventListener('DOMContentLoaded', function() {
  updateCountdown();
  setInterval(updateCountdown, 1000*60);
});

let status = await dogmi_sneed_dapp_backend.get_status();
let active = status["active"];
if (active) {
  document.getElementById("submit_button").removeAttribute("disabled"); 
  document.getElementById("convert").removeAttribute("disabled"); 
  document.getElementById("dapp_status").innerHTML = "Active."; 
  document.getElementById("dapp_id").innerText = status["canister_id"]; 
  document.getElementById("dapp_id_warn").innerText = status["canister_id"]; 
  document.getElementById("main_div").setAttribute("class", "active");   
  document.getElementById("test_version").innerText = "";
} else {
  document.getElementById("dapp_status").innerHTML = "Inactive.";   
  document.getElementById("main_div").setAttribute("class", "inactive");   
  document.getElementById("test_version").innerText = "(Test version original app will be deployed after sns launch)";
}