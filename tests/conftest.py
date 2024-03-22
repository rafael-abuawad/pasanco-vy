import pytest


@pytest.fixture(scope="function")
def sender(accounts):
    return accounts[0]


@pytest.fixture(scope="function")
def players(accounts):
    return [accounts[1], accounts[2], accounts[3], accounts[4], accounts[5]]


@pytest.fixture(scope="function")
def token(project, sender):
    return project.ERC20.deploy(
        "Test Token", "TST", int(1000e18), "test-token", "v0.1", sender=sender
    )


@pytest.fixture(scope="function")
def vault(project, sender, token):
    return project.Vault.deploy(token, int(10e18), "vault", "v0.1", sender=sender)
