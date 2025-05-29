// scripts/LocalDeployAll.js

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

// ignition/modules 디렉토리 경로를 절대 경로로 지정
const modulesDir = path.join(__dirname, "../ignition/modules");

fs.readdirSync(modulesDir).forEach((file) => {
  if (file.endsWith(".js")) {
    const modulePath = path.join(modulesDir, file);

    console.log(`Deploying ${file}...`);

    try {
      execSync(`npx hardhat ignition deploy ${modulePath} --network localhost`, {
        stdio: "inherit",
      });
    } catch (error) {
      console.error(`❌ Failed to deploy ${file}:`, error.message);
    }
  }
});
