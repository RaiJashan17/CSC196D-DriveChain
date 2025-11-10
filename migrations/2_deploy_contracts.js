const Policy = artifacts.require("Policy");
const Claim  = artifacts.require("Claim");

module.exports = async function (deployer, network, accounts) {
  const admin    = accounts[0];

  // Deploy Policy
  await deployer.deploy(Policy, { from: admin });
  const policy = await Policy.deployed();

  // Deploy Claim with the Policy registry address
  await deployer.deploy(Claim, policy.address, { from: admin });
  const claim = await Claim.deployed();

  console.log("Policy deployed to:", policy.address);
  console.log("Claim  deployed to:", claim.address);

  // Example Policy and Claim
  // const adjuster = accounts[1];
  // const now = Math.floor(Date.now() / 1000);
  // const oneYear = 365 * 24 * 60 * 60;

  // const effectiveAt = now;
  // const expiresAt   = now + oneYear;

  // const maxCoverage = web3.utils.toBN("5000000");
  // const deductible  = web3.utils.toBN("500");
  // const details     = "Vehicle VIN: TESTVIN123…";

  // const tx = await policy.createPolicy(
  //   effectiveAt,
  //   expiresAt,
  //   maxCoverage,
  //   deductible,
  //   details,
  //   { from: admin }
  // );
  // const policyId = tx.logs[0].args.policyId.toString();
  // console.log("Sample policyId:", policyId);

  // const claimCode = toBytes8("A1234567");
  // const incidentAt = effectiveAt + 60;

  // const incidentType = 0;

  // await claim.createClaim(
  //   claimCode,
  //   policyId,
  //   incidentAt,
  //   "123 Main St",
  //   "Rear bumper damage, drivable",
  //   incidentType,
  //   { from: admin }
  // );
  // console.log("Sample claim created with code A1234567");

  // await claim.setAdjuster(claimCode, adjuster, { from: admin });
  // console.log("Adjuster set to:", adjuster);
};