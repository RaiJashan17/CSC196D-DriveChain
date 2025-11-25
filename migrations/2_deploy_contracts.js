require('dotenv').config();
const axios  = require('axios');

const Policy = artifacts.require("Policy");
const Claim  = artifacts.require("Claim");

function toBytes8ClaimCode(code, web3) {
  if (!/^[A-Z][0-9]{7}$/.test(code)) throw new Error("claimCode must be [A-Z][0-9]{7}");
  const hex = web3.utils.asciiToHex(code);
  if (hex.length !== 18) throw new Error("bad hex for bytes8: " + hex);
  return hex;
}
async function getJSON(url) {
  const { data } = await axios.get(url, { timeout: 20_000 });
  return data;
}
function mapIncidentType(s) {
  const map = { Collision:0, Theft:1, Vandalism:2, Weather:3 };
  if (map[s] === undefined) throw new Error("bad incidentType: " + s);
  return map[s];
}
function stripSlash(s){ return s.replace(/\/$/, ''); }

function clampToWindow(x, a, b) {
  if (typeof x !== 'number') x = Number(x)|0;
  if (typeof a !== 'number') a = Number(a)|0;
  if (typeof b !== 'number') b = Number(b)|0;
  if (a >= b) return a;
  if (x < a) return a;
  if (x >= b) return b - 1;
  return x|0;
}

module.exports = async function (deployer, network, accounts) {
  const admin = accounts[0];

  await deployer.deploy(Policy, { from: admin });
  const policy = await Policy.deployed();

  await deployer.deploy(Claim, policy.address, { from: admin });
  const claim = await Claim.deployed();

  const gateway = stripSlash(process.env.CLAIMS_GATEWAY || "http://127.0.0.1:8080");
  const polCid  = process.env.POLICIES_CID;
  const clmCid  = process.env.CLAIMS_CID;
  const limit   = parseInt(process.env.CLAIMS_LIMIT || "0", 10);

  const policyInfos = [];
  if (polCid) {
    const rootPol = `${gateway}/ipfs/${polCid}`;
    const manPol  = await getJSON(`${rootPol}/policies.manifest.json`);
    if (!manPol || !Array.isArray(manPol.files)) throw new Error("bad policies.manifest");
    console.log(`Importing ${manPol.files.length} policies...`);

    for (let i=0; i<manPol.files.length; i++) {
      const f = manPol.files[i];
      const data = await getJSON(`${rootPol}/policies/${f}`);

      const holder = accounts[Math.min(accounts.length-1, Math.max(1, data.holderIndex))];
      const eff = data.effectiveAt|0;
      const exp = data.expiresAt|0;

      const maxC = data.maxCoverageETH;
      const ded  = data.deductibleETH;
      const det  = data.details || "";

      const tx = await policy.createPolicy(eff, exp, maxC, ded, det, { from: holder });
      const ev = tx.logs.find(l => l.event === 'PolicyCreated');
      const policyId = ev ? ev.args.policyId.toString() : String(i+1);

      policyInfos.push({ id: policyId, holder, eff, exp });
      console.log("  policy created", { index: i+1, policyId, holder, eff, exp, maxCoverageETH: data.maxCoverageETH, deductibleETH: data.deductibleETH });
    }
  } else {
    console.log("No POLICIES_CID; skipping policy import.");
  }

  if (clmCid) {
    const rootClm = `${gateway}/ipfs/${clmCid}`;
    const manClm  = await getJSON(`${rootClm}/claims.manifest.json`);
    if (!manClm || !Array.isArray(manClm.files)) throw new Error("bad claims.manifest");

    const files = limit > 0 ? manClm.files.slice(0, limit) : manClm.files;
    console.log(`Importing ${files.length} claims...`);

    for (let i=0;i<files.length;i++){
      const fname = files[i];
      const data = await getJSON(`${rootClm}/claims/${fname}`);

      const codeHex  = toBytes8ClaimCode(data.claimCode, web3);
      const pIndex   = Math.max(1, data.policyIndex|0) - 1;
      const pInfo    = policyInfos[pIndex] || policyInfos[0];

      if (!pInfo) throw new Error("No policies created; cannot import claims");

      const incidentAtRaw = data.incidentAt|0;
      const incidentAt    = clampToWindow(incidentAtRaw, pInfo.eff, pInfo.exp);

      const incidentAddress = data.incidentAddress || "";
      const description     = data.description || "";
      const incidentType    = mapIncidentType(data.incidentType);

      const claimant = pInfo.holder;
      const policyId = pInfo.id;

      try {
        let tx;
        tx = await claim.createClaim(codeHex, policyId, incidentAt, incidentAddress, description, incidentType, { from: claimant });
        console.log("  claim created", {
          code: data.claimCode,
          policyId,
          claimant,
          incidentAt
        });
      } catch (err) {
        console.error("  failed to create claim", fname, err.message, {
          policyWindow: [pInfo.eff, pInfo.exp],
          incidentAtRaw
        });
        throw err;
      }
    }
  } else {
    console.log("No CLAIMS_CID; skipping claim import.");
  }

  console.log("Policy:", policy.address);
  console.log("Claim: ", claim.address);
};
