// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;


contract Loyalty3 {

    //owner data
    uint256 public ownerCount;
    mapping(address => uint256) public ownerToOwnerId;
    address public newOwnerPending;
    uint256 public blockedOwnerCount;
    mapping(address => uint256) public blockedOwnerToOwnerId;

    // points data
    uint256 public maxSupply; // Maximum number of points that can be minted.
    uint256 public totalSupply; // Total points in circulation at the time of enquiry.

   //user data
   mapping(bytes32 => uint256) userIdToPoints;
   mapping(bytes32 => string) public userIdToString;
   mapping(string => bytes32) public userStringToId;

   //coupon data
   uint256 public couponCount = 0;
   mapping(uint256 => bytes32) public couponIdToUserId;
   mapping(uint256 => uint256) public couponIdToPoints;
   mapping(uint256 => uint256) public couponIdToExpiry;
   mapping(uint256 => string) public couponIdToRefVia;

   //redeem data
   uint256 public redeemCount = 0;
   mapping(uint256 => string) public redeemIdToRefId;

   //events
   event pointsAllocated(bytes32 indexed _userId, uint256 indexed _points, uint256 indexed _couponId);
   event pointsExpired(bytes32 indexed _userId, uint256 indexed _points, uint256 indexed _couponId);
   event pointsRedeemed(bytes32 indexed _userId, uint256 indexed _points, uint256 indexed _couponId);
   event pointsRedeemedDetails(bytes32 indexed _userId, uint256 indexed _points, uint256 indexed _redeemId);
   event userPoints (bytes32 indexed _userId, uint256 indexed _points);
   event ownerSet (address indexed _newOwner);
   event ownerPrompt (address indexed _newOwner);
   event ownerBlocked (address indexed _blockedOwner);
   event couponModified (bytes32 indexed _userId, uint256 indexed _points, uint256 indexed _couponId);

   //owner functions

   // Set the max supply of the points during contract creation.
    constructor (uint256 _maxSupply) {
        maxSupply = _maxSupply;
        blockedOwnerCount = 0;
        ownerCount = 1;
        ownerToOwnerId[msg.sender] = ownerCount;
    }
    
    //Modifier to check if caller is the owner of this contract. Used on most state change functions.
    modifier onlyOwner () {
        require (ownerToOwnerId[msg.sender] > 0, "Only owner can call this function.");
        require (blockedOwnerToOwnerId[msg.sender] == 0, "You have been blocked.");
        _;
    }

    // This function adds a user to the list owners of the contract. Only an existing owner can add a new owner. The new owner has to confirm by calling the confirmOwner function.
    function setOwner(address _newOwner) external onlyOwner {
        require(ownerToOwnerId[_newOwner] == 0, "Owner already added.");
        newOwnerPending = _newOwner;
        emit ownerPrompt(_newOwner);
    }

    // This function is used by the new owner added to the owners list. The new owner calls this function to confirm the ownership.
    function confirmOwner() external {      
        require(msg.sender == newOwnerPending, "You are not the new owner");
        ownerCount = ownerCount + 1;
        ownerToOwnerId[newOwnerPending] = ownerCount;        
        emit ownerSet(newOwnerPending);
    }

    // This function blocks a certain user/address to access the contract. The user to be blocked is added to the blocked user's list.
    function blockOwner(address _owner) external onlyOwner {
        require(msg.sender != _owner, "You cannot block yourself");
        blockedOwnerCount = blockedOwnerCount + 1;
        blockedOwnerToOwnerId[_owner] = blockedOwnerCount;
        emit ownerBlocked(_owner);
    }

    // earn points
    //The function creates a new coupon and assigns the input data to the coupon.
    function allocatePoints(string memory _userIdString, uint256 _points, uint256 _expiryDate, string memory _refVia) external onlyOwner {
       require (totalSupply + _points <= maxSupply, "Maximum points limit exceeded.");
       require(_expiryDate > block.timestamp, "Expiry date should not be in the past.");
       bytes32 _userId = keccak256(abi.encodePacked(_userIdString));
       updateUserPoints(_userId);
       userIdToPoints[_userId] = userIdToPoints[_userId] + _points;
       couponCount = couponCount + 1;
       couponIdToUserId[couponCount] = _userId;
       userIdToString[_userId] = _userIdString;
       userStringToId[_userIdString] = _userId;
       couponIdToPoints[couponCount] = _points;
       couponIdToExpiry[couponCount] = _expiryDate;
       couponIdToRefVia[couponCount] = _refVia;
       totalSupply = totalSupply + _points;
       emit pointsAllocated(_userId, _points, couponCount);
    } 


    // Internal functions   
    // Goes through all coupon Ids. Checks for the expired coupons and burns the points of the expired coupons. Filters the coupons with the user ID. Adds up all the points of a user's coupons and updates the 'userIdToPoints' mapping.
    function updateUserPoints(bytes32 _userId) private {
       uint256 points = 0;
       for (uint256 couponId = 1; couponId <= couponCount; couponId++) {
           if (couponIdToPoints[couponId] > 0) {
               if (couponIdToExpiry[couponId] <= block.timestamp) {
                   totalSupply = totalSupply - couponIdToPoints[couponId];
                   bytes32 thisUserId = couponIdToUserId[couponId];
                   emit pointsExpired(thisUserId, couponIdToPoints[couponId], couponId);
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
    function getUserPoints (string memory _userIdString) public onlyOwner returns(uint256) {
        bytes32 _userId = keccak256(abi.encodePacked(_userIdString));
        updateUserPoints(_userId);
        emit userPoints(_userId, userIdToPoints[_userId]);   
        return userIdToPoints[_userId];
    }

    //redeemUserPoints
    // The function will check the current points the user has. Goes through all the coupons ids in increasing order. Filters the coupons with user Id and availability of points. Subtracts points from coupon Ids untill the desired number of points have been extracted.
    function redeemUserPoints (string memory _userIdString, uint256 _points, string memory _refId) external onlyOwner {
        bytes32 _userId = keccak256(abi.encodePacked(_userIdString));
        uint256 availablePoints = getUserPoints(_userIdString);
        if (availablePoints >= _points) {
            redeemCount = redeemCount + 1;
            redeemIdToRefId[redeemCount] = _refId;
            emit pointsRedeemedDetails(_userId, _points, redeemCount);
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
        
    }

    // Modify the number of points in a coupon. Checks the coupon for expiry first. Then replaces the coupon points with new points.
    function modifyCouponPoints (uint256 _couponId, uint256 _points ) external onlyOwner {
        require (couponIdToExpiry[_couponId] > block.timestamp, "Coupon has already expired.");
        require (totalSupply + _points - couponIdToPoints[_couponId] <= maxSupply, "Points limit has exceeded max limit.");
        totalSupply = totalSupply + _points - couponIdToPoints[_couponId];
        couponIdToPoints[_couponId] = _points;
        emit couponModified(couponIdToUserId[_couponId], couponIdToPoints[_couponId], _couponId);        
    }
}