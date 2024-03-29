// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error RandomIpfsNft__RangeOutOfBounds();
error RandomIpfsNft__NeedMoreEthSent();
error RandomIpfsNft__TransferFailed();
error RandomIpfsNft__AlreadyInitialized();

contract RandomIpfsNft is VRFConsumerBaseV2, ERC721URIStorage, Ownable {
    //When we mint an NFt, we will trigger a Chainlink VRF call to get a random number
    //Using that number, we will get a random NFF
    //Pug, Shiba Inu, St Bernard
    //Pug super Rare.
    //Shiba sort of rare
    //St. Bernard common
    //User have to pay to mint an NFT
    // the owner of the contract can withdraw the ETH

    // State varaibles
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gaslane;
    uint64 private immutable i_subcriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_minFee;

    //VRF helpers
    mapping(uint256 => address) public s_requestIdToSender;

    // Type Declaration
    enum Breed {
        PUG,
        SHIBA_INU,
        ST_BERNARD
    }

    // NFT variables
    uint256 public s_tokenCounter;
    uint256 internal constant MAX_CHANCE_VALUE = 100;
    string[] internal s_dogTokenURIs;
    bool private s_initialized;

    // Events
    event NftRequested(uint256 indexed requestId, address requester);
    event NftMinted(Breed dogBreed, address minter);

    constructor(
        address vrfCoordiantorV2,
        uint64 subcriptionId,
        bytes32 gaslane,
        uint32 callbackGasLimit,
        string[3] memory dogTokenURIs,
        uint256 mintFee
    ) VRFConsumerBaseV2(vrfCoordiantorV2) ERC721("Random IPFS NFT", "RIN") {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordiantorV2);
        i_gaslane = gaslane;
        i_subcriptionId = subcriptionId;
        i_callbackGasLimit = callbackGasLimit;
        _initializeContract(dogTokenURIs);
        s_tokenCounter = 0;
        i_minFee = mintFee;
    }

    function requestNft() public payable returns (uint256 requestId) {
        if (msg.value < i_minFee) {
            revert RandomIpfsNft__NeedMoreEthSent();
        }
        requestId = i_vrfCoordinator.requestRandomWords(
            i_gaslane,
            i_subcriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        s_requestIdToSender[requestId] = msg.sender; //The requester is the owner, not the vrf node

        emit NftRequested(requestId, msg.sender);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        address dogOwner = s_requestIdToSender[requestId];
        uint256 newTokenId = s_tokenCounter;

        //What does this token looks like?
        uint256 moddedRng = randomWords[0] % MAX_CHANCE_VALUE;
        //0 - 99
        // 0 - 10 => PUG
        // 10 - 30 => St. Bernard
        // 30 - 99 => Shiba
        Breed dogBreed = getBreedFromModdedRng(moddedRng);
        s_tokenCounter += 1;
        _safeMint(dogOwner, newTokenId);
        _setTokenURI(newTokenId, s_dogTokenURIs[uint256(dogBreed)]);

        emit NftMinted(dogBreed, dogOwner);
    }

    function getChanceArray() public pure returns (uint256[3] memory) {
        return [10, 30, MAX_CHANCE_VALUE];
    }

    function _initializeContract(string[3] memory dogTokenUris) private {
        if (s_initialized) {
            revert RandomIpfsNft__AlreadyInitialized();
        }
        s_dogTokenURIs = dogTokenUris;
        s_initialized = true;
    }

    function getBreedFromModdedRng(uint256 moddedRng) public pure returns (Breed) {
        uint256 cumulativeSum = 0;
        uint256[3] memory chanceArray = getChanceArray();
        for (uint256 i = 0; i < chanceArray.length; i++) {
            if (moddedRng >= cumulativeSum && moddedRng < chanceArray[i]) {
                return Breed(i);
            }
            cumulativeSum = chanceArray[i];
        }
        revert RandomIpfsNft__RangeOutOfBounds();
    }

    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert RandomIpfsNft__TransferFailed();
        }
    }

    function getMintFee() public view returns (uint256) {
        return i_minFee;
    }

    function getTokenUris(uint256 index) public view returns (string memory) {
        return s_dogTokenURIs[index];
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }

    function getInitialized() public view returns (bool) {
        return s_initialized;
    }
}
