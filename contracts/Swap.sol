// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./ChainlinkClientUpgradeable.sol";
import "./TransferHelper.sol";

contract Swap is Initializable, OwnableUpgradeable, ChainlinkClientUpgradeable {

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public feeA_Storage;  // storage that the fee of token A can be stored
    uint256 public feeB_Storage;  // storage that the fee of token B can be stored

    uint256 public rate;
    uint256 private fee;
    
    uint256 lastTimeStamp;
    uint256 lastPriceFeed;
    uint256 rateTimeOut;
    
    using Chainlink for Chainlink.Request;

    // address of verified off-chain node
    address verifiedNode;
    bytes32 jobId;

    address public tokenA;
    address public tokenB;

    string public commDexName;
    uint256 public tradeFee;

    event LowTokenBalance(address Token, uint256 balanceLeft);
    event RequestRate(bytes32 indexed requestRate, uint256 rate);

    modifier onlyVerifiedNode() {
        require(_msgSender() == verifiedNode, "caller should be verified node's address");
        _;
    }

    function initialize(
        address _tokenA, 
        address _tokenB, 
        address _verifiedNode,
        address _chainlinkToken,
        address _chainlinkOracle,
        string memory _commDexName,
        uint256 _tradeFee,
        uint256 _rateTimeOut
    ) public initializer {
		__Ownable_init();

        tokenA = _tokenA;
        tokenB = _tokenB;
        verifiedNode = _verifiedNode;
        commDexName = _commDexName;
        tradeFee = _tradeFee;
        rateTimeOut = _rateTimeOut;




        setChainlinkToken(_chainlinkToken);
        setChainlinkOracle(_chainlinkOracle);
        jobId = '7d80a6386ef543a3abb52817f6707e3b';
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    function swap(uint256 _amountIn, address _from, address _to) external {
        require((_from == tokenA && _to == tokenB) || (_to == tokenA && _from == tokenB), "wrong pair");
        require(tradeFee >=0 && tradeFee <= 10**8, "wrong fee amount");

        uint256 amountFee = _amountIn * tradeFee / (10**8);

        if (_from == tokenA) {
            uint256 amountA = _amountIn - amountFee;
            uint256 amountB = amountA * lastPriceFeed / (10**8);

            setPriceFeed(1);

            if(reserveB < amountB) emit LowTokenBalance(tokenB, reserveB);
            require(reserveB >= amountB, "not enough balance");

            TransferHelper.safeTransferFrom(tokenA, msg.sender, address(this), amountA);
            TransferHelper.safeTransfer(tokenB, msg.sender, amountB);

            reserveA = reserveA + amountA;
            reserveB = reserveB - amountB;
            feeA_Storage = feeA_Storage + amountFee;
        } else {
            uint256 amountB = _amountIn - amountFee;
            uint256 amountA = amountB * (10**8) / lastPriceFeed;

            setPriceFeed(0);

            if(reserveA < amountA) emit LowTokenBalance(tokenA, reserveA);
            require(reserveA >= amountA, "not enough balance");

            TransferHelper.safeTransfer(tokenA, msg.sender, amountA);
            TransferHelper.safeTransferFrom(tokenB, msg.sender, address(this), amountB);

            reserveA = reserveA - amountA;
            reserveB = reserveB + amountB;
            feeB_Storage = feeB_Storage + amountFee;
        }
    }

    function setPriceFeed(uint256 _isSale) internal {
        if(lastTimeStamp == 0) { requestVolumeData(_isSale); lastTimeStamp = block.timestamp; lastPriceFeed = rate; }
        if(block.timestamp - lastTimeStamp > rateTimeOut) { requestVolumeData(_isSale); lastTimeStamp = block.timestamp; lastPriceFeed = rate; }
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external onlyOwner {
        require(amountA * rate == amountB, "amountA should be equal with amountB");
        TransferHelper.safeTransferFrom(tokenA, msg.sender, address(this), amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, address(this), amountB);
        reserveA = reserveA + amountA;
        reserveB = reserveB + amountB;
    }

    function removeLiquidity(uint256 amountA, uint256 amountB) external onlyOwner {
        require(amountA * rate == amountB, "amountA should be equal with amountB");
        TransferHelper.safeTransfer(tokenA, _msgSender(), amountA);
        TransferHelper.safeTransfer(tokenB, _msgSender(), amountB);
        reserveA = reserveA - amountA;
        reserveB = reserveB - amountB;
    }

    function requestVolumeData(uint256 flag) public returns (bytes32 requestRate) {
        Chainlink.Request memory req = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);

        // Set the URL to perform the GET request on
        req.add('get', 'https://api.ainsliewealth.com.au/v1/spot/USD?bearer=bXJoYjo0S1QhNG8mZmpKckJGcTAydg==');
        
        // Set the path to find the desired data in the API response, where the response format is:
        // {"RAW":
        //   {"ETH":
        //    {"USD":
        //     {
        //      "VOLUME24HOUR": xxx.xxx,
        //     }
        //    }
        //   }
        //  }
        // request.add("path", "RAW.ETH.USD.VOLUME24HOUR"); // Chainlink nodes prior to 1.0.0 support this format
        if(flag == 0) // get buy request
            req.add('path', 'AssetList,0,Buy'); // Chainlink nodes 1.0.0 and later support this format
        else    //get sell request
            req.add('path', 'AssetList,0,Sell'); // Chainlink nodes 1.0.0 and later support this format

        // Multiply the result by 1000000000000000000 to remove decimals
        int256 timesAmount = 10**8;
        req.addInt('times', timesAmount);

        // Sends the request
        return sendChainlinkRequest(req, fee);
    }

    // rate between token A and token B * (10**8)

    function fulfill(bytes32 _requestRate, uint256 _rate) public recordChainlinkFulfillment(_requestRate) {
        emit RequestRate(_requestRate, _rate);
        rate = _rate;
    }   

    function setVerifiedNode(address _verifiedNode) external onlyOwner {
        verifiedNode = _verifiedNode;
    }

    function setRateTimeOut(uint256 _newDuration) external onlyOwner {
        require(_newDuration >= 120 && _newDuration <= 300, "Wrong Duration!");
        rateTimeOut = _newDuration;
    }

    function withdrawFees() external onlyOwner {
        
        TransferHelper.safeTransfer(tokenA, msg.sender, feeA_Storage);
        TransferHelper.safeTransfer(tokenB, msg.sender, feeB_Storage);
    }

    function emergencyWithdraw() external onlyOwner {
        TransferHelper.safeTransfer(tokenA, msg.sender, feeA_Storage);
        TransferHelper.safeTransfer(tokenB, msg.sender, feeB_Storage);

        TransferHelper.safeTransfer(tokenA, msg.sender, reserveA);
        TransferHelper.safeTransfer(tokenB, msg.sender, reserveB);
    }

    function modifyChainlinkTokenAddr(address _newChainlinkAddr) public {
        setChainlinkToken(_newChainlinkAddr);
    }

    function modifyChainlinkOracleAddr(address _newChainlinkOracleAddr) public {
        setChainlinkOracle(_newChainlinkOracleAddr);
    }

    function getRate() public view returns (uint256) {
        return rate;
    }
}
