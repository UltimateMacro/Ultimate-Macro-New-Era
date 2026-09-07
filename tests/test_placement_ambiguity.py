"""Regression contracts for the v1.3.4b placement decision policy."""


def placement_policy(observations, max_clicks=5):
    """Model bounded retries after passive observations."""
    clicks = 0
    for observation in observations:
        clicks += 1
        if observation == "success":
            return "confirmed_success", clicks
        if observation == "failure":
            return "confirmed_failure_retry", clicks
        if clicks >= max_clicks:
            return "ambiguous_retry_exhausted", clicks
    return "ambiguous_retry_pending", clicks


def test_confirmed_placement():
    assert placement_policy(["success"]) == ("confirmed_success", 1)


def test_confirmed_failure_uses_bounded_retry_path():
    assert placement_policy(["failure"]) == ("confirmed_failure_retry", 1)


def test_ambiguous_then_later_confirmed():
    assert placement_policy(["ambiguous", "ambiguous", "success"]) == ("confirmed_success", 3)


def test_persistent_ambiguous_keeps_strategy_alive():
    assert placement_policy(["ambiguous", "ambiguous", "ambiguous"]) == ("ambiguous_retry_pending", 3)


def test_ambiguous_retries_are_bounded():
    assert placement_policy(["ambiguous"] * 5) == ("ambiguous_retry_exhausted", 5)


if __name__ == "__main__":
    for test in (
        test_confirmed_placement,
        test_confirmed_failure_uses_bounded_retry_path,
        test_ambiguous_then_later_confirmed,
        test_persistent_ambiguous_keeps_strategy_alive,
        test_ambiguous_retries_are_bounded,
    ):
        test()
    print("placement ambiguity contracts: PASS")