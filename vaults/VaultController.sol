// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;


import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";

import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/IPancakePair.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IMasterChef.sol";
import "../interfaces/IFlexMinterV2.sol";
import "../interfaces/IFlexChef.sol";
import "../library/PausableUpgradeable.sol";
import "../library/WhitelistUpgradeable.sol";


abstract contract VaultController is IVaultController, PausableUpgradeable, WhitelistUpgradeable {
    using SafeBEP20 for IBEP20;


    /* ========== STATE VARIABLES ========== */

    address public keeper;
    IBEP20 internal _stakingToken;
    IFlexMinterV2 internal _minter;
    IFlexChef internal _flexChef;

    /* ========== VARIABLE GAP ========== */

    uint256[49] private __gap;

    /* ========== Event ========== */

    event Recovered(address token, uint amount);


    /* ========== MODIFIERS ========== */

    modifier onlyKeeper {
        require(msg.sender == keeper || msg.sender == owner(), 'VaultController: caller is not the owner or keeper');
        _;
    }

    /* ========== INITIALIZER ========== */

    function __VaultController_init(IBEP20 token) internal initializer {
        __PausableUpgradeable_init();
        __WhitelistUpgradeable_init();

        keeper = 0x793074D9799DC3c6039F8056F1Ba884a73462051;
        _stakingToken = token;
    }

    /* ========== VIEWS FUNCTIONS ========== */

    function minter() external view override returns (address) {
        return canMint() ? address(_minter) : address(0);
    }

    function canMint() internal view returns (bool) {
        return address(_minter) != address(0) && _minter.isMinter(address(this));
    }

    function flexChef() external view override returns (address) {
        return address(_flexChef);
    }

    function stakingToken() external view override returns (address) {
        return address(_stakingToken);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setKeeper(address _keeper) external onlyKeeper {
        require(_keeper != address(0), 'VaultController: invalid keeper address');
        keeper = _keeper;
    }

    function setMinter(address newMinter) virtual public onlyOwner {
        // can zero
        if (newMinter != address(0)) {
            require(newMinter == FLEX.getOwner(), 'VaultController: not flex minter');
            _stakingToken.safeApprove(newMinter, 0);
            _stakingToken.safeApprove(newMinter, uint(- 1));
        }
        if (address(_minter) != address(0)) _stakingToken.safeApprove(address(_minter), 0);
        _minter = IFlexMinterV2(newMinter);
    }

    function setFlexChef(IFlexChef newFlexChef) virtual public onlyOwner {
        require(address(_flexChef) == address(0), 'VaultController: setFlexChef only once');
        _flexChef = newFlexChef;
    }

    /* ========== SALVAGE PURPOSE ONLY ========== */

    function recoverToken(address _token, uint amount) virtual external onlyOwner {
        require(_token != address(_stakingToken), 'VaultController: cannot recover underlying token');
        IBEP20(_token).safeTransfer(owner(), amount);

        emit Recovered(_token, amount);
    }
}
