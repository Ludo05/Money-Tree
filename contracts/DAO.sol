// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.9;

import "./MoneyTreeFactory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
/**
 * @title MoneyTreeFactory's DAO contract.
 */
contract DAO is Ownable {
    using SafeMath for uint256;


    address public Owner;

    MoneyTreeFactory internal bank;

    bool public recruitingFinished = false;

    uint256 private totalScore;

    struct Vote {
        uint256 value;
        uint256 votingNo;
    }

    struct Voting {
        uint256 sum;
        uint256 sumScores;
        uint256 No;
    }

    mapping(bytes32 => Vote) private votes;
    mapping(uint8 => Voting) private votings;
    mapping(address => uint256) private Dao;

    event EditDAO(address dao, uint256 score);
    event FinishRecruiting();
    event SetVote(address dao, uint8 _type, uint256 _value);
    event Update(uint8 indexed _type, uint256 _value);

    string private constant INVALID_ADDRESS = "INVALID_ADDRESS";
    string private constant RECRUITING_FINISHED = "RECRUITING_FINISHED";
    string private constant INVALID_SCORE = "INVALID_SCORE";

    constructor(address payable  _moneytreefactoryAddr)

    {
        Owner = msg.sender;
        bank = MoneyTreeFactory(_moneytreefactoryAddr);
    }

    /**
     * @notice Sign a ballot.
     * @param _value The value of a variable.
     * @param _type The variable code.
     */
    function vote(uint8 _type, uint256 _value)
    external
    {
        address dao = msg.sender;
        uint256 score = Dao[dao];
        bytes32 votesKey = keccak256(abi.encodePacked(dao,_type));
        if (votings[_type].No == 0) {
            votings[_type].No++;
        }
        if (votes[votesKey].votingNo == votings[_type].No) {
            votings[_type].sum = votings[_type].sum.sub(votes[votesKey].value.mul(score));
            votings[_type].sumScores = votings[_type].sumScores.sub(score);
        }
        votes[votesKey].value = _value;
        votes[votesKey].votingNo = votings[_type].No;
        votings[_type].sum = votings[_type].sum.add(_value.mul(score));
        votings[_type].sumScores = votings[_type].sumScores.add(score);
        emit SetVote(dao, _type, _value);
        if (totalScore.div(votings[_type].sumScores) < 2) {
            updateMoneyTreeFactory(_type);
        }
    }

    /**
     * @notice Update the MoneyTreeFactory variable.
     * @param _type The variable code.
     */
    function updateMoneyTreeFactory(uint8 _type)
    internal
    {
        uint256 _value = votings[_type].sum.div(votings[_type].sumScores);
        bank.setVariable(_type, _value);
        votings[_type].sum = 0;
        votings[_type].sumScores = 0;
        votings[_type].No++;
        emit Update(_type, _value);
    }

    /**
     * @notice Manipulate (add/remove/edit score) member of Dao.
     * @param _account The dao account.
     * @param _score The score of dao.
     */
    function setScore(address _account, uint256 _score)
    external
    onlyOwner
    canRecruiting
    {
        require(_account != address(0), INVALID_ADDRESS);
        require(0 <= _score && _score <= 100, INVALID_SCORE);
        totalScore = totalScore.sub(Dao[_account]);
        totalScore = totalScore.add(_score);
        Dao[_account] = _score;
        emit EditDAO(_account, _score);
    }

    /**
    * @notice Function to stop recruiting new dao.
    */
    function finishRecruiting()
    external
    onlyOwner
    canRecruiting
    {
        recruitingFinished = true;
        emit FinishRecruiting();
    }

    /**
     * @dev Throws if recruiting finished.
     */
    modifier canRecruiting() {
        require(!recruitingFinished, RECRUITING_FINISHED);
        _;
    }
}
