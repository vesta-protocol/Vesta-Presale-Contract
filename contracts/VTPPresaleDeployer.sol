pragma solidity ^0.6.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import './VTPToken.sol';
import './VTPPresale.sol';
import "@openzeppelin/contracts/access/Ownable.sol";

contract VTPPresaleDeployer{
    event DeployLog(address token, address presale,uint start);

    constructor(uint range,address payable master,address uniswapRouter,uint step) public
    {
        uint offset = 100;
        VTPToken token = new VTPToken();
        VTPPresale presale = new VTPPresale(50000,token,master,block.number + offset,block.number + offset + range,uniswapRouter,step);
        Ownable(token).transferOwnership(address(presale));
        Ownable(presale).transferOwnership(address(msg.sender));

        emit DeployLog(address (token),address (presale),block.number + offset);
    }
}
