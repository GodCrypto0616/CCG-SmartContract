// Market contract
// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./BoatsailNFT.sol";

interface IBoatsailNFT {
	function initialize(address creator, address _adminAddress, bool bPublic) external;	
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function creatorOf(uint256 _tokenId) external view returns (address);
	function royalties(uint256 _tokenId) external view returns (uint256);	
}

contract BoatsailMarket is Ownable, ERC721Holder {
    using SafeMath for uint256;

	uint256 constant public PERCENTS_DIVIDER = 1000;

	uint256 public feeAdmin = 0;	
	address public adminAddress; 	

    /* Pairs to swap NFT _id => price */
	struct Pair {
		uint256 pair_id;
		address collection;
		uint256 token_id;
		address owner;
		address creator;
		address tokenAdr;
		uint256 creatorFee;
		uint256 price;
        bool bValid;		
	}

	address[] public collections;
	// collection address => creator address

	// token id => Pair mapping
    mapping(uint256 => Pair) public pairs;
	uint256 public currentPairId;

	uint256 public totalEarning; /* Total BoatSail Token */
	uint256 public totalSwapped; /* Total swap count */
    
	/** Events */
    event CollectionCreated(address collection_address, address owner, bool isPublic);
    event ItemListed(uint256 id, address collection, uint256 token_id, address tokenAdr, uint256 price, address creator, address owner, uint256 creatorFee);
	event ItemDelisted(uint256 id);
	event Swapped(address buyer, Pair pair);

	constructor (address collAddr) {	
		emit CollectionCreated(collAddr, msg.sender, true);
	}  

	function initialize(address _adminAddress) external onlyOwner {
		adminAddress = _adminAddress;
		
	}   

	function setFee(uint256 _feeAdmin, address _adminAddress) external onlyOwner {		
        feeAdmin = _feeAdmin;
		adminAddress = _adminAddress;		
    }

	function createCollection(bool bPublic) public returns(address collection) {
		bytes memory bytecode = type(BoatsailNFT).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp));
        assembly {
            collection := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IBoatsailNFT(collection).initialize(msg.sender, adminAddress, bPublic);
		collections.push(collection);
		
		emit CollectionCreated(collection, msg.sender, bPublic);
	}
    function list(address _collection, uint256 _token_id, address _tokenAdr, uint256 _price) OnlyItemOwner(_collection,_token_id) external {
		require(_price > 0, "invalid price");		

		IBoatsailNFT nft = IBoatsailNFT(_collection);        
        nft.safeTransferFrom(msg.sender, address(this), _token_id);

		currentPairId = currentPairId.add(1);

		pairs[currentPairId].pair_id = currentPairId;
		pairs[currentPairId].collection = _collection;
		pairs[currentPairId].token_id = _token_id;
		pairs[currentPairId].owner = msg.sender;
		pairs[currentPairId].creator = nft.creatorOf(_token_id);	
		pairs[currentPairId].creatorFee = nft.royalties(_token_id);	
		pairs[currentPairId].price = _price;	
		pairs[currentPairId].tokenAdr = _tokenAdr;
        pairs[currentPairId].bValid = true;	

        emit ItemListed(currentPairId, 
			_collection,
			_token_id, 
			_tokenAdr,
			_price, 
			pairs[currentPairId].creator,
			msg.sender,
			pairs[currentPairId].creatorFee
		);
    }

    function delist(uint256 _id) external {        
        require(pairs[_id].bValid, "not exist");
        require(msg.sender == pairs[_id].owner || msg.sender == owner(), "Error, you are not the owner");        
        IBoatsailNFT(pairs[_id].collection).safeTransferFrom(address(this), pairs[_id].owner, pairs[_id].token_id);        
        pairs[_id].bValid = false;
        emit ItemDelisted(_id);        
    }


    function buy(uint256 _id) external payable {
		require(_id <= currentPairId && pairs[_id].pair_id == _id, "Could not find item");
        require(pairs[_id].bValid, "invalid Pair id");
		require(pairs[_id].owner != msg.sender, "owner can not buy");

		Pair memory pair = pairs[_id];
		uint256 totalAmount = pair.price;
		uint256 ownerPercent = PERCENTS_DIVIDER.sub(feeAdmin);

		if (pairs[_id].tokenAdr == address(0x0)) { //BNB
            require(msg.value >= totalAmount, "insufficient balance");
			// transfer coin to feeAdmin
			if (feeAdmin > 0){
				payable(adminAddress).transfer(totalAmount.mul(feeAdmin).div(PERCENTS_DIVIDER));
			}
			// transfer coin to owner			
			payable(pair.owner).transfer(totalAmount.mul(ownerPercent).div(PERCENTS_DIVIDER));
        } else {
            IERC20 governanceToken = IERC20(pairs[_id].tokenAdr);
			//require(governanceToken.transferFrom(msg.sender, address(this), totalAmount), "insufficient token balance");
			// transfer governance token to feeAdmin
			if (feeAdmin > 0)governanceToken.transferFrom(msg.sender, adminAddress, totalAmount.mul(feeAdmin).div(PERCENTS_DIVIDER));			
			// transfer governance token to owner
			governanceToken.transferFrom(msg.sender, pair.owner, totalAmount.mul(ownerPercent).div(PERCENTS_DIVIDER));
        }
		
		// transfer NFT token to buyer
		IBoatsailNFT(pairs[_id].collection).safeTransferFrom(address(this), msg.sender, pair.token_id);
		
		pairs[_id].bValid = false;

		totalEarning = totalEarning.add(totalAmount);
		totalSwapped = totalSwapped.add(1);

        emit Swapped(msg.sender, pair);		
    }

	function withdrawCoin() public onlyOwner {
		uint balance = address(this).balance;
		require(balance > 0, "insufficient balance");
		payable(msg.sender).transfer(balance);
	}
	function withdrawToken(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
		uint balance = token.balanceOf(address(this));
		require(balance > 0, "insufficient balance");
		require(token.transfer(msg.sender, balance));			
	}

	modifier OnlyItemOwner(address tokenAddress, uint256 tokenId){
        IERC721 tokenContract = IERC721(tokenAddress);
        require(tokenContract.ownerOf(tokenId) == msg.sender);
        _;
    }    
}
