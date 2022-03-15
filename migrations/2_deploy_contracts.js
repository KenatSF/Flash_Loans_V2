let Flashloan = artifacts.require("Flashy");

const path = require('path')
require('dotenv').config({ path: path.resolve(__dirname, '../.env') })

module.exports = async function (deployer, network) {
    try {
        await deployer.deploy(Flashloan, process.env.MY_ACCOUNT_0, '0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5', 'Botsy');
    } catch (e) {
        console.log(`Error in migration: ${e.message}`);
    }
}