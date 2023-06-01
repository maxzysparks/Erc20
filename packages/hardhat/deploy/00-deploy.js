// deploy/00_deploy_my_contract.js

const { ethers } = require("hardhat");

// const sleep = (ms) =>
//   new Promise((r) =>
//     setTimeout(() => {
//       console.log(`waited for ${(ms / 1000).toFixed(3)} seconds`);
//       r();
//     }, ms)
//   );

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("ERC20Token", {
    from: deployer,
    args: ["MyToken", "MTK"], // Specify the name and symbol as arguments
    log: true,
  });
};

module.exports.tags = ["ERC20Token"];
