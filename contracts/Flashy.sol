// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { SafeMath } from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';


//import "./../utils/Withdrawable.sol";

interface ILendingPool {
  function flashLoan(
    address receiverAddress,
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata modes,
    address onBehalfOf,
    bytes calldata params,
    uint16 referralCode
  ) external;
}

/**
 * @title LendingPoolAddressesProvider contract
 * @dev Main registry of addresses part of or connected to the protocol, including permissioned roles
 * - Acting also as factory of proxies and admin of those, so with right to change its implementations
 * - Owned by the Aave Governance
 * @author Aave
 **/
interface ILendingPoolAddressesProvider {
  event MarketIdSet(string newMarketId);
  event LendingPoolUpdated(address indexed newAddress);
  event ConfigurationAdminUpdated(address indexed newAddress);
  event EmergencyAdminUpdated(address indexed newAddress);
  event LendingPoolConfiguratorUpdated(address indexed newAddress);
  event LendingPoolCollateralManagerUpdated(address indexed newAddress);
  event PriceOracleUpdated(address indexed newAddress);
  event LendingRateOracleUpdated(address indexed newAddress);
  event ProxyCreated(bytes32 id, address indexed newAddress);
  event AddressSet(bytes32 id, address indexed newAddress, bool hasProxy);

  function getMarketId() external view returns (string memory);

  function setMarketId(string calldata marketId) external;

  function setAddress(bytes32 id, address newAddress) external;

  function setAddressAsProxy(bytes32 id, address impl) external;

  function getAddress(bytes32 id) external view returns (address);

  function getLendingPool() external view returns (address);

  function setLendingPoolImpl(address pool) external;

  function getLendingPoolConfigurator() external view returns (address);

  function setLendingPoolConfiguratorImpl(address configurator) external;

  function getLendingPoolCollateralManager() external view returns (address);

  function setLendingPoolCollateralManager(address manager) external;

  function getPoolAdmin() external view returns (address);

  function setPoolAdmin(address admin) external;

  function getEmergencyAdmin() external view returns (address);

  function setEmergencyAdmin(address admin) external;

  function getPriceOracle() external view returns (address);

  function setPriceOracle(address priceOracle) external;

  function getLendingRateOracle() external view returns (address);

  function setLendingRateOracle(address lendingRateOracle) external;
}

interface IFlashLoanReceiver {
  function executeOperation(
    address[] calldata assets,
    uint[] calldata amounts,
    uint[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external returns (bool);
}

abstract contract FlashLoanReceiverBase is IFlashLoanReceiver {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  ILendingPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
  ILendingPool public immutable LENDING_POOL;

  constructor(address provider) {
    ADDRESSES_PROVIDER = ILendingPoolAddressesProvider(provider);
    LENDING_POOL = ILendingPool(ILendingPoolAddressesProvider(provider).getLendingPool());
  }

  receive() payable external {}
}



interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}


contract Flashy is FlashLoanReceiverBase {
    using SafeMath for uint;
    address payable owner;

    uint256[] public quantities;
    address[] public tokens_addresses;
    address[] public the_routers;
    string public name;

    IUniswapV2Router02 public Router;


    constructor(address payable _owner, address _addressProvider, string memory _name) FlashLoanReceiverBase(_addressProvider) {
        owner = _owner;
        name = _name;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function get_name() public view returns ( string memory ) {
        return name;
    }
    
    function set_name( string memory _name ) onlyOwner public returns ( bool ) {
        name = _name;
        return true;
    } 

    fallback() external payable {}

    //##################        Swap

    function swap(address _router, address _tokenIn, address _tokenOut, uint256 _amountIn) public {

    require(_amountIn <= IERC20(_tokenIn).balanceOf(address(this)), "Insufficient balance, please fund this contract!");

    Router = IUniswapV2Router02(_router);

    IERC20(_tokenIn).approve(address(Router), _amountIn);

    address[] memory _path = get_path(_tokenIn, _tokenOut);

    uint _amountOutMin = get_amountsOut(_amountIn, _path, Router);

    Router.swapExactTokensForTokens(_amountIn, _amountOutMin, _path, address(this), block.timestamp + 300); 
   }

   function arb_swap(address _router_a, address _router_b, address _token_a, address _token_b, uint256 _amountIn) public {
       swap(_router_a, _token_a, _token_b, _amountIn);
       swap(_router_b, _token_b, _token_a, get_contract_token_balance(_token_b));   
   }

   //function fund_swap(address _tokenIn, uint256 _amountIn) public  {
   //    IERC20(_tokenIn).transfer(address(this), _amountIn);
   //}

    //##########        Info
    function get_path(address _tokenIn, address _tokenOut) internal pure returns (address[] memory) {
      address[] memory path;
      path = new address[](2);
      path[0] = _tokenIn;
      path[1] = _tokenOut;
      return path;
    }

    function get_amountsOut(uint256 _amountIn, address[] memory _path, IUniswapV2Router02 _router) internal view returns (uint) {
      uint256[] memory amountsOut = _router.getAmountsOut(_amountIn, _path);
      uint amountOutMin = amountsOut[amountsOut.length - 1];
      return amountOutMin;
    }

    function get_contract_token_balance(address _token) public view returns (uint) {
        return IERC20(_token).balanceOf(address(this));
    }

    //############      Transfer

    function transfer_amount(address _token, uint256 _amount) onlyOwner public returns ( bool ) {
        uint balance = get_contract_token_balance(_token);
        require(balance >= _amount, "The amount exceeds balance");
        bool check = IERC20(_token).transfer(msg.sender, _amount);

        return check;
    }

    function transfer_full_amount(address _token) onlyOwner public returns ( bool ) {
        uint balance = get_contract_token_balance(_token);
        require(balance > 0, "This constract has insufficient balance");   
        bool check = IERC20(_token).transfer(msg.sender, balance);

        return check;
    }
    
    
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    )
        external
        override
        returns (bool)
    {
        
        arb_swap(the_routers[0], the_routers[1], tokens_addresses[0], tokens_addresses[1], quantities[0]);
        
        
        // At the end of your logic above, this contract owes
        // the flashloaned amounts + premiums.
        // Therefore ensure your contract has enough to repay
        // these amounts.
        
        // Approve the LendingPool contract allowance to *pull* the owed amount
        for (uint i = 0; i < assets.length; i++) {
            uint amountOwing = amounts[i].add(premiums[i]);
            IERC20(assets[i]).approve(address(LENDING_POOL), amountOwing);
        }
        
        return true;
    }

    function _flashloan(address[] memory assets, uint256[] memory amounts) internal {
        address receiverAddress = address(this);

        uint256[] memory modes = new uint256[](assets.length);

        // 0 = no debt (flash), 1 = stable, 2 = variable
        for (uint256 i = 0; i < assets.length; i++) {
            modes[i] = 0;
        }

        address onBehalfOf = address(this);
        bytes memory params = "";
        uint16 referralCode = 0;


        LENDING_POOL.flashLoan(
            receiverAddress,
            assets,
            amounts,
            modes,
            onBehalfOf,
            params,
            referralCode
        );
    }

    
    function flashloan(address _router01, address _router02, address _asset01, address _asset02, uint256 _amount) onlyOwner public {
        //uint amount = 100 ether;

        address[] memory assets = new address[](1);
        assets[0] = _asset01;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;

        quantities = amounts;
        tokens_addresses = [_asset01, _asset02];
        the_routers = [_router01, _router02];

        _flashloan(assets, amounts);
    }

    function close(address payable _to) onlyOwner public payable {
        selfdestruct(_to);
    }
}
