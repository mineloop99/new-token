// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./lib.sol";

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this;
        return msg.data;
    }
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

abstract contract ERC165 is IERC165 {
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId;
    }
}

interface IAccessControl {
    function hasRole(bytes32 role, address account)
        external
        view
        returns (bool);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function renounceRole(bytes32 role, address account) external;
}

abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }
    mapping(bytes32 => RoleData) private _roles;
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    event RoleAdminChanged(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed newAdminRole
    );
    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IAccessControl).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function hasRole(bytes32 role, address account)
        public
        view
        override
        returns (bool)
    {
        return _roles[role].members[account];
    }

    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
        return _roles[role].adminRole;
    }

    function grantRole(bytes32 role, address account) public virtual override {
        require(
            hasRole(getRoleAdmin(role), _msgSender()),
            "AccessControl: sender must be an admin to grant"
        );
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public virtual override {
        require(
            hasRole(getRoleAdmin(role), _msgSender()),
            "AccessControl: sender must be an admin to revoke"
        );
        _revokeRole(role, account);
    }

    function renounceRole(bytes32 role, address account)
        public
        virtual
        override
    {
        require(
            account == _msgSender(),
            "AccessControl: can only renounce roles for self"
        );
        _revokeRole(role, account);
    }

    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        emit RoleAdminChanged(role, getRoleAdmin(role), adminRole);
        _roles[role].adminRole = adminRole;
    }

    function _grantRole(bytes32 role, address account) private {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

contract SpendAni is AccessControl {
    using SafeBEP20 for IBEP20;
    IBEP20 public aniToken;
    bytes32 public constant CREATOR_ADMIN_SERVER =
        keccak256("CREATOR_ADMIN_SERVER");

    address public recipient = 0x35Af6B31a61eC9F030849a3953394A69a1f9f9eC;
    // Store key of mapping
    string[] shopNames;
    // Key as Shop Name, Amount at uint256
    mapping(string => uint256) shopInfo;

    event PurchaseItem(
        address Owner,
        uint256 fee,
        string itemName,
        uint256 timePurchaseItem
    );

    constructor(address minter, address _aniToken) {
        _setupRole(DEFAULT_ADMIN_ROLE, address(msg.sender));
        _setupRole(CREATOR_ADMIN_SERVER, minter);
        aniToken = IBEP20(_aniToken); // Ani Token
    }

    function purchaseItem(string memory _itemName) public {
        require(aniToken.balanceOf(address(msg.sender)) > 0, "need amount > 0");
        require(shopInfo[_itemName] > 0, "The specific name do not exists");
        uint256 _amount = shopInfo[_itemName];
        aniToken.safeTransferFrom(
            address(msg.sender),
            address(recipient),
            _amount
        );
        emit PurchaseItem(msg.sender, _amount, _itemName, block.timestamp);
    }

    function addItemShop(string memory _itemName, uint256 _amount) public {
        require(
            hasRole(CREATOR_ADMIN_SERVER, address(msg.sender)),
            "You are not an Owner"
        );
        require(_amount > 0, "Amount need to be greater than 0.");
        shopNames.push(_itemName);
        shopInfo[shopNames[shopNames.length - 1]] = _amount;
    }

    function removeItemShop(string memory _itemName) public {
        require(
            hasRole(CREATOR_ADMIN_SERVER, address(msg.sender)),
            "You are not an Owner"
        );
        bytes32 _temp = keccak256(abi.encodePacked(_itemName));
        shopInfo[_itemName] = 0;
        for (uint256 i = 0; i < shopNames.length; i++) {
            if (keccak256(abi.encodePacked(shopNames[i])) == _temp) {
                delete shopNames[i];
                return;
            }
        }
    }

    function getAllShopInfo()
        public
        view
        returns (string[] memory, uint256[] memory)
    {
        uint256[] memory _amounts = new uint256[](shopNames.length);
        for (uint256 i = 0; i < shopNames.length; i++) {
            _amounts[i] = shopInfo[shopNames[i]];
        }
        return (shopNames, _amounts);
    }
}
