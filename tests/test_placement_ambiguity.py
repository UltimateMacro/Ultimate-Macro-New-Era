"""Regression contracts for placement failure classification and coordinate safety."""


def placement_policy(observations, max_unknown=8):
    """Model: only explicit space rejection may advance to another coordinate."""
    position = 0
    unknown = 0
    events = []
    for observation in observations:
        events.append((position, observation))
        if observation == "success":
            return "confirmed_success", events
        if observation == "funds":
            # Money is a temporal condition, never a geometry failure.
            continue
        if observation == "space":
            position += 1
            unknown = 0
            continue
        if observation == "unknown":
            unknown += 1
            if unknown >= max_unknown:
                return "unknown_failed_safe", events
            continue
        raise ValueError(observation)
    return "pending", events


def test_cash_never_moves_recorded_position():
    status, events = placement_policy(["funds", "funds", "funds", "success"])
    assert status == "confirmed_success"
    assert {position for position, _ in events} == {0}


def test_space_rejection_moves_once():
    status, events = placement_policy(["space", "success"])
    assert status == "confirmed_success"
    assert [position for position, _ in events] == [0, 1]


def test_unknown_never_guesses_an_offset():
    status, events = placement_policy(["unknown"] * 8)
    assert status == "unknown_failed_safe"
    assert {position for position, _ in events} == {0}


def test_mixed_cash_then_space_only_moves_after_space_signal():
    status, events = placement_policy(["funds", "unknown", "funds", "space", "success"])
    assert status == "confirmed_success"
    assert [position for position, _ in events] == [0, 0, 0, 0, 1]


if __name__ == "__main__":
    for test in (
        test_cash_never_moves_recorded_position,
        test_space_rejection_moves_once,
        test_unknown_never_guesses_an_offset,
        test_mixed_cash_then_space_only_moves_after_space_signal,
    ):
        test()
    print("placement ambiguity contracts: PASS")