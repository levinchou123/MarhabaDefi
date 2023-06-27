// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract TestToken is ERC20Upgradeable {
    uint256 private constant _totalSupply = 8 * 10**8 * 10**18; // 800M

    function initialize(string memory name, string memory symbol) public initializer {
        __ERC20_init(name, symbol);

        // allocate all the found to the contract
        _mint(msg.sender, _totalSupply);
    }
}
