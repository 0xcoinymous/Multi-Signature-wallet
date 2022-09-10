// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

// with possiblity for adding new owners :

contract MultiSigWallet {

    // struct OwnerCandidate{
    //     address candida ;
    //     uint confirmations;
    // }

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint confirmations;
    }

    uint public requiredConfirmationTrx;
    uint public requiredConfirmationAddOwner;

    
    address[] public owners;

    // address [] public ownerCandidates ;
    Transaction[] public transactions;


    mapping(address => bool) public isOwner;          // mapping from owner address => bool(is owner ot not)

    mapping(uint => mapping(address => bool)) public isConfirmed;         // mapping from index of transaction => owner address => bool
    mapping(address => mapping(address => bool)) public isConfirmedOwnerCandidate;     // mapping from owner candidate => current owner => bool
    mapping(address => bool) public isownerCandidate ;
    mapping(address => uint) public candidateConfirmations ;

    event Deposit(address indexed sender, uint amount);
    event SubmitTrx( address indexed owner, uint indexed trxIndex, address indexed to, uint value, bytes data );
    event NewCandidate(address indexed candidate);
    event ConfirmTransaction(address indexed owner, uint indexed trxIndex);
    event ConfirmCandidate(address indexed candidate);
    event RevokeConfirmation(address indexed owner, uint indexed trxIndex);
    event ExecuteTransaction(address indexed owner, uint indexed trxIndex);
    event NewOwner(address indexed candidate) ;


    

    modifier trxExist(uint _trxIndex) {
        require(_trxIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint _trxIndex) {
        require(!transactions[_trxIndex].executed, "tx already executed");
        _;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    constructor(address[] memory _owners, uint _requiredConfirmationTrx , uint _requiredConfirmationAddOwner) {
        require(_owners.length > 0, "owners required");
        require(_requiredConfirmationTrx > 0 && _requiredConfirmationTrx <= _owners.length, "invalid number of required confirmations" );
        require(_requiredConfirmationAddOwner > 0 , "invalid number of required confirmations for adding owner " );

        for (uint i = 0; i < _owners.length; i++) {

            address owner = _owners[i];
            _addOwner(owner) ;

        }

        requiredConfirmationTrx = _requiredConfirmationTrx;
        requiredConfirmationAddOwner = _requiredConfirmationAddOwner ;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function addOwnerCandidate(address _ownerCandida) public onlyOwner {
        require(!isownerCandidate[_ownerCandida] && !isOwner[_ownerCandida] , "invalid address :already been submitted or currently owner! ");
        isownerCandidate[_ownerCandida] = true ;
        emit NewCandidate(_ownerCandida);

    }

    function addOwner(address _ownerCandida) public onlyOwner returns(uint) {
        require(isownerCandidate[_ownerCandida] && !isOwner[_ownerCandida] , "invalid address :already been submitted or currently owner! ");
        require(!isConfirmedOwnerCandidate[_ownerCandida][msg.sender] , "you've already confirmed this candidate for becoming owner! ");

        isConfirmedOwnerCandidate[_ownerCandida][msg.sender] = true ;
        candidateConfirmations[_ownerCandida] ++ ;
        emit ConfirmCandidate(_ownerCandida) ;
        if(candidateConfirmations[_ownerCandida] == requiredConfirmationAddOwner){
            _addOwner(_ownerCandida) ;
            emit NewOwner(_ownerCandida) ;
        }
        return candidateConfirmations[_ownerCandida] ;
    }

    function _addOwner(address _ownerCandida) private {
        require(!isOwner[_ownerCandida], "Repetitious owners! ");
        require(_ownerCandida != address(0), "address(0) can't be owner! ");

        owners.push(_ownerCandida);
        isOwner[_ownerCandida] = true;
    }

    function submitTrx( address _to, uint _value, bytes memory _data ) public onlyOwner {
        uint trxIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                confirmations: 0
            })
        );

        emit SubmitTrx(msg.sender, trxIndex, _to, _value, _data);
    }

    function confirmTransaction(uint _trxIndex)public onlyOwner trxExist(_trxIndex) notExecuted(_trxIndex) {

        require(!isConfirmed[_trxIndex][msg.sender], " You've already confirmed the transaction ");
        transactions[_trxIndex].confirmations += 1;
        isConfirmed[_trxIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _trxIndex);
    }

    function executeTransaction(uint _trxIndex) public onlyOwner trxExist(_trxIndex) notExecuted(_trxIndex){
        Transaction storage transaction = transactions[_trxIndex];

        require(
            transaction.confirmations >= requiredConfirmationTrx,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _trxIndex);
    }

    function revokeConfirmation(uint _trxIndex) public onlyOwner trxExist(_trxIndex) notExecuted(_trxIndex){

        require(isConfirmed[_trxIndex][msg.sender], "tx not confirmed");

        transactions[_trxIndex].confirmations -= 1;
        isConfirmed[_trxIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _trxIndex);
    }

    function getTransactionInfo(uint _trxIndex) public view returns (address to, uint value, bytes memory data, bool executed, uint confirmations){
        
        Transaction storage transaction = transactions[_trxIndex];

        return (transaction.to, transaction.value, transaction.data, transaction.executed, transaction.confirmations );
    }
}

