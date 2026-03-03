// scripts/deploy.js
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with:", deployer.address);
  console.log("Balance:", (await deployer.getBalance()).toString());

  // 1. Deploy QGToken
  const QGToken = await hre.ethers.getContractFactory("QGToken");
  const token = await QGToken.deploy();
  await token.deployed();
  console.log("QGToken deployed:", token.address);

  // 2. Deploy QuantumGuardDID
  const DID = await hre.ethers.getContractFactory("QuantumGuardDID");
  const did = await DID.deploy();
  await did.deployed();
  console.log("QuantumGuardDID deployed:", did.address);

  // 3. Verify on Polygonscan
  if (hre.network.name !== "hardhat") {
    console.log("Waiting for block confirmations...");
    await token.deployTransaction.wait(5);
    await did.deployTransaction.wait(5);

    await hre.run("verify:verify", {
      address: token.address,
      constructorArguments: [],
    });

    await hre.run("verify:verify", {
      address: did.address,
      constructorArguments: [],
    });
  }

  // Output addresses for .env
  console.log("\n── .env entries ──");
  console.log(`QG_TOKEN_ADDRESS=${token.address}`);
  console.log(`QG_DID_ADDRESS=${did.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
