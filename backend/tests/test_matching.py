import unittest

from app import exercise_catalog as catalog
from app.ai_service import _standard_variant


def pick(q):
    cands = catalog.find_candidates(q, limit=10, min_score=0.5)
    it = _standard_variant(q, cands)
    return it["name"] if it else None


class StandardVariantTests(unittest.TestCase):
    def test_unqualified_names_pick_barbell_first(self):
        self.assertEqual(pick("bench press"), "barbell bench press")

    def test_prefers_dumbbell_when_no_barbell(self):
        self.assertIn(pick("lateral raise"), (None, "dumbbell lateral raise"))

    def test_qualified_incline_not_forced(self):
        # "incline bench press" için standart seçim, düz bench press olmamalı
        self.assertNotEqual(pick("incline bench press"), "barbell bench press")


if __name__ == "__main__":
    unittest.main()
