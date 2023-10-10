// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.22 <=0.6.0;

import "./helper_contracts/ERC721.sol";

contract RESNFT is ERC721 {

    uint256 public assetCount;
    address public oracleAddress;

    struct Asset {
        uint256 assetId;
        uint256 price;
        uint256 parent;
        uint256 percent;
    }

    mapping(uint256=>Asset)   public assetMap;
    mapping(uint256=>address) public assetApprovals;
    mapping(uint256=>address) public assetOwner;
    mapping(uint256=>address) public assetRenter;
    mapping(address=>bool)    public eligibleList;

    constructor() public{
        oracleAddress = msg.sender;
    }
    

    // Event
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event AddedToWhiteList(address indexed);
    event RemoveFromWhiteList(address indexed);

    function addToEligibleList(address eligible) public {
        require( msg.sender == oracleAddress,"Only oracle can add eligible" );
        eligibleList[eligible] = true;
         emit AddedToWhiteList(eligible);
    }

    function removeFromEligibleList(address deligible) public {
        require( msg.sender == oracleAddress,"Only oracle can remove eligible" );
        eligibleList[deligible] = false;
        emit RemoveFromWhiteList(deligible);
    }

    function ownerOf(uint256 tokenId) public view returns(address) {
        address owner = assetOwner[tokenId];
        require(owner != address(0), "No Asset Exists");
        return owner;
    } 

    function getRenter(uint256 tokenId) public view returns(address) {
        require(assetRenter[tokenId] != address(0), "No Asset Exists");
        return assetRenter[tokenId];
    } 

    function transferFrom(address payable from, uint256 assetId) public payable {
        //require( eligibleList[msg.sender] == true ,"Only the oreligibles can transfer" );
        // اکانتی که قصد دارد این توکن را انتقال دهد یا باید خود مالک باشد یا از سمت مالک تایید شده باشد
        require(isApprovedOrOwner(msg.sender, assetId), "Not An Approved Owner");

        // توکن را فقط از مالک آن میتوانیم خرید کنیم
        require(ownerOf(assetId) == from, "Not The Asset Owner");

        // فراخوانی کننده این فانکشن باید قیمت توکن را پرداخت کرده باشد تا بتواند این توکن را انتقال دهد
        require(msg.value == assetMap[assetId].price * 10**18, "Not enough Value");

        clearApproval(assetId, getApproved(assetId));


        // آدرس مالک جدید را برای توکن ست میکنیم
        assetOwner[assetId] = msg.sender;

        // قیمت توکن که اکنون در اسمارت کانترکت نشسته، به مالک قبلی انتقال داده می شود
        from.transfer(assetMap[assetId].price * 10**18);

        emit Transfer(from, msg.sender, assetId);
    }

    function changeRenter(uint assetId, address newRenter) public{ 

        // توکن را فقط از مالک آن میتوانیم خرید کنیم
        require( oracleAddress == msg.sender, "only oracle can change renter");

        require( eligibleList[newRenter]," Owner address is not eligible" );

        assetRenter[assetId] = newRenter;

    }

    function split(uint id, uint count, uint[] memory percents, address[] memory addresses) public {
        require(checkPercentes(count, percents, assetMap[id].percent), "Some thing is wrong with percentes");
        require(checkAddressesEligibleity(count, addresses), "All address must be eligible");
        require(assetOwner[id] != address(0) || id >= 0, "Asset not exist");
        require(assetOwner[id] == msg.sender, "Only owner can split ");
        assetOwner[id] = address(0);
        //clearApproval(id, getApproved(id));
        for(uint i = 0; i < count; i++) {
            assetCount++;
            assetMap[assetCount] = Asset(assetCount, 0, id, percents[i]);
            assetOwner[assetCount] = addresses[i];
        }
    }

    function approve(address to, uint256 assetId) public {
        //require( eligibleList[to] == true ,"Only can approve to oreligibles" );
        address owner = ownerOf(assetId);

         require(to != owner, "Current Owner Approval");

        // فقط مالک توکن اجازه دارد که بقیه اکانت ها را تایید کند
        require(msg.sender == owner, "Not The Asset Owner");
        
        require( eligibleList[to]," Owner address is not eligible" );
        assetApprovals[assetId] = to;

        emit Approval(owner, to, assetId);
    }
    
    function getApproved(uint256 assetId) public view returns(address) {
        require(exists(assetId), "ERC721: approved query for nonexistent token");
        return assetApprovals[assetId];
    }


    ////////////////////////////////////////////////////////////////////////////////
    //             Functions used internally by another functions                 //
    ////////////////////////////////////////////////////////////////////////////////
    function mint(address to, uint256 assetId) internal {

        require(to != address(0), "Zero Address Minting");

        assetOwner[assetId] = to;
        assetRenter[assetCount] = to;
        
        emit Transfer(address(0), to, assetId);
    }

    function exists(uint256 assetId) internal view returns(bool) {
        return assetOwner[assetId] != address(0);
    }

    function isApprovedOrOwner(address spender, uint assetId) internal view returns(bool) {
        require(exists(assetId), "ERC721: operator query for nonexistent token");

        address owner = ownerOf(assetId);

        return (spender == owner || spender == getApproved(assetId) ); // 
    }


    ////////////////////////////////////////////////////////////////////////////////
    //                     Unused ERC721 functions                                //
    ////////////////////////////////////////////////////////////////////////////////

    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    mapping (address => mapping (address => bool)) private _operatorApprovals;

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function setApprovalForAll(address to, bool approved) public {
        require(to != msg.sender, "ERC721: approve to caller");
        _operatorApprovals[msg.sender][to] = approved;
        emit ApprovalForAll(msg.sender, to, approved);
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public {
        transferFrom(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) internal returns (bool) {
        if (!to.isContract()) {
            return true;
        }
        bytes4 retval = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data);
        return (retval == _ERC721_RECEIVED);
    }

    ////////////////////////////////////////////////////////////////////////////////
    //                 Additional functions added to the  token                   //
    ////////////////////////////////////////////////////////////////////////////////

    function addAsset(uint256 price, address to) public {
        
        // فقط اکانت اوراکل قادر به اضافه کردن توکن است
        require(msg.sender == oracleAddress, "only oracle address can call this function!");

        //require( eligibleList[to] == true ,"Assets can only add to eligibles " );

        require( eligibleList[to]," Owner address is not eligible" );
        assetMap[assetCount] = Asset(assetCount, price, 0, 100);
        
        // ایجاد دارایی
        assetMap[assetCount] = Asset(assetCount, price,0,100);       // price : Eth   ,  assetCount ~ assetId

        // انتصاب دارایی به مالک
        mint(to, assetCount);

        assetCount++;
    }
    
    

    function clearApproval(uint256 assetId, address approved) internal {
        if(approved == assetApprovals[assetId]) {
            assetApprovals[assetId] = address(0);
        } 
    }
    

    // افزایش قیمت توکن
    function changePrice(uint256 assetId, uint256 value) public {
        // فقط مالک می تواند این تابع را صدا بزند
        require(msg.sender == assetOwner[assetId] , "Only owner address Can call this Function!");
        assetMap[assetId].price = value;   // value , price : Eth
    }

    function checkPercentes(uint count, uint[] memory percents, uint parentPercent) pure private returns(bool) {
        uint _percent;
        for(uint i = 0; i < count; i++ ){
            if(percents[i] < 1){
                return false;
            }
            _percent = _percent + percents[i];
        }
        if(_percent == parentPercent){
            return true;
        }
        return false;
    } 

    function checkAddressesEligibleity(uint count, address[] memory addresses) view private returns(bool) {
        for(uint i = 0; i < count; i++ ){
            if(eligibleList[addresses[i]] == false){
                return false;
            }
        }
        return true;
    } 
  
}



/* 


// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.5 ;

contract test {

    uint256 public assetCount = 1 ;
    
    struct Asset {
        uint256 assetId;
        uint256 price;
        uint256 parent;
        uint256 percent;
    }

    mapping(uint256=>Asset)   public assetMap;
    mapping(uint256=>address) public assetOwner;

    function addAsset(uint _price) public {
        assetMap[assetCount] = Asset(assetCount, _price, 0, 100);
        assetOwner[assetCount] = msg.sender;
        assetCount++;
    }

    function split(uint id, uint count, uint[] memory percents, address[] memory addresses) public {
        require(checkPercentes(count, percents, assetMap[id].percent), "Some thing is wrong with percentes");
        assetOwner[id] = address(0);
        for(uint i = 0; i < count; i++) {
            assetMap[assetCount] = Asset(assetCount, 0, id, percents[i]);
            assetOwner[assetCount] = addresses[i];
            assetCount++;
        }
    }

    function getAsset(uint id) view public returns( Asset memory ) {
        require(assetOwner[id] != address(0) || id > 0, "Asset not exist");
        return assetMap[id] ;
    }

    function checkPercentes(uint count, uint[] memory percents, uint parentPercent) pure private returns(bool) {
        uint _percent;
        for(uint i = 0; i < count; i++ ){
            if(percents[i] < 1){
                return false;
            }
            _percent = _percent + percents[i];
        }
        if(_percent == parentPercent){
            return true;
        }
        return false;
    } 

}
//      [50,50]
//      ["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"]


*/