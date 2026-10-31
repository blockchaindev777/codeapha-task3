// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title PollingSystem
/// @notice Create polls with a deadline; each address may vote once per poll.
contract PollingSystem {
    // ───────────────────────── Data structures ─────────────────────────

    struct Poll {
        string title;
        string[] options;
        uint256 endTime;
        address creator;
        // optionIndex => vote count
        mapping(uint256 => uint256) voteCount;
        // voter => has voted?
        mapping(address => bool) hasVoted;
    }

    uint256 public pollCount;
    mapping(uint256 => Poll) private polls;

    // ───────────────────────────── Events ──────────────────────────────

    event PollCreated(uint256 indexed pollId, address indexed creator, string title, uint256 endTime);
    event Voted(uint256 indexed pollId, address indexed voter, uint256 optionIndex);

    // ───────────────────────────── Errors ──────────────────────────────

    error PollDoesNotExist();
    error NeedAtLeastTwoOptions();
    error EmptyTitle();
    error DeadlineMustBeInFuture();
    error VotingClosed();
    error VotingStillOpen();
    error AlreadyVoted();
    error InvalidOption();

    // ───────────────────────────── Modifiers ───────────────────────────

    modifier pollExists(uint256 pollId) {
        if (pollId >= pollCount) revert PollDoesNotExist();
        _;
    }

    // ──────────────────────── Poll creation ────────────────────────────

    /// @notice Create a new poll.
    /// @param title    Poll question/title.
    /// @param options  List of choices (at least 2).
    /// @param endTime  Unix timestamp after which voting closes.
    /// @return pollId  Id of the newly created poll.
    function createPoll(
        string calldata title,
        string[] calldata options,
        uint256 endTime
    ) external returns (uint256 pollId) {
        if (bytes(title).length == 0) revert EmptyTitle();
        if (options.length < 2) revert NeedAtLeastTwoOptions();
        if (endTime <= block.timestamp) revert DeadlineMustBeInFuture();

        pollId = pollCount++;
        Poll storage p = polls[pollId];
        p.title = title;
        p.endTime = endTime;
        p.creator = msg.sender;

        for (uint256 i = 0; i < options.length; i++) {
            p.options.push(options[i]);
        }

        emit PollCreated(pollId, msg.sender, title, endTime);
    }

    // ───────────────────────────── Voting ──────────────────────────────

    /// @notice Cast a single vote before the deadline.
    function vote(uint256 pollId, uint256 optionIndex) external pollExists(pollId) {
        Poll storage p = polls[pollId];

        if (block.timestamp >= p.endTime) revert VotingClosed();
        if (p.hasVoted[msg.sender]) revert AlreadyVoted();
        if (optionIndex >= p.options.length) revert InvalidOption();

        p.hasVoted[msg.sender] = true;
        p.voteCount[optionIndex] += 1;

        emit Voted(pollId, msg.sender, optionIndex);
    }

    // ──────────────────────────── Results ──────────────────────────────

    /// @notice Returns the winning option once the poll has ended.
    /// @dev On a tie, the option with the lowest index wins and `isTie` is true.
    function getWinner(uint256 pollId)
        external
        view
        pollExists(pollId)
        returns (
            uint256 winningIndex,
            string memory winningOption,
            uint256 winningVotes,
            bool isTie
        )
    {
        Poll storage p = polls[pollId];
        if (block.timestamp < p.endTime) revert VotingStillOpen();

        uint256 len = p.options.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 v = p.voteCount[i];
            if (v > winningVotes) {
                winningVotes = v;
                winningIndex = i;
                isTie = false;
            } else if (v == winningVotes && i != winningIndex) {
                isTie = true;
            }
        }
        winningOption = p.options[winningIndex];
    }

    // ───────────────────────────── Views ───────────────────────────────

    function getPoll(uint256 pollId)
        external
        view
        pollExists(pollId)
        returns (
            string memory title,
            string[] memory options,
            uint256 endTime,
            address creator,
            bool isOpen
        )
    {
        Poll storage p = polls[pollId];
        return (p.title, p.options, p.endTime, p.creator, block.timestamp < p.endTime);
    }

    function getVoteCount(uint256 pollId, uint256 optionIndex)
        external
        view
        pollExists(pollId)
        returns (uint256)
    {
        Poll storage p = polls[pollId];
        if (optionIndex >= p.options.length) revert InvalidOption();
        return p.voteCount[optionIndex];
    }

    function hasVoted(uint256 pollId, address voter)
        external
        view
        pollExists(pollId)
        returns (bool)
    {
        return polls[pollId].hasVoted[voter];
    }
}
