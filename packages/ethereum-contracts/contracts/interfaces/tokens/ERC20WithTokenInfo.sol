// SPDX-License-Identifier: AGPLv3
pragma solidity >= 0.5.0;

import { IERC20 } from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.2.0-solc-0.7/contracts/token/ERC20/IERC20.sol";
import { TokenInfo } from "./TokenInfo.sol";


/**
 *
 * @dev Interface for ERC20 token with token info
 *
 * NOTE: Using abstract contract instead of interfaces because old solidity
 * does not support interface inheriting other interfaces
 * solhint-disable-next-line no-empty-blocks
 *
 */
// solhint-disable-next-line no-empty-blocks
abstract contract ERC20WithTokenInfo is IERC20, TokenInfo {}
