// app-policy.js
console.log("app-policy.js loaded");
// Truffle/Lab style Web3.js front-end for Policy contract
// Runs in browser. Serve this folder with:  python3 -m http.server 8020
// Then open http://127.0.0.1:8020/policy.html

const Web3 = window.Web3; // loaded globally from script tag in HTML

let web3;
let accounts = [];
let activeIndex = 0;
let Policy = null;
let policyAbi = null;
// ---------- Utils ----------
function safeStringify(obj, space=0) {
  return safeStringify(obj, (_, v) => (typeof v === 'bigint' ? v.toString() : v), space);
}

// De-proxy Web3 "Result" objects into plain JSONable data (avoid circular refs)
function toPlain(val, seen = new Set()) {
  if (typeof val === 'bigint') return val.toString();
  if (val === null || val === undefined) return val;
  if (Array.isArray(val)) return val.map(v => toPlain(v, seen));
  const t = typeof val;
  if (t === 'function') return undefined;
  if (t !== 'object') return val;
  if (seen.has(val)) return '[Circular]';
  seen.add(val);
  const out = {};
  for (const k of Object.keys(val)) {
    try {
      const v = val[k];
      if (typeof v !== 'function') out[k] = toPlain(v, seen);
    } catch (e) {
      out[k] = `[Unserializable: ${e.message}]`;
    }
  }
  seen.delete(val);
  return out;
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
    // Lab style: connect directly to Ganache JSON-RPC
    web3 = new Web3("http://127.0.0.1:8545");
    accounts = await web3.eth.getAccounts();
    if (!accounts.length) throw new Error("No accounts from Ganache. Is ganache-cli running?");
    // Populate dropdown
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

// ---------- Load Policy ABI + Contract ----------
async function loadPolicyAbi() {
  if (policyAbi) return policyAbi;
  const res = await fetch("./build/contracts/Policy.json");
  if (!res.ok) throw new Error("Failed to fetch build/contracts/Policy.json");
  const artifact = await res.json();
  policyAbi = artifact.abi;
  return policyAbi;
}

export async function loadPolicyContract() {
  try {
    if (!web3) throw new Error("Click 'Init RPC (Ganache)' first.");
    const addr = $("#policyAddress").value.trim();
    if (!addr) throw new Error("Please enter the Policy contract address.");
    const abi = await loadPolicyAbi();
    Policy = new web3.eth.Contract(abi, addr);
    log(`Policy loaded at ${addr}`);
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

// ---------- Reads ----------
export async function uiGetPolicy() {
  try {
    if (!Policy) throw new Error("Load the Policy contract first.");
    const id = BigInt($("#policyId").value || "0");
    const result = await Policy.methods.getPolicy(id.toString()).call({ from: accounts[activeIndex] });
    // result could be array/tuple — display raw + friendly mapping when possible
    log(`getPolicy(${id}) → ${safeStringify(result)}`);
    $("#getPolicyOut").textContent = safeStringify(result, 2);
  } catch (e) {
    console.error(e); log(`getPolicy error: ${e.message}`);
  }
}

export async function uiIsPolicyActiveAt() {
  try {
    if (!Policy) throw new Error("Load the Policy contract first.");
    const id = BigInt($("#policyId2").value || "0");
    let tsRaw = ($("#timestamp").value || "0").trim();
    // If a ms timestamp was entered (13+ digits), convert to seconds
    // if (/^\d{13,}$/.test(tsRaw)) {
    //   tsRaw = String(Math.floor(Number(tsRaw) / 1000));
    // }
    const ts = BigInt(tsRaw || "0");
    const ok = await Policy.methods.isPolicyActiveAt(id.toString(), ts.toString()).call({ from: accounts[activeIndex] });
    log(`isPolicyActiveAt(${id}, ${ts}) → ${ok}`);
    $("#isActiveOut").textContent = ok ? "YES" : "NO";
  } catch (e) {
    console.error(e); log(`isPolicyActiveAt error: ${e.message}`);
  }
}

// ---------- Dynamic callers (optional) ----------
export async function uiCallPolicy() {
  try {
    if (!Policy) throw new Error("Load the Policy contract first.");
    const fn = $("#callFn").value.trim();
    const args = ($("#callArgs").value.trim() || "")
      .split(",")
      .map(s => s.trim())
      .filter(Boolean);
    if (!Policy.methods[fn]) throw new Error(`Function "${fn}" not in ABI`);
    const res = await Policy.methods[fn](...args).call({ from: accounts[activeIndex] });
    log(`call ${fn}(${args.join(", ")}) → ${safeStringify(res)}`);
  } catch (e) {
    console.error(e); log(`call error: ${e.message}`);
  }
}

export async function uiSendPolicy() {
  try {
    if (!Policy) throw new Error("Load the Policy contract first.");
    const fn = $("#sendFn").value.trim();
    const args = ($("#sendArgs").value.trim() || "")
      .split(",")
      .map(s => s.trim())
      .filter(Boolean);
    if (!Policy.methods[fn]) throw new Error(`Function "${fn}" not in ABI`);
    const gas = await Policy.methods[fn](...args).estimateGas({ from: accounts[activeIndex] });
    const tx = await Policy.methods[fn](...args).send({
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
  $("#btnLoadPolicy").addEventListener("click", loadPolicyContract);
  $("#activeAccount").addEventListener("change", onActiveAccountChanged);
  $("#btnGetPolicy").addEventListener("click", uiGetPolicy);
  $("#btnIsActive").addEventListener("click", uiIsPolicyActiveAt);
  $("#btnCall").addEventListener("click", uiCallPolicy);
  $("#btnSend").addEventListener("click", uiSendPolicy);
});
