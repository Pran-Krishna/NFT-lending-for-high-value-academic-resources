// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interface for ERC721 (NFT)
interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function balanceOf(address owner) external view returns (uint256);
}

// Contract for lending and borrowing NFTs (academic resources)
contract NFTLending {

    address public admin;
    IERC721 public nftContract;
    
    struct LendingDetails {
        address borrower;
        uint256 tokenId;
        uint256 lendingStart;
        uint256 lendingEnd;
        bool isActive;
    }

    mapping(uint256 => LendingDetails) public lendings;

    event NFTLended(address indexed lender, address indexed borrower, uint256 indexed tokenId, uint256 lendingEnd);
    event NFTReturned(address indexed borrower, uint256 indexed tokenId, uint256 returnTime);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyOwner(uint256 tokenId) {
        require(nftContract.ownerOf(tokenId) == msg.sender, "Only the owner can perform this action");
        _;
    }

    modifier isLendingActive(uint256 tokenId) {
        require(lendings[tokenId].isActive, "This NFT is not currently lent out");
        _;
    }

    modifier isNotLentOut(uint256 tokenId) {
        require(!lendings[tokenId].isActive, "This NFT is already lent out");
        _;
    }

    constructor(address _nftContractAddress) {
        admin = msg.sender;
        nftContract = IERC721(_nftContractAddress);
    }

    // Lend an NFT to a borrower for a specific time
    function lendNFT(uint256 tokenId, address borrower, uint256 lendingDuration) external onlyOwner(tokenId) isNotLentOut(tokenId) {
        require(borrower != msg.sender, "Lender cannot be the borrower");
        require(lendingDuration > 0, "Lending duration must be greater than zero");
        
        nftContract.safeTransferFrom(msg.sender, address(this), tokenId);
        
        LendingDetails memory lending = LendingDetails({
            borrower: borrower,
            tokenId: tokenId,
            lendingStart: block.timestamp,
            lendingEnd: block.timestamp + lendingDuration,
            isActive: true
        });

        lendings[tokenId] = lending;

        emit NFTLended(msg.sender, borrower, tokenId, lending.lendingEnd);
    }

    // Return a lent NFT
    function returnNFT(uint256 tokenId) external isLendingActive(tokenId) {
        LendingDetails storage lending = lendings[tokenId];
        
        require(lending.borrower == msg.sender, "Only the borrower can return the NFT");
        require(block.timestamp >= lending.lendingEnd, "Lending period has not ended yet");
        
        nftContract.safeTransferFrom(address(this), lending.borrower, tokenId);
        
        lending.isActive = false;

        emit NFTReturned(msg.sender, tokenId, block.timestamp);
    }

    // Admin can retrieve NFT if borrower does not return on time
    function retrieveNFT(uint256 tokenId) external onlyAdmin isLendingActive(tokenId) {
        LendingDetails storage lending = lendings[tokenId];
        
        require(block.timestamp >= lending.lendingEnd, "Lending period has not ended yet");
        
        nftContract.safeTransferFrom(address(this), lending.borrower, tokenId);
        
        lending.isActive = false;

        emit NFTReturned(lending.borrower, tokenId, block.timestamp);
    }

    // Get the current lending details for an NFT
    function getLendingDetails(uint256 tokenId) external view returns (address borrower, uint256 lendingStart, uint256 lendingEnd, bool isActive) {
        LendingDetails memory lending = lendings[tokenId];
        return (lending.borrower, lending.lendingStart, lending.lendingEnd, lending.isActive);
    }
}
