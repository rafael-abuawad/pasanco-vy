from ape import project, accounts


def main():
    sender= accounts.test_accounts[0]
    players = [accounts.test_accounts[1], accounts.test_accounts[2], accounts.test_accounts[3], accounts.test_accounts[4], accounts.test_accounts[5]]
    token = project.ERC20.deploy("Boliviano", "BOB", int(1000e18), "", "v0.1", sender=sender)
    vault = project.Vault.deploy(token, int(10e18), "vault", "v0.1", sender=sender)

    print("### MODO PRUEBA")
    print("Creado tokens a cada jugador (100 tokens por jugador)")
    for player in players:
        amount = int(100e18)
        token.mint(player, amount, sender=sender)
        print(f"Acuñando {amount/int(1e18)} {token.symbol()} a {player}")
    
    print("")
    print("Registrando jugadores...")
    for player in players:
        amount = vault.deposit_amount()
        vault.register_player(player, sender=player)
        print(f"Jugador {player} registrado!")
 
    for _ in range(1):
        print("")
        print("Depositando su pasanaco...")
        for player in players:
            amount = vault.deposit_amount()
            token.approve(vault, amount, sender=player)
            vault.deposit(sender=player)
            print(f"Jugador {player} deposito {amount/int(1e18)} {token.symbol()}")

        player_on_turn = vault.player_on_turn()
        turn = vault.turn() + 1
        print("")
        print("### MODO PRUEBA")
        print(f"\t- Jugador {player_on_turn} (#{turn})")

        print(f"El balance inicial del jugador de turno (#{turn})")
        print(f"\t- Balance {token.symbol()} ({token.balanceOf(player_on_turn)/int(1e18)})")
        print("Reclamando...")
        vault.redeem(sender=sender)
        print(f"El balance despues de reclamar del jugador de turno (#{vault.turn()-1})")
        print(f"\t- Balance {token.symbol()} ({token.balanceOf(player_on_turn)/int(1e18)})")
    
 


