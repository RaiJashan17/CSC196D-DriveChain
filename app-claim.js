// app-claim.js
console.log("app-claim.js loaded");
// Truffle/Lab style Web3.js front-end for Claim contract
// Serve with:  python3 -m http.server 8030
// Then open http://127.0.0.1:8030/claim.html

const Web3 = window.Web3; // loaded globally from script tag in HTML

let web3;
let accounts = [];
let activeIndex = 0;
let Claim = null;
let claimAbi = null;
// ---------- Utils ----------
function safeStringify(obj, space=0) {
  return safeStringify(obj, (_, v) => (typeof v === 'bigint' ? v.toString() : v), space);
}


// ---------- UI helpers ----------
const $ = (sel) => document.querySelector(sel);
const logEl = () => $("#log");
function log(msg) {
  const now = new Date().toLocaleTimeString();
  logEl().textContent += `[${now}] ${msg}\n`;
  logEl().scrollTop = logEl().scrollHeight;
}
function setConnected(addr) {
  $("#activeAccount").value = String(activeIndex);
  $("#connected").textContent = `Active: ${addr}`;
}

// ---------- Init RPC (Ganache) ----------
export async function initRPC() {
  try {
    web3 = new Web3("http://127.0.0.1:8545");
    accounts = await web3.eth.getAccounts();
    if (!accounts.length) throw new Error("No accounts from Ganache. Is ganache-cli running?");
    const sel = $("#activeAccount");
    sel.innerHTML = "";
    accounts.forEach((a, i) => {
      const opt = document.createElement("option");
      opt.value = String(i);
      opt.textContent = `${i}: ${a}`;
      sel.appendChild(opt);
    });
    activeIndex = 0;
    setConnected(accounts[0]);
    log("RPC initialized (Ganache) and accounts loaded.");
  } catch (e) {
    console.error(e); log(`Init error: ${e.message}`);
  }
}

// ---------- Load Claim ABI + Contract ----------
async function loadClaimAbi() {
  if (claimAbi) return claimAbi;
  const res = await fetch("./build/contracts/Claim.json");
  if (!res.ok) throw new Error("Failed to fetch build/contracts/Claim.json");
  const artifact = await res.json();
  claimAbi = artifact.abi;
  return claimAbi;
}

export async function loadClaimContract() {
  try {
    if (!web3) throw new Error("Click 'Init RPC (Ganache)' first.");
    const addr = $("#claimAddress").value.trim();
    if (!addr) throw new Error("Please enter the Claim contract address.");
    const abi = await loadClaimAbi();
    Claim = new web3.eth.Contract(abi, addr);
    log(`Claim loaded at ${addr}`);
  } catch (e) {
    console.error(e); log(`Load error: ${e.message}`);
  }
}

// ---------- Account switching ----------
export function onActiveAccountChanged() {
  activeIndex = Number($("#activeAccount").value || 0);
  setConnected(accounts[activeIndex]);
  log(`Switched active account to ${accounts[activeIndex]}`);
}

// ---------- transferOwnership (write) ----------
export async function uiTransferOwnership() {
  try {
    if (!Claim) throw new Error("Load the Claim contract first.");
    const to = $("#newOwner").value.trim();
    if (!web3.utils.isAddress(to)) throw new Error("Enter a valid recipient address.");
    const gas = await Claim.methods.transferOwnership(to).estimateGas({ from: accounts[activeIndex] });
    const tx = await Claim.methods.transferOwnership(to).send({
      from: accounts[activeIndex],
      gas,
      gasPrice: web3.utils.toWei("20", "gwei")
    });
    log(`transferOwnership → tx: ${tx.transactionHash}`);
    $("#xferOut").textContent = tx.transactionHash;
  } catch (e) {
    console.error(e); log(`transferOwnership error: ${e.message}`);
  }
}

// ---------- Dynamic callers (optional) ----------
export async function uiCallClaim() {
  try {
    if (!Claim) throw new Error("Load the Claim contract first.");
    const fn = $("#callFn").value.trim();
    const args = ($("#callArgs").value.trim() || "")
      .split(",")
      .map(s => s.trim())
      .filter(Boolean);
    if (!Claim.methods[fn]) throw new Error(`Function "${fn}" not in ABI`);
    const res = await Claim.methods[fn](...args).call({ from: accounts[activeIndex] });
    log(`call ${fn}(${args.join(", ")}) → ${safeStringify(res)}`);
  } catch (e) {
    console.error(e); log(`call error: ${e.message}`);
  }
}

export async function uiSendClaim() {
  try {
    if (!Claim) throw new Error("Load the Claim contract first.");
    const fn = $("#sendFn").value.trim();
    const args = ($("#sendArgs").value.trim() || "")
      .split(",")
      .map(s => s.trim())
      .filter(Boolean);
    if (!Claim.methods[fn]) throw new Error(`Function "${fn}" not in ABI`);
    const gas = await Claim.methods[fn](...args).estimateGas({ from: accounts[activeIndex] });
    const tx = await Claim.methods[fn](...args).send({
      from: accounts[activeIndex],
      gas,
      gasPrice: web3.utils.toWei("20", "gwei")
    });
    log(`tx ${fn}: ${tx.transactionHash}`);
  } catch (e) {
    console.error(e); log(`send error: ${e.message}`);
  }
}

// ---------- Wire UI ----------
window.addEventListener("DOMContentLoaded", () => {
  $("#btnInit").addEventListener("click", initRPC);
  $("#btnLoadClaim").addEventListener("click", loadClaimContract);
  $("#activeAccount").addEventListener("change", onActiveAccountChanged);
  $("#btnXfer").addEventListener("click", uiTransferOwnership);
  $("#btnCall").addEventListener("click", uiCallClaim);
  $("#btnSend").addEventListener("click", uiSendClaim);
});
