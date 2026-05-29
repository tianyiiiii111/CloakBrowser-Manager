from backend.version import app_version, is_newer, version_tuple


def test_version_tuple():
    assert version_tuple("1.2.3") == (1, 2, 3)
    assert version_tuple("v0.1.10") == (0, 1, 10)


def test_is_newer():
    assert is_newer("0.2.0", "0.1.11")
    assert not is_newer("0.1.0", "0.1.11")
    assert not is_newer("0.1.11", "0.1.11")


def test_app_version_from_pyproject():
    v = app_version()
    assert v.count(".") >= 1
