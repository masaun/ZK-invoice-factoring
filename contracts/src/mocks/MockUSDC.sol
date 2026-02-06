// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @dev Simple ERC20 token for testing purposes
 */
contract MockUSDC is ERC20 {
    uint8 private _decimals;

    constructor() ERC20("USD Coin", "USDC") {
        _decimals = 6; // USDC uses 6 decimals
        _mint(msg.sender, 1000000 * 10**6); // Mint 1M USDC to deployer
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Mint new tokens (for testing purposes)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
