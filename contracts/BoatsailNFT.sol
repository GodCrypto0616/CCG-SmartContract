// NFT token
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BoatsailNFT is ERC721 {
    using SafeMath for uint256;

    uint256 constant public PERCENTS_DIVIDER = 1000;
	uint256 constant public FEE_MAX_PERCENT = 200; // 20 % : 200
    uint256 constant public FEE_MIN_PERCENT = 0; // 5 % : 50
    uint256 public FEE_MINT = 0; // 2000000000000000; // 0.002 BNB
    address public adminAddress;

    bool public isPublic;
    address public factory;
    address public owner;

    struct Item {
        uint256 id;
        address creator; 
        string uri;  // MetaData
        uint256 royalty; //Fee      
    }
    uint256 public currentID;    
    mapping (uint256 => Item) public Items;

    event TokenUriUpdated(uint256 id, string uri);
    event ItemCreated(uint256 id, address creator, string uri, uint256 royalty);

    constructor() ERC721("Boatsail NFT","BSN") {    
        factory = msg.sender;
    }

    /**
		Initialize from Swap contract
	 */
    function initialize(
        address creator,
        address _adminAddress,
        bool bPublic
    ) external {
        require(msg.sender == factory, "Only for factory");
        owner = creator;
        adminAddress = _adminAddress;
        isPublic = bPublic;
    }

    function setAdminAddress(address _adminAddress) public {
        require(msg.sender == adminAddress, "Admin can only change adminAddress");
        adminAddress = _adminAddress;
    }

    function setFeeMint(uint256 fee_mint_price) public onlyOwner{
        FEE_MINT = fee_mint_price;
    }

    function mintTo(string memory _tokenURI, uint256 royalty) external payable returns (uint256){        
        require(royalty <= FEE_MAX_PERCENT, "too big royalties");
        require(royalty >= FEE_MIN_PERCENT, "too small royalties");
        if (FEE_MINT > 0)payable(adminAddress).transfer(FEE_MINT);
        currentID = currentID.add(1);        
        _safeMint(msg.sender, currentID);
        Items[currentID] = Item(currentID, msg.sender, _tokenURI, royalty);       
        emit ItemCreated(currentID, msg.sender, _tokenURI, royalty); 
        return currentID;
    }

    function setTokenURI(uint256 _tokenId, string memory _newURI)
        public
        creatorOnly(_tokenId)
    {
        Items[_tokenId].uri = _newURI;
        emit TokenUriUpdated( _tokenId, _newURI);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return Items[tokenId].uri;
    }    

    function creatorOf(uint256 _tokenId) external view returns (address) {
        return Items[_tokenId].creator;
    }

    function royalties(uint256 _tokenId) public view returns (uint256) {
        return Items[_tokenId].royalty;
	}

    modifier onlyOwner() {
        require(owner == _msgSender(), "caller is not the owner");
        _;
    }
    /**
     * @dev Require _msgSender() to be the creator of the token id
     */
    modifier creatorOnly(uint256 _id) {
        require(
            Items[_id].creator == _msgSender(),
            "ERC721Tradable#creatorOnly: ONLY_CREATOR_ALLOWED"
        );
        _;
    }
}
