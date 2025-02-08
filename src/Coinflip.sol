// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DirectFundingConsumer} from "./DirectFundingConsumer.sol";

interface LinkTokenInterface {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

/**
 * Coinflip contract that integrates with the Chainlink VRF system using DirectFundingConsumer
 */
contract Coinflip is Ownable {
    // A map of the player and their corresponding requestId
    mapping(address => uint256) public playerRequestID;
    // A map that stores the player's 3 Coinflip guesses
    mapping(address => uint8[3]) public bets;
    // An instance of the random number requestor (VRF)
    DirectFundingConsumer private vrfRequestor;

    /// @dev Constructor to initialize the Coinflip contract and set the owner
    constructor() Ownable(msg.sender) {
        vrfRequestor = new DirectFundingConsumer(); // Deploys a new VRF requestor automatically
    }
    
    
    /// @notice Fund the VRF instance with **5** LINK tokens.
    /// @return boolean indicating whether the funding was successful
    function fundOracle() external returns (bool) {
        // Ensure the vrfRequestor is set and not zero
        require(address(vrfRequestor) != address(0), "VRF Requestor address is not set");
    
        address Link_addr = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
        uint256 amount = 5 * 10**18; // 5 LINK tokens (18 decimals)
    
        LinkTokenInterface link = LinkTokenInterface(Link_addr);

        // Require sufficient balance
        require(link.balanceOf(address(this)) >= amount, "Insufficient LINK balance");
    
        // Transfer LINK from this contract to the VRF contract
        require(link.transfer(address(vrfRequestor), amount), "LINK transfer failed");
    
        return true;
    }
    

    /// @notice User guesses THREE flips, either a 1 or a 0.
    /// @param Guesses 3 guesses - which is "required" to be 1 or 0
    /// @dev After validating the user input, store the user input and request ID in their respective global mappings and call the "requestRandomWords" function in VRF instance
    function userInput(uint8[3] calldata Guesses) external {
        // Validate that each guess is either 0 or 1
        for (uint8 i = 0; i < 3; i++) {
            require(Guesses[i] == 0 || Guesses[i] == 1, "Invalid guess: Must be 0 or 1");
        }
        // Store user input
        bets[msg.sender] = Guesses;
        
        // Request 3 random numbers from the VRF contract
        uint256 requestId = vrfRequestor.requestRandomWords(false); // false = pay in LINK (you can modify to true if you want native payments)
    
        // Store request ID
        playerRequestID[msg.sender] = requestId;
        
    }

    /// @notice Check the status of the randomness request
    /// @return boolean indicating if the request is fulfilled
    function checkStatus() external view returns (bool) {
        uint256 requestId = playerRequestID[msg.sender];
        require(requestId != 0, "No request found");
        
        // Ensure the VRF request has been fulfilled
        (, bool fulfilled, ) = vrfRequestor.getRequestStatus(requestId);
        require(fulfilled, "Randomness not fulfilled yet");

        return fulfilled;
    }

    /// @notice Determine if the user wins based on their guesses and the random flips.
    /// @return boolean indicating whether the user won or not
    function determineFlip() external view returns(bool) {
        uint256 requestId = playerRequestID[msg.sender];
        require(requestId != 0, "No request found");

        // Ensure randomWords array is not empty
        (, bool fulfilled, uint256[] memory randomWords) = vrfRequestor.getRequestStatus(requestId);
        require(fulfilled, "Randomness not fulfilled yet");
        require(randomWords.length > 0, "No random words received");
        
        // Process the first random number
        uint8 randomFlip = uint8(randomWords[0] % 2);
    
        // Compare the user's guesses
        return bets[msg.sender][0] == randomFlip;
    }
}
