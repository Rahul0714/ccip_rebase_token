// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
/**
 * @title Rebase Token
 * @author Rahul
 * @notice This is a cross-chain rebase token that incentives users to deposit into vault and gain interest in rewards
 * @notice The interest rate in smart contract can only descrease
 * @notice Each user will have their own interest rate that is the global interest rate at the time of deposit
 */

contract RebaseToken is ERC20, Ownable, AccessControl {

    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private s_interestRate = 5e10;
    uint256 private PRECISION_FACTOR = 1e18;
    bytes32 private MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    mapping(address user => uint256 interestRate) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate); 
    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    } 


    //check this interest rate only decrease
    function setInterestRate(uint256 _interestRate) external onlyOwner{
        if(s_interestRate <= _interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _interestRate);
        }
        s_interestRate = _interestRate;
        emit InterestRateSet(s_interestRate);
    }
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE){
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE){
        
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    function balanceOf(address _user) public view override returns(uint256) {
        return (super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user)) / PRECISION_FACTOR;
    }

    function principleBalanceOf(address _user) external view returns(uint256) {
        return super.balanceOf(_user);
    }

    function transfer(address _to, uint256 _amount) public override returns(bool) {
        _mintAccruedInterest(_to);
        _mintAccruedInterest(msg.sender);
        if(_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if(balanceOf(_to) == 0) {
            s_userInterestRate[_to] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_to, _amount);
    }

    function transferFrom(address _from, address _to, uint256 _amount) public override returns(bool) {
        _mintAccruedInterest(_from);
        _mintAccruedInterest(_to);
        if(_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        if(balanceOf(_to) == 0) {
            s_userInterestRate[_to] = s_userInterestRate[_from];
        }
        return super.transferFrom(_from, _to, _amount);
    }


    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns(uint256) {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        return (PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed));
    }

    function _mintAccruedInterest(address _user) internal {
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        uint256 currentPrincipleBalance = balanceOf(_user);
        uint256 increasedBalance = currentPrincipleBalance - previousPrincipleBalance;
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        _mint(_user, increasedBalance); 
    }


    function getGlobalInterestRate() external view returns(uint256) {
        return s_interestRate;
    }
    function getUserInterestRate(address _user) external view returns(uint256) {
        return s_userInterestRate[_user];
    }
    function getInterestRate() external view returns(uint256) {
        return s_interestRate;
    }

}