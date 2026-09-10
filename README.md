# Dividend-Based Token (ERC-20 ETH Wrapper with Dividends)

A Solidity smart contract implementing a mintable ERC-20 token (similar to Wrapped ETH) that distributes ETH dividend payouts proportionally to token holders based on their balance relative to the total supply.

---

## Technical Overview

* **Token Mechanics:** Callers mint tokens 1:1 by depositing ETH via `mint()`. Burning tokens via `burn()` destroys the token balance and returns the equivalent amount of underlying ETH.
* **Proportional Dividend Payouts:** Dividend depositors send ETH using `recordDividend()`. The contract loops through all active token holders and assigns each holder their proportional ETH payout share.
* **Historical Entitlement:** Dividend payouts accrue directly to a separate balance mapping (`withdrawableDividends`). Holders retain entitlement to accrued dividends even if they subsequently transfer or burn their underlying tokens.
* **Gas-Efficient Holder Tracking:** Uses an *Enumerable Set* pattern (an array combined with a 1-based index mapping) to maintain $O(1)$ dynamic additions and dynamic removals (*swap-and-pop*).

---

## Contract Interface & Key Methods

### Token Operations
* `mint()` *(payable)*: Mints tokens equal to `msg.value` sent by the caller.
* `burn(address payable dest)`: Burns all tokens owned by the caller and transfers the corresponding ETH balance to `dest`.
* `transfer(address to, uint256 value)`: Transfers tokens and updates holder iteration state for both sender and recipient.
* `transferFrom(address from, address to, uint256 value)`: Standard ERC-20 transfer using approved allowances.

### Dividend Operations
* `recordDividend()` *(payable)*: Distributes `msg.value` across all active token holders proportional to their current token balances.
* `getWithdrawableDividend(address payee)` *(view)*: Returns the unclaimed ETH dividend balance accrued by `payee`.
* `withdrawDividend(address payable dest)`: Claims all accrued ETH dividends for `msg.sender` and sends them to `dest`.

### Enumerable Holder Enumeration
* `getNumTokenHolders()` *(view)*: Returns the count of active addresses holding a positive token balance.
* `getTokenHolder(uint256 index)` *(view)*: Returns the holder address at the given 1-based index (`1` to `numHolders`).

---

## Core Design Decisions

### 1. Dynamic Holder Tracking (Swap-and-Pop)
To avoid iterating over addresses with zero balances during dividend payouts:
* An `address[] private holders` array stores active holder addresses.
* A `mapping(address => uint256) private holderIndex` maps each address to `arrayIndex + 1` (allowing `0` to denote non-membership).
* When a user's token balance drops to `0`, the address is removed from `holders` in $O(1)$ time by swapping it with the last array element before calling `holders.pop()`.

### 2. 1-Based Indexing Alignment
The assessment testing harness accesses `getTokenHolder(index)` using 1-based indices ($1 \le index \le N$). `getTokenHolder` maps input $index$ directly to `holders[index - 1]` to maintain zero-indexed storage internal array safety.

### 3. Reentrancy Protection & Safety
* `withdrawDividend` adheres strictly to the **Checks-Effects-Interactions** pattern: clearing the user's `withdrawableDividends` balance prior to invoking external ETH transfer low-level call (`.call{value: amount}("")`).
* Utilizes `SafeMath` for all mathematical computations under Solidity `0.7.0`.

---

## Local Development & Testing

### Prerequisites
* [Node.js](https://nodejs.org/) (v14+ recommended)
* [Truffle](https://trufflesuite.com/) or [Hardhat](https://hardhat.org/) test runner

### Installation & Setup

1. Clone the repository and install dependencies:
   ```bash
   npm install
