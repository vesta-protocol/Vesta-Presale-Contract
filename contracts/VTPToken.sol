pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VTPToken is ERC20,Ownable{

    using SafeMath for uint256;
    using Address for address;

    bytes32 public DOMAIN_SEPARATOR;

    constructor()
    ERC20("vesta",'vesta')
    public {
        uint chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                //keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes("Vesta")),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }

    function mint(address account, uint256 amount) public onlyOwner{
        return _mint(account, amount);
    }
}
