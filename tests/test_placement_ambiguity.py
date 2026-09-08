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


def build_placement_targets(base_x, base_y, radii=(5, 10, 20)):
    """Mirror of BuildPlacementTargets: recorded pixel first, then rings."""
    targets = [(base_x, base_y)]
    for radius in radii:
        for dx, dy in (
            (0, -radius), (radius, 0), (0, radius), (-radius, 0),
            (radius, -radius), (radius, radius), (-radius, radius), (-radius, -radius),
        ):
            targets.append((base_x + dx, base_y + dy))
    return targets


def clicked_positions(observations, base=(500, 400), max_attempts=9):
    """Positions actually clicked when every listed observation rejects."""
    targets = build_placement_targets(*base)
    rejected = set()
    clicked = []
    index = 0

    for observation in observations:
        while index < len(targets) and targets[index] in rejected:
            index += 1
        if index >= len(targets) or len(clicked) >= max_attempts:
            break
        position = targets[index]
        clicked.append(position)
        if observation == "success":
            break
        rejected.add(position)
        index += 1

    return clicked


def test_first_attempt_uses_the_recorded_position():
    assert clicked_positions(["success"])[0] == (500, 400)


def test_a_rejected_position_is_never_clicked_again():
    clicked = clicked_positions(["failure"] * 6)
    assert len(clicked) == len(set(clicked)), "placement re-clicked a position it had already rejected"
    assert clicked[1] != (500, 400), "the retry must move off the failed pixel"


def test_unresolved_placements_also_retire_their_position():
    clicked = clicked_positions(["ambiguous", "ambiguous", "success"])
    assert len(clicked) == len(set(clicked))


def test_placement_attempts_stay_bounded():
    assert len(clicked_positions(["failure"] * 50)) == 9


if __name__ == "__main__":
    for test in (
        test_confirmed_placement,
        test_confirmed_failure_uses_bounded_retry_path,
        test_ambiguous_then_later_confirmed,
        test_persistent_ambiguous_keeps_strategy_alive,
        test_ambiguous_retries_are_bounded,
        test_first_attempt_uses_the_recorded_position,
        test_a_rejected_position_is_never_clicked_again,
        test_unresolved_placements_also_retire_their_position,
        test_placement_attempts_stay_bounded,
    ):
        test()
    print("placement ambiguity contracts: PASS")