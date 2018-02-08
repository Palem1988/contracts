pragma solidity ^0.4.18;

import "./TokenDriver.sol";
import "./GameBase.sol";

import "../token/IZXToken.sol";

import 'zeppelin-solidity/contracts/payment/PullPayment.sol';
import "zeppelin-solidity/contracts/math/SafeMath.sol";

contract CampaignManager is TokenDriver, PullPayment {

    DriveToken  public    drive_token;

    struct Prize {
        GameBase game;
        address holder;
        address master;
        address winner;

        uint256 value;
        uint256 expiration;
    }

    uint256 constant public MASTER_PAYOUT_SHARE = 10;
    uint256 constant public GAME_PAYOUT_SHARE = 20;
    uint256 constant public WINNER_PAYOUT_SHARE = 20;
    uint256 constant public HOLDER_PAYOUT_SHARE = 50;

    uint256 constant public TOKEN_RESERVE_AMOUNT = 1 ether;

    mapping (uint256 => Prize) public prizes;

    using SafeMath for uint256;


    function CampaignManager(IZXToken _izx_token) TokenDriver(_izx_token) public {
        drive_token = new DriveToken();
    }

    function issue_prizes(GameBase _game, uint256 _lifetime, uint256[] _hashes, uint256[] _extra) payable public {

        require(_lifetime>0);

        uint256 expiration = now + _lifetime;
        uint256 prize_value = msg.value / _hashes.length;
        uint256 change = msg.value % _hashes.length;

        address holder = reserve_tokens(
            TOKEN_RESERVE_AMOUNT.mul(_hashes.length),
            HOLDER_PAYOUT_SHARE.mul(prize_value)/100);

        require(holder != address(0));

        for(uint256 i=0;i<_hashes.length;i++){

           uint256 tokenId = drive_token.mint(_game);

           require( address(prizes[tokenId].game)==address(0) );
           prizes[tokenId] = Prize(_game, holder, msg.sender, address(0), prize_value, expiration);

           _game.place_prize(_hashes[i], tokenId, _extra[i]);
        }

        if(change>0){
            asyncSend(msg.sender, change);
        }

    }

    function win_prize(uint256 _tokenId, address _winner) public {

        Prize storage prize = prizes[_tokenId];

        require(msg.sender == address(prize.game));
        require(prize.winner==address(0));

        prize.winner = _winner;

    }


    function payout_prize(uint256 _tokenId)  public {

        Prize storage prize = prizes[_tokenId];

        require(prize.winner != address(0));
        require(prize.master == msg.sender);
        require(prize.expiration >= now);

        drive_token.burn(_tokenId);

        if(prize.value>0){
            execute_payouts(prize);
        }

        release_tokens(prize.holder, TOKEN_RESERVE_AMOUNT);
        delete prizes[_tokenId];
    }

    function revoke_prize(uint256 _tokenId)  public {

        Prize storage prize = prizes[_tokenId];
        require(prize.expiration < now);

        drive_token.burn(_tokenId);

        if(prize.value>0){
            asyncSend(prize.master, prize.value);
        }

        release_tokens(prize.holder, TOKEN_RESERVE_AMOUNT);

    }

    function execute_payouts(Prize _prize) private {

        uint256 payout = _prize.value;

        uint256 v = payout.mul(GAME_PAYOUT_SHARE) / 100;
        asyncSend(_prize.game.vault(), v);
        payout = payout.sub(v);

        v = payout.mul(WINNER_PAYOUT_SHARE) / 100;
        asyncSend(_prize.winner, v);
        payout = payout.sub(v);

        v = payout.mul(HOLDER_PAYOUT_SHARE) / 100;
        asyncSend(_prize.holder, v);

        asyncSend(_prize.master, payout.sub(v));

    }

}