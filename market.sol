// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MarketContract {
    address public admin;
    uint256 public customerInputFee = 0.01 ether; // Default fee for customer inputs (~10 cents)
    uint256 public voteFee = 0.01 ether; // Fee for voting (~10 cents)
    uint256 public vendorSetupFee = 1 ether; // Minimum bond fee for vendor setup ($100)
    uint256 public vendorUpdateFee = 0.1 ether; // Minimum vendor profile update fee ($10)

    enum BondLevel { Basic, Intermediate, Advanced }
    enum Category { Electronics, Clothing, Food, Other }

    struct Vendor {
        string name;
        BondLevel bondLevel;
        uint256 voteRank;
        Category category;
        string productDescription;
        string productImageLink;
        string externalLinks; // For vendor/customer off-chain communications
        string pgpKey;
        bool isListed;
    }

    mapping(address => Vendor) public vendors;
    mapping(string => address[]) public categoryVendors;
    mapping(address => mapping(address => bool)) public hasVoted;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyVendor() {
        require(bytes(vendors[msg.sender].name).length > 0, "Only vendors can call this function");
        _;
    }

    event VendorRegistered(address indexed vendor, string name, BondLevel bondLevel);
    event VendorUpdated(address indexed vendor, string productDescription, string productImageLink);
    event Voted(address indexed voter, address indexed vendor, bool isUpvote);
    event VendorDeleted(address indexed vendor, string name);

    constructor() {
        admin = msg.sender;
    }

    function setCustomerInputFee(uint256 _fee) external onlyAdmin {
        customerInputFee = _fee;
    }

    function setVoteFee(uint256 _fee) external onlyAdmin {
        voteFee = _fee;
    }

    function setVendorSetupFee(uint256 _fee) external onlyAdmin {
        vendorSetupFee = _fee;
    }

    function setVendorUpdateFee(uint256 _fee) external onlyAdmin {
        vendorSetupFee = _fee;
    }

    function registerVendor(string memory _name, Category _category) external payable {
        require(msg.value >= vendorSetupFee, "Insufficient bond fee");
        require(bytes(vendors[msg.sender].name).length == 0, "Vendor already registered");

        BondLevel bondLevel = BondLevel.Basic;
        if (msg.value >= 10 ether) {
            bondLevel = BondLevel.Intermediate;
        } else if (msg.value >= 100 ether) {
            bondLevel = BondLevel.Advanced;
        }

        vendors[msg.sender] = Vendor({
            name: _name,
            bondLevel: bondLevel,
            voteRank: 0,
            category: _category,
            productDescription: "",
            productImageLink: "",
            externalLinks: "",
            pgpKey: "",
            isListed: true
        });

        categoryVendors[categoryToString(_category)].push(msg.sender);
        emit VendorRegistered(msg.sender, _name, bondLevel);
    }

    function updateVendorProfile(string memory _productDescription, string memory _productImageLink, string memory _externalLinks, string memory _pgpKey) external payable onlyVendor {
        require(msg.value >= vendorUpdateFee, "Insufficient update fee");

        Vendor storage vendor = vendors[msg.sender];
        vendor.productDescription = _productDescription;
        vendor.productImageLink = _productImageLink;
        vendor.externalLinks = _externalLinks; // For vendor/customer off-chain communications
        vendor.pgpKey = _pgpKey; 

        emit VendorUpdated(msg.sender, _productDescription, _productImageLink);
    }

    function vote(address _vendor, bool _isUpvote) external payable {
        require(msg.value >= voteFee, "Insufficient vote fee");
        require(!hasVoted[msg.sender][_vendor], "Already voted for this vendor");

        Vendor storage vendor = vendors[_vendor];
        if (_isUpvote) {
            vendor.voteRank += 1;
        } else {
            vendor.voteRank -= 1;
        }

        hasVoted[msg.sender][_vendor] = true;
        emit Voted(msg.sender, _vendor, _isUpvote);
    }

    function getVendorsByCategory(Category _category) external view returns (address[] memory) {
        return categoryVendors[categoryToString(_category)];
    }

    function categoryToString(Category _category) internal pure returns (string memory) {
        if (_category == Category.Electronics) return "Electronics";
        if (_category == Category.Clothing) return "Clothing";
        if (_category == Category.Food) return "Food";
        return "Other";
    }

    function liquidateFunds() external onlyAdmin {
        payable(admin).transfer(address(this).balance);
    }

    // New function to delete a vendor
    function deleteVendor(address _vendor) external onlyAdmin {
        require(bytes(vendors[_vendor].name).length > 0, "Vendor does not exist");

        // Get the vendor's category
        string memory category = categoryToString(vendors[_vendor].category);

        // Remove the vendor from the categoryVendors array
        address[] storage vendorsInCategory = categoryVendors[category];
        for (uint256 i = 0; i < vendorsInCategory.length; i++) {
            if (vendorsInCategory[i] == _vendor) {
                // Swap the vendor with the last element and pop
                vendorsInCategory[i] = vendorsInCategory[vendorsInCategory.length - 1];
                vendorsInCategory.pop();
                break;
            }
        }

        // Emit an event before deleting the vendor
        emit VendorDeleted(_vendor, vendors[_vendor].name);

        // Delete the vendor from the vendors mapping
        delete vendors[_vendor];
    }
}