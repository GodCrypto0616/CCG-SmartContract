// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CryptoChampion is ERC721URIStorage, Ownable {
    using Strings for uint256;

    address payable private _PaymentAddress = payable(0xc3a9e945DC81820e2B5173EbdfD2346bFC125DE4);
    struct Item{
        uint256 supply;
        uint256 order_cnt;
        uint256 order_id;
        string base_uri;
    }//MILITARY, WESTERN, CYBRPNK, UNDEAD, FANTASY

    uint256 public currentID = 0;
    mapping (uint256 => Item) public Items;
    mapping (uint256 => string) public tokenIds;
    uint256 public PUBLIC_PRICE = 0.001 ether; // 1000000000000000
    uint256 public Item_Count = 0;
    bool public ENABLE_REVEAL = false;
    string private UNREVEAL_URI;

    constructor() ERC721("Crypto Champion", "CCG") {}

    function setPaymentAddress(address paymentAddress) external onlyOwner {
        _PaymentAddress = payable(paymentAddress);
    }

    function setMintPrice(uint256 publicPrice) external onlyOwner {
        PUBLIC_PRICE = publicPrice;
    }

    function setUnrevealURI(string memory unrevealURI) external onlyOwner {
        UNREVEAL_URI = unrevealURI;
    }

    function setTokenURI(uint256 _tokenId, string memory tokenUri) external onlyOwner {
        require(_exists(_tokenId), "Token does not exist");
        tokenIds[_tokenId] = tokenUri;
        _setTokenURI(_tokenId, tokenUri);
    }

    function setBaseInfo(string[] memory baseURI, uint256[] memory supply, bool isEnable) external onlyOwner {
        Item_Count = supply.length;
        for (uint i = 0 ; i < supply.length ; i++){
            Items[i].supply = supply[i];
            Items[i].base_uri = baseURI[i];
            if (i == 0) Items[i].order_cnt = supply[0];
            else Items[i].order_cnt = Items[i - 1].order_cnt + supply[i];
            Items[i].order_id = 0;
        }
        currentID = 0;
        ENABLE_REVEAL = isEnable;
    }

    function airdrop(address[] memory airdropAddress, uint256 numberOfTokens) external onlyOwner {
        require(Items[currentID].order_id + numberOfTokens <= Items[currentID].supply,"Purchase would exceed");
        for (uint256 k = 0; k < airdropAddress.length; k++) {
            _mintTo(airdropAddress[k], numberOfTokens);
        }
    }

    function mint(uint256 numberOfTokens) external payable {
        require(Items[currentID].order_id + numberOfTokens <= Items[currentID].supply ,"Purchase would exceed");

        require(PUBLIC_PRICE * numberOfTokens <= msg.value,"ETH amount is not sufficient");

        _PaymentAddress.transfer(msg.value);

        _mintTo(_msgSender(), numberOfTokens);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        if (ENABLE_REVEAL){
            if (bytes(tokenIds[tokenId]).length != 0)return tokenIds[tokenId];
            for (uint256 k = 0; k < Item_Count; k++) {
                if (tokenId < Items[k].order_cnt){
                    uint256 del = k == 0 ? 0 : Items[k - 1].order_cnt;
                    return string(abi.encodePacked(Items[k].base_uri, (tokenId - del).toString()));
                }
            }            
        }
        return UNREVEAL_URI;
        
    }

    function getTokenId() external view returns (uint256) {
        return Items[currentID].order_id;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;

        payable(msg.sender).transfer(balance);
    }

    function _mintTo(address toAddress, uint256 numberOfTokens) internal {
        for (uint256 i = 0; i < numberOfTokens; i++) {
            uint256 tokenId = Items[currentID].order_id + (currentID == 0 ? 0 : Items[currentID - 1].order_cnt);
            if (tokenId >= Items[currentID].order_cnt - 1)currentID++;
            else Items[currentID].order_id++;
            if (!_exists(tokenId)) _safeMint(toAddress, tokenId);
        }
    }

    function withdrawToken(address toAddress, uint256 amount, address tokenAddress) external onlyOwner returns(bool isTransferred) {
        IERC20 token = IERC20(tokenAddress);
		isTransferred = token.transferFrom(msg.sender, toAddress, amount);
    }
}
