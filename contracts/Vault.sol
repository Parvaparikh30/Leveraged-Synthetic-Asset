// SPDX-License-Identifier:MIT
pragma solidity ^0.8.12;

import "./IERC20.sol";
import "./PriceFeed.sol";
import "./utils/ReentrancyGuard.sol";

contract Vault is ReentrancyGuard {
    address public collateralToken;
    address public syntheticToken;
    address public priceFeed;
    uint256 public syntheticAmountLocked;
    uint8 public constant DECIMALS = 18;
    mapping(address => uint256) internal positionIndex;
    mapping(address => uint256) public collateralAmount;
    mapping(address => uint256) public collateralLocked;
    mapping(address => mapping(uint256 => Position)) internal positions;

    struct Position {
        address account;
        uint256 index;
        uint256 collateralAmount;
        uint256 syntheticAmount;
        uint256 syntheticEntryPrice;
        uint256 leverageMultiplier;
        bool isLong;
    }

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
        if (position.isLong) {
            if (syntheticPrice >= position.syntheticEntryPrice) {
                netPnL =
                    ((syntheticPrice - position.syntheticEntryPrice) *
                        position.syntheticAmount) /
                    (10 ** DECIMALS);
                positionCollateralAmount = positionCollateralAmount + netPnL;
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
            if (syntheticPrice >= position.syntheticEntryPrice) {
                netPnL =
                    ((syntheticPrice - position.syntheticEntryPrice) *
                        position.syntheticAmount) /
                    (10 ** DECIMALS);
                positionCollateralAmount = positionCollateralAmount - netPnL;
            } else {
                netPnL =
                    ((position.syntheticEntryPrice - syntheticPrice) *
                        position.syntheticAmount) /
                    (10 ** DECIMALS);

                positionCollateralAmount = positionCollateralAmount + netPnL;
            }
        }
        collateralAmount[msg.sender] = positionCollateralAmount;
        collateralLocked[msg.sender] =
            collateralLocked[msg.sender] -
            position.collateralAmount;
        syntheticAmountLocked =
            syntheticAmountLocked -
            position.syntheticAmount;

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
    function poolAmount() public view returns (uint256) {
        return
            IERC20(syntheticToken).balanceOf(address(this)) -
            syntheticAmountLocked;
    }
    function getPosition(
        address account,
        uint256 _index
    ) external view returns (Position memory) {
        return positions[account][_index];
    }
    function remainingCollateral(
        address account
    ) public view returns (uint256) {
        return collateralAmount[account] - collateralLocked[account];
    }

    function syntheticTokenPrice() external view returns (uint256) {
        return PriceFeed(priceFeed).latestAnswer();
    }

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
