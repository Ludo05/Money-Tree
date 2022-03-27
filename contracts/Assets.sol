// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract Assets {
    AggregatorV3Interface internal AVAX;
    AggregatorV3Interface internal ETH;
    AggregatorV3Interface internal BTC;

    constructor() {
        AVAX = AggregatorV3Interface(0x5498BB86BC934c8D34FDA08E81D444153d0D06aD);
        BTC = AggregatorV3Interface(0x31CF013A08c6Ac228C94551d535d5BAfE19c602a);
        ETH = AggregatorV3Interface(0x86d67c3D38D2bCeE722E601025C25a575021c6EA);

    }

    function getPriceForAsset(string memory asset) public view returns (int256) {
        if (keccak256(abi.encodePacked(asset)) == keccak256(abi.encodePacked("AVAX"))) {
            (,int price,,,) = AVAX.latestRoundData();
            return price;
        } else if (keccak256(abi.encodePacked(asset)) == keccak256(abi.encodePacked("BTC"))) {
            (,int price,,,) = BTC.latestRoundData();
            return price;
        } else if (keccak256(abi.encodePacked(asset)) == keccak256(abi.encodePacked("ETH"))) {
            (,int price,,,) = ETH.latestRoundData();
            return price;
        }
        return 0;
    }

    function test() public pure returns (string memory) {
        return "Tester";
    }
}
