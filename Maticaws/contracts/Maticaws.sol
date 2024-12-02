// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Imports for NFT contract
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// Imports for Merkle airdropping
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Maticaws is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Pausable,
    Ownable
{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    string private _baseTokenURI;
    uint256 public constant MAX_SUPPLY = 6996;
    bytes32 public merkleRoot;
    uint256 public PRICE_PER_MINT = 15 ether;
    uint256 public MAX_MINT_PER_TX = 100;

    bool public round1Reset = false;
    bool public round2Reset = false;
    bool public round3Reset = false;

    bool public b1g1f = false;

    // In this contract, you can get some number of free airdrop mints by proving that
    // you are part of the merkle tree once per "round". There are three rounds, and
    // each round has the same merkle root.

    // We have an enum for the three rounds
    enum Round {
        Round1,
        Round2,
        Round3,
        NoFreeMints
    }

    // We have a mapping from the address to the mapping of the round to the number
    // of free mints they have claimed. This is so that we can keep track of how many
    // free mints they have claimed in each round.
    mapping(address => mapping(Round => uint256)) public freeMintsClaimed;

    // == INIT ==
    /// @param _merkleRoot of claimees
    constructor(bytes32 _merkleRoot) ERC721("Maticaws", "MATICAW") {
        // We're going to be behind an API until minting is done, then we'll migrate to IPFS
        _baseTokenURI = "https://api.maticaws.club/metadata/";
        merkleRoot = _merkleRoot;
    }

    // == GETTERS ==
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function getCurrentRound() public view returns (Round) {
        return getRoundFor(_tokenIdCounter.current());
    }

    //
    function getRoundFor(uint256 currentSupply) public pure returns (Round) {
        // We decide the round based on the current number of minted nfts
        if (currentSupply <= 501) {
            return Round.Round1;
        } else if (currentSupply <= 2000) {
            return Round.NoFreeMints;
        } else if (currentSupply <= 2500) {
            return Round.Round2;
        } else if (currentSupply <= 5001) {
            return Round.NoFreeMints;
        } else if (currentSupply <= 5500) {
            return Round.Round3;
        } else {
            return Round.NoFreeMints;
        }
    }

    // == FREE MINTING ==
    function freeMintNFT(
        uint256 amount,
        bytes32[] calldata merkleProof
    ) public payable {
        // Check if we're in a round where free mints are allowed
        Round currentRound = getCurrentRound();
        require(
            currentRound != Round.NoFreeMints,
            "No free mints allowed for now"
        );
        require(amount <= MAX_MINT_PER_TX, "Exceeds max mint per tx");
        require(
            _tokenIdCounter.current() + amount <= MAX_SUPPLY,
            "Exceeds max supply"
        );

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(msg.sender, amount));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "Invalid proof."
        );

        // Are we in a reset-round? This means everyone gets to free mint again.
        bool isCurrentlyReset = false;
        if (currentRound == Round.Round1) {
            isCurrentlyReset = round1Reset;
        } else if (currentRound == Round.Round2) {
            isCurrentlyReset = round2Reset;
        } else if (currentRound == Round.Round3) {
            isCurrentlyReset = round3Reset;
        }

        // They're approved, let's check if they've claimed their free mints yet.
        if (!isCurrentlyReset) {
            require(
                freeMintsClaimed[msg.sender][currentRound] == 0,
                "Already claimed free mints for this round"
            );
        }

        if (isCurrentlyReset) {
            require(
                freeMintsClaimed[msg.sender][currentRound] <= amount,
                "Already claimed free mints for this reset round"
            );
        }

        // Mark it claimed and send the token.
        freeMintsClaimed[msg.sender][currentRound] += amount;

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(msg.sender, tokenId);
        }
    }

    // == REGULAR MINTING ==
    function mintNFT(uint256 amount) public payable {
        require(amount <= MAX_MINT_PER_TX, "Exceeds max mint per tx");
        require(
            _tokenIdCounter.current() + amount <= MAX_SUPPLY,
            "Exceeds max supply"
        );
        require(msg.value >= PRICE_PER_MINT * amount, "Insufficient funds");

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(msg.sender, tokenId);
        }

        if (b1g1f) {
            require(
                amount + amount <= MAX_MINT_PER_TX,
                "Exceeds max mint per tx"
            );
            require(
                _tokenIdCounter.current() + amount <= MAX_SUPPLY,
                "Exceeds max supply"
            );
            for (uint256 i = 0; i < amount; i++) {
                uint256 tokenId = _tokenIdCounter.current();
                _tokenIdCounter.increment();
                _safeMint(msg.sender, tokenId);
            }
        }
    }

    // == ADMIN ==
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    // == SETTERS ==
    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function setPrice(uint256 price) public onlyOwner {
        PRICE_PER_MINT = price;
    }

    function setMaxMintPerTx(uint256 maxMintPerTx) public onlyOwner {
        MAX_MINT_PER_TX = maxMintPerTx;
    }

    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setPricePerMint(uint256 _pricePerMint) public onlyOwner {
        PRICE_PER_MINT = _pricePerMint;
    }

    function setb1g1f(bool _b1g1f) public onlyOwner {
        b1g1f = _b1g1f;
    }

    function setRound1Reset(bool _round1Reset) public onlyOwner {
        round1Reset = _round1Reset;
    }

    function setRound2Reset(bool _round2Reset) public onlyOwner {
        round2Reset = _round2Reset;
    }

    function setRound3Reset(bool _round3Reset) public onlyOwner {
        round3Reset = _round3Reset;
    }

    // == EMERGENCY FUNCTIONS ==
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // UNUSED: the following functions are overrides required by Solidity.

    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
