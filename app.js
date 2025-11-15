'use strict';

const POLICY_ABI = [
  {
    "inputs": [
      { "internalType": "uint128", "name": "effectiveAt", "type": "uint128" },
      { "internalType": "uint128", "name": "expiresAt",   "type": "uint128" },
      { "internalType": "uint128", "name": "maxCoverage", "type": "uint128" },
      { "internalType": "uint128", "name": "deductible",  "type": "uint128" },
      { "internalType": "string",  "name": "details",     "type": "string"  }
    ],
    "name": "createPolicy",
    "outputs": [{ "internalType": "uint256", "name": "policyId", "type": "uint256" }],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType":"uint256", "name":"policyId", "type":"uint256" }],
    "name": "getPolicy",
    "outputs": [
      { "internalType":"address","name":"holder",     "type":"address" },
      { "internalType":"uint128","name":"effectiveAt","type":"uint128" },
      { "internalType":"uint128","name":"expiresAt",  "type":"uint128" },
      { "internalType":"uint128","name":"maxCoverage","type":"uint128" },
      { "internalType":"uint128","name":"deductible", "type":"uint128" },
      { "internalType":"bool",   "name":"active",     "type":"bool"    },
      { "internalType":"string", "name":"details",    "type":"string"  }
    ],
    "stateMutability":"view",
    "type":"function"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true,  "internalType":"uint256","name":"policyId",    "type":"uint256" },
      { "indexed": true,  "internalType":"address","name":"holder",      "type":"address" },
      { "indexed": false, "internalType":"uint128","name":"effectiveAt", "type":"uint128" },
      { "indexed": false, "internalType":"uint128","name":"expiresAt",   "type":"uint128" },
      { "indexed": false, "internalType":"uint128","name":"maxCoverage", "type":"uint128" },
      { "indexed": false, "internalType":"uint128","name":"deductible",  "type":"uint128" },
      { "indexed": false, "internalType":"string", "name":"details",     "type":"string"  }
    ],
    "name": "PolicyCreated",
    "type": "event"
  }
];

const CLAIM_ABI = [
  {
    "inputs":[
      {"internalType":"bytes8","name":"claimCode","type":"bytes8"},
      {"internalType":"uint256","name":"policyId","type":"uint256"},
      {"internalType":"uint64","name":"incidentAt","type":"uint64"},
      {"internalType":"string","name":"incidentAddress","type":"string"},
      {"internalType":"string","name":"description","type":"string"},
      {"internalType":"uint8","name":"incidentType","type":"uint8"}
    ],
    "name":"createClaim",
    "outputs":[{"internalType":"bytes8","name":"","type":"bytes8"}],
    "stateMutability":"nonpayable",
    "type":"function"
  },
  {
    "inputs":[{"internalType":"bytes8","name":"claimCode","type":"bytes8"}],
    "name":"getClaim",
    "outputs":[
      {
        "components":[
          {"internalType":"bytes8","name":"claimCode","type":"bytes8"},
          {"internalType":"address","name":"claimant","type":"address"},
          {"internalType":"uint64","name":"createdAt","type":"uint64"},
          {"internalType":"uint256","name":"policyId","type":"uint256"},
          {"internalType":"address","name":"policyHolder","type":"address"},
          {"internalType":"uint64","name":"policyEffectiveAt","type":"uint64"},
          {"internalType":"uint64","name":"policyExpiresAt","type":"uint64"},
          {"internalType":"uint128","name":"policyMaxCoverage","type":"uint128"},
          {"internalType":"uint128","name":"policyDeductible","type":"uint128"},
          {"internalType":"string","name":"policyDetails","type":"string"},
          {"internalType":"address","name":"adjuster","type":"address"},
          {"internalType":"address","name":"shop","type":"address"},
          {"internalType":"address","name":"payee","type":"address"},
          {"internalType":"uint8","name":"status","type":"uint8"},
          {"internalType":"uint64","name":"submittedAt","type":"uint64"},
          {"internalType":"uint64","name":"severityProposedAt","type":"uint64"},
          {"internalType":"uint64","name":"severityFinalizedAt","type":"uint64"},
          {"internalType":"uint64","name":"quoteSubmittedAt","type":"uint64"},
          {"internalType":"uint64","name":"approvedAt","type":"uint64"},
          {"internalType":"uint64","name":"paidAt","type":"uint64"},
          {"internalType":"uint64","name":"closedAt","type":"uint64"},
          {"internalType":"uint64","name":"incidentAt","type":"uint64"},
          {"internalType":"string","name":"incidentAddress","type":"string"},
          {"internalType":"string","name":"description","type":"string"},
          {"internalType":"uint8","name":"incidentType","type":"uint8"},
          {"internalType":"uint128","name":"finalCapAmount","type":"uint128"},
          {"internalType":"string","name":"adjusterNotes","type":"string"},
          {"internalType":"bool","name":"isCapLocked","type":"bool"},
          {"internalType":"uint128","name":"quoteAmount","type":"uint128"},
          {"internalType":"string","name":"quoteRef","type":"string"},
          {"internalType":"address","name":"quoteCurrency","type":"address"},
          {"internalType":"uint128","name":"approvedAmount","type":"uint128"},
          {"internalType":"address","name":"payoutCurrency","type":"address"},
          {"internalType":"uint256","name":"escrowId","type":"uint256"},
          {"internalType":"bool","name":"payoutToShop","type":"bool"},
          {"internalType":"bytes32","name":"payoutTxRef","type":"bytes32"}
        ],
        "internalType":"struct Claim.ClaimData",
        "name":"",
        "type":"tuple"
      }
    ],
    "stateMutability":"view",
    "type":"function"
  },
  {
    "anonymous":false,
    "inputs":[
      {"indexed":true,"internalType":"bytes8","name":"claimCode","type":"bytes8"},
      {"indexed":true,"internalType":"address","name":"claimant","type":"address"},
      {"indexed":false,"internalType":"uint64","name":"incidentAt","type":"uint64"},
      {"indexed":false,"internalType":"string","name":"incidentAddress","type":"string"},
      {"indexed":false,"internalType":"string","name":"description","type":"string"},
      {"indexed":false,"internalType":"uint8","name":"incidentType","type":"uint8"},
      {"indexed":true,"internalType":"uint256","name":"policyId","type":"uint256"}
    ],
    "name":"ClaimSubmitted",
    "type":"event"
  },
  {
    "inputs": [
      { "internalType":"bytes8",  "name":"claimCode", "type":"bytes8"  },
      { "internalType":"uint128", "name":"amount",    "type":"uint128" },
      { "internalType":"string",  "name":"quoteRef",  "type":"string"  },
      { "internalType":"address", "name":"currency",  "type":"address" }
    ],
    "name":"submitRepairQuote",
    "outputs":[],
    "stateMutability":"nonpayable",
    "type":"function"
  },
  {
    "anonymous":false,
    "inputs":[
      {"indexed":true,"internalType":"bytes8","name":"claimCode","type":"bytes8"},
      {"indexed":true,"internalType":"address","name":"shop","type":"address"},
      {"indexed":false,"internalType":"uint128","name":"quoteAmount","type":"uint128"},
      {"indexed":false,"internalType":"string","name":"quoteRef","type":"string"},
      {"indexed":false,"internalType":"address","name":"quoteCurrency","type":"address"}
    ],
    "name":"QuoteSubmitted",
    "type":"event"
  },
  {
  "inputs": [
    { "internalType": "bytes8",  "name": "claimCode", "type": "bytes8" },
    { "internalType": "address", "name": "shop",      "type": "address" }
  ],
  "name": "setShop",
  "outputs": [],
  "stateMutability": "nonpayable",
  "type": "function"
  },
  {
  "anonymous": false,
  "inputs": [
    { "indexed": true,  "internalType":"bytes8",  "name":"claimCode", "type":"bytes8"  },
    { "indexed": true,  "internalType":"address", "name":"shop",      "type":"address" }
  ],
  "name": "ShopAssigned",
  "type": "event"
  }
];

let web3;
let account = null;
let chainId = null;
let policy, claim; 
let POLICY_ADDRESS = "";
let CLAIM_ADDRESS  = "";

function parseGasInputs(prefix) {
  const gasStr = (el(prefix + "Gas")?.value || "").trim();
  const gpStr  = (el(prefix + "GasPrice")?.value || "").trim();
  const valStr = (el(prefix + "Value")?.value || "").trim();
  const sendOpts = {};
  if (gasStr) {
    const n = Number(gasStr);
    if (Number.isFinite(n) && n > 21000) sendOpts.gas = Math.floor(n);
  }
  if (gpStr) {
    try { sendOpts.gasPrice = web3.utils.toWei(gpStr, "gwei"); } catch {}
  }
  if (valStr) {
    sendOpts.value = valStr;
  }
  return sendOpts;
}

const el = (id) => document.getElementById(id);
const STATUS = ["Submitted","SeverityProposed","SeverityFinalized","QuoteSubmitted","PayoutApproved","Denied","Paid","Closed"];
const INCIDENT = ["Collision","Theft","Vandalism","Weather","Other"];

function assert(cond, msg) { if (!cond) throw new Error(msg || "Assertion failed"); }

function toSeconds(dtLocalValue) {
  if (!dtLocalValue) return null;
  const ms = Date.parse(dtLocalValue);
  if (Number.isNaN(ms)) return null;
  return Math.floor(ms / 1000);
}
function tsToISO(ts) {
  if (!ts) return "";
  const n = typeof ts === "string" ? Number(ts) : ts;
  if (!Number.isFinite(n) || n <= 0) return "";
  return new Date(n * 1000).toISOString();
}
function asEtherMaybe(x) {
  try { return web3.utils.fromWei(x, "ether"); } catch { return x?.toString?.() ?? String(x); }
}

function asciiToBytes8(str) {
  assert(typeof str === "string", "claim code must be string");
  const s = str.trim().toUpperCase();
  assert(/^[A-Z][0-9]{7}$/.test(s), "Code must match ^[A-Z][0-9]{7}$");
  const hex = web3.utils.utf8ToHex(s);
  assert(hex.length === 18, "Claim code must be exactly 8 ASCII chars");
  return hex;
}
function bytes8ToAscii(hex) {
  try { return web3.utils.hexToUtf8(hex); } catch { return hex; }
}

function renderKV(obj) {
  const escape = (v) => (v === null || v === undefined ? "" : String(v));
  return `
    <div class="kv small">
      ${Object.entries(obj).map(([k,v]) => `<div class="muted">${k}</div><div class="mono">${escape(v)}</div>`).join("")}
    </div>
  `;
}

function setStatus(acct, chain) {
  el("acct").textContent = acct || "—";
  el("chain").textContent = chain || "—";
}

function attachContracts() {
  assert(web3, "Init RPC");
  assert(web3.utils.isAddress(POLICY_ADDRESS), "Invalid Policy address");
  assert(web3.utils.isAddress(CLAIM_ADDRESS), "Invalid Claim address");
  policy = new web3.eth.Contract(POLICY_ABI, POLICY_ADDRESS);
  claim  = new web3.eth.Contract(CLAIM_ABI,  CLAIM_ADDRESS);
}

function requireContractsReady() {
  assert(web3 && account, "Init RPC and choose an account");
  assert(policy && claim, "Set the contract addresses and click 'Use These Addresses'");
}

async function initGanache() {
  const url = el("rpcUrl").value.trim() || "http://127.0.0.1:8545";
  web3 = new Web3(new Web3.providers.HttpProvider(url));
  const accounts = await web3.eth.getAccounts();
  if (!accounts || accounts.length === 0) throw new Error("No accounts from RPC. Is Ganache running?");
  const sel = el("activeAccount");
  sel.innerHTML = accounts.map(a => `<option value="${a}">${a}</option>`).join("");
  account = accounts[0];
  sel.value = account;
  sel.addEventListener("change", () => {
    account = sel.value;
    setStatus(account, chainId);
  });
  try { chainId = await web3.eth.getChainId(); } catch { chainId = "unknown"; }
  setStatus(account, chainId);
}

async function createPolicy() {
  requireContractsReady();
  const effectiveAt = toSeconds(el("effectiveAt").value);
  const expiresAt   = toSeconds(el("expiresAt").value);
  const maxCoverage = el("maxCoverage").value.trim();
  const deductible  = el("deductible").value.trim();
  const details     = el("details").value.trim();

  assert(effectiveAt && expiresAt, "Provide valid Effective/Expires times");
  assert(effectiveAt < expiresAt, "Effective must be before Expires");
  assert(maxCoverage && deductible, "Provide coverage and deductible");

  el("policyTx").textContent = "Submitting transaction…";
  try {
    const method = policy.methods.createPolicy(
      String(effectiveAt), String(expiresAt), String(maxCoverage), String(deductible), details
    );
    try { await method.call({ from: account, ...(parseGasInputs("policy").value ? { value: parseGasInputs("policy").value } : {}) }); } catch (dryErr) { throw dryErr; }
    let sendOpts = { from: account, ...parseGasInputs("policy") };
    if (!sendOpts.gas) {
      try {
        const est = await method.estimateGas({ from: account, value: sendOpts.value || 0 });
        sendOpts.gas = Math.max(300000, Math.ceil(est * 1.25));
      } catch (egErr) {
        sendOpts.gas = 1000000;
      }
    }
    const tx = await method.send(sendOpts);
    let newId = null;
    if (tx?.events?.PolicyCreated?.returnValues?.policyId) newId = tx.events.PolicyCreated.returnValues.policyId;
    el("policyTx").innerHTML = `Policy created. TX: <span class="mono">${tx.transactionHash}</span>${newId ? " • Policy ID: "+newId : ""}`;
  } catch (err) {
    el("policyTx").innerHTML = `<span class="err">Error:</span> ${(err && (err.message || err.reason || JSON.stringify(err)))}`;
    console.error(err);
  }
}

async function loadMyPolicies() {
  requireContractsReady();
  el("policiesList").innerHTML = `<span class="muted">Loading your PolicyCreated events…</span>`;
  try {
    const latest = await web3.eth.getBlockNumber();
    const holderFilter = { holder: account };
    const events = await policy.getPastEvents("PolicyCreated", {
      filter: holderFilter, fromBlock: 0, toBlock: latest
    });
    if (!events.length) {
      el("policiesList").innerHTML = `<span class="warn">No policies found for ${account}</span>`;
      return;
    }
    events.sort((a,b) => (a.blockNumber - b.blockNumber) || (a.logIndex - b.logIndex));
    const rows = [];
    for (const ev of events) {
      const id = ev.returnValues.policyId || ev.returnValues[0];
      const p  = await policy.methods.getPolicy(String(id)).call();
      rows.push(renderPolicy(id, p));
    }
    el("policiesList").innerHTML = rows.join("<hr/>");
  } catch (err) {
    el("policiesList").innerHTML = `<span class="err">Error:</span> ${(err && (err.message || err.reason || JSON.stringify(err)))}`;
    console.error(err);
  }
}

function renderPolicy(id, p) {
  const holder      = p.holder ?? p[0];
  const effectiveAt = p.effectiveAt ?? p[1];
  const expiresAt   = p.expiresAt ?? p[2];
  const maxCoverage = p.maxCoverage ?? p[3];
  const deductible  = p.deductible ?? p[4];
  const active      = (p.active ?? p[5]) ? "true" : "false";
  const details     = p.details ?? p[6];
  const kv = {
    "Policy ID": id,
    "Holder": holder,
    "Effective": tsToISO(effectiveAt),
    "Expires": tsToISO(expiresAt),
    "Max Coverage (USD)": String(maxCoverage),
    "Max Coverage (Ether)": asEtherMaybe(String(maxCoverage)),
    "Deductible (USD)": String(deductible),
    "Deductible (Ether)": asEtherMaybe(String(deductible)),
    "Active": active,
    "Details": details
  };
  return `<div class="card">${renderKV(kv)}</div>`;
}

async function createClaim() {
  requireContractsReady();
  const policyId   = el("claimPolicyId").value.trim();
  const codeStr    = el("claimCode").value.trim();
  const incidentAt = toSeconds(el("incidentAt").value);
  const incAddr    = el("incidentAddress").value.trim();
  const desc       = el("description").value.trim();
  const incType    = el("incidentType").value;

  assert(policyId, "Enter Policy ID");
  const code = asciiToBytes8(codeStr);
  assert(incidentAt, "Provide a valid incident time");
  assert(incAddr, "Provide an incident address");
  assert(desc, "Provide a description");

  el("claimTx").textContent = "Submitting transaction…";
  try {
    const method = claim.methods.createClaim(
      code, String(policyId), String(incidentAt), incAddr, desc, String(incType)
    );
    try { await method.call({ from: account, ...(parseGasInputs("claim").value ? { value: parseGasInputs("claim").value } : {}) }); } catch (dryErr) { throw dryErr; }
    let sendOpts = { from: account, ...parseGasInputs("claim") };
    if (!sendOpts.gas) {
      try {
        const est = await method.estimateGas({ from: account, value: sendOpts.value || 0 });
        sendOpts.gas = Math.max(300000, Math.ceil(est * 1.25));
      } catch (egErr) {
        sendOpts.gas = 1000000;
      }
    }
    const tx = await method.send(sendOpts);
    el("claimTx").innerHTML = `Claim created. TX: <span class="mono">${tx.transactionHash}</span>`;
  } catch (err) {
    el("claimTx").innerHTML = `<span class="err">Error:</span> ${(err && (err.message || err.reason || JSON.stringify(err)))}`;
    console.error(err);
  }
}

async function loadMyClaims() {
  requireContractsReady();
  el("claimsList").innerHTML = `<span class="muted">Loading your ClaimSubmitted events…</span>`;
  try {
    const latest = await web3.eth.getBlockNumber();
    const claimantFilter = { claimant: account };
    const events = await claim.getPastEvents("ClaimSubmitted", {
      filter: claimantFilter, fromBlock: 0, toBlock: latest
    });
    if (!events.length) {
      el("claimsList").innerHTML = `<span class="warn">No claims found for ${account}</span>`;
      return;
    }
    events.sort((a,b) => (a.blockNumber - b.blockNumber) || (a.logIndex - b.logIndex));
    const rows = [];
    for (const ev of events) {
      const raw = ev.returnValues.claimCode || ev.returnValues[0];
      const id = "0x" + raw.slice(2, 18);
      const c  = await claim.methods.getClaim(String(id)).call();
      rows.push(renderClaimToUser(c));
    }
    el("claimsList").innerHTML = rows.join("<hr/>");
  } catch (err) {
    el("claimsList").innerHTML = `<span class="err">Error:</span> ${(err && (err.message || err.reason || JSON.stringify(err)))}`;
    console.error(err);
  }
}

async function submitShopQuote() {
  requireContractsReady();
  const codeStr    = el("claimCode").value.trim();
  const shopAddr = el("shopAddress").value.trim();
  const quoteAmount = el("quoteAmount").value.trim();
  const quoteRef    = el("quoteRef").value.trim();
  const quoteCurrency = el("quoteCurrency").value.trim() || "0x0000000000000000000000000000000000000000"; // default value

  const code = asciiToBytes8(codeStr);
  assert(shopAddr, "Provide a valid shop address");
  assert(quoteAmount, "Provide a valid quote amount");
  assert(quoteRef, "Provide quote reference notes");

  el("quoteTx").textContent = "Submitting transaction…";
  try {
    let method = claim.methods.setShop(
      code, shopAddr
    );
    try { await method.call({ from: account, ...(parseGasInputs("quote").value ? { value: parseGasInputs("quote").value } : {}) }); } catch (dryErr) { throw dryErr; }
    let sendOpts = { from: account, ...parseGasInputs("quote") };
    if (!sendOpts.gas) {
      try {
        const est = await method.estimateGas({ from: account, value: sendOpts.value || 0 });
        sendOpts.gas = Math.max(300000, Math.ceil(est * 1.25));
      } catch (egErr) {
        sendOpts.gas = 1000000;
      }
    }
    let tx = await method.send(sendOpts);
    method = claim.methods.submitRepairQuote(
      code, quoteAmount, String(quoteRef), quoteCurrency
    );
    try { await method.call({ from: account, ...(parseGasInputs("quote").value ? { value: parseGasInputs("quote").value } : {}) }); } catch (dryErr) { throw dryErr; }
    sendOpts = { from: account, ...parseGasInputs("quote") };
    if (!sendOpts.gas) {
      try {
        const est = await method.estimateGas({ from: account, value: sendOpts.value || 0 });
        sendOpts.gas = Math.max(300000, Math.ceil(est * 1.25));
      } catch (egErr) {
        sendOpts.gas = 1000000;
      }
    }
    tx = await method.send(sendOpts);
    el("quoteTx").innerHTML = `Shop quote submitted. TX: <span class="mono">${tx.transactionHash}</span>`;
    const updated = await claim.methods.getClaim(code).call();
    el("claimResult").innerHTML = renderClaim(updated);
  } catch (err) {
    el("quoteTx").innerHTML = `<span class="err">Error:</span> ${(err && (err.message || err.reason || JSON.stringify(err)))}`;
    console.error(err);
  }
}

function renderClaim(c) {
  const kv = {
    "Claim Code": bytes8ToAscii(c.claimCode ?? c[0]),
    "Claimant": c.claimant ?? c[1],
    "Created": tsToISO(c.createdAt ?? c[2]),
    "Policy ID": String(c.policyId ?? c[3]),
    "Policy Holder": c.policyHolder ?? c[4],
    "Policy Effective": tsToISO(c.policyEffectiveAt ?? c[5]),
    "Policy Expires": tsToISO(c.policyExpiresAt ?? c[6]),
    "Policy Max (USD)": String(c.policyMaxCoverage ?? c[7]),
    "Policy Deductible (USD)": String(c.policyDeductible ?? c[8]),
    "Policy Details": c.policyDetails ?? c[9],
    "Adjuster": c.adjuster ?? c[10],
    "Shop": c.shop ?? c[11],
    "Payee": c.payee ?? c[12],
    "Status": STATUS[Number(c.status ?? c[13]) || 0],
    "Submitted At": tsToISO(c.submittedAt ?? c[14]),
    "Severity Proposed At": tsToISO(c.severityProposedAt ?? c[15]),
    "Severity Finalized At": tsToISO(c.severityFinalizedAt ?? c[16]),
    "Quote Submitted At": tsToISO(c.quoteSubmittedAt ?? c[17]),
    "Approved At": tsToISO(c.approvedAt ?? c[18]),
    "Paid At": tsToISO(c.paidAt ?? c[19]),
    "Closed At": tsToISO(c.closedAt ?? c[20]),
    "Incident At": tsToISO(c.incidentAt ?? c[21]),
    "Incident Address": c.incidentAddress ?? c[22],
    "Incident Description": c.description ?? c[23],
    "Incident Type": INCIDENT[Number(c.incidentType ?? c[24]) || 0],
    "Final Cap Amount": String(c.finalCapAmount ?? c[25]),
    "Adjuster Notes": c.adjusterNotes ?? c[26],
    "Cap Locked": (c.isCapLocked ?? c[27]) ? "true" : "false",
    "Quote Amount": String(c.quoteAmount ?? c[28]),
    "Quote Ref": c.quoteRef ?? c[29],
    "Quote Currency": c.quoteCurrency ?? c[30],
    "Approved Amount": String(c.approvedAmount ?? c[31]),
    "Payout Currency": c.payoutCurrency ?? c[32],
    "Escrow ID": String(c.escrowId ?? c[33]),
    "Payout To Shop": (c.payoutToShop ?? c[34]) ? "true" : "false",
    "Payout Tx Ref": (c.payoutTxRef ?? c[35])
  };
  return `<div class="card">${renderKV(kv)}</div>`;
}

function renderClaimToUser(c) {
  const kv = {
    "Claim Code": bytes8ToAscii(c.claimCode ?? c[0]),
    "Claimant": c.claimant ?? c[1],
    "Created": tsToISO(c.createdAt ?? c[2]),
    "Policy ID": String(c.policyId ?? c[3]),
    "Policy Holder": c.policyHolder ?? c[4],
    "Policy Effective": tsToISO(c.policyEffectiveAt ?? c[5]),
    "Policy Expires": tsToISO(c.policyExpiresAt ?? c[6]),
    "Policy Max (USD)": String(c.policyMaxCoverage ?? c[7]),
    "Policy Deductible (USD)": String(c.policyDeductible ?? c[8]),
    "Policy Details": c.policyDetails ?? c[9],
    "Adjuster": c.adjuster ?? c[10],
    "Shop": c.shop ?? c[11],
    "Payee": c.payee ?? c[12],
    "Status": STATUS[Number(c.status ?? c[13]) || 0],
    "Submitted At": tsToISO(c.submittedAt ?? c[14]),
    "Paid At": tsToISO(c.paidAt ?? c[19]),
    "Closed At": tsToISO(c.closedAt ?? c[20]),
    "Incident At": tsToISO(c.incidentAt ?? c[21]),
    "Incident Address": c.incidentAddress ?? c[22],
    "Incident Description": c.description ?? c[23],
    "Incident Type": INCIDENT[Number(c.incidentType ?? c[24]) || 0],
    "Quote Amount": String(c.quoteAmount ?? c[28]),
    "Approved Amount": String(c.approvedAmount ?? c[31]),
  };
  return `<div class="card">${renderKV(kv)}</div>`;
}

window.addEventListener("DOMContentLoaded", () => {
  el("initGanacheBtn").addEventListener("click", async () => {
    try { await initGanache(); } catch (err) { alert((err && (err.message || err.reason || JSON.stringify(err)))); }
  });
  el("saveAddressesBtn").addEventListener("click", () => {
    POLICY_ADDRESS = el("policyAddress").value.trim();
    CLAIM_ADDRESS  = el("claimAddress").value.trim();
    try { attachContracts(); alert("Attached to contracts"); }
    catch (err) { alert((err && (err.message || err.reason || JSON.stringify(err)))); }
  });
  el("createPolicyBtn").addEventListener("click", async () => {
    try { await createPolicy(); } catch (err) { alert((err && (err.message || err.reason || JSON.stringify(err)))); }
  });
  el("loadPoliciesBtn").addEventListener("click", async () => {
    try { await loadMyPolicies(); } catch (err) { alert((err && (err.message || err.reason || JSON.stringify(err)))); }
  });
  el("createClaimBtn").addEventListener("click", async () => {
    try { await createClaim(); } catch (err) { alert((err && (err.message || err.reason || JSON.stringify(err)))); }
  });
  el("loadClaimsBtn").addEventListener("click", async () => {
    try { await loadMyClaims(); } catch (err) { alert((err && (err.message || err.reason || JSON.stringify(err)))); }
  });
  el("submitRepairQuoteBtn").addEventListener("click", async () => {
    try { await submitShopQuote(); } catch (err) { alert((err && (err.message || err.reason || JSON.stringify(err)))); }
  });
});
