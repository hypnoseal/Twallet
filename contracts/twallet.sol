// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <=0.8.0;
// Twallet, the Twitter wallet.
contract Twallet {
    // Setting of contract variables.
    // moneybot represents the wallet address for the Twitter moneybot.
    // onwer represents the owner of the Twallet.
    // twitter_id should be the twitter_id of the twallet owner to aid in
    // searching the blockchain.
    address payable public moneybot;
    address payable public owner;
    uint  public twitter_id;

    // Events to emit for when this contract has funds added or when funds are
    // transfered.
    event Funded(address _sender, uint _value);
    event Transfered(address _recipient, uint _value);

    // This modifier ensures that only the moneybot or twallet owner can peform
    // some of the functions in this smart contract.
    modifier onlyAuthorized {
        require(
            msg.sender == owner || msg.sender == moneybot,
            "Sorry, only the twallet owner or moneybot can do that."
            );
            _;
    }

    // The constructor sets the moneybot address as the the msg.sender, it is
    // assumed that the moneybot will be constructing the twallet. Owner is set
    // to the wallet address of the twitter user. twitter_id is set to the
    // Twitter ID of the twallet owner.
    constructor(address payable _owner, uint _twitter_id) payable {
        moneybot = payable(msg.sender);
        owner = _owner;
        twitter_id = _twitter_id;
    }

    // A specific function to add funds to the Twallet after the Twallet
    // contract is created. Anyone can addFunds to the twallet. The receive()
    // and fallback() functions below also allow the twallet to be funded if
    // the addFunds is not called.
    //function addFunds() payable public returns (bool success) {
    //    emit Funded(msg.sender, msg.value);
    //}

    // This function transfers funds from the twallet owner's twallet to the
    // recepient's twallet address.
    function transferFunds(address payable recipient, uint amount) public onlyAuthorized {
        require(
            address(this).balance >= amount + MoneyBot(moneybot).fetchFee(),
            "Sorry, insufficient funds available."
            );
        moneybot.transfer(MoneyBot(moneybot).fetchFee());
        recipient.transfer(amount);
        emit Transfered(recipient, amount);
    }

    // A function to allow the destruction of a Twallet. All funds are returned
    // to the twallet owner's wallet address.
    function destroyWallet() public onlyAuthorized {
        selfdestruct(owner);
    }

    // receive() function to ensure funds are deposited into the twallet if the
    // addFunds() function is not called.
    receive() external payable {
        emit Funded(msg.sender, msg.value);
    }

    // fallback() function to ensure funds are deposited into the twallet if the
    // addFunds() function is not called.
    fallback() external payable {
        emit Funded(msg.sender, msg.value);
    }
}
// TweetScrow, a short-term escrow wallet for Twitter IDs that do not yet have a
// Twallet.
contract TweetScrow {
    address payable public moneybot;
    address payable public sender;
    uint public sender_twitter_id;
    uint public recipient_twitter_id;
    uint public startdate;
    uint public timelimit;
    bytes32 public tweetscrowsecret;

    // Events to emit for when this contract has funds added or when funds are
    // transfered.
    event Funded(address _sender, uint _value);
    event Deposited(address _recipient, uint _value);
    event Destroyed(address _destroyer, bool _value);
    event Expired(address _expirer, bool _value);

    // Modifier to ensure that only the TweetScrow sender or moneybot can
    // utilize some functions.
    modifier onlyAuthorized {
      require(
          msg.sender == sender || msg.sender == moneybot,
          "Sorry, only a twallet owner or moneybot can do that."
          );
          _;
    }

    // Modifier to ensure that only the moneybot can utilize some functions.
    modifier onlyMoneyBot {
      require(
        msg.sender == moneybot,
        "Sorry, only money bot can do that."
        );
        _;
    }

    // Contract constructor
    constructor(address payable _sender, uint _sender_twitter_id, uint _recipient_twitter_id, uint _timelimit, bytes32 _tweetscrowsecret) payable {
      // It is assumed that moneybot will be sending the tweetscrow, so the
      // msg.sender is set as moneybot.
      moneybot = payable(msg.sender);
      // sender represents the Twallet of the Twitter user sending the transfer.
      sender = _sender;
      // sender_twitter_id represents the Twitter ID of the sender.
      sender_twitter_id = _sender_twitter_id;
      // recipient_twitter_id represents the Twitter ID of the recipient.
      recipient_twitter_id = _recipient_twitter_id;
      // timelimit sets the timelimit before the tweetscrow is expired.
      timelimit = _timelimit;
      // tweetscrowsecret is the hashed (keccak256) tweetscrowkey, the hash is
      // done by web3 and the tweetscrowkey shared to the Twitter Recipient by
      // DM.
      tweetscrowsecret = _tweetscrowsecret;
    }

    // depositTweetScrow function ensures that the appropriate recipient is
    // depositing the funds. Then creates a new Twallet for the recipient
    // Twitter ID. Finally it deposits the funds into the new Twallet through
    // the selfdestruct call.
    function depositTweetScrow(bytes32 _tweetscrowkey, address payable _recipient_address) public onlyMoneyBot {
      // require that the keccak256 of _tweetscrowkey matches _tweetscrowsecret.
      require(
        tweetscrowsecret == keccak256(abi.encode(_tweetscrowkey)),
        "Sorry, that TweetScrow Key is incorrect."
        );
      // Use the MoneyBot contract to create a new Twallet for the recipient's
      // Twitter ID.
      MoneyBot(moneybot).createTwallet(_recipient_address, recipient_twitter_id);
      // Pay the MoneyBot transfer fee to MoneyBot!
      moneybot.transfer(MoneyBot(moneybot).fetchFee());
      // emit that the Deposit will go through.
      emit Deposited(MoneyBot(moneybot).requestTwalletAddress(recipient_twitter_id), address(this).balance);
      // selfdestruct the TweetScrow and set the recipient address for the ether
      // in the contract for the Twallet Contract for the recipient Twitter ID.
      selfdestruct(MoneyBot(moneybot).requestTwalletAddress(recipient_twitter_id));
    }

    // destroyTweetScrow exists to destroy the TweetScrow for whatever reason
    // by the original sender Twallet or by MoneyBot contract.
    function destroyTweetScrow() public onlyAuthorized {
      // emits that the TweetScrow will be destroyed.
      emit Destroyed(msg.sender, true);
      // selfdestruct for the TweetScrow and returns funds to the original
      // sending Twallet.
      selfdestruct(sender);
    }

    // expireTweetScrow function exists to expire the TweetScrow after the
    // appropriate time as set by timelimit in the MoneyBot contract. Onlt the
    // MoneyBot can do this function.
    function expireTweetScrow() public onlyMoneyBot {
      // Require that the difference between the startdate and now is greater
      // than or equal to the timelimit.
      require(
        startdate - block.timestamp >= timelimit,
        "Sorry, the timelimit has not been reached."
        );
      // emit that the expiration will occcur and was done my message sender.
      emit Expired(msg.sender, true);
      // selfdestruct returning funds back to sender twallet.
      selfdestruct(sender);
    }

    // receive() function to ensure funds are deposited into the tweetscrow.
    receive() external payable {
        emit Funded(msg.sender, msg.value);
    }

    // fallback() function to ensure funds are deposited into the tweetscrow.
    fallback() external payable {
        emit Funded(msg.sender, msg.value);
    }

}
// MoneyBot, the Twallet and TweetScrow bot contract.
contract MoneyBot {
    address payable public moneybot;
    address payable public emptyAddress;
    uint public fee;
    uint public timelimit;

    mapping(uint => Twallet) public twallets;
    mapping(uint => mapping(uint => TweetScrow)) public tweetscrows;

    event FeeUpdated(address _sender, uint _value);
    event TwalletCreated(address _sender, address _twallet);

    modifier onlyMoneyBot {
      require(
        msg.sender == moneybot,
        "Sorry, only the MoneyBot can do that."
        );
        _;
    }

    constructor(uint _fee, uint _timelimit) payable {
      moneybot = payable(msg.sender);
      fee = _fee;
      timelimit = _timelimit;
      emptyAddress = payable(address(uint160(0)));
    }

    function createTwallet(address payable _owner, uint _twitter_id) public onlyMoneyBot payable {
      require(
        twallets[_twitter_id] == Twallet(emptyAddress),
        "Cannot create wallet, it already exists for this Twitter ID."
        );
      twallets[_twitter_id] = new Twallet(_owner, _twitter_id);
      if (msg.value > 0) {
        payable(twallets[_twitter_id]).transfer(msg.value);
      }
    }

    function createTweetScrow(uint _sender_twitter_id, uint _recipient_twitter_id, uint _amount, bytes32 _tweetscrowsecret) public onlyMoneyBot payable {
      require(
        twallets[_recipient_twitter_id] == Twallet(emptyAddress),
        "Sorry, cannot create a TweetScrow for a wallet that exists."
        );
      require(
        tweetscrows[_recipient_twitter_id][_sender_twitter_id] == TweetScrow(emptyAddress),
        "Sorry, you already have a pending transfer to that Twitter ID. Please try again later."
        );
      tweetscrows[_recipient_twitter_id][_sender_twitter_id] = new TweetScrow(payable(twallets[_sender_twitter_id]), _sender_twitter_id, _recipient_twitter_id, timelimit, _tweetscrowsecret);
      Twallet(twallets[_sender_twitter_id]).transferFunds(payable(tweetscrows[_recipient_twitter_id][_sender_twitter_id]), _amount);
      if(msg.value > 0) {
        payable(tweetscrows[_recipient_twitter_id][_sender_twitter_id]).transfer(msg.value);
      }
    }

    function fundTwallet(uint _twitter_id) public payable {
      require(
        twallets[_twitter_id] != Twallet(emptyAddress),
        "Sorry, only Twallets that exist can be funded."
        );
        payable(twallets[_twitter_id]).transfer(msg.value);
    }

    function transferTwallet(uint _sender_twitter_id, uint _recipient_twitter_id, uint _amount, bytes32 _secret) public onlyMoneyBot {
      require(
        twallets[_sender_twitter_id] != Twallet(emptyAddress),
        "Sorry, only Twallets that exist can be transfered funds."
        );
      if (twallets[_recipient_twitter_id] != Twallet(emptyAddress)) {
        twallets[_sender_twitter_id].transferFunds(payable(twallets[_recipient_twitter_id]), _amount);
      } else {
        createTweetScrow(_sender_twitter_id, _recipient_twitter_id, _amount, _secret);
      }
    }

    function requestTwalletAddress(uint _twitter_id) public view returns (address payable) {
      require(
        twallets[_twitter_id] != Twallet(emptyAddress),
        "Sorry, there is no Twallet for that Twitter ID."
        );
      return payable(address(twallets[_twitter_id]));
    }

    function fetchFee() public view returns (uint) {
      return fee;
    }

    function updateFee(uint _newFee) public onlyMoneyBot {
      fee = _newFee;
    }

    function fetchTimeLimit() public view returns (uint) {
      return timelimit;
    }

    function updateTimelimit(uint _newTimeLimit) public onlyMoneyBot {
      timelimit = _newTimeLimit;
    }

    receive() external payable {

    }
}
