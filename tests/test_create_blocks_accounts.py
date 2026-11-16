from conftest import NAMES, OU_ID, ROOT_ID

OLD_STYLE_ID = "2026/10/15/[$LATEST]0123456789abcdef"


def test_create_returns_stable_physical_id(harness):
    first = harness.invoke("Create")
    second = harness.invoke("Create")
    assert first == second


def test_redeploy_of_new_style_stack_keeps_accounts_in_ou(harness):
    pid = harness.invoke("Create")
    assert harness.redeploy(pid) == pid
    assert harness.parents() == {OU_ID}


def test_redeploy_of_old_style_stack_keeps_accounts_in_ou(harness):
    assert harness.redeploy(OLD_STYLE_ID) == OLD_STYLE_ID
    assert harness.parents() == {OU_ID}


def test_repeated_redeploys_never_move_accounts(harness):
    pid = OLD_STYLE_ID
    for _ in range(3):
        pid = harness.redeploy(pid)
    assert harness.orgs.moves == []


def test_update_repairs_account_outside_ou(harness):
    harness.orgs.parent[NAMES[0]] = ROOT_ID
    harness.invoke("Update", OLD_STYLE_ID)
    assert harness.parents() == {OU_ID}


def test_real_delete_moves_accounts_to_root(harness):
    pid = harness.invoke("Create")
    harness.invoke("Delete", pid)
    assert harness.parents() == {ROOT_ID}


def test_real_delete_of_old_style_stack_moves_accounts_to_root(harness):
    harness.invoke("Delete", OLD_STYLE_ID)
    assert harness.parents() == {ROOT_ID}
