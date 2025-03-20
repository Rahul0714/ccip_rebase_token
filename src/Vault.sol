// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IRebaseToken} from "./interfaces/IRabaseToken.sol";
contract Vault {
    error Value__RedeemFailed(); 

    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken _i_rebaseToken){
        i_rebaseToken = _i_rebaseToken;
    }

    receive() external payable{}

    function deposit() external payable {
        uint256 interestRate = i_rebaseToken.getInterestRate();
        i_rebaseToken.mint(msg.sender,msg.value, interestRate);
        emit Deposit(msg.sender, msg.value);
    }
    function redeem(uint256 _amount) external {
        if(_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        i_rebaseToken.burn(msg.sender, _amount);
        (bool success,) = payable(msg.sender).call{value:_amount}("");
        if(!success) {
            revert Value__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    function getRebaseTokenAddress() external view returns(address) {
        return address(i_rebaseToken);
    }
}