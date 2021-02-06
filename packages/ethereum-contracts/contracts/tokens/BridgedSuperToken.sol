// SPDX-License-Identifier: AGPLv3
pragma solidity 0.7.6;

/*
* PoC implementation of a SuperToken suited to be used with the POA Tokenbridge (https://docs.tokenbridge.net/)
*
* It uses the Custom Super Token pattern, meaning that the additional functionality is implemented in the
* storage/proxy contract itself while the existing functionality is delegated through the ERC-1822 based
* proxy mechanism to the SuperToken logic contract.
* The implementation is based on the implementation of the ETH Custom Super Token.
* Note that this makes the additional functionality non-upgradeable.
*
* The additional functionality is:
* - mint() and burn() as specified by the Tokenbridge
* - transferAndCall() as specified by [ERC-677](https://github.com/ethereum/EIPs/issues/677)
* - a custom implementation of ERC-20 transfer() and transferFrom() which calls the ERC677 hook if sending to the owner
*
* The contract implements the Ownable interface. That allows the Tokenbridge (the AMB mediator contract)
* to take ownership, giving it exclusive permission to mint new tokens.
* Note that the bridge mediator contract must be deployed by the same account as the token for that ownership transfer
* to succeed.
*
* All variations of transfer delegate actual execution to the SuperToken implementation.
* delegateCall is used in order to preserve the actual sender.
*
* Deploy with: npx truffle exec scripts/deploy-bridged-super-token.js --network=<network>
*/

import {
    CustomSuperTokenProxyBase,
    ISuperToken
} from "../interfaces/superfluid/CustomSuperTokenProxyBase.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { UUPSProxy } from "../upgradability/UUPSProxy.sol";

interface IBurnableMintableERC677 {
    // see https://github.com/ethereum/EIPs/issues/677
    // TODO: is location calldata good here?
    function transferAndCall(address recipient, uint amount, bytes calldata data) external returns (bool success);

    // same interface as used by the POA tokenbridge
    function mint(address recipient, uint256 amount) external returns (bool);
    function burn(uint256 amount) external;

    /**
    * @dev Allows to transfer any locked token on the ERC677 token contract.
    * This is not part of ERC677, but expected by the bridge mediator contracts.
    * @param _token address of the token, if it is not provided, native tokens will be transferred.
    * @param _to address that will receive the locked tokens on this contract.
    */
    //function claimTokens(address _token, address _to) external; // TODO: implement
}

// the order of inheritance is important! (storage slot ordering)
// solhint-disable-next-line no-empty-blocks
abstract contract BridgedSuperTokenProxyBase is CustomSuperTokenProxyBase, IBurnableMintableERC677, Ownable {}

/**
 * @dev Super Token extended with the functionality needed by the POA tokenbridge
 * TODO: check if we also need the functionality of PermittableToken
 */
contract BridgedSuperTokenProxy is BridgedSuperTokenProxyBase, UUPSProxy {
    // called by the tokenbridge mediator on initialization.
    // we ignore this (empty implementation) because it's not needed - it duplicates the Ownable interface.
    // the bridge mediator anyway calls transferOwnership() too which sets the needed permissions.
    // solhint-disable-next-line no-empty-blocks
    function setBridgeContract(address bridgeContract) public onlyOwner view { }

    function mint(address recipient, uint256 amount) public onlyOwner override returns(bool) {
        ISuperToken(address(this)).selfMint(recipient, amount, new bytes(0));
        return true;
    }

    function burn(uint256 amount) public override {
        ISuperToken(address(this)).selfBurn(msg.sender, amount, new bytes(0));
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        return transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        // uses delegateCall in order to preserve the actual sender (important for approval matching)
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = _implementation().delegatecall(abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                sender,
                recipient,
                amount
            ));
        require(success, "transferFrom failed");

        if (recipient == owner()) {
            // for transfers to the bridge, we use the ERC677 hook to notify the bridge contract
            require(_callERC677Hook(sender, recipient, amount, new bytes(0)), "ERC677 callback failed");
        }

        return true;
    }

    // ERC677 method which extends the ERC20 transfer with a callback in case the receiver is a contract.
    // The bridge mediator contract implements this callback (method onTokenTransfer()) and uses it
    // to trigger the bridge transfer.
    function transferAndCall(address recipient, uint amount, bytes calldata data) public override returns (bool) {
        // uses delegateCall in order to preserve the actual sender (important for approval matching)
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = _implementation().delegatecall(abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                msg.sender,
                recipient,
                amount
            ));
        require(success, "transferFrom failed");

        if (Address.isContract(recipient)) {
            require(_callERC677Hook(msg.sender, recipient, amount, data), "ERC677 callback failed");
        }

        return true;
    }

    bytes4 private constant _ON_TOKEN_TRANSFER_SELECTOR = 0xa4c0ed36; // onTokenTransfer(address,uint256,bytes))
    
    /// calls onTokenTransfer fallback on the token recipient contract
    function _callERC677Hook(address sender, address to, uint256 amount, bytes memory data) private returns (bool) {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = to.call(abi.encodeWithSelector(_ON_TOKEN_TRANSFER_SELECTOR, sender, amount, data));
        return success;
    }
}

/**
* @dev interface which contains all interfaces available for the Bridged Super Token
*/
// solhint-disable-next-line no-empty-blocks
abstract contract BridgedSuperToken is BridgedSuperTokenProxyBase, ISuperToken { }
