import ape


def test_correct_asset_set(vault, token):
    assert vault.asset() == token


def test_max_player_count(vault):
    assert vault.max_players() == 5


def test_goal_deposit_amount(vault):
    assert vault.max_deposit_amount() == (vault.deposit_amount() * vault.max_players())


def test_current_turn(vault):
    assert vault.turn() == 0


def test_all_players_enter_the_game(vault, players):
    for player in players:
        vault.register_player(player, sender=player)


def test_extra_player_reverts(vault, players, sender):
    for player in players:
        vault.register_player(player, sender=player)
    with ape.reverts():
        vault.register_player(sender, sender=sender)


def test_players_can_deposit_amount(vault, token, players, sender):
    amount = vault.deposit_amount()
    deposits = 0
    for player in players:
        vault.register_player(player, sender=player)
        token.mint(player, amount, sender=sender)
        token.approve(vault, amount, sender=player)
        vault.deposit(sender=player)
        deposits += amount

    assert vault.total_assets() == deposits


def test_player_cannot_redeem(vault, token, players, sender):
    amount = vault.deposit_amount()
    for i in range(len(players) - 3):
        player = players[i]
        vault.register_player(player, sender=player)
        token.mint(player, amount, sender=sender)
        token.approve(vault, amount, sender=player)
        vault.deposit(sender=player)

    with ape.reverts():
        vault.redeem(sender=sender)


def test_players_can_deposit_amount(vault, token, players, sender):
    amount = vault.deposit_amount()
    initial_player = players[0]
    initial_balance = token.balanceOf(initial_player)
    deposits = 0

    for player in players:
        vault.register_player(player, sender=player)
        token.mint(player, amount, sender=sender)
        token.approve(vault, amount, sender=player)
        vault.deposit(sender=player)
        deposits += amount

    vault.redeem(sender=sender)
    final_balance = token.balanceOf(initial_player)
    assert (initial_balance + deposits) == final_balance

    # resets correctly
    assert vault.turn() == 1
    assert vault.total_assets() == 0
