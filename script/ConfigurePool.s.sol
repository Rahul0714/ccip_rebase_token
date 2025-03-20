// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "../lib/forge-std/src/Script.sol";
import {TokenPool} from "../lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "../lib/ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";

contract ConfigurePool is Script {
    function run(
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteToken,
        bool outBoundRateLimiterEnabled,
        uint128 outBoundRateLimiterCapacity,
        uint128 outBoundRateLimiterRate,
        bool inBoundRateLimiterEnabled,
        uint128 inBoundRateLimiterCapacity,
        uint128 inBoundRateLimiterRate
    ) public {
        vm.startBroadcast();
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector:remoteChainSelector,
            allowed:true,
            remotePoolAddress:abi.encode(address(remotePool)),
            remoteTokenAddress:abi.encode(address(remoteToken)),
            outboundRateLimiterConfig:RateLimiter.Config({
                isEnabled:outBoundRateLimiterEnabled,
                capacity:outBoundRateLimiterCapacity,
                rate:outBoundRateLimiterRate
            }),
            inboundRateLimiterConfig:RateLimiter.Config({
                isEnabled:inBoundRateLimiterEnabled,
                capacity:inBoundRateLimiterCapacity,
                rate:inBoundRateLimiterRate
            })
        });
        TokenPool(localPool).applyChainUpdates(chainsToAdd);
        vm.stopBroadcast();
    }
}
