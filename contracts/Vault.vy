# pragma version ^0.3.10

# @dev We import the `ERC20` interface,
# which is a built-in interface of the Vyper compiler.
from vyper.interfaces import ERC20


# @dev We import and implement the `IERC5267` interface,
# which is written using standard Vyper syntax.
from interfaces import IERC5267
implements: IERC5267


# @dev Constant used as part of the ECDSA recovery function.
_MALLEABILITY_THRESHOLD: constant(bytes32) = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0


# @dev The 32-byte type hash for the EIP-712 domain separator.
_TYPE_HASH: constant(bytes32) = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")


# @dev The 32-byte type hash of the `permit` function.
_PERMIT_TYPE_HASH: constant(bytes32) = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")


# @dev Returns the address of the underlying token
# used for the vault for accounting, depositing,
# and withdrawing. To preserve consistency with the
# ERC-4626 interface, we use lower case letters for
# the `immutable` variable `name`.
# @notice Vyper returns the `address` type for interface
# types by default.
asset: public(immutable(ERC20))


# @dev Caches the domain separator as an `immutable`
# value, but also stores the corresponding chain ID
# to invalidate the cached domain separator if the
# chain ID changes.
_CACHED_DOMAIN_SEPARATOR: immutable(bytes32)
_CACHED_CHAIN_ID: immutable(uint256)


# @dev Caches `self` to `immutable` storage to avoid
# potential issues if a vanilla contract is used in
# a `delegatecall` context.
_CACHED_SELF: immutable(address)


# @dev `immutable` variables to store the (hashed)
# name and (hashed) version during contract creation.
_NAME: immutable(String[50])
_HASHED_NAME: immutable(bytes32)
_VERSION: immutable(String[20])
_HASHED_VERSION: immutable(bytes32)


# @dev Stores the maximun amount of players
MAX_PLAYER_COUNT: constant(uint256) = 5


# @dev Stores the amount of money that each pllayer needs to play.
AMOUNT: immutable(uint256)


# @dev Stores the amount of money that needs to be played.
GOAL_AMOUNT: immutable(uint256)


# @dev Returns the addreses of all players
players: public(DynArray[address, MAX_PLAYER_COUNT])


# @dev Returns if the player address has deposited
deposited: public(HashMap[address, bool])


# @dev Returns the addreses of all players
turn: public(uint256)


# @dev Returns if the game is ongoing
ongoing: public(bool)


# @dev Returns the amount of tokens in existence.
totalSupply: public(uint256)


# @dev Returns the current on-chain tracked nonce
# of `address`.
nonces: public(HashMap[address, uint256])


# @dev Emitted when `amount` tokens are moved
# from one account (`owner`) to another (`to`).
# Note that the parameter `amount` may be zero.
event Transfer:
    owner: indexed(address)
    to: indexed(address)
    amount: uint256


# @dev Emitted when the allowance of a `spender`
# for an `owner` is set by a call to `approve`.
# The parameter `amount` is the new allowance.
event Approval:
    owner: indexed(address)
    spender: indexed(address)
    amount: uint256


# @dev Emitted when `sender` has exchanged `assets`
# for `shares`, and transferred those `shares`
# to `owner`.
event Deposit:
    sender: indexed(address)
    owner: indexed(address)
    assets: uint256


# @dev May be emitted to signal that the domain could
# have changed.
event EIP712DomainChanged:
    pass


@external
@payable
def __init__(asset_: ERC20, amount_: uint256, name_eip712_: String[50], version_eip712_: String[20]):
    """
    @dev To omit the opcodes for checking the `msg.value`
         in the creation-time EVM bytecode, the constructor
         is declared as `payable`.
    @param asset_ The ERC-20 compatible (i.e. ERC-777 is also viable)
           underlying asset contract.
    @param amount_ The amount needed to deposit in order to play
           the game
    @param name_eip712_ The maximum 50-character user-readable
           string name of the signing domain, i.e. the name
           of the dApp or protocol.
    @param version_eip712_ The maximum 20-character current
           main version of the signing domain. Signatures
           from different versions are not compatible.
    """
    asset = asset_
    self.ongoing = True

    _NAME = name_eip712_
    _VERSION = version_eip712_
    _HASHED_NAME = keccak256(name_eip712_)
    _HASHED_VERSION = keccak256(version_eip712_)
    _CACHED_DOMAIN_SEPARATOR = self._build_domain_separator()
    _CACHED_CHAIN_ID = chain.id
    _CACHED_SELF = self
    AMOUNT = amount_
    GOAL_AMOUNT = amount_ * MAX_PLAYER_COUNT


@external
@view
def DOMAIN_SEPARATOR() -> bytes32:
    """
    @dev Sourced from {ERC20-DOMAIN_SEPARATOR}.
    @notice See {ERC20-DOMAIN_SEPARATOR} for the
            function docstring.
    """
    return self._domain_separator_v4()


@external
@view
def eip712Domain() -> (bytes1, String[50], String[20], uint256, address, bytes32, DynArray[uint256, 128]):
    """
    @dev Returns the fields and values that describe the domain
         separator used by this contract for EIP-712 signatures.
    @notice The bits in the 1-byte bit map are read from the least
            significant to the most significant, and fields are indexed
            in the order that is specified by EIP-712, identical to the
            order in which they are listed in the function type.
    @return bytes1 The 1-byte bit map where bit `i` is set to 1
            if and only if domain field `i` is present (`0 ≤ i ≤ 4`).
    @return String The maximum 50-character user-readable string name
            of the signing domain, i.e. the name of the dApp or protocol.
    @return String The maximum 20-character current main version of
            the signing domain. Signatures from different versions are
            not compatible.
    @return uint256 The 32-byte EIP-155 chain ID.
    @return address The 20-byte address of the verifying contract.
    @return bytes32 The 32-byte disambiguation salt for the protocol.
    @return DynArray The 32-byte array of EIP-712 extensions.
    """
    # Note that `\x0f` equals `01111`.
    return (convert(b"\x0f", bytes1), _NAME, _VERSION, chain.id, self, empty(bytes32), empty(DynArray[uint256, 128]))


@external
def register_player(player: address) -> bool:
    """
    @dev Register a new player to the game.
    @param player Address of the new player.
    @return bool True if the registration is successful, False otherwise.
    """
    assert self.ongoing, "game has finished"
    assert self.turn == 0, "game has already started"
    assert len(self.players) < MAX_PLAYER_COUNT, "too many players"
    self.players.append(player)
    return True


@external
@view
def player_on_turn() -> address:
    """
    @dev Returns the player on turn
    @return address The address of the player in turn
    """
    return self.players[self.turn]


@external
@view
def total_assets() -> uint256:
    """
    @dev Returns the total amount of the underlying asset
         that is managed by the vault.
    @notice For the to be fulfilled conditions, please refer to:
            https://eips.ethereum.org/EIPS/eip-4626#totalassets.
    @return uint256 The 32-byte total managed assets.
    """
    return self._total_assets()


@external
@view
def max_players() -> uint256:
    """
    @dev Returns the maximum amount of players that
         can participate.
    @return uint256 The 32-byte maximum amount of players.
    """
    return MAX_PLAYER_COUNT


@external
@view
def deposit_amount() -> uint256:
    """
    @dev Returns the amount of the underlying asset
         that can be deposited into the vault for the `receiver`,
         through a `deposit` call.
    @return uint256 The 32-byte deposit amount.
    """
    return AMOUNT


@external
@view
def max_deposit_amount() -> uint256:
    """
    @dev Returns the maximum amount of the underlying asset
         that can be deposited into the vault for the `receiver`,
         through a `deposit` call.
    @return uint256 The 32-byte maximum deposit amount.
    """
    return GOAL_AMOUNT


@external
def deposit() -> bool:
    """
    @dev Allow players to deposit their share into the pool.
    @return bool Indicating whether the deposit succeeded.
    """
    amount: uint256 = AMOUNT

    assert self._is_player(msg.sender), "is not a registred player"
    assert not self.deposited[msg.sender], "player already deposited"
    assert asset.transferFrom(msg.sender, self, amount, default_return_value=True), "transferFrom operation did not succeed"

    self.deposited[msg.sender] = True
    self.totalSupply += amount
    log Deposit(msg.sender, self, amount)
    return True


@external
def redeem() -> uint256:
    """
    @dev Redeem the accumulated rewards by distributing them among active players.
    @return uint256 Amount received by the caller upon redemption.
    """
    player: address = self.players[self.turn]
    totalSupply: uint256 = self.totalSupply

    assert player != empty(address), "transfer to the zero address"
    assert totalSupply >= GOAL_AMOUNT, "waiting for players to deposit"
    assert asset.transfer(player, totalSupply, default_return_value=True), "transfer operation did not succeed"
    
    self._reset()
    log Transfer(self, player, totalSupply)

    return totalSupply


@internal
@view
def _is_player(player: address) -> bool:
    """
    @dev Check whether the given address is a player.
    @param player Address of the potential player.
    @return bool True if the address is in the list of players; false otherwise.
    """
    return player in self.players


@internal
def _reset():
    """
    @dev Reset all game states by resetting deposits
         and incrementing the turn count.
    """
    for player in self.players:
        self.deposited[player] = False
    self.totalSupply = 0
    self.turn += 1

    if self.turn == MAX_PLAYER_COUNT:
        self.ongoing = False


@internal
@view
def _domain_separator_v4() -> bytes32:
    """
    @dev Sourced from {EIP712DomainSeparator-domain_separator_v4}.
    @notice See {EIP712DomainSeparator-domain_separator_v4}
            for the function docstring.
    """
    if (self == _CACHED_SELF and chain.id == _CACHED_CHAIN_ID):
        return _CACHED_DOMAIN_SEPARATOR
    else:
        return self._build_domain_separator()


@internal
@view
def _build_domain_separator() -> bytes32:
    """
    @dev Sourced from {EIP712DomainSeparator-_build_domain_separator}.
    @notice See {EIP712DomainSeparator-_build_domain_separator}
            for the function docstring.
    """
    return keccak256(_abi_encode(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION, chain.id, self))


@internal
@view
def _hash_typed_data_v4(struct_hash: bytes32) -> bytes32:
    """
    @dev Sourced from {EIP712DomainSeparator-hash_typed_data_v4}.
    @notice See {EIP712DomainSeparator-hash_typed_data_v4}
            for the function docstring.
    """
    return self._to_typed_data_hash(self._domain_separator_v4(), struct_hash)


@internal
@pure
def _to_typed_data_hash(domain_separator: bytes32, struct_hash: bytes32) -> bytes32:
    """
    @dev Sourced from {ECDSA-to_typed_data_hash}.
    @notice See {ECDSA-to_typed_data_hash} for the
            function docstring.
    """
    return keccak256(concat(b"\x19\x01", domain_separator, struct_hash))


@internal
@pure
def _recover_vrs(hash: bytes32, v: uint256, r: uint256, s: uint256) -> address:
    """
    @dev Sourced from {ECDSA-_recover_vrs}.
    @notice See {ECDSA-_recover_vrs} for the
            function docstring.
    """
    return self._try_recover_vrs(hash, v, r, s)


@internal
@pure
def _try_recover_vrs(hash: bytes32, v: uint256, r: uint256, s: uint256) -> address:
    """
    @dev Sourced from {ECDSA-_try_recover_vrs}.
    @notice See {ECDSA-_try_recover_vrs} for the
            function docstring.
    """
    assert s <= convert(_MALLEABILITY_THRESHOLD, uint256), "ECDSA: invalid signature `s` value"

    signer: address = ecrecover(hash, v, r, s)
    assert signer != empty(address), "ECDSA: invalid signature"

    return signer


@internal
@view
def _try_get_underlying_decimals(underlying: ERC20) -> (bool, uint8):
    """
    @dev Attempts to fetch the underlying's decimals. A return
         value of `False` indicates that the attempt failed in
         some way.
    @param underlying The ERC-20 compatible (i.e. ERC-777 is also viable)
           underlying asset contract.
    @return bool The verification whether the call succeeded or
            failed.
    @return uint8 The fetched underlying's decimals.
    """
    success: bool = empty(bool)
    return_data: Bytes[32] = b""
    # The following low-level call does not revert, but instead
    # returns `False` if the callable contract does not implement
    # the `decimals` function. Since we perform a length check of
    # 32 bytes for the return data in the return expression at the
    # end, we also return `False` for EOA wallets instead of reverting
    # (remember that the EVM always considers a call to an EOA as
    # successful with return data `0x`). Furthermore, it is important
    # to note that an external call via `raw_call` does not perform an
    # external code size check on the target address.
    success, return_data = raw_call(underlying.address, method_id("decimals()"), max_outsize=32, is_static_call=True, revert_on_failure=False)
    if (success and (len(return_data) == 32) and (convert(return_data, uint256) <= convert(max_value(uint8), uint256))):
        return (True, convert(return_data, uint8))
    return (False, empty(uint8))


@internal
@view
def _total_assets() -> uint256:
    """
    @dev An `internal` helper function that returns the total amount
         of the underlying asset that is managed by the vault.
    @notice For the to be fulfilled conditions, please refer to:
            https://eips.ethereum.org/EIPS/eip-4626#totalassets.
    @return uint256 The 32-byte total managed assets.
    """
    return asset.balanceOf(self)


@internal
@pure
def _mul_div(x: uint256, y: uint256, denominator: uint256, roundup: bool) -> uint256:
    """
    @dev Sourced from {Math-mul_div}.
    @notice See {Math-mul_div} for the function
            docstring.
    """
    # Handle division by zero.
    assert denominator != empty(uint256), "Math: mul_div division by zero"

    # 512-bit multiplication "[prod1 prod0] = x * y".
    # Compute the product "mod 2**256" and "mod 2**256 - 1".
    # Then use the Chinese Remainder theorem to reconstruct
    # the 512-bit result. The result is stored in two 256-bit
    # variables, where: "product = prod1 * 2**256 + prod0".
    mm: uint256 = uint256_mulmod(x, y, max_value(uint256))
    # The least significant 256 bits of the product.
    prod0: uint256 = unsafe_mul(x, y)
    # The most significant 256 bits of the product.
    prod1: uint256 = empty(uint256)

    if (mm < prod0):
        prod1 = unsafe_sub(unsafe_sub(mm, prod0), 1)
    else:
        prod1 = unsafe_sub(mm, prod0)

    # Handling of non-overflow cases, 256 by 256 division.
    if (prod1 == empty(uint256)):
        if (roundup and uint256_mulmod(x, y, denominator) != empty(uint256)):
            # Calculate "ceil((x * y) / denominator)". The following
            # line cannot overflow because we have the previous check
            # "(x * y) % denominator != 0", which accordingly rules out
            # the possibility of "x * y = 2**256 - 1" and `denominator == 1`.
            return unsafe_add(unsafe_div(prod0, denominator), 1)
        else:
            return unsafe_div(prod0, denominator)

    # Ensure that the result is less than 2**256. Also,
    # prevents that `denominator == 0`.
    assert denominator > prod1, "Math: mul_div overflow"

    #######################
    # 512 by 256 Division #
    #######################

    # Make division exact by subtracting the remainder
    # from "[prod1 prod0]". First, compute remainder using
    # the `uint256_mulmod` operation.
    remainder: uint256 = uint256_mulmod(x, y, denominator)

    # Second, subtract the 256-bit number from the 512-bit
    # number.
    if (remainder > prod0):
        prod1 = unsafe_sub(prod1, 1)
    prod0 = unsafe_sub(prod0, remainder)

    # Factor powers of two out of the denominator and calculate
    # the largest power of two divisor of denominator. Always `>= 1`,
    # unless the denominator is zero (which is prevented above),
    # in which case `twos` is zero. For more details, please refer to:
    # https://cs.stackexchange.com/q/138556.
    twos: uint256 = unsafe_sub(0, denominator) & denominator
    # Divide denominator by `twos`.
    denominator_div: uint256 = unsafe_div(denominator, twos)
    # Divide "[prod1 prod0]" by `twos`.
    prod0 = unsafe_div(prod0, twos)
    # Flip `twos` such that it is "2**256 / twos". If `twos` is zero,
    # it becomes one.
    twos = unsafe_add(unsafe_div(unsafe_sub(empty(uint256), twos), twos), 1)

    # Shift bits from `prod1` to `prod0`.
    prod0 |= unsafe_mul(prod1, twos)

    # Invert the denominator "mod 2**256". Since the denominator is
    # now an odd number, it has an inverse modulo 2**256, so we have:
    # "denominator * inverse = 1 mod 2**256". Calculate the inverse by
    # starting with a seed that is correct for four bits. That is,
    # "denominator * inverse = 1 mod 2**4".
    inverse: uint256 = unsafe_mul(3, denominator_div) ^ 2

    # Use Newton-Raphson iteration to improve accuracy. Thanks to Hensel's
    # lifting lemma, this also works in modular arithmetic by doubling the
    # correct bits in each step.
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator_div, inverse))) # Inverse "mod 2**8".
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator_div, inverse))) # Inverse "mod 2**16".
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator_div, inverse))) # Inverse "mod 2**32".
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator_div, inverse))) # Inverse "mod 2**64".
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator_div, inverse))) # Inverse "mod 2**128".
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator_div, inverse))) # Inverse "mod 2**256".

    # Since the division is now exact, we can divide by multiplying
    # with the modular inverse of the denominator. This returns the
    # correct result modulo 2**256. Since the preconditions guarantee
    # that the result is less than 2**256, this is the final result.
    # We do not need to calculate the high bits of the result and
    # `prod1` is no longer necessary.
    result: uint256 = unsafe_mul(prod0, inverse)

    if (roundup and uint256_mulmod(x, y, denominator) != empty(uint256)):
        # Calculate "ceil((x * y) / denominator)". The following
        # line uses intentionally checked arithmetic to prevent
        # a theoretically possible overflow.
        result += 1

    return result