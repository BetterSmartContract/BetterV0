// SPDX-License-Identifier: MIT
//0x26deFCEb3509a933b16619AAbEe1EdD7FeF7e927
//0xCc9aD5887B9996220cb6BaFB97B05B1EB4A65c52

pragma solidity ^0.8.12;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

import "https://github.com/BetterSmartContract/BetterV0/blob/main/BetterOracle_ChainLink.sol";

contract BettingContract {
    address public developer;

    BetterOracle_ChainLink public better_oracle;

    uint80 public roundID;
    int public price;
    uint public startedAt;
    uint public timeStamp;
    uint80 public answeredInRound;

    struct SupportedToken {
        uint256 id;
        address token;
        uint256 decimails;
        bool valid;
        address oracle_address;
    }

    struct Bet {
        uint256 bet_id;
        uint256 betting_id;
        address user;
        uint256 predictedPrice;
        uint256 amount;
        bool winner;
        bool claimed;
        bool rebeted;
        uint256 winningsRatio;
        uint256 winningsAmount;
    }

    enum Status {
        Open,
        Pending,
        Closed
    }

    Status constant default_value = Status.Open;

    struct Betting {
        uint256 id;
        address token;
        address creater;
        uint256 startTime;
        uint256 endTime;
        uint256 pendingTime;
        uint256 correctPrice;
        uint256 totalBets;
        uint256 totalAmount;
        Status status;
        bool hadWinner;
    }

    uint256 public bettingCount;
    uint256 public betCount;
    uint256 public SupportedTokenCount;
    mapping(uint256 => Betting) public bettings;
    mapping(uint256 => Bet) public bets;
    mapping(uint256 => SupportedToken) public supported_tokens;

    // uint256 fee_deviation = 50; // 2%
    uint256 fee_percentage = 2; // 2%
    uint256 range_percentage = 3; // 3%
    uint256 ratio_decimails = 10 ** 18;

    event SupportedTokenAdded(
        uint256 id,
        address token,
        address oracle_address
    );
    event BettingCreated(
        uint256 id,
        address token,
        address creater,
        uint256 startTime,
        uint256 endTime,
        uint256 pendingTime,
        bool hadWinner
    );
    event BetPlaced(
        uint256 bet_id,
        uint256 betting_id,
        address user,
        uint256 predictedPrice,
        uint256 amount,
        bool winner,
        bool claimed,
        bool rebeted,
        uint256 winningsRatio,
        uint256 winningsAmount
    );
    event BettingClosed(uint256 id, uint256 correctPrice);
    event WinningClaimed(address user, uint256 amount);

    constructor() {
        developer = msg.sender;
    }

    /**
     *test ok
     */
    function AddSupportedToken(
        address token_address,
        uint256 decimails,
        address oracle_address
    ) public returns (bool) {
        require(
            developer == msg.sender,
            "only developer can add supported tokens @ AddSupportedToken()"
        );
        bool newToken = true;

        for (uint256 i = 0; i <= SupportedTokenCount; i++) {
            if (supported_tokens[i].token == token_address) {
                newToken = false;
            }
        }

        if (newToken) {
            SupportedTokenCount++;

            SupportedToken storage newSupportedToken = supported_tokens[
                SupportedTokenCount
            ];
            newSupportedToken.id = SupportedTokenCount;
            newSupportedToken.token = token_address;
            newSupportedToken.decimails = decimails;
            newSupportedToken.valid = true;
            newSupportedToken.oracle_address = oracle_address;

            emit SupportedTokenAdded(
                SupportedTokenCount,
                token_address,
                oracle_address
            );
        }

        return newToken;
    }

    /**
     *test ok
     */
    function UpdateSupportedToken(
        uint256 id,
        address token_address,
        bool valid,
        address oracle_address
    ) public {
        require(
            developer == msg.sender,
            "only developer can update supported tokens @ UpdateSupportedToken()"
        );
        require(
            supported_tokens[id].token == token_address,
            "token address is not matched @ UpdateSupportedToken()"
        );

        supported_tokens[id].oracle_address = oracle_address;
        supported_tokens[id].valid = valid;
    }

    /**
     *test ok
     */
    function CreateBetting(
        address token_address,
        uint256 startTime,
        uint256 endTime,
        uint256 pendingTime
    ) public returns (uint256) {
        require(
            startTime >= block.timestamp,
            "Betting cannot start in the past @ CreateBetting()"
        );
        require(endTime > pendingTime, "Invalid end time @ CreateBetting()");
        require(
            pendingTime > startTime,
            "Invalid pending time @ CreateBetting()"
        );

        address creater = msg.sender;
        bettingCount++;

        bool supportedToken = false;

        for (uint256 i = 0; i <= SupportedTokenCount; i++) {
            if (
                supported_tokens[i].token == token_address &&
                supported_tokens[i].valid == true
            ) {
                supportedToken = true;
            }
        }

        require(
            supportedToken == true,
            "token address not supported! @ CreateBetting()"
        );

        Betting storage newBetting = bettings[bettingCount];
        newBetting.token = token_address;
        newBetting.creater = creater;
        newBetting.id = bettingCount;
        newBetting.startTime = startTime;
        newBetting.endTime = endTime;
        newBetting.pendingTime = pendingTime;
        newBetting.correctPrice = 0;
        newBetting.totalBets = 0;
        newBetting.totalAmount = 0;
        newBetting.status = Status.Open;
        newBetting.hadWinner = false;

        emit BettingCreated(
            bettingCount,
            token_address,
            creater,
            startTime,
            endTime,
            pendingTime,
            false
        );

        return bettingCount;
    }

    /**
     *test ok
     */
    function CreateBet(
        address token_address,
        uint256 betting_id,
        uint256 predictedPrice,
        uint256 amount
    ) public returns (uint256) {
        require(
            token_address == bettings[betting_id].token,
            "incompatible token address @ CreateBet()"
        );
        require(
            betting_id > 0 && betting_id <= bettingCount,
            "Invalid betting ID @ CreateBet()"
        );
        require(
            bettings[betting_id].status == Status.Open,
            "Betting is not open for bets @ CreateBet()"
        );
        require(
            block.timestamp < bettings[betting_id].pendingTime,
            "Betting is closed for new bets @ CreateBet()"
        );
        require(amount > 0, "Invalid bet amount @ CreateBet()");

        (
            uint256 bet_id_in_current_betting_id,
            uint256 bet_id_in_all_bet_list
        ) = bet_id_by_user(betting_id, msg.sender);
        require(bet_id_in_all_bet_list == 0, "wrong betting id @ CreateBet()");
        require(
            bet_id_in_current_betting_id == 0,
            "You already bed on this betting! @ CreateBet()"
        );

        IERC20 token = IERC20(token_address);
        require(
            token.balanceOf(msg.sender) >= amount,
            "Insufficient token balance @ CreateBet()"
        );
        require(
            token.approve(address(this), amount),
            "Not approving token transfer! @ CreateBet()"
        );
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Transfer failed @ CreateBet()"
        );

        betCount++;

        uint256 currrent_bet_length = bet_length(betting_id);
        uint256 new_bet_id = currrent_bet_length + 1;

        bettings[betting_id].totalBets++;
        bettings[betting_id].totalAmount += amount;

        Bet storage newBet = bets[betCount];
        newBet.bet_id = new_bet_id;
        newBet.betting_id = betting_id;
        newBet.user = msg.sender;
        newBet.predictedPrice = predictedPrice;
        newBet.amount = amount;
        newBet.winner = false;
        newBet.claimed = false;
        newBet.rebeted = false;
        newBet.winningsRatio = 0;
        newBet.winningsAmount = 0;

        emit BetPlaced(
            new_bet_id,
            betting_id,
            msg.sender,
            predictedPrice,
            amount,
            false,
            false,
            false,
            0,
            0
        );

        return betCount;
    }

    /**
     * all betters can close betting if betting is passing pending time
     * loop current betting by betting id to calculate winners
     *test ok, to do oracle
     */
    function CloseBetting(uint256 _betting_id) public {
        (
            uint256 bet_id_in_current_betting_id,
            uint256 bet_id_in_all_bet_list
        ) = bet_id_by_user(_betting_id, msg.sender);

        bool better = false;

        if (bets[bet_id_in_all_bet_list].betting_id == _betting_id) {
            if (bets[bet_id_in_all_bet_list].amount > 0) {
                better = true;
            }
        }

        require(
            better == true,
            "only betters can close betting @ CloseBetting()"
        );

        Betting storage betting = bettings[_betting_id];

        require(
            betting.status == Status.Open,
            "Betting is not open @ CloseBetting()"
        );
        require(
            block.timestamp >= betting.pendingTime,
            "Betting pendingTime has not passed yet @ CloseBetting()"
        );
        require(
            block.timestamp >= betting.endTime,
            "Betting endTime has not passed yet @ CloseBetting()"
        );

        uint256 token_decimails;
        address oracle_address;

        // get token decimals
        for (uint256 i = 0; i <= SupportedTokenCount; i++) {
            if (
                supported_tokens[i].token == betting.token &&
                supported_tokens[i].valid == true
            ) {
                token_decimails = supported_tokens[i].decimails;
                oracle_address = supported_tokens[i].oracle_address;
            }
        }

        //oracle_address : 0x600F3136cd6d72D1f98db4596a5638e20113A3bD
        better_oracle = BetterOracle_ChainLink(oracle_address);

        (uint256 _correctPrice, uint80 target_roundID) = better_oracle
            .fetch_closest_price_to_timestamp(
                betting.token,
                betting.endTime,
                token_decimails
            );

        //to do: use oracle to replace this line
        bettings[_betting_id].correctPrice = _correctPrice;

        bool hasWinner = false;

        uint256 all_winner_bet_amount = 0;

        uint256 correct_price_range = (_correctPrice * range_percentage) / 100;

        uint256 correct_price_upper_bond = _correctPrice + correct_price_range;

        uint256 correct_price_lower_bond = _correctPrice - correct_price_range;

        //loop current betting to calculate winners
        for (uint256 i = 0; i <= betCount; i++) {
            if (bets[i].betting_id == _betting_id) {
                if (bets[i].amount != 0) {
                    // meet the price range
                    if (
                        bets[i].predictedPrice >= correct_price_lower_bond &&
                        bets[i].predictedPrice <= correct_price_upper_bond
                    ) {
                        bets[i].winner = true;
                        hasWinner = true;

                        all_winner_bet_amount += bets[i].amount;
                    }
                }
            }
        }

        //loop current betting to calculate winning ratio and winning amount
        if (hasWinner == true) {
            for (uint256 i = 0; i <= betCount; i++) {
                if (bets[i].betting_id == _betting_id) {
                    if (bets[i].winner == true) {
                        //uint256 winnings_ratio = (bets[i].amount * ratio_decimails )/ all_winner_bet_amount;

                        //bets[i].winningsRatio = (bets[i].amount * ratio_decimails )/ all_winner_bet_amount;
                        //bets[i].winningsAmount = (((bets[i].amount * ratio_decimails )/ all_winner_bet_amount) * (bettings[_betting_id].totalAmount - all_winner_bet_amount)) / ratio_decimails;
                        bets[i].winningsRatio = calculate_winningsRatio(
                            i,
                            all_winner_bet_amount
                        );
                        bets[i].winningsAmount = calculate_winningsAmount(
                            _betting_id,
                            i,
                            all_winner_bet_amount
                        );
                    }
                }
            }
        }

        //betting is closed, waiting for user to claim winnings
        betting.status = Status.Pending;
        betting.hadWinner = hasWinner;
    }

    /**
     * calculate_winningsRatio for CloseBetting(uint256 _betting_id)
     */
    function calculate_winningsRatio(
        uint256 bet_id,
        uint256 all_winner_bet_amount
    ) private view returns (uint256) {
        return (bets[bet_id].amount * ratio_decimails) / all_winner_bet_amount;
    }

    /**
     * calculate_winningsAmount for CloseBetting(uint256 _betting_id)
     */
    function calculate_winningsAmount(
        uint256 _betting_id,
        uint256 bet_id,
        uint256 all_winner_bet_amount
    ) private view returns (uint256) {
        return
            (((bets[bet_id].amount * ratio_decimails) / all_winner_bet_amount) *
                (bettings[_betting_id].totalAmount - all_winner_bet_amount)) /
            ratio_decimails;
    }

    /**
     * if betting has no winners, all better can not claims
     * if betting has winner, only winners can claims
     *test ok
     */
    function WinningClaims(address token_address, uint256 _bettingId) public {
        (
            uint256 bet_id_in_current_betting_id,
            uint256 bet_id_in_all_bet_list
        ) = bet_id_by_user(_bettingId, msg.sender);

        require(
            bet_id_in_all_bet_list > 0,
            "wrong bet id in bet list @ WinningClaims()"
        );
        require(
            bet_id_in_current_betting_id > 0,
            "wrong bet id in betting list @ WinningClaims()"
        );
        require(
            bets[bet_id_in_all_bet_list].betting_id == _bettingId,
            "wrong betting id @ WinningClaims()"
        );

        require(
            bettings[_bettingId].status == Status.Pending,
            "Betting is not pending @ WinningClaims()"
        );

        require(
            bettings[_bettingId].hadWinner == true,
            "This betting has no winner. @ WinningClaims()"
        );

        require(
            bets[bet_id_in_all_bet_list].user == msg.sender,
            "You did not bet on this betting. @ WinningClaims()"
        );
        require(
            bets[bet_id_in_all_bet_list].winner == true,
            "You did not win over this bet. @ WinningClaims()"
        );

        uint256 winnings = bets[bet_id_in_all_bet_list].winningsAmount;
        uint256 bet_amount = bets[bet_id_in_all_bet_list].amount;
        uint256 transfer_amount = winnings + bet_amount;

        require(
            transfer_amount > 0,
            "Your winning amount is zero. @ WinningClaims()"
        );
        require(
            bets[bet_id_in_all_bet_list].claimed == false,
            "You have already claimed your winnings. @ WinningClaims()"
        );
        require(
            bets[bet_id_in_all_bet_list].rebeted == false,
            "You have already rebeted your winnings. @ WinningClaims()"
        );

        if (transfer_amount > 0) {
            uint256 total_fee = FeeCollector(_bettingId, transfer_amount);

            uint256 new_transfer_amount = transfer_amount - total_fee;

            IERC20 token = IERC20(token_address);

            token.transfer(msg.sender, new_transfer_amount);

            bets[bet_id_in_all_bet_list].claimed = true;

            emit WinningClaimed(msg.sender, transfer_amount);
        }
    }

    /**
     * if betting has no winners, all better can rebet
     * if betting has winner, only winners can rebet
     *test ok
     */
    function ReBet(
        address token_address,
        uint256 _originalbetting_bettingId,
        uint256 _newbetting_bettingId,
        uint256 predictedPrice
    ) public returns (bool) {
        (
            uint256 bet_id_in_current_betting_id,
            uint256 bet_id_in_all_bet_list
        ) = bet_id_by_user(_originalbetting_bettingId, msg.sender);
        require(
            bet_id_in_all_bet_list > 0,
            "wrong bet id in bet list @ ReBet()"
        );
        require(
            bet_id_in_current_betting_id > 0,
            "wrong bet id in betting list @ ReBet()"
        );
        require(
            bets[bet_id_in_all_bet_list].betting_id ==
                _originalbetting_bettingId,
            "wrong betting id @ ReBet()"
        );

        require(
            bettings[_originalbetting_bettingId].status == Status.Pending,
            "Betting is not pending @ ReBet()"
        );
        require(
            bettings[_originalbetting_bettingId].token == token_address,
            "incompatible token address for _originalbetting_bettingId @ ReBet()"
        );

        require(
            bets[bet_id_in_all_bet_list].user == msg.sender,
            "You did not bet on this betting. @ ReBet()"
        );
        require(
            bets[bet_id_in_all_bet_list].claimed == false,
            "You have already claimed your winnings. @ ReBet()"
        );
        require(
            bets[bet_id_in_all_bet_list].rebeted == false,
            "You have already rebeted your winnings. @ ReBet()"
        );

        uint256 rebet_amount = 0;

        if (bettings[_originalbetting_bettingId].hadWinner == true) {
            require(
                bets[bet_id_in_all_bet_list].winner == true,
                "Only winner can rebet. @ ReBet()"
            );
            //only winner can rebet
            uint256 winnings = bets[bet_id_in_all_bet_list].winningsAmount;
            uint256 bet_amount = bets[bet_id_in_all_bet_list].amount;
            rebet_amount = winnings + bet_amount;
        } else {
            // if betting has no winners, all better can rebet
            rebet_amount = bets[bet_id_in_all_bet_list].amount;
        }

        require(
            rebet_amount > 0,
            "You don't have enough amount to rebet @ ReBet()"
        );

        if (rebet_amount > 0) {
            uint256 total_fee = FeeCollector(
                _originalbetting_bettingId,
                rebet_amount
            );

            uint256 new_bet_amount = rebet_amount - total_fee;

            uint256 new_bet_length = CreateBet(
                token_address,
                _newbetting_bettingId,
                predictedPrice,
                new_bet_amount
            );

            if (new_bet_length > bet_id_in_all_bet_list) {
                bets[bet_id_in_all_bet_list].rebeted = true;

                return true;
            } else {
                return false;
            }
        } else {
            return false;
        }
    }

    /**
     * total fee eaquals 2 times of fee_percentage for betting creater and developer
     *test ok
     */
    function FeeCollector(
        uint256 _bettingId,
        uint256 amount
    ) private returns (uint256) {
        uint256 total_fee = 0;

        address token_address = bettings[_bettingId].token;

        IERC20 token = IERC20(token_address);

        uint256 fee = (amount * fee_percentage) / 100;

        address recipient_1 = bettings[_bettingId].creater;

        token.transferFrom(msg.sender, recipient_1, fee);

        address recipient_2 = bettings[_bettingId].creater;
        token.transferFrom(developer, recipient_2, fee);

        total_fee = fee * 2;

        return total_fee;
    }

    /**
    return last uint256 key index of bet from indicated bettingId
    test ok
    */
    function bet_length(uint256 _bettingId) public view returns (uint256) {
        uint256 currentBetting_bet_length = bettings[_bettingId].totalBets;

        return currentBetting_bet_length;
    }

    /**
    return uint256 key index of specific bet from indicated bettingId
    test ok
    */
    function bet_id_by_user(
        uint256 _bettingId,
        address user
    ) public view returns (uint256, uint256) {
        uint256 bet_id_in_all_bet_list = 0;
        uint256 bet_id_in_current_betting_id = 0;

        for (uint256 i = 0; i <= betCount; i++) {
            if (bets[i].betting_id == _bettingId) {
                if (bets[i].user == user) {
                    bet_id_in_all_bet_list = i;
                    bet_id_in_current_betting_id = bets[i].bet_id;
                    break;
                }
            }
        }
        return (bet_id_in_current_betting_id, bet_id_in_all_bet_list);
    }

    /**
     *test only, remove when production
     * test ok
     */
    function test_withdraw_all_token_balance(address token_address) public {
        IERC20 token = IERC20(token_address);
        uint256 amount = token.balanceOf(address(this));
        token.transfer(msg.sender, amount);
    }

    function get_oracle_data()
        public
        returns (uint80, int, uint, uint, uint80)
    {
        better_oracle = BetterOracle_ChainLink(
            0x600F3136cd6d72D1f98db4596a5638e20113A3bD
        );

        (roundID, price, startedAt, timeStamp, answeredInRound) = better_oracle
            .getLatestPrice();

        return (roundID, price, startedAt, timeStamp, answeredInRound);
    }
}
