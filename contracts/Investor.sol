pragma solidity ^0.8.0;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPstake} from "./pStake.sol";

contract InvestorClaim {
    using SafeERC20 for IPstake;

    struct Claim {
        uint256 amountClaimed;
        uint256 amountLeft;
        uint256 amountTotal;
    }

    struct InvestorInit {
        address investorAddress;
        uint256 totalAmount;
    }

    uint256 denomMultiplier = 1e18;
    uint256 public minAmountAdd = 0;
    IPstake public token;
    mapping(address => Claim) public investors;
    address[] private investorsCount;
    address public admin;
    address public contractAdmin;
    //    EVENTS
    event ClaimedAmount(address investorAddress, uint256 amount);
    event ReturnedAmount(address adminAddress, uint256 amount);
    event AddedMoney(address adminAddress, uint256 amount);
    event InvestorRemoved(address investorAddress);
    event InvestorReplaced(address oldInvestorAddress, address newInvestorAddress);

    //ERRORS
    error NotAdmin();
    error NotInvestor();
    error AlreadyClaimed();
    error AmountLessThanTotalInvestorAmount(uint256 amountAdding, uint256 amountNeeded);
    error TokenLeftToClaim();

    constructor(address _admin, IPstake _token, InvestorInit[] memory _investorList){
        admin = _admin;
        token = _token;
        for (uint i = 0; i < _investorList.length; ++i) {
            investors[_investorList[i].investorAddress].amountTotal = _investorList[i].totalAmount * denomMultiplier;
            investorsCount.push(_investorList[i].investorAddress);
            minAmountAdd += uint256(_investorList[i].totalAmount * denomMultiplier / 12);
        }
    }

    function addMoney(uint256 amount) external {
        if (msg.sender != admin) {
            revert NotAdmin();
        }
        amount = amount * denomMultiplier;
        if (amount < minAmountAdd) {
            revert AmountLessThanTotalInvestorAmount(amount, minAmountAdd);
        }
        token.safeTransferFrom(msg.sender, address(this), amount);
        for (uint i = 0; i < investorsCount.length; ++i) {
            investors[investorsCount[i]].amountLeft += uint256(investors[investorsCount[i]].amountTotal / 12);
        }
        emit AddedMoney(msg.sender, amount);
    }

    function claimedTokens() external view returns (uint256){
        return investors[msg.sender].amountClaimed;
    }

    function totalClaimable() external view returns (uint256){
        return investors[msg.sender].amountTotal;
    }

    function tokensLeft() external view returns (uint256){
        return investors[msg.sender].amountLeft;
    }

    function returnAmountLeft() external {
        if (!checkIfReturnable()) {
            revert TokenLeftToClaim();
        }
        emit ReturnedAmount(admin, token.balanceOf(address(this)));
        token.safeTransfer(admin, token.balanceOf(address(this)));
    }

    function removeInvestor(address[] memory investor_addresses) external {
        if (msg.sender != admin) {
            revert NotAdmin();
        }
        uint256 amount = 0;
        for (uint i = 0; i < investor_addresses.length; ++i) {
            amount += investors[investor_addresses[i]].amountLeft;
            investors[investor_addresses[i]].amountLeft = 0;
            minAmountAdd -= investors[investor_addresses[i]].amountTotal / 12;
            investors[investor_addresses[i]].amountTotal = 0;
            emit InvestorRemoved(investor_addresses[i]);
        }
        token.safeTransfer(admin, amount);

    }

    function replaceInvestor(address oldAddress, address newAddress) external {
        if (msg.sender != admin) {
            revert NotAdmin();
        }
        investors[newAddress].amountTotal = investors[oldAddress].amountTotal;
        investors[newAddress].amountLeft = investors[oldAddress].amountLeft;
        investors[newAddress].amountClaimed = investors[oldAddress].amountClaimed;
        investorsCount.push(newAddress);
        investors[oldAddress].amountClaimed = 0;
        investors[oldAddress].amountLeft = 0;
        investors[oldAddress].amountTotal = 0;
        emit InvestorReplaced(oldAddress, newAddress);
    }

    function checkIfReturnable() public view returns (bool){
        for (uint i = 0; i < investorsCount.length; ++i) {
            if (investors[investorsCount[i]].amountLeft != 0) {
                return false;
            }
        }
        return true;
    }

    function checkInvestor(address investorAddress) public view returns (bool){
        if (investors[investorAddress].amountTotal > 0) {
            return true;
        }
        return false;
    }

    function claim() external {
        if (!checkInvestor(msg.sender)) {
            revert NotInvestor();
        }
        if (investors[msg.sender].amountLeft <= denomMultiplier) {
            revert AlreadyClaimed();
        }
        token.safeTransfer(msg.sender, investors[msg.sender].amountLeft);
        emit ClaimedAmount(msg.sender, investors[msg.sender].amountLeft);
        investors[msg.sender].amountClaimed += investors[msg.sender].amountLeft;
        investors[msg.sender].amountLeft = 0;
    }
}
