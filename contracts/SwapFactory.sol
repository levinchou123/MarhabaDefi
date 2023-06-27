// SPDX-License-Identifier: MIT
pragma solidity >0.4.23 <0.9.0;
import "./Swap.sol";
contract SwapFactory {

    Swap[] private _swaps;

    function createSwap(address _tokenA, address _tokenB, address _verifiedNode, address _chainlinkToken, address _chainlinkOracle, string memory _commDexName, uint256 _tradeFee, uint256 _rateTimeOut) public {
        require(_rateTimeOut >= 120 && _rateTimeOut <= 300, "Wrong Duration!");
        require(_swaps.length < 1000 , "You reached out limitation");
        Swap swap = new Swap();
        swap.initialize(_tokenA, _tokenB, _verifiedNode, _chainlinkToken, _chainlinkOracle, _commDexName, _tradeFee, _rateTimeOut);
        _swaps.push(swap);
    }

    function getSwaps() public view returns (Swap[] memory)
    {
        return _swaps;
    }

}