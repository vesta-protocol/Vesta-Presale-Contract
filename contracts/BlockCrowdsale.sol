pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Crowdsale.sol";

contract BlockCrowdsale is Crowdsale {
    using SafeMath for uint256;

    uint private _openingBlock;
    uint private _closingBlock;

    event BlockCrowdsaleExtended(uint prevClosingBlock, uint newClosingBlock);

    /**
     * @dev Reverts if not in crowdsale block range.
     */
    modifier onlyWhileOpen {
        require(isOpen(), "BlockCrowdsale: not open");
        _;
    }

    constructor (uint256 rate, address payable wallet, IERC20 token,uint openingBlock, uint closingBlock) Crowdsale(rate,wallet,token) public {
        require(openingBlock >= block.number, "BlockCrowdsale: opening time is before current time");
        require(openingBlock < closingBlock, "BlockCrowdsale: opening time is not before closing time");

        _openingBlock = openingBlock;
        _closingBlock = closingBlock;
    }

    function openingBlock() public view returns (uint256) {
        return _openingBlock;
    }

    function closingBlock() public view returns (uint256) {
        return _closingBlock;
    }

    function isOpen() public view returns (bool) {
        return block.number >= _openingBlock && block.number <= _closingBlock;
    }

    function hasClosed() public view returns (bool) {
        return block.number > _closingBlock;
    }

    function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal onlyWhileOpen view virtual override{
        super._preValidatePurchase(beneficiary, weiAmount);
    }

    function _extendBlock(uint newClosingBlock) internal {
        require(!hasClosed(), "BlockCrowdsale: already closed");
        // solhint-disable-next-line max-line-length
        require(newClosingBlock >= _closingBlock, "BlockCrowdsale: new closing block is before current closing block");
        if(newClosingBlock == _closingBlock) return;

        emit BlockCrowdsaleExtended(_closingBlock, newClosingBlock);
        _closingBlock = newClosingBlock;
    }
}

