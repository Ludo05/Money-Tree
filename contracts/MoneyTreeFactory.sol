// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.9;

import "./MoneyTree.sol";
import "./Liquidator.sol";
import "./Assets.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";



/**
 * @title MoneyTreeFactory contract.
 */
contract MoneyTreeFactory {

    uint256 public closingFee;
    uint256 public lastLoanId;
    uint256 public collateralRatio;
    uint256 public liquidationDuration;

    address public DaoAddr;
    address public liquidatorAddr;
    address public moneyTreeAddr;
    address public moneyTreeFactoryAddress;

    Assets internal assetManger;
    MoneyTree internal token;
    Liquidator internal liquidator;

    uint256 constant internal PRECISION_POINT = 10 ** 13;
    uint256 constant internal AVAX_TO_WEI = 10 ** 18;
    uint256 constant internal MAX_LOAN = 10000 * 10 ** 18;
    uint256 constant internal COLLATERAL_MULTIPLIER = 2;

    enum Types {
        AVAX_PRICE,
        COLLATERAL_RATIO,
        LIQUIDATION_DURATION
    }

    enum LoanState {
        UNDEFINED,
        ACTIVE,
        UNDER_LIQUIDATION,
        LIQUIDATED,
        SETTLED
    }

    enum AssetsType {
        BTC,
        ETH,
        AVAX
    }

    struct Loan {
        address payable recipient;
        uint256 collateral;
        uint256 amount;
        string asset;
        LoanState state;
    }

    mapping(uint256 => Loan) public loans;

    event LoanGot(address indexed recipient, uint256 indexed loanId, string assetType, uint256 collateral, uint256 amount);
    event LoanSettled(address recipient, uint256 indexed loanId, uint256 collateral, uint256 amount);
    event CollateralIncreased(address indexed recipient, uint256 indexed loanId, uint256 collateral);
    event CollateralDecreased(address indexed recipient, uint256 indexed loanId, uint256 collateral);

    string private constant INVALID_AMOUNT = "INVALID_AMOUNT";
    string private constant INITIALIZED_BEFORE = "INITIALIZED_BEFORE";
    string private constant SUFFICIENT_COLLATERAL = "SUFFICIENT_COLLATERAL";
    string private constant INSUFFICIENT_COLLATERAL = "INSUFFICIENT_COLLATERAL";
    string private constant INSUFFICIENT_ALLOWANCE = "INSUFFICIENT_ALLOWANCE";
    string private constant ONLY_LOAN_OWNER = "ONLY_LOAN_OWNER";
    string private constant ONLY_LIQUIDATOR = "ONLY_LIQUIDATOR";
    string private constant ONLY_DAO = "ONLY_DAO";
    string private constant INVALID_LOAN_STATE = "INVALID_LOAN_STATE";
    string private constant EXCEEDED_MAX_LOAN = "EXCEEDED_MAX_LOAN";

    constructor(address _tokenAddr, address _oracle) {
        closingFee=50; // 0.5%
        moneyTreeFactoryAddress = address(this);
        moneyTreeAddr = _tokenAddr;
        token = MoneyTree(_tokenAddr);
        assetManger = Assets(_oracle);

        collateralRatio = 1500; // = 1.5 * PRECISION_POINT
        liquidationDuration = 7200; // = 2 hours
    }

    /**
     * @notice Returns the latest price Avax/USD
     * @dev chainlink function.
     */



    /**
     * @notice Gives out as much as half the maximum loan you can possibly receive from the smart contract
     * @dev Fallback function.
     */
    fallback() external
    payable {

    }

    /**
    * @notice to surpress warning which states recieve fallback is needed when using fallback.
    * @notice info at link - https://stackoverflow.com/questions/59651032/why-does-solidity-suggest-me-to-implement-a-receive-ether-function-when-i-have-a
    *
    */

    receive() external payable {
        // custom function code
    }

    /**
     * @notice Set Liquidator's address.
     * @param _liquidatorAddr The Liquidator's contract address.
     */
    function setLiquidator(address _liquidatorAddr)
    external
    {
        require(liquidatorAddr == address(0), INITIALIZED_BEFORE);

        liquidatorAddr = _liquidatorAddr;
        liquidator = Liquidator(_liquidatorAddr);
    }

    /**
     * @notice Set oracle's address.
     * @param _DaoAddr The oracle's contract address.
     */
    function setOracle(address _DaoAddr)
    external
    {
        require (DaoAddr == address(0), INITIALIZED_BEFORE);

        DaoAddr = _DaoAddr;
    }

    /**
     * @notice Set important varibales by DAO.
     * @param _type Type of the variable.
     * @param value Amount of the variable.
     */
    function setVariable(uint8 _type, uint256 value)
    external
    onlyDAO
    throwIfEqualToZero(value)
    {

        if (uint8(Types.COLLATERAL_RATIO) == _type) {
            collateralRatio = value;
        } else if (uint8(Types.LIQUIDATION_DURATION) == _type) {
            liquidationDuration = value;
        }
    }

    /**
     * @notice Deposit avax to borrow USDR.
     * @param amount The amount of requsted loan in USDR.
     */
    function getLoan(uint256 amount, string memory asset)
    public
    payable
    throwIfEqualToZero(amount)
    throwIfEqualToZero(msg.value)
    {
        require (keccak256(abi.encodePacked(asset)) != keccak256(abi.encodePacked("AVAX")), "PLEASE PROVIDE AVAX");
        require (amount <= MAX_LOAN, EXCEEDED_MAX_LOAN);
        require (minCollateral(amount, asset) <= msg.value, INSUFFICIENT_COLLATERAL);
        uint256 loanId = ++lastLoanId;
        loans[loanId].recipient = payable(msg.sender);
        loans[loanId].asset = asset;
        loans[loanId].collateral = msg.value;
        loans[loanId].amount = amount;
        loans[loanId].state = LoanState.ACTIVE;
        emit LoanGot(msg.sender, loanId, asset, msg.value, amount);
        MoneyTree(moneyTreeAddr).mint(msg.sender, amount);
        MoneyTree(moneyTreeAddr).increaseAllowanceToSpender(moneyTreeFactoryAddress,amount);

    }

    /**
     * @notice Increase the loan's collateral.
     * @param loanId The loan id.
     */
    function increaseCollateral(uint256 loanId)
    external
    payable
    throwIfEqualToZero(msg.value)
    checkLoanState(loanId, LoanState.ACTIVE)
    {
        loans[loanId].collateral = loans[loanId].collateral + (msg.value);
        emit CollateralIncreased(msg.sender, loanId, msg.value);
    }

    /**
     * @notice Pay back extera collateral.
     * @param loanId The loan id.
     * @param amount The amout of extera colatral.
     */
    function decreaseCollateral(uint256 loanId, uint256 amount, address payable, string memory asset)
    external
    throwIfEqualToZero(amount)
    onlyLoanOwner(loanId)
    {
        require(loans[loanId].state != LoanState.UNDER_LIQUIDATION, INVALID_LOAN_STATE);
        require(minCollateral(loans[loanId].amount, asset) <= loans[loanId].collateral - (amount), INSUFFICIENT_COLLATERAL);
        loans[loanId].collateral = loans[loanId].collateral - (amount);
        emit CollateralDecreased(msg.sender, loanId, amount);
        loans[loanId].recipient.transfer(amount);
    }

    /**
    * @notice pay USDR back to settle the loan.
    * @param loanId The loan id.
    * @param amount The USDR amount payed back.
    */
    function settleLoan(uint256 loanId, uint256 amount)
    external
    checkLoanState(loanId, LoanState.ACTIVE)
    throwIfEqualToZero(amount)
    {
        uint256 fee = closingFee * amount;
        require(amount  <= (loans[loanId].amount + fee), INVALID_AMOUNT);

        MoneyTree(moneyTreeAddr).approve(moneyTreeFactoryAddress,amount);
        require(MoneyTree(moneyTreeAddr).transferFrom(msg.sender, moneyTreeAddr, amount), INSUFFICIENT_ALLOWANCE);
        uint256 payback = loans[loanId].collateral * (amount) / (loans[loanId].amount);
        MoneyTree(moneyTreeAddr).burn(msg.sender, amount);

        loans[loanId].collateral = loans[loanId].collateral - (payback);
        loans[loanId].amount = loans[loanId].amount - (amount);
        if (loans[loanId].amount == 0) {
            loans[loanId].state = LoanState.SETTLED;
        }
        emit LoanSettled(loans[loanId].recipient, loanId, payback, amount);
        loans[loanId].recipient.transfer(payback);
    }

    /**
     * @notice Start liquidation process of the loan.
     * @param loanId The loan id.
     */
    function liquidate(uint256 loanId, string memory asset)
    external
    checkLoanState(loanId, LoanState.ACTIVE)
    {
        require (loans[loanId].collateral < minCollateral(loans[loanId].amount, asset), SUFFICIENT_COLLATERAL);
        loans[loanId].state = LoanState.UNDER_LIQUIDATION;
        liquidator.startLiquidation(
            loanId,
            loans[loanId].collateral,
            loans[loanId].amount,
            liquidationDuration
        );
    }

    /**
     * @dev pay a part of the collateral to the auction's winner.
     * @param loanId The loan id.
     * @param collateral The bid of winner.
     * @param buyer The winner account.
     */
    function liquidated(uint256 loanId, uint256 collateral, address payable buyer)
    external
    onlyLiquidator
    checkLoanState(loanId, LoanState.UNDER_LIQUIDATION)
    {
        require (collateral <= loans[loanId].collateral, INVALID_AMOUNT);
        loans[loanId].collateral = loans[loanId].collateral - (collateral);
        loans[loanId].amount = 0;
        loans[loanId].state = LoanState.LIQUIDATED;
        buyer.transfer(collateral);
    }


    /**
     * @notice Minimum collateral in wei that is required for borrowing `amount` cents.
     * @param amount The amount of the loan in cents.
     */
    function minCollateral(uint256 amount, string memory asset)
    public
    view
    returns (uint256)
    {
        uint256 min = amount * (collateralRatio) * (AVAX_TO_WEI) / (PRECISION_POINT) / (uint256(assetManger.getPriceForAsset(asset)));
        return min;
    }



    /**
     * @dev Throws if called by any account other than our Oracle.
     */
    modifier onlyDAO() {
        require(msg.sender == DaoAddr, ONLY_DAO);
        _;
    }

    /**
     * @dev Throws if called by any account other than our Liquidator.
     */
    modifier onlyLiquidator() {
        require(msg.sender == liquidatorAddr, ONLY_LIQUIDATOR);
        _;
    }

    /**
     * @dev Throws if the number is equal to zero.
     * @param number The number to validate.
     */
    modifier throwIfEqualToZero(uint number) {
        require(number != 0, INVALID_AMOUNT);
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner of the loan.
     * @param loanId The loan id.
     */
    modifier onlyLoanOwner(uint256 loanId) {
        require(loans[loanId].recipient == msg.sender, ONLY_LOAN_OWNER);
        _;
    }

    /**
     * @dev Throws if state is not equal to needState.
     * @param loanId The id of the loan.
     * @param needState The state which needed.
     */
    modifier checkLoanState(uint256 loanId, LoanState needState) {
        require(loans[loanId].state == needState, INVALID_LOAN_STATE);
        _;
    }
}
