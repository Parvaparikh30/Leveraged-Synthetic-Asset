// SPDX-License-Identifier:MIT
pragma solidity ^0.8.12;

import "./IERC20.sol";
import "./PriceFeed.sol";
import "./utils/ReentrancyGuard.sol";

contract Vault is ReentrancyGuard {
    // Token Addresses
    address public collateralToken;
    address public syntheticToken;
    address public priceFeed;
    // To track How much synthetic tokens are locked in the vault
    uint256 public syntheticAmountLocked;
    uint8 public constant DECIMALS = 18;
    // To track the position index of each user
    mapping(address => uint256) internal positionIndex;
    // To track the total collateral deposited of each user
    mapping(address => uint256) public collateralAmount;
    // To track the collateral locked in the positions
    mapping(address => uint256) public collateralLocked;
    // To track the positions of each user
    mapping(address => mapping(uint256 => Position)) internal positions;

    // Position Struct
    struct Position {
        address account;
        uint256 index;
        uint256 collateralAmount;
        uint256 syntheticAmount;
        uint256 syntheticEntryPrice;
        uint256 leverageMultiplier;
        bool isLong;
    }
    // Initalizing the events that will be emitted
    event PositionOpened(
        address indexed account,
        uint256 indexed index,
        uint256 collateralAmount,
        uint256 syntheticAmount,
        uint256 syntheticEntryPrice,
        uint256 leverageMultiplier,
        bool isLong
    );
    event PositionClosed(
        address indexed account,
        uint256 indexed index,
        uint256 collateralAmount,
        uint256 syntheticAmount,
        uint256 syntheticEntryPrice,
        uint256 leverageMultiplier,
        bool isLong
    );
    event PositionUpdated(
        address indexed account,
        uint256 indexed index,
        uint256 collateralAmount,
        uint256 syntheticAmount,
        uint256 syntheticEntryPrice,
        uint256 leverageMultiplier,
        bool isLong
    );
    event CollateralDeposited(
        address indexed account,
        uint256 collateralAmount
    );
    event CollateralWithdrawn(
        address indexed account,
        uint256 collateralAmount
    );
    // constructor to initialize the contract with the token addresses
    constructor(
        address _collateralToken,
        address _syntheticToken,
        address _priceFeed
    ) {
        collateralToken = _collateralToken;
        syntheticToken = _syntheticToken;
        priceFeed = _priceFeed;
    }
    function depositCollateral(
        uint256 _collateralAmount
    ) external nonReentrant returns (bool) {
        require(_collateralAmount > 0, "Amount Must be greater than zero");
        require(
            IERC20(collateralToken).balanceOf(msg.sender) >= _collateralAmount,
            "Insufficient Collateral"
        );
        require(
            IERC20(collateralToken).allowance(msg.sender, address(this)) >=
                _collateralAmount,
            "Insufficient Allowance"
        );
        //  Collateral Token transfer from user to the vault after the user has approved the vault to spend the collateral
        IERC20(collateralToken).transferFrom(
            msg.sender,
            address(this),
            _collateralAmount
        );
        collateralAmount[msg.sender] =
            collateralAmount[msg.sender] +
            _collateralAmount;
        emit CollateralDeposited(msg.sender, _collateralAmount);
        return true;
    }

    function withdrawCollateral(
        uint256 _collateralAmount
    ) external nonReentrant returns (bool) {
        require(_collateralAmount > 0, "Amount Must be greater than zero");
        require(
            _collateralAmount <= remainingCollateral(msg.sender),
            "Insufficient Collateral Balance"
        );
        collateralAmount[msg.sender] =
            collateralAmount[msg.sender] -
            _collateralAmount;
        //  Desired Collateral Token transfer from vault to user
        IERC20(collateralToken).transfer(msg.sender, _collateralAmount);
        emit CollateralWithdrawn(msg.sender, _collateralAmount);
        return true;
    }

    function openPosition(
        uint256 _collateralAmount,
        bool _isLong,
        uint256 _leverage
    ) external returns (bool) {
        require(_collateralAmount > 0, "Amount Must be greater than zero");
        require(_leverage > 0, "Leverage Must be greater than zero");
        require(_leverage <= 10, "Leverage Must be less than 10");

        require(
            _collateralAmount <= remainingCollateral(msg.sender),
            "Insufficient Collateral Balance"
        );
        uint256 tokenPrice = PriceFeed(priceFeed).latestAnswer();
        require(tokenPrice != 0, "Synthetic Price is Zero");
        // Size of Position in terms of Synthetic Tokene and get locked from pool
        uint256 syntheticAmount = ((_collateralAmount * (10 ** DECIMALS)) /
            tokenPrice) * _leverage;
        require(syntheticAmount < poolAmount(), "Insufficient Liquidity");

        collateralLocked[msg.sender] =
            collateralLocked[msg.sender] +
            _collateralAmount;
        syntheticAmountLocked = syntheticAmountLocked + syntheticAmount;

        uint256 index = positionIndex[msg.sender];
        positionIndex[msg.sender] = index + 1;
        Position memory newPosition = Position(
            msg.sender,
            index + 1,
            _collateralAmount,
            syntheticAmount,
            tokenPrice,
            _leverage,
            _isLong
        );
        positions[msg.sender][index + 1] = newPosition;
        emit PositionOpened(
            msg.sender,
            index + 1,
            _collateralAmount,
            syntheticAmount,
            tokenPrice,
            _leverage,
            _isLong
        );
        return true;
    }

    function cancelPosition(uint256 _index) external returns (bool) {
        require(_index <= positionIndex[msg.sender], "Invalid Index");
        Position memory position = positions[msg.sender][_index];

        uint256 syntheticPrice = PriceFeed(priceFeed).latestAnswer();
        require(syntheticPrice != 0, "Synthetic Price is Zero");
        uint256 netPnL;
        uint256 positionCollateralAmount = collateralAmount[msg.sender];
        // To Calculate the Profit or Loss
        // long position
        if (position.isLong) {
            // if price of token increased after opening the position
            if (syntheticPrice >= position.syntheticEntryPrice) {
                netPnL =
                    ((syntheticPrice - position.syntheticEntryPrice) *
                        position.syntheticAmount) /
                    (10 ** DECIMALS);
                positionCollateralAmount = positionCollateralAmount + netPnL;
                // if price of token decreased after opening the position
            } else {
                netPnL =
                    ((position.syntheticEntryPrice - syntheticPrice) *
                        position.syntheticAmount) /
                    (10 ** DECIMALS);
                positionCollateralAmount = positionCollateralAmount - netPnL;
            }
        }
        // short position
        else {
            // if price of token increased after opening the position
            if (syntheticPrice >= position.syntheticEntryPrice) {
                netPnL =
                    ((syntheticPrice - position.syntheticEntryPrice) *
                        position.syntheticAmount) /
                    (10 ** DECIMALS);
                positionCollateralAmount = positionCollateralAmount - netPnL;
                // if price of token decreased after opening the position
            } else {
                netPnL =
                    ((position.syntheticEntryPrice - syntheticPrice) *
                        position.syntheticAmount) /
                    (10 ** DECIMALS);

                positionCollateralAmount = positionCollateralAmount + netPnL;
            }
        }
        // If Profit is made then the profit is added to the total collateral amount otherwise the loss is deducted from the collateral amount
        collateralAmount[msg.sender] = positionCollateralAmount;
        // Locked collateral and synthetic tokens are released
        collateralLocked[msg.sender] =
            collateralLocked[msg.sender] -
            position.collateralAmount;
        syntheticAmountLocked =
            syntheticAmountLocked -
            position.syntheticAmount;
        // Position is deleted
        delete positions[msg.sender][_index];
        emit PositionClosed(
            msg.sender,
            _index,
            position.collateralAmount,
            position.syntheticAmount,
            position.syntheticEntryPrice,
            position.leverageMultiplier,
            position.isLong
        );

        return true;
    }
    function updatePosition(
        uint256 _index,
        uint256 _leverage
    ) external returns (bool) {
        require(_index <= positionIndex[msg.sender], "Invalid Index");
        Position memory position = positions[msg.sender][_index];
        require(position.account == msg.sender, "Invalid Index");
        require(_leverage > 0, "Leverage Must be greater than zero");
        require(_leverage <= 10, "Leverage Must be less than 10");

        uint256 tokenPrice = PriceFeed(priceFeed).latestAnswer();
        uint256 syntheticAmount = (position.collateralAmount / tokenPrice) *
            _leverage *
            (10 ** DECIMALS);
        require(syntheticAmount < poolAmount(), "Insufficient Liquidity");
        syntheticAmountLocked =
            syntheticAmountLocked -
            position.syntheticAmount +
            syntheticAmount;
        // Position is updated with new leverage and based on that new synthetic amount is calculated
        Position memory newPosition = Position(
            msg.sender,
            _index,
            position.collateralAmount,
            syntheticAmount,
            tokenPrice,
            _leverage,
            position.isLong
        );
        positions[msg.sender][_index] = newPosition;
        emit PositionUpdated(
            msg.sender,
            _index,
            position.collateralAmount,
            syntheticAmount,
            tokenPrice,
            _leverage,
            position.isLong
        );
        return true;
    }
    // To get the total available amount of synthetic tokens in the pool
    function poolAmount() public view returns (uint256) {
        return
            IERC20(syntheticToken).balanceOf(address(this)) -
            syntheticAmountLocked;
    }
    // To get the position details of a user based on the index
    function getPosition(
        address account,
        uint256 _index
    ) external view returns (Position memory) {
        return positions[account][_index];
    }
    //  to get the remaining collateral that in unlocked
    function remainingCollateral(
        address account
    ) public view returns (uint256) {
        return collateralAmount[account] - collateralLocked[account];
    }
    //  To fetch the latest price of the synthetic token
    function syntheticTokenPrice() external view returns (uint256) {
        return PriceFeed(priceFeed).latestAnswer();
    }

    // to find the Profit and Loss of a position at a given price if the user decides to close the position
    function expectedPnL(
        address account,
        uint256 _index
    ) external view returns (bool, uint256) {
        Position memory position = positions[account][_index];
        uint256 syntheticPrice = PriceFeed(priceFeed).latestAnswer();
        require(syntheticPrice != 0, "Synthetic Price is Zero");
        uint256 netPnL;
        if (position.isLong) {
            if (syntheticPrice >= position.syntheticEntryPrice) {
                netPnL =
                    ((syntheticPrice - position.syntheticEntryPrice) *
                        position.syntheticAmount) /
                    (10 ** DECIMALS);
                return (true, netPnL);
            } else {
                netPnL =
                    ((position.syntheticEntryPrice - syntheticPrice) *
                        position.syntheticAmount) /
                    (10 ** DECIMALS);
                return (false, netPnL);
            }
        }
        // short position
        else {
            if (syntheticPrice >= position.syntheticEntryPrice) {
                netPnL =
                    ((syntheticPrice - position.syntheticEntryPrice) *
                        position.syntheticAmount) /
                    (10 ** DECIMALS);
                return (false, netPnL);
            } else {
                netPnL =
                    ((position.syntheticEntryPrice - syntheticPrice) *
                        position.syntheticAmount) /
                    (10 ** DECIMALS);
                return (true, netPnL);
            }
        }
    }
}
