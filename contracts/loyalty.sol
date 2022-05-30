// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


contract Loyaltyoriginal {

    //owner data
    address public owner;

    // points data
    uint256 public maxSupply; // Maximum number of points that can be minted.
    uint256 public totalSupply; // Total points in circulation at the time of enquiry.

   //user data
   uint256 public userCount; 
   mapping(uint256 => uint256) userIdToPoints;

   //coupon data
   uint256 public couponCount = 0;
   mapping(uint256 => uint256) public couponIdToUserId;
   mapping(uint256 => uint256) public couponIdToPoints;
   mapping(uint256 => uint256) public couponIdToExpiry;
   mapping(uint256 => string) public couponIdToRefVia;

   //events
   event pointsAllocated(uint256 indexed _userId, uint256 indexed _points, uint256 indexed _couponId);
   event pointsExpired(uint256 indexed _userId, uint256 indexed _points, uint256 indexed _couponId);
   event pointsRedeemed(uint256 indexed _userId, uint256 indexed _points, uint256 indexed _couponId);
   event userPoints (uint256 indexed _userId, uint256 indexed _points);
   event ownerSet (address indexed _newOwner);
   event couponModified (uint256 indexed _userId, uint256 indexed _points, uint256 indexed _couponId);

   //owner functions

   // Set the max supply of the points during contract creation.
    constructor (uint256 _maxSupply) {
        maxSupply = _maxSupply;
        owner = msg.sender;
    }
    
    //Modifier to check if caller is the owner of this contract. Used on most state change functions.
    modifier onlyOwner () {
        require (msg.sender == owner, "Only owner can call this function.");
        _;
    }

    // This function can transfer the ownership of the contract. Only existing owner can transfer it to the new owner.
    function setOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
        emit ownerSet(owner);
    }

    // earn points
    //The function creates a new coupon and assigns the input data to the coupon.
    function allocatePoints(uint256 _userId, uint256 _points, uint256 _expiryDate, string memory _refVia) public onlyOwner {
       require (totalSupply + _points <= maxSupply, "Maximum points limit exceeded.");
       require(_expiryDate > block.timestamp, "Expiry date should not be in the past.");
       updateUserPoints(_userId);
       userIdToPoints[_userId] = userIdToPoints[_userId] + _points;
       couponCount = couponCount + 1;
       couponIdToUserId[couponCount] = _userId;
       couponIdToPoints[couponCount] = _points;
       couponIdToExpiry[couponCount] = _expiryDate;
       couponIdToRefVia[couponCount] = _refVia;
       totalSupply = totalSupply + _points;
       emit pointsAllocated(_userId, _points, couponCount);
    } 


    // Internal functions

   
    // Goes through all coupon Ids. Checks for the expired coupons and burns the points of the expired coupons. Filters the coupons with the user ID. Adds up all the points of a user's coupons and updates the 'userIdToPoints' mapping.
    function updateUserPoints(uint256 _userId) private {
       uint256 points = 0;
       for (uint256 couponId = 1; couponId <= couponCount; couponId++) {
           if (couponIdToPoints[couponId] > 0) {
               if (couponIdToExpiry[couponId] <= block.timestamp) {
                   totalSupply = totalSupply - couponIdToPoints[couponId];
                   emit pointsExpired(_userId, couponIdToPoints[couponId], couponId);
                   couponIdToPoints[couponId] = 0;
               } else {
                   if (couponIdToUserId[couponId] == _userId) {
                   points = points + couponIdToPoints[couponId];
                    }
               }               
           }
        }
        userIdToPoints[_userId] = points;
    }

    //gets points available to a user. calls the 'updateUserPoints' function first to check for expired coupons. returns the 'userIdToPoints' mapping.
    function getUserPoints (uint256 _userId) public onlyOwner returns(uint256) {
        updateUserPoints(_userId);
        emit userPoints(_userId, userIdToPoints[_userId]);   
        return userIdToPoints[_userId];
    }

    //redeemUserPoints
    // The function will check the current points the user has. Goes through all the coupons ids in increasing order. Filters the coupons with user Id and availability of points. Subtracts points from coupon Ids untill the desired number of points have been extracted.
    function redeemUserPoints (uint256 _userId, uint256 _points) public onlyOwner {
        require(getUserPoints(_userId) >= _points, "User does not have enough points to redeem.");
        uint256 redeemedpoints = 0;
        uint256 couponId = 1;
        while (redeemedpoints < _points && couponId <= couponCount) {
            if (couponIdToPoints[couponId] > 0 && couponIdToUserId[couponId] == _userId) {
                uint256 pointsToBeRedeemed = _points - redeemedpoints;
                if (couponIdToPoints[couponId] >= pointsToBeRedeemed ) {
                    totalSupply = totalSupply - pointsToBeRedeemed;
                    emit pointsRedeemed(_userId, pointsToBeRedeemed, couponId);
                    couponIdToPoints[couponId] = couponIdToPoints[couponId] - pointsToBeRedeemed;
                    redeemedpoints = _points;
                } else {                    
                    totalSupply = totalSupply - couponIdToPoints[couponId];
                    emit pointsRedeemed(_userId, couponIdToPoints[couponId], couponId);
                    redeemedpoints = redeemedpoints + couponIdToPoints[couponId];
                    couponIdToPoints[couponId] = 0;                    
                }
            }
            couponId = couponId + 1;
        }        
    }

    // Modify the number of points in a coupon. Checks the coupon for expiry first. Then replaces the coupon points with new points.
    function modifyCouponPoints (uint256 _couponId, uint256 _points ) public onlyOwner {
        require (couponIdToExpiry[_couponId] > block.timestamp, "Coupon has already expired.");
        require (totalSupply + _points - couponIdToPoints[_couponId] <= maxSupply, "Points limit has exceeded max limit.");
        totalSupply = totalSupply + _points - couponIdToPoints[_couponId];
        couponIdToPoints[_couponId] = _points;
        emit couponModified(couponIdToUserId[_couponId],couponIdToPoints[_couponId], _couponId);        
    }
}