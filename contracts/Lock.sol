// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// Ticket (coin) mint/buy function
// Limit to amount of coins to mint
// Balance function

// Function for date - use for burning
// reselling/staking function
// Ticket verification for resold tickets

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

    contract Ticket is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private tokenIdCounter;

    struct TicketInfo {
        uint256 tokenId;
        uint256 totalTickets;
        uint256 ticketsSold;
        uint256 ticketPrice;
        uint256 ticketStartDate;
        uint256 ticketEndDate;
        uint256 ticketHoldDate;
        address creator;
        bool ticketSold;
        bool isResellable;
    }

    struct PurchaseInfo { // important for reselling
        uint256 ticketsBought;
        uint256 ticketsToResell;
        uint256 totalPrice;
        uint256 ticketId;
        uint256 purchaseId;
        uint256 purchaseTimestamp;
        address buyer;
    }

    uint256 public creationFeePercentage;  // Fee percentage for creating a ticket
    uint256 public purchaseFeePercentage;  // Fee percentage for purchasing a ticket
    uint256 public resellingFeePercentage; // Fee percentage for reselling a ticket

    mapping(uint256 => TicketInfo) public tickets;
    mapping(address => uint256[]) public userTickets;
    mapping(uint256 => PurchaseInfo[]) public ticketPurchases;  // Mapping to store purchase information for each ticket

    
    event TicketCreated(
        uint256 indexed tokenId,
        uint256 totalTickets,
        uint256 ticketPrice,
        uint256 ticketStartDate,
        uint256 ticketEndDate
    );

    event TicketPurchased(
        uint256 indexed tokenId,
        address buyer,
        uint256 ticketsBought
    );

    event TicketResell(
        uint256 indexed tokenId,
        address reseller,
        uint256 ticketsBought
    );

    event TicketResold(
        uint256 indexed tokenId,
        address reseller,
        address rebuyer,
        uint256 ticketsBought
    );

    constructor(uint256 _creationFeePercentage, uint256 _purchaseFeePercentage, uint256 _resellingFeePercentage) ERC721("Ticket", "TICKET") {
        creationFeePercentage = _creationFeePercentage;
        purchaseFeePercentage = _purchaseFeePercentage;
        resellingFeePercentage = _resellingFeePercentage;
    }

    function createTicket( 
        string calldata tokenURI,
        uint256 _totalTickets,
        uint256 _ticketPrice,
        uint256 _ticketEndDate
    ) external payable {
        require(_totalTickets > 0, "Total tickets must be greater than 0");
        require(_ticketPrice > 0, "Ticket price must be greater than 0");
        require(_ticketEndDate > block.timestamp, "Ticket end date must be in the future");

        uint256 currentID = tokenIdCounter.current();
        tokenIdCounter.increment();

        _safeMint(msg.sender, currentID);
        _setTokenURI(currentID, tokenURI);

        uint256 ticketStartDate = block.timestamp;

        tickets[currentID] = TicketInfo({
            tokenId: currentID,
            totalTickets: _totalTickets,
            ticketsSold: 0,
            ticketPrice: _ticketPrice,
            ticketStartDate: ticketStartDate,
            ticketHoldDate: 0,
            ticketEndDate: _ticketEndDate,
            creator: msg.sender,
            ticketSold: false,
            isResellable: false
        });

        // Calculate creation fee and transfer to contract owner
        uint256 creationFee = creationFeePercentage;
        require(msg.value == creationFee, "Incorrect creation fee sent");

        // Transfer the creation fee to the contract owner
        payable(owner()).transfer(creationFee);

        emit TicketCreated(currentID, _totalTickets, _ticketPrice, ticketStartDate, _ticketEndDate);
    }

    function purchaseTicket(uint256 tokenID, uint256 ticketsToBuy) external payable {
        TicketInfo storage ticket = tickets[tokenID];
        require(!ticket.ticketSold, "Ticket has already been sold");
        require(ticketsToBuy < 3);
        require(ticketsToBuy > 0 && ticketsToBuy <= ticket.totalTickets - ticket.ticketsSold, "Invalid number of tickets");

        uint256 totalPrice = ticket.ticketPrice * ticketsToBuy;
        uint256 purchaseFee = purchaseFeePercentage;
        uint256 totalPriceWithFee = totalPrice + purchaseFee;

        require(msg.value == totalPriceWithFee, "Incorrect amount sent");

        // Transfer the ticket price directly to the ticket creator
        payable(ticket.creator).transfer(totalPrice);

        // Transfer the purchase fee to the contract owner
        payable(owner()).transfer(purchaseFee);

        // Mint tickets and record purchases
        for (uint256 i = 0; i < ticketsToBuy; i++) {
            uint256 newTokenId = tokenIdCounter.current();
            tokenIdCounter.increment();
            _safeMint(msg.sender, newTokenId);
            _setTokenURI(newTokenId, tokenURI(tokenID));

            // Store the purchased ticket for the user
            userTickets[msg.sender].push(newTokenId);

            // Store the purchase information for the ticket
            ticketPurchases[newTokenId].push(PurchaseInfo({
                buyer: msg.sender,
                ticketsBought: 1,
                ticketsToResell: 1,
                totalPrice: ticket.ticketPrice,
                ticketId:tokenID,
                purchaseId:newTokenId,
                purchaseTimestamp: block.timestamp
            }));

            ticket.ticketsSold++;

            emit TicketPurchased(newTokenId, msg.sender, ticketsToBuy);
        }

        // Mark the ticket as sold when all tickets are sold
        if (ticket.ticketsSold == ticket.totalTickets) {
            ticket.ticketSold = true;
        }
    }

    
    function resellTicket(uint256 tokenId, uint256 ticketsToSell) external {
    TicketInfo storage ticket = tickets[tokenId];
    require(ticketsToSell > 0, "Invalid number of tickets");
    require(ticketsToSell <= ticket.ticketsSold, "Not enough tickets sold");
    require(ticket.ticketHoldDate >= ticket.ticketEndDate, "Ticket cannot be resold yet");

    uint256 ownedTickets = 0;
    uint256 resoldTickets = 0;
    for (uint256 i = 0; i < ticketPurchases[tokenId].length; i++) {
        if (ticketPurchases[tokenId][i].buyer == msg.sender) {
            ownedTickets += ticketPurchases[tokenId][i].ticketsBought;
            resoldTickets += ticketPurchases[tokenId][i].ticketsToResell;
        }
    }
    require(ownedTickets >= ticketsToSell, "Not enough tickets owned");
    require(resoldTickets + ticketsToSell <= ownedTickets, "Cannot resell more tickets than owned");

    // Update the ticketsToResell field for each struct that matches the buyer address
    for (uint256 i = 0; i < ticketPurchases[tokenId].length; i++) {
        if (ticketPurchases[tokenId][i].buyer == msg.sender) {
            ticketPurchases[tokenId][i].ticketsToResell += ticketsToSell;
            break;
        }
    }

    emit TicketResell(tokenId, msg.sender, ticketsToSell);
}

    function reBuyTicket(uint256 tokenId, uint256 buyticketId) external payable {
    require(tickets[tokenId].ticketsSold >= 1, "Not enough tickets available for resale");

    // Transfer the ticket price to the original buyer
    uint256 ticketPrice = tickets[tokenId].ticketPrice + (tickets[tokenId].ticketPrice * resellingFeePercentage);
    payable(msg.sender).transfer(ticketPrice);

    // Transfer the ticket to the new buyer
    for(uint256 i = 0; i < ticketPurchases[tokenId].length; i++) {
        if (ticketPurchases[tokenId][i].ticketId == buyticketId) {
            _transfer(ticketPurchases[tokenId][i].buyer, msg.sender, buyticketId);
             emit TicketResold(tokenId, ticketPurchases[tokenId][i].buyer, msg.sender, buyticketId);
            break;
        }
    }
}

    function getUserTickets(address user) external view returns (uint256[] memory) {
        return userTickets[user];
    }

    function getTicketInfo(uint256 tokenID) external view returns (TicketInfo memory) {
        return tickets[tokenID];
    }

    function getPurchaseInfo(uint256 tokenID) external view returns (PurchaseInfo[] memory) {
        return ticketPurchases[tokenID];
    }

    function updateCreationFeePercentage(uint256 _creationFeePercentage) external onlyOwner {
        creationFeePercentage = _creationFeePercentage;
    }

    function updatePurchaseFeePercentage(uint256 _purchaseFeePercentage) external onlyOwner {
        purchaseFeePercentage = _purchaseFeePercentage;
    }

    function getCreationFeePercentage() external view returns (uint256) {
        return creationFeePercentage;
    }

    function getPurchaseFeePercentage() external view returns (uint256) {
        return purchaseFeePercentage;
    }
    
    }                                                                                                                                                                                                                                                                                                                                                         