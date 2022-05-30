from eth_account import Account
from brownie import exceptions, Loyalty2
from scripts.tools import get_account
from scripts.deploy import deploy
import time
import pytest


# 1. should be able to allocate points
# 2. Should be able to get points available to a user
# 3. Should be able to remove expired points
# 4. Should be able to redeem points. Should revert if the user doesn’t have enough points
# 5. Should be able to modify points
# 6. Should be able to set a new owner
# 7. Should revert if caller is not the owner
# 8. Should be able to blacklist an owner
# 9. Should revert if total supply of points exceeds maxSupply
# 10. Should burn points even when not redeemable with redeem function


user = "psd&%#256"
user2 = "ps215d&%#256"


def test_can_allocate_points():
    # Arrange
    account = get_account()
    my_contract = Loyalty2.deploy(100, {"from": account})
    current_time = time.time()
    expiry = int(current_time) + 120
    ref_via = "website or something else"
    # Act
    allocate_tx = my_contract.allocatePoints(
        user, 10, expiry, ref_via, {"from": account}
    )
    allocate_tx.wait(1)
    # assert
    assert allocate_tx.events["pointsAllocated"]["_points"] == 10
    assert allocate_tx.events["pointsAllocated"]["_couponId"] == 1


def test_get_user_points():
    # Arrange
    account = get_account()
    my_contract = Loyalty2[-1]
    # Act
    user_points_tx = my_contract.getUserPoints(user, {"from": account})
    user_points_tx.wait(1)
    # Assert
    assert user_points_tx.events["userPoints"]["_points"] == 10


def test_expire_points():
    # Arrange
    account = get_account()
    my_contract = Loyalty2[-1]
    current_time = time.time()
    expiry = int(current_time) + 120
    isexpired = False
    # Act
    while isexpired == False:
        current_time = time.time()
        if int(current_time) > expiry:
            isexpired = True
        else:
            isexpired = False
        print("Waiting to expire...")
    user_points_tx = my_contract.getUserPoints(user, {"from": account})
    user_points_tx.wait(1)
    # Assert
    assert user_points_tx.events["userPoints"]["_points"] == 0


def test_can_redeem_points():
    # Arrange
    account = get_account()
    my_contract = Loyalty2[-1]
    current_time = time.time()
    expiry1 = int(current_time) + 60
    expiry2 = int(current_time) + 120
    expiry3 = int(current_time) + 180
    allocate_tx = my_contract.allocatePoints(
        user, 10, expiry1, "ref_via", {"from": account}
    )
    allocate_tx.wait(1)
    allocate_tx = my_contract.allocatePoints(
        user, 10, expiry2, "ref_via", {"from": account}
    )
    allocate_tx.wait(1)
    allocate_tx = my_contract.allocatePoints(
        user, 10, expiry3, "ref_via", {"from": account}
    )
    allocate_tx.wait(1)
    # Act
    redeem_tx = my_contract.redeemUserPoints(user, 17, {"from": account})
    redeem_tx.wait(1)
    user_points_tx = my_contract.getUserPoints(user, {"from": account})
    user_points_tx.wait(1)
    redeem_tx_2 = my_contract.redeemUserPoints(user, 17, {"from": account})
    redeem_tx_2.wait(1)
    user_points_tx_2 = my_contract.getUserPoints(user, {"from": account})
    user_points_tx_2.wait(1)
    # Assert
    assert redeem_tx.events["pointsRedeemed"]["_points"] == 10
    assert user_points_tx.events["userPoints"]["_points"] == 13
    assert user_points_tx.events["userPoints"]["_points"] == 13


def test_modify_points():
    # Arrange
    account = get_account()
    my_contract = Loyalty2[-1]
    current_time = time.time()
    expiry = int(current_time) + 120
    # Act
    allocate_tx = my_contract.allocatePoints(
        user, 10, expiry, "ref_via", {"from": account}
    )
    allocate_tx.wait(1)
    coupon_id = allocate_tx.events["pointsAllocated"]["_couponId"]
    modify_tx = my_contract.modifyCouponPoints(coupon_id, 39, {"from": account})
    modify_tx.wait(1)
    coupon_points = my_contract.couponIdToPoints(coupon_id)
    # assert
    assert allocate_tx.events["pointsAllocated"]["_points"] == 10
    assert modify_tx.events["couponModified"]["_points"] == 39
    assert coupon_points == 39


def test_can_add_owner():
    # Arrange
    account = get_account()
    new_account = get_account(1)
    new_account2 = get_account(2)
    new_account3 = get_account(3)
    current_time = time.time()
    expiry = int(current_time) + 60
    my_contract = Loyalty2[-1]
    user_points_tx = my_contract.getUserPoints(user, {"from": account})
    user_points_tx.wait(1)
    user_points = user_points_tx.events["userPoints"]["_points"]
    # Act
    set_owner_tx = my_contract.setOwner(new_account, {"from": account})
    set_owner_tx.wait(1)
    confirm_owner_tx = my_contract.confirmOwner({"from": new_account})
    confirm_owner_tx.wait(1)
    allocate_tx = my_contract.allocatePoints(
        user, 10, expiry, "ref_via", {"from": new_account}
    )
    allocate_tx.wait(1)
    user_points_tx = my_contract.getUserPoints(user, {"from": account})
    user_points_tx.wait(1)
    set_owner_tx = my_contract.setOwner(new_account2, {"from": new_account})
    set_owner_tx.wait(1)
    # Assert
    assert allocate_tx.events["pointsAllocated"]["_points"] == 10
    assert user_points_tx.events["userPoints"]["_points"] == 10 + user_points
    with pytest.raises(exceptions.VirtualMachineError):
        my_contract.getUserPoints(user, {"from": new_account2})
    with pytest.raises(exceptions.VirtualMachineError):
        my_contract.setOwner(new_account, {"from": new_account})
    with pytest.raises(exceptions.VirtualMachineError):
        my_contract.setOwner(new_account3, {"from": new_account2})


def test_can_blacklist_owner():
    # Arrange
    account = get_account()
    second_account = get_account(1)
    my_contract = Loyalty2[-1]
    # Act
    block_tx = my_contract.blockOwner(second_account, {"from": account})
    block_tx.wait(1)
    # Assert
    with pytest.raises(exceptions.VirtualMachineError):
        my_contract.getUserPoints(user, {"from": second_account})
    with pytest.raises(exceptions.VirtualMachineError):
        my_contract.blockOwner(account, {"from": account})


def test_cannot_exceed_max_supply():
    # Arrange
    account = get_account()
    my_contract = Loyalty2[-1]
    current_time = time.time()
    expiry = int(current_time) + 120
    current_supply = my_contract.totalSupply()
    # Assert
    with pytest.raises(exceptions.VirtualMachineError):
        my_contract.allocatePoints(
            user, (100 - current_supply + 1), expiry, "ref_via", {"from": account}
        )


def test_can_burn_points_with_redeem():
    # Arrange
    account = get_account()
    my_contract = Loyalty2[-1]
    user_points_tx = my_contract.getUserPoints(user2, {"from": account})
    user_points_tx.wait(1)
    user_points = user_points_tx.events["userPoints"]["_points"]
    total_supply = my_contract.totalSupply()
    current_time = time.time()
    expiry = int(current_time) + 30
    allocate_tx = my_contract.allocatePoints(
        user2, 10, expiry, "ref_via", {"from": account}
    )
    allocate_tx.wait(1)
    user_points_tx_2 = my_contract.getUserPoints(user2, {"from": account})
    user_points_tx_2.wait(1)
    total_supply_2 = my_contract.totalSupply()
    isexpired = False
    # Act
    while isexpired == False:
        current_time = time.time()
        if int(current_time) > expiry:
            isexpired = True
        else:
            isexpired = False
        print("Waiting to expire...")

    redeem_tx = my_contract.redeemUserPoints(user2, 7, {"from": account})
    total_supply_3 = my_contract.totalSupply()
    user_points_tx_3 = my_contract.getUserPoints(user2, {"from": account})
    user_points_tx_3.wait(1)
    # Assert
    assert user_points_tx_2.events["userPoints"]["_points"] == user_points + 10
    assert user_points_tx_3.events["userPoints"]["_points"] == user_points
    assert total_supply_2 == total_supply + 10
    assert total_supply_3 == total_supply_2 - 10
