// SPDX-License-Identifier: MIT
pragma solidity ^0.7.5;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.2.2-solc-0.7/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.2.2-solc-0.7/contracts/token/ERC20/ERC20.sol";

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {
  event Pause();
  event Unpause();

  bool public paused = true;

  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
  modifier whenPaused() {
    require(paused);
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause() public onlyOwner whenNotPaused {
    paused = true;
    emit Pause();
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() public onlyOwner whenPaused {
    paused = false;
    emit Unpause();
  }
}

contract PersistenceToken is Ownable, ERC20, Pausable {

    /*
    * @info 100M = (100 * 10**6) * 10**18
    */
    constructor () ERC20("Persistence", "XPRT") {
       _mint(msg.sender, (100 * 10**6) * 10**18);
    }

    /*
    * @title Transfer tokens to multiple addresses
    * @return bool
    */
    function transferToMany(address[] calldata to, uint[] calldata tokens) public onlyOwner returns (bool success) {
        assert(to.length == tokens.length);

        for (uint i = 0; i < to.length; i++) {
            super.transfer(to[i], tokens[i]);
        }
        
        return true;
    }

    /*
    * @title Pausing below functions
    * @return bool
    */
    function approve(address _spender, uint _value) public whenNotPaused override returns (bool success) {
        return super.approve(_spender, _value);
    }

    function transfer(address _recipient, uint _value) public whenNotPaused override returns (bool success) {
        return super.transfer(_recipient, _value);
    }

    function increaseAllowance(address _spender, uint _value) public whenNotPaused override returns (bool success) {
        return super.increaseAllowance(_spender, _value);
    }

    function decreaseAllowance(address _spender, uint _value) public whenNotPaused override returns (bool success) {
        return super.decreaseAllowance(_spender, _value);
    }

    function transferFrom(address _sender, address _recipient, uint _value) public whenNotPaused override returns (bool success) {
        return super.transferFrom(_sender, _recipient, _value);
    }
}
