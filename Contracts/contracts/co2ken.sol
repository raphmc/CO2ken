pragma solidity ^0.6.0;

/**
 * Allows for the minting and retiring of CO2kens (a carbon
 * certificate token) as a means for offsetting carbon emissions
 */

// @dev used for importing in truffle
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

// Interface to the CO2kenData contract
abstract contract CO2kenDataLike {
    uint256 public co2kenPrice;
}

// Interface to the Dai contract
abstract contract DaiLike {
    function transferFrom(address src, address dst, uint wad) public virtual returns (bool);

    function balanceOf(address tokenOwner) public view virtual returns (uint balance);

    function transfer(address dst, uint wad) external virtual returns (bool);

    function approve(address usr, uint wad) external virtual returns (bool);
}


/**
 * CO2ken - a contract implementing the "token" logic (it's not exactly a token as it cannot be transferred).
 * The contracts just tracks the overall balance of available CO2 tokens (CO2kens). Users do not need to be
 * tracked by the contract as the amount of CO2kens they bought can be computed offchain by summing the values
 * in the CarbonOffsetted event.
 */
contract CO2ken is Ownable {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    CO2kenDataLike storageData;
    DaiLike daiToken;

    using SafeMath for uint256;

    uint256 public balance;

    event CarbonOffsetted(address indexed from, uint256 value, uint256 daiAmount);
    event Minted(string ipfsHash, uint256 dollarValue, uint256 tokensMinted);
    event Withdrawal(uint256 value);

    // --- Math ---
    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = SafeMath.mul(x, y) / 10e18;
    }

    constructor(address storageTarget, address daiTarget, string memory name, string memory symbol, uint8 decimals) public {
        // set our token detail
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
        // interface with dai token
        daiToken = DaiLike(daiTarget);
        // interface with our "oracle"
        storageData = CO2kenDataLike(storageTarget);
    }

    // @dev amountTokens = number of tokens (certificates bought) in 10e18

    /**
     * @param ipfsHash the ipfsHash storing the carbon certifcate
     * @param amountTokens a fixed point integer with 18 decimals
     */
    function mint(string memory ipfsHash, uint256 amountTokens) public onlyOwner() {
        balance = balance.add(amountTokens);
        emit Minted(ipfsHash, amountTokens, storageData.co2kenPrice());
    }

    function approve() public {
        daiToken.approve(address(this), uint(- 1));
    }

    function withdraw() public onlyOwner() {
        daiToken.transfer(owner(), daiToken.balanceOf(address(this)));
        emit Withdrawal(daiToken.balanceOf(address(this)));
    }

    /**
     * @dev allow users to offset using dollar-denominated payment
     * @param daiAmount - payment in DAI tokens
     */
    function offsetCarbon(uint256 daiAmount) public {
        // receive the DAI payment
        daiToken.transferFrom(_msgSender(), address(this), daiAmount);
        uint256 tokensToBurn = daiAmount / storageData.co2kenPrice();
        // burn CO2
        balance = balance.sub(tokensToBurn);
        emit CarbonOffsetted(_msgSender(), tokensToBurn, daiAmount);
    }

    /**
     * @dev allow users to offset using tons CO2 emitted
     * @param tons a fixed point integer with 27 decimals
     */
    function offsetCarbonTons(uint256 tons) public {
        // calculate retire amount using current token price
        uint256 daiAmount = rmul(tons, storageData.co2kenPrice());
        offsetCarbon(daiAmount);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }
}
