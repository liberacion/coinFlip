pragma solidity 0.5.12;
import "./Ownable.sol";
import "https://github.com/provable-things/ethereum-api/provableAPI.sol";

contract Coinflip is Ownable, usingProvable{

  uint private balance = address(this).balance;
  bytes32 queryId;
  uint private constant NUM_RANDOM_BYTES_REQUESTED = 1;

  struct Bet {
      address payable player;
      uint totalBet;
      uint choice;
      bool result;
  }

  mapping(bytes32 => Bet) betting;
  mapping(address => bool) wait;

  modifier costs(uint cost){
       require(balance >= msg.value * 2);
       require(msg.value >= cost && msg.value <= 1 ether, "min bet is 0.01 ether and max bet is 1 ether");
       _;
   }

    event betRecieved(address indexed player, bytes32 Id, uint choice, uint totalBet, bool result);
    event betPlaced(address indexed player,bytes32 queryId, uint choice, uint totalBet);
    event funded(address balance, uint funding);
    event LogNewProvableQuery(string description);
    event generatedRandomNumber(uint256 randomNumber);

    constructor()
        public
    {
        provable_setProof(proofType_Ledger);

    }

    function __callback(bytes32 _queryId, string memory _result, bytes memory _proof) public {
        require(msg.sender == provable_cbAddress());

        if(provable_randomDS_proofVerify__returnCode(_queryId, _result, _proof) == 0){
            uint256 randomNumber = uint256(keccak256(abi.encodePacked(_result))) % 2;
            _verifyResult (randomNumber, _queryId);
            emit generatedRandomNumber(randomNumber);
        }

    }


    function _verifyResult (uint _randomNumber, bytes32 _queryId) internal{

        if(_randomNumber == betting{_queryId}.choice){
            betting[_queryId].result = true;
            betting[_queryId].player.transfer((betting[_queryId].totalBet)* 2);
            balance -= betting[_queryId].totalBet * 2;
        }
        else{
            betting[_queryId].result = false;
            balance += betting[_queryId].totalBet;

        }
        wait[betting[_queryId].player] = false;


        emit betRecieved(betting[_queryId].player, _queryId, betting[_queryId].choice, betting[_queryId].totalBet, betting[_queryId].result);

        }



  function update()
       internal

   {
       uint256 QUERY_EXECUTION_DELAY = 0;
       uint256 GAS_FOR_CALLBACK = 200000;
       bytes32 queryId = provable_newRandomDSQuery(
           QUERY_EXECUTION_DELAY,
           NUM_RANDOM_BYTES_REQUESTED,
           GAS_FOR_CALLBACK
           );
           emit LogNewProvableQuery("Provable query was sent, standing by for the answer");
   }

  function flip(uint _choice) public payable costs(0.01 ether) {
      require(_choice == 0 || _choice == 1);
      require(wait[msg.sender] == false);

      wait[msg.sender] = true;

      update();

      betting[queryId] = Bet({player: msg.sender, totalBet: msg.value, result: false});

      emit betPlaced(msg.sender, queryId, msg.value);
  }

  function withdrawAll() public onlyOwner returns(uint) {
        msg.sender.transfer(balance);
        assert(balance == 0);
        return balance;
  }
   function getBalance()public view returns(uint){
      return balance;
      }

  function fund() external payable onlyOwner returns(uint){
      require(msg.value == 50 ether, "You need to transfer 50 ether");
      balance += msg.value;
      emit funded(msg.sender, msg.value);
      return msg.value;
  }
  }
