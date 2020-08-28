// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./VTPToken.sol";
import "./BlockCrowdsale.sol";

contract VTPPresale is BlockCrowdsale,Ownable {
    using SafeMath for uint256;
    using Address for address;

    struct ReleaseOneStage{
        bool release;
        uint block;
        uint256 valueWei;
    }

    struct ReleaseRecord{
        uint size;
        mapping (uint => ReleaseOneStage) stages;
        bool done;
    }

    struct ReleaseRecordArray{
        uint size;
        mapping (uint => ReleaseRecord) content;
    }

    mapping (address => ReleaseRecordArray) private _releasePool;
    mapping (address => uint256) public addressLimit;

    uint256 private _storeValue;
    uint256 private _storeTokenValue;
    uint256 private _rateVTP;
    VTPToken private _token;
    uint private _rawCloseBlock;

    uint private _preExtend;
    uint private _rateReduce;
    IUniswapV2Router01 private _uniswap;
    uint private _step;

    bool private _unlock;
    uint private _dailyRelease;

    constructor(uint256 rate, VTPToken token,address payable project,uint openBlock,uint closeBlock,address uniswap,uint step)
    BlockCrowdsale(rate,project,token,openBlock,closeBlock) public{
        require(openBlock<closeBlock,"VTPPresale:Time Breaking");
        require(step > 0,"VTPPresale:Step can not be zero");
        require(step <= 100,"VTPPresale:Step is too big");
        _rateVTP = rate;
        _token = token;
        _rawCloseBlock = closeBlock;
        _preExtend = 24 * step;
        _rateReduce = 1000;
        _uniswap = IUniswapV2Router01(uniswap);
        _unlock = false;
        _step = step;//on mainnet it should be 100
    }

    function storeAmount() public view returns(uint256,uint256){
        return (_storeValue,_storeTokenValue);
    }

    function rate() public view override returns (uint256) {
        return _rateVTP.sub(_storeValue.div(10 ** 18).div(500).mul(_rateReduce));
    }

    function _getTokenAmount(uint256 weiAmount) internal view override returns (uint256) {
        uint256 r = rate();
        require(r > 0,"VTPPresale:can not any token now!");
        return weiAmount.mul(r);
    }

    /**
    * save get eth total
    */
    function _forwardFunds() internal override {
        _storeValue = _storeValue.add(msg.value);
        addressLimit[msg.sender] += msg.value;
    }

    function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal view override {
        super._preValidatePurchase(beneficiary, weiAmount);
        require(_storeValue < 3000 * 10 ** uint256(18),"VTPPresale:Exceed maximum");
        require(_storeValue.add(weiAmount) < 20000 * 10 ** uint256(18),"VTPPresale:Oops");
        require(weiAmount > 10000000000000000,"VTPPresale:Maybe buy little more?");
        require(_step <= 2 || addressLimit[msg.sender] < _storeValue.div(100).add(100000000000000000000),"VTPPresale:Buy limit");
    }

    function _updatePurchasingState(address, uint256 weiAmount) internal override{
        //
        uint256 amount = _storeValue.add(weiAmount).div(10 ** 18);
        uint256 times = 0;//per 100 eth increase once time
        if(amount > 500){
            times = uint256(5).add(amount.sub(500).div(500));
        }else{
            times = amount.div(100);
        }
        uint256 newBlock = times.mul(_preExtend).add(_rawCloseBlock);

        _extendBlock(uint(newBlock));
    }

    /**
    * token
    */
    function _processPurchase(address beneficiary, uint256 tokenAmount) internal override{
        ReleaseRecordArray storage records = _releasePool[beneficiary];
        records.size++;
        ReleaseRecord storage record = records.content[records.size - 1];
        record.size = 3;
        record.stages[0] = ReleaseOneStage(false,block.number + 140 * _step,tokenAmount.mul(2).div(10));
        record.stages[1] = ReleaseOneStage(false,block.number + 216 * _step,tokenAmount.mul(3).div(10));
        record.stages[2] = ReleaseOneStage(false,block.number + 288 * _step,tokenAmount.mul(5).div(10));
        record.done = false;

        _storeTokenValue = _storeTokenValue.add(tokenAmount);
    }

    event ReleaseVTP(address beneficiary, uint256 amount,uint stage,uint id);

    function canRelease() public view returns(bool){
        return _unlock;
    }

    function release() public nonReentrant{
        require(_unlock == true,"VTPPresale:Locking");
        ReleaseRecordArray storage records = _releasePool[msg.sender];
        for(uint record = 0;record < records.size;record++){
            ReleaseRecord storage stages = records.content[record];
            if(stages.done == false){
                uint releaseTimes = 0;
                for(uint i = 0;i < 3;i++){
                    ReleaseOneStage storage one = stages.stages[i];
                    if(one.block <= block.number && one.release == false){
                        one.release = true;
                        _token.mint(msg.sender,one.valueWei);

                        emit ReleaseVTP(msg.sender,one.valueWei,i,record);
                    }

                    if(one.release == true){
                        releaseTimes = releaseTimes + 1;
                    }
                }
                if(releaseTimes == 3) stages.done = true;
            }
        }
    }

    function buyRecords() public view returns(uint256[] memory returnData){
        ReleaseRecordArray storage array = _releasePool[msg.sender];
        returnData = new uint256[](array.size*9);
        for(uint i = 0;i<array.size;i++){
            ReleaseRecord storage rawOneRecord = array.content[i];
            for(uint ii = 0;ii<rawOneRecord.size;ii++){//3
                if(rawOneRecord.stages[ii].release){
                    returnData[i*9+ii*3] = 1;
                }else{
                    returnData[i*9+ii*3] = 0;
                }

                returnData[i*9+ii*3+1] = uint256(rawOneRecord.stages[ii].block);//2
                returnData[i*9+ii*3+2] = rawOneRecord.stages[ii].valueWei;
            }
        }
    }

    event UnlockRelease(uint block,address self);

    function afterClose() public onlyOwner nonReentrant{
        if(_step != 1){//todo:
            require(hasClosed(),"VTPPresale:have not close");
        }
        address payable project = Crowdsale(address (this)).wallet();

        uint toMaster = _storeTokenValue.mul(11).div(10);
        uint toSwap = _storeTokenValue.mul(4).div(10);
        //to master
        _token.mint(project,toMaster);
        uint256 last = _storeValue.div(2);
        project.transfer(last);
        last = _storeValue.sub(last);

        //to uniswap
        _token.mint(address(this),toSwap);
        _token.approve(address(_uniswap), toSwap);
        //lock in contract address
        _uniswap.addLiquidityETH{value: last}(address(_token), toSwap, toSwap, last,address(this),now);

        _unlock = true;
        _dailyRelease = block.number.add(216 * _step);
        emit UnlockRelease(block.number,address (this));
    }

    function getPair() public view returns(address){
        return pairFor(_uniswap.factory(),address (_token),_uniswap.WETH());
    }

    event DailyRelease(uint amount,uint nextBlock);

    //daily release
    function projectRelease() public onlyOwner{
        if(_step != 1) require(_dailyRelease <= block.number,"VTPPresale:not the block");
        _dailyRelease = _dailyRelease + 72 * _step;
        IUniswapV2Pair pair = IUniswapV2Pair(getPair());

        uint liq = pair.balanceOf(address (this));
        uint releaseAmount = liq.mul(5).div(100);
        require(releaseAmount > 0,"VTPPresale:have not liquidity");
        pair.approve(address (_uniswap), releaseAmount);
        _uniswap.removeLiquidityETH(address (_token),releaseAmount,0,0,address (wallet()),now);
        emit DailyRelease(releaseAmount,_dailyRelease);
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order from:UniswapV2Library
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls from:UniswapV2Library
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            ))));
    }
}


