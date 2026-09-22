import unittest
from validate_rooms import validate

NOTES = {
    "n_break": {"id": "n_break", "pitch_class": "C", "category": "destructive", "index": 0},
    "n_step":  {"id": "n_step",  "pitch_class": "E", "category": "movement",    "index": 0},
}
MEL = {"d1": {"id": "d1", "notes": ["C4"]}}  # 1-note door, needs C


def graph(exits_drip):
    # hollow(note C) -> drip(note E) -> overlook, with the drip->overlook exit under test
    return {
        "start": {"room": "hollow", "entry": "spawn"},
        "rooms": {
            "hollow":   {"notes": ["n_break"], "entries": ["spawn"],
                         "exits": [{"to": "drip", "to_entry": "from_hollow"}]},
            "drip":     {"notes": ["n_step"], "entries": ["from_hollow", "from_overlook"],
                         "exits": exits_drip},
            "overlook": {"notes": [], "entries": ["from_drip"], "exits": []},
        },
    }


class AbilityGate(unittest.TestCase):
    def test_passable_when_note_owned(self):
        # drip holds n_step, gate requires n_step -> overlook reachable, no errors
        g = graph([{"to": "overlook", "to_entry": "from_drip", "requires": {"note": "n_step"}}])
        errors, _ = validate(g, NOTES, MEL)
        self.assertEqual(errors, [])

    def test_unreachable_when_note_missing(self):
        # gate requires a note found nowhere -> overlook unreachable -> error
        g = graph([{"to": "overlook", "to_entry": "from_drip", "requires": {"note": "n_mend"}}])
        errors, _ = validate(g, NOTES, MEL)
        self.assertTrue(any("overlook" in e and "unreachable" in e for e in errors))

    def test_unknown_required_note_errors(self):
        g = graph([{"to": "overlook", "to_entry": "from_drip", "requires": {"note": "n_bogus"}}])
        errors, _ = validate(g, NOTES, MEL)
        self.assertTrue(any("n_bogus" in e for e in errors))

    def test_door_and_requires_on_one_exit_errors(self):
        g = graph([{"to": "overlook", "to_entry": "from_drip",
                    "door": "d1", "requires": {"note": "n_step"}}])
        errors, _ = validate(g, NOTES, MEL)
        self.assertTrue(any("both" in e.lower() for e in errors))

    def test_door_and_requires_on_unreachable_exit_also_errors(self):
        # An orphan room with no incoming edges (unreachable) has an exit with both
        # door and requires. The both-fields error must fire unconditionally, not
        # only for reachable exits. This test fails if the check is scoped to
        # reachability.
        g = {
            "start": {"room": "hollow", "entry": "spawn"},
            "rooms": {
                "hollow":   {"notes": ["n_break"], "entries": ["spawn"],
                             "exits": [{"to": "drip", "to_entry": "from_hollow"}]},
                "drip":     {"notes": ["n_step"], "entries": ["from_hollow"],
                             "exits": []},
                "orphan":   {"notes": [], "entries": ["from_nowhere"],
                             "exits": [{"to": "drip", "to_entry": "from_hollow",
                                        "door": "d1", "requires": {"note": "n_step"}}]},
            },
        }
        errors, _ = validate(g, NOTES, MEL)
        # Must flag both-fields error (orphan is never visited by fixpoint)
        self.assertTrue(any("both" in e.lower() for e in errors))


if __name__ == "__main__":
    unittest.main()
