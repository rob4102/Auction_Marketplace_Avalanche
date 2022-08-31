pragma solidity ^0.6.9;

import "../contracts/Utils/SafeMathPlus.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IDutchAuction.sol";
                                                            
                                                              
// ---------------------------------------------------------------------
// SPDX-License-Identifier: GPL-3.0
// ---------------------------------------------------------------------



contract DutchSwapIDO {

    using SafeMath for uint256;
    uint256 private constant TENPOW18 = 10 ** 18;
    /// @dev The placeholder ETH address.
    address private constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // ERC20 basic token contract being held
    IDutchAuction public auction;
    address public auctionToken; 
    address public paymentCurrency; 

    // timestamp when token refund is enabled
    bool private initialised;
    uint256 public refundTime;
    uint256 public refundPct;  // 90 = 90% refunded to user
    uint256 public refundDuration;
    mapping(address => uint256) private refunded;


    /**
     * @notice Initialise contract parameters
     */
    function initAuctionIDO( address _auction) public {
        // solhint-disable-next-line not-rely-on-time
        require(!initialised);
        require(_refundPct < 100 && _refundPct > 0);

        auction = IDutchAuction(_auction);
        require(refundTime > auction.endDate(), "Timelock: refund time is before endDate");
        require(auction.wallet() == address(this));

        // might need a refund duration, say 1 week
        auctionToken = auction.auctionToken();
        paymentCurrency = auction.paymentCurrency();

        initialised = true;
    }

    // Things it needs to do
    // [] Create Uniswap pool
    // [] Wrap half funds as WETH
    // [] Mint LP tokens

    /**
     * @return the amount of tokens claimable.
     */


    /**
     * @notice Reject direct ETH payments.
     */
    receive () external payable {
        revert();
    }

    //--------------------------------------------------------
    // Helper Functions
    //--------------------------------------------------------

    // There are many non-compliant ERC20 tokens... this can handle most, adapted from UniSwap V2
    // I'm trying to make it a habit to put external calls last (reentrancy)
    // You can put this in an internal function if you like.
    function _safeTransfer(address token, address to, uint256 amount) internal {
        // solium-disable-next-line security/no-low-level-calls
        (bool success, bytes memory data) = token.call(
            // 0xa9059cbb = bytes4(keccak256("transferFrom(address,address,uint256)"))
            abi.encodeWithSelector(0xa9059cbb, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool)))); // ERC20 Transfer failed 
    }

    function _safeTransferFrom(address token, address from, uint256 amount) internal {
        // solium-disable-next-line security/no-low-level-calls
        (bool success, bytes memory data) = token.call(
            // 0x23b872dd = bytes4(keccak256("transferFrom(address,address,uint256)"))
            abi.encodeWithSelector(0x23b872dd, from, address(this), amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool)))); // ERC20 TransferFrom failed 
    }

    /// @dev Helper function to handle both ETH and ERC20 payments
    function _tokenPayment(address _token, address payable _to, uint256 _amount) internal {
        if (address(_token) == ETH_ADDRESS) {
            _to.transfer(_amount);
        } else {
            _safeTransfer(_token, _to, _amount);
        }
    }


}