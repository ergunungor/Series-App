import unittest

from app.ai_service import normalize_supersets


class SupersetNormalizeTests(unittest.TestCase):
    def test_groups_renumbered_and_synced(self):
        ex = [
            {"name": "a", "sets": 3, "rest_seconds": 60, "superset_group": "A"},
            {"name": "b", "sets": 4, "rest_seconds": 90, "superset_group": "A"},
            {"name": "c", "sets": 3, "superset_group": "Z"},  # tek başına: süperset değil
            {"name": "d", "sets": 2, "rest_seconds": 30, "superset_group": 7, "drop_sets": 9},
            {"name": "e", "sets": 2, "rest_seconds": 30, "superset_group": 7},
        ]
        normalize_supersets(ex)
        self.assertEqual([e.get("superset_group") for e in ex], [1, 1, None, 2, 2])
        self.assertEqual(ex[1]["sets"], 3)
        self.assertEqual(ex[0]["rest_seconds"], 0)
        self.assertEqual(ex[1]["rest_seconds"], 90)
        self.assertEqual(ex[3]["drop_sets"], 4)
        self.assertNotIn("drop_sets", ex[0])

    def test_noncontiguous_group_is_dropped(self):
        ex = [
            {"name": "a", "sets": 3, "superset_group": 1},
            {"name": "b", "sets": 3},
            {"name": "c", "sets": 3, "superset_group": 1},
        ]
        normalize_supersets(ex)
        self.assertTrue(all("superset_group" not in e for e in ex))

    def test_sanitize_applies_it(self):
        from app.ai_service import sanitize_program_data
        data = {"workouts": [{"exercises": [
            {"name": "a", "sets": 3, "reps": "10", "superset_group": 1},
            {"name": "b", "sets": 3, "reps": "10", "superset_group": 1, "rest_seconds": 75},
        ]}]}
        out = sanitize_program_data(data)["workouts"][0]["exercises"]
        self.assertEqual([e["superset_group"] for e in out], [1, 1])
        self.assertEqual(out[0]["rest_seconds"], 0)


if __name__ == "__main__":
    unittest.main()
