import json
import unittest

from app.ai_service import parse_program_from_input

SAMPLE = {
    "program_name": "Gym + Kalistenik",
    "schedule": [
        {
            "day_tr": "Salı",
            "title_tr": "Gym A – İtiş + bacak",
            "est_duration_min": 50,
            "warmup": [
                {"exercise_id": "0993", "display_name_tr": "Band pull-apart", "sets": 2, "reps": "20"}
            ],
            "items": [
                {"exercise_id": "0314", "display_name_tr": "Incline DB press", "sets": 3, "reps": "6-10", "rest_sec": 120},
                {"exercise_id": "0178", "display_name_tr": "Cable lateral raise", "sets": 3, "reps": "12-15", "superset_group": "A"},
                {"exercise_id": "0200", "display_name_tr": "Rope pushdown", "sets": 3, "reps": "12-15", "rest_sec": 75, "superset_group": "A"},
            ],
        },
        {
            "day_tr": "Cumartesi",
            "title_tr": "Gym C",
            "items": [
                {"exercise_id": "0336", "display_name_tr": "Walking lunge", "sets": 3, "reps": "10", "per_side": True},
                {"type": "cardio", "exercise_id": None, "display_name_tr": "Row erg finisher",
                 "fallback_exercise_id": "2138", "repeats": 5, "distance_m": 250, "effort": "sert", "recovery_sec": 60},
            ],
        },
    ],
}


class StructuredImportTests(unittest.TestCase):
    def setUp(self):
        self.out = parse_program_from_input(text=json.dumps(SAMPLE))

    def test_all_days_and_ids_kept(self):
        w = self.out["workouts"]
        self.assertEqual(len(w), 2)
        self.assertEqual([e["id"] for e in w[0]["exercises"]], ["0993", "0314", "0178", "0200"])
        self.assertEqual(w[0]["name"], "Salı: Gym A – İtiş + bacak")
        self.assertEqual(w[0]["exercises"][1]["rest_seconds"], 120)

    def test_superset_letters_become_group(self):
        ex = self.out["workouts"][0]["exercises"]
        self.assertEqual([e.get("superset_group") for e in ex], [None, None, 1, 1])
        self.assertEqual(ex[2]["rest_seconds"], 0)
        self.assertEqual(ex[3]["rest_seconds"], 75)

    def test_cardio_and_per_side(self):
        ex = self.out["workouts"][1]["exercises"]
        self.assertEqual(ex[0]["notes"], "Her taraf için")
        self.assertEqual((ex[1]["sets"], ex[1]["reps"], ex[1]["rest_seconds"]), (5, "250 m", 60))
        self.assertIn("sert", ex[1]["notes"])


if __name__ == "__main__":
    unittest.main()
