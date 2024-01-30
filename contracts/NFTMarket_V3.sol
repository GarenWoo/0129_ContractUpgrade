//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface NFTMarket_Standard_Interface_V1 {
    function NFTPermit_PrepareForBuy(
        address,
        uint256,
        uint256,
        uint8,
        bytes32,
        bytes32
    ) external returns (bool);

    function NFTPermit_PrepareForList(
        address,
        uint256,
        uint256,
        uint256,
        uint8,
        bytes32,
        bytes32
    ) external returns (bool);
}

/**
 * @title This is a NFT exchange contract that can provide trading for ERC721 Tokens. Various ERC721 tokens are able to be traded here.
 *
 * @author Garen Woo
 */
contract NFTMarket_V3 is Initializable, IERC721Receiver {
    address private owner;
    mapping(address tokenAddress => mapping(uint tokenId => uint price))
        private price;
    mapping(address userAddress => uint balance) private balance;
    address public tokenAddr;
    mapping(address tokenAddress => mapping(uint tokenId => bool isOnSale))
        public onSale;
    event NFTListed(address NFTAddr, uint256 tokenId, uint price);
    event NFTDelisted(address NFTAddr, uint256 tokenId);
    event NFTBought(address NFTAddr, uint256 tokenId, uint bidValue);
    event NFTBoughtWithPermit(address NFTAddr, uint256 tokenId, uint bidValue);
    event WithdrawBalance(address withdrawer, uint withdrawnValue);
    error ZeroPrice();
    error NotOwnerOfNFT();
    error NotOwnerOfNFTMarket();
    error BidLessThanPrice(uint bidAmount, uint priceAmount);
    error NotOnSale();
    error WithdrawalExceedBalance(uint withdrawAmount, uint balanceAmount);
    error ERC721PermitBoughtByWrongFunction(
        string calledFunction,
        string validFunction
    );

    // constructor(address _tokenAddr) {
    //     tokenAddr = _tokenAddr;
    //     owner = msg.sender;
    // }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwnerOfNFTMarket();
        }
        _;
    }

    function init(address _tokenAddr) public initializer {
        tokenAddr = _tokenAddr;
        owner = msg.sender;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * @notice Once this function is called, the 'msg.sender' will try to buy NFT with the token transferred.
     * The NFT address and tokenId of the NFT separately come from `nftAddress` and 'tokenId', which are decoded from the `data` in the input list.
     *
     * @dev Important! If your NFT project supports the function of buying NFT with off-chain signature of messages(i.e.permit), make sure the NFT contract(s) should have realized NFTMarket_Standard_Interface_V1.
     * Without the realization of NFTMarket_Standard_Interface_V1, malevolent EOAs can directly buy NFTs without permit-checking.
     */
    function tokensReceived(
        address _recipient,
        uint _amount,
        bytes calldata _data
    ) external {
        (address nftAddress, uint256 tokenId) = _decode(_data);
        bool checkResult = _beforeUpdateNFT(
            _recipient,
            nftAddress,
            tokenId,
            _amount
        );
        bool hasNFTMarketStandardInterface = _support_NFTMarketStandardInterface(
                nftAddress
            );
        if (hasNFTMarketStandardInterface) {
            revert ERC721PermitBoughtByWrongFunction("buy", "buyWithPermit");
        }
        if (checkResult) {
            _updateNFT(_recipient, nftAddress, tokenId, _amount);
            emit NFTBought(nftAddress, tokenId, _amount);
        }
    }

    /* Once the NFT is listed:
     1. The actual owner of the NFT is the NFT exchange.
     2. The previous owner of the NFT(the EOA who lists the NFT) is the current '_tokenApprovals'(@ERC721.sol) of the NFT.
     3. The spender which needs to be approved should be set as the buyer.
     */
    function list(address _nftAddr, uint256 _tokenId, uint _price) external {
        if (msg.sender != IERC721(_nftAddr).ownerOf(_tokenId))
            revert NotOwnerOfNFT();
        if (_price == 0) revert ZeroPrice();
        require(
            onSale[_nftAddr][_tokenId] == false,
            "This NFT is already listed"
        );
        _List(_nftAddr, _tokenId, _price);
    }

    /**
     * @dev Besides `list`, this function is also used to list NFT on a NFT exchange.
     *  this function verifies off-chain signature of the message signed by the owner of the NFT.
     *  List NFT in this way can have better user experience, because valid signature will lead to automatic approval.
     */
    function listWithPermit(
        address _nftAddr,
        uint256 _tokenId,
        uint256 _price,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        if (_price == 0) revert ZeroPrice();
        require(
            onSale[_nftAddr][_tokenId] == false,
            "This NFT is already listed"
        );
        bool isPermitVerified = NFTMarket_Standard_Interface_V1(_nftAddr)
            .NFTPermit_PrepareForList(
                address(this),
                _tokenId,
                _price,
                _deadline,
                _v,
                _r,
                _s
            );
        if (isPermitVerified) {
            _List(_nftAddr, _tokenId, _price);
        }
    }

    /// @dev The seller(EOA), is the owner of the NFT when it was not listed.
    function delist(address _nftAddr, uint256 _tokenId) external {
        require(
            IERC721(_nftAddr).getApproved(_tokenId) == msg.sender,
            "Not seller or Not on sale"
        );
        if (onSale[_nftAddr][_tokenId] != true) revert NotOnSale();
        IERC721(_nftAddr).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId,
            "Delist successfully"
        );
        delete price[_nftAddr][_tokenId];
        onSale[_nftAddr][_tokenId] = false;
        emit NFTDelisted(_nftAddr, _tokenId);
    }

    /**
     * @notice Directly Buy NFT without checking ERC721 token permit.
     *
     * @dev Important! If your NFT project supports the function of buying NFT with off-chain signature of messages(i.e.permit), make sure the NFT contract(s) should have realized NFTMarket_Standard_Interface_V1.
     * Without the realization of NFTMarket_Standard_Interface_V1, malevolent EOAs can directly buy NFTs without permit-checking.
     */
    function buy(address _nftAddr, uint256 _tokenId, uint _bidValue) external {
        bool checkResult = _beforeUpdateNFT(
            msg.sender,
            _nftAddr,
            _tokenId,
            _bidValue
        );
        bool hasNFTMarketStandardInterface = _support_NFTMarketStandardInterface(
                _nftAddr
            );
        if (hasNFTMarketStandardInterface) {
            revert ERC721PermitBoughtByWrongFunction("buy", "buyWithPermit");
        }
        if (checkResult) {
            _updateNFT(msg.sender, _nftAddr, _tokenId, _bidValue);
            emit NFTBought(_nftAddr, _tokenId, _bidValue);
        }
    }

    /* 
        Buy NFT with checking the white-list membership of the msg.sender.
    */
    function buyWithPermit(
        address _nftAddr,
        uint256 _tokenId,
        uint _bidValue,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        bool checkResult = _beforeUpdateNFT(
            msg.sender,
            _nftAddr,
            _tokenId,
            _bidValue
        );
        bool isPermitVerified = NFTMarket_Standard_Interface_V1(_nftAddr)
            .NFTPermit_PrepareForBuy(
                msg.sender,
                _tokenId,
                _deadline,
                _v,
                _r,
                _s
            );
        if (checkResult && isPermitVerified) {
            _updateNFT(msg.sender, _nftAddr, _tokenId, _bidValue);
            emit NFTBoughtWithPermit(_nftAddr, _tokenId, _bidValue);
        }
    }

    function withdrawBalance(uint _value) external {
        if (_value > balance[msg.sender])
            revert WithdrawalExceedBalance(_value, balance[msg.sender]);
        bool _success = IERC20(tokenAddr).transfer(msg.sender, _value);
        require(_success, "withdrawal failed");
        balance[msg.sender] -= _value;
        emit WithdrawBalance(msg.sender, _value);
    }

    /**
     * @dev This function is used to change the owner of this contract by modifying slot.
     */
    function changeOwnerOfNFTMarket(address _newOwner) public onlyOwner {
        assembly {
            sstore(0, _newOwner)
        }
    }

    /**
     * @dev This function is used to get the owner of this contract by modifying slot.
     */
    function getOwnerOfNFTMarket() public view returns (address ownerAddress) {
        assembly {
            ownerAddress := sload(0)
        }
    }

    function checkIfApprovedByNFT(
        address _nftAddr,
        uint256 _tokenId
    ) public view returns (bool) {
        bool isApproved = false;
        if (IERC721(_nftAddr).getApproved(_tokenId) == address(this)) {
            isApproved = true;
        }
        return isApproved;
    }

    function _support_NFTMarketStandardInterface(
        address _nftAddr
    ) internal view returns (bool) {
        bytes4 NFTMarket_Standard_Interface_V1_Id = type(
            NFTMarket_Standard_Interface_V1
        ).interfaceId;
        IERC165 NFTContract = IERC165(_nftAddr);
        return
            NFTContract.supportsInterface(NFTMarket_Standard_Interface_V1_Id);
    }

    function _List(address _nftAddr, uint256 _tokenId, uint _price) internal {
        IERC721(_nftAddr).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            "List successfully"
        );
        IERC721(_nftAddr).approve(msg.sender, _tokenId);
        price[_nftAddr][_tokenId] = _price;
        onSale[_nftAddr][_tokenId] = true;
        emit NFTListed(_nftAddr, _tokenId, _price);
    }

    function _beforeUpdateNFT(
        address _recipient,
        address _nftAddr,
        uint256 _tokenId,
        uint _tokenAmount
    ) internal returns (bool) {
        if (onSale[_nftAddr][_tokenId] != true) {
            revert NotOnSale();
        }
        if (_tokenAmount < price[_nftAddr][_tokenId]) {
            revert BidLessThanPrice(_tokenAmount, price[_nftAddr][_tokenId]);
        }
        require(
            // When NFT listed, the previous owner(EOA, the seller) should be approved. So, this EOA can delist NFT whenever he/she wants.
            // After NFT is listed successfully, getApproved() will return the orginal owner of the listed NFT.
            _recipient != IERC721(_nftAddr).getApproved(_tokenId),
            "Owner cannot buy!"
        );
        return true;
    }

    function _updateNFT(
        address _recipient,
        address _nftAddr,
        uint256 _tokenId,
        uint _tokenAmount
    ) internal {
        balance[IERC721(_nftAddr).getApproved(_tokenId)] += _tokenAmount;
        bool _success = IERC20(tokenAddr).transferFrom(
            _recipient,
            address(this),
            _tokenAmount
        );
        require(_success, "Fail to buy or Allowance is insufficient");
        IERC721(_nftAddr).transferFrom(address(this), _recipient, _tokenId);
        delete price[_nftAddr][_tokenId];
        onSale[_nftAddr][_tokenId] = false;
    }

    function _decode(
        bytes calldata _data
    ) public pure returns (address, uint256) {
        (address NFTAddress, uint256 rawTokenId) = abi.decode(
            _data,
            (address, uint256)
        );
        return (NFTAddress, rawTokenId);
    }

    function getNFTPrice(
        address _nftAddr,
        uint _tokenId
    ) external view returns (uint) {
        return price[_nftAddr][_tokenId];
    }

    function getBalance() external view returns (uint) {
        return balance[msg.sender];
    }

    function getNFTOwner(
        address _nftAddr,
        uint _tokenId
    ) external view returns (address) {
        return IERC721(_nftAddr).ownerOf(_tokenId);
    }
}
