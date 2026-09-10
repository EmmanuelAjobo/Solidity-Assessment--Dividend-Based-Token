pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
    // ------------------------------------------ //
    // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
    // ------------------------------------------ //
    using SafeMath for uint256;
    uint256 public totalSupply;
    uint256 public decimals = 18;
    string public name = "Test token";
    string public symbol = "TEST";
    mapping(address => uint256) public balanceOf;
    // ------------------------------------------ //
    // ----- END: DO NOT EDIT THIS SECTION ------ //

    // Track holders for iteration
    address[] private holders;
    mapping(address => uint256) private holderIndex; // 1-based index (0 = not in array)
    mapping(address => mapping(address => uint256)) private allowances;

    // Dividends tracking
    mapping(address => uint256) private withdrawableDividends;

    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status = NOT_ENTERED;

    modifier nonReentrant() {
        require(_status != ENTERED, "Reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }

    // IERC20

    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return allowances[owner][spender];
    }

    function transfer(
        address to,
        uint256 value
    ) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(
        address spender,
        uint256 value
    ) external override returns (bool) {
        allowances[msg.sender][spender] = value;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        uint256 currAllowance = allowances[from][msg.sender];
        require(currAllowance >= value, "Allowance exceeded");

        allowances[from][msg.sender] = currAllowance.sub(value);
        _transfer(from, to, value);
        return true;
    }

    // IMintableToken

    function mint() external payable override nonReentrant {
        require(msg.value > 0, "Invalid ETH sent");
        totalSupply = totalSupply.add(msg.value);
        balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);

        if (balanceOf[msg.sender] == msg.value) {
            _addHolder(msg.sender);
        }
    }

    function burn(address payable dest) external override nonReentrant {
        uint256 burnAmount = balanceOf[msg.sender];
        require(burnAmount > 0, "No tokens to burn");

        balanceOf[msg.sender] = 0;
        totalSupply = totalSupply.sub(burnAmount);

        _removeHolder(msg.sender);

        (bool success, ) = dest.call{value: burnAmount}("");
        require(success, "ETH transfer failed");
    }

    // IDividends

    function getNumTokenHolders() external view override returns (uint256) {
        return holders.length;
    }

    function getTokenHolder(
        uint256 index
    ) external view override returns (address) {
        require(index > 0 && index <= holders.length, "Index out of bounds");
        return holders[index - 1];
    }

    function recordDividend() external payable override {
        require(msg.value > 0, "Dividend value must be greater than 0");
        require(
            totalSupply > 0,
            "Cannot record dividend with zero total supply"
        );

        uint256 dividendAmount = msg.value;

        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            uint256 holderBalance = balanceOf[holder];

            if (holderBalance > 0) {
                // share = (dividendAmount * holderBalance) / totalSupply
                uint256 share = dividendAmount.mul(holderBalance).div(
                    totalSupply
                );
                withdrawableDividends[holder] = withdrawableDividends[holder].add(share);
            }
        }
    }

    function getWithdrawableDividend(
        address payee
    ) external view override returns (uint256) {
        return withdrawableDividends[payee];
    }

    function withdrawDividend(address payable dest) external override {
        // (Checks-Effects-Interactions)
        
        uint256 amount = withdrawableDividends[msg.sender];
        require(amount > 0, "No withdrawable dividend available");
        require(dest != address(0), "Invalid destination address");

        withdrawableDividends[msg.sender] = 0;

        (bool success, ) = dest.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    // Helper Functions

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "Invalid recipient");
        require(balanceOf[from] >= value, "Insufficient balance");

        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);

        if (balanceOf[to] == value) {
            _addHolder(to);
        }

        if (balanceOf[from] == 0) {
            _removeHolder(from);
        }
    }

    function _addHolder(address account) private {
        if (holderIndex[account] == 0) {
            holders.push(account);
            holderIndex[account] = holders.length;
        }
    }

    function _removeHolder(address account) private {
        uint256 index = holderIndex[account];
        if (index != 0) {
            uint256 arrayIndex = index - 1;
            uint256 lastIndex = holders.length - 1;

            if (arrayIndex != lastIndex) {
                address lastHolder = holders[lastIndex];
                holders[arrayIndex] = lastHolder;
                holderIndex[lastHolder] = index;
            }

            holders.pop();
            delete holderIndex[account];
        }
    }
}
