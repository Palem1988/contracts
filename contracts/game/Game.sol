pragma solidity ^0.4.11;

import "../token/ERC20.sol";
import "../util/Owned.sol";
import "./GameController.sol";

contract Game is Owned {

    struct Prize {
        address issuer;
        address owner;
        uint256 tokens;
        uint256 value;
        uint256 expiration;
    }

    ERC20                       public token;
    GameController              public controller;
    mapping (uint256 => Prize)  public prizes;
    mapping (address => uint)   public pendingWithdrawals;
    mapping (address => uint)   public issuedPrizes;

    event Issue(address indexed issuer, address indexed owner, uint amount);
    event Claim(address indexed issuer, address indexed owner, address indexed winner, uint amount);
    event Expired(address indexed issuer, address indexed owner, uint amount);

    function Game(  ERC20 _token, GameController _controller  ) public {
        require(address(_token)!=address(0));
        require(address(_controller)!=address(0));
        token = _token;
        controller = _controller;
    }

    function issue(uint256[] _hashes, uint256 _expiration) payable public {

        uint256 reserved_amount = reserve_amount(_hashes.length, msg.value, msg.sender);
        require(reserved_amount>0 && _expiration > now);

        address tokens_owner = controller.amount_owner(this, reserved_amount);

        if(tokens_owner!=address(0)){
            require( token.transferFrom(tokens_owner, this, reserved_amount) );
            for(uint i=0;i<reserved_amount;i++){
                prizes[_hashes[i]] = Prize(msg.sender, tokens_owner, 1, msg.value, _expiration);
            }
            issuedPrizes[msg.sender] += reserved_amount;
            Issue(msg.sender, tokens_owner, reserved_amount);
        }
    }

    function claim(uint256 _key, address _winner) public returns (bool){

        uint256 hash = key_hash256(_key);

        Prize storage prize = prizes[hash];
        require(prize.owner != address(0));

        if( now>prize.expiration ){

            require( token.transfer(prize.owner, prize.tokens) );
            if(prize.value>0){
                pendingWithdrawals[prize.issuer] += prize.value;
            }
            issuedPrizes[msg.sender] -= 1;

            Expired(prize.issuer, prize.owner, prize.tokens);

            delete(prizes[hash]);
            return false;
        }else{
            payout(prize, _winner);
            issuedPrizes[msg.sender] -= 1;

            Claim(prize.issuer, prize.owner, _winner, prize.tokens);

            delete(prizes[hash]);
            return true;
        }


    }


    function key_hash256(uint256 _key) public view returns(uint256) {
        return uint256(sha256(_key, address(this)));
    }

    function withdraw() public {
        uint amount = pendingWithdrawals[msg.sender];
        pendingWithdrawals[msg.sender] = 0;
        if(amount>0){
            require(msg.sender.call.value(amount)());
        }
    }


    function reserve_amount( uint256 _requested_amount, uint256 _payed_value, address _buyer ) internal returns(uint256);

    function payout(Prize storage _prize, address _winner) internal;


}