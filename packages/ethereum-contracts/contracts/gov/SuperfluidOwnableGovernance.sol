// SPDX-License-Identifier: AGPLv3
pragma solidity 0.7.6;

import {
    ISuperfluid,
    ISuperfluidToken
} from "../interfaces/superfluid/ISuperfluid.sol";
import { SuperfluidGovernanceBase } from "./SuperfluidGovernanceBase.sol";

import { Ownable } from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.2.0-solc-0.7/contracts/access/Ownable.sol";


contract SuperfluidOwnableGovernance is
    Ownable,
    SuperfluidGovernanceBase
{
    function _requireAuthorised(ISuperfluid /*host*/)
        internal view override
    {
        require(owner() == _msgSender(), "SFGov: only owner is authorized");
    }
}
