import unittest

from app.program_edit import apply_edits, new_exercises, render_program


def prog():
    return {"program_name": "P", "workouts": [
        {"day_number": 1, "name": "A", "exercises": [
            {"id": "0993", "name": "Band pull-apart", "sets": 2, "reps": "20", "rest_seconds": 30, "section": "warmup"},
            {"id": "0025", "name": "Bench", "sets": 4, "reps": "8", "rest_seconds": 120, "notes": "yavaş in"},
            {"id": "0200", "name": "Rope", "sets": 3, "reps": "12", "rest_seconds": 0, "superset_group": 1},
            {"id": "0194", "name": "OH ext", "sets": 3, "reps": "12", "rest_seconds": 60, "superset_group": 1},
        ]},
        {"day_number": 2, "name": "B", "exercises": [
            {"id": "0652", "name": "Barfiks", "sets": 4, "reps": "6", "rest_seconds": 90},
            {"id": "", "name": "Kendi hareketim", "sets": 3, "reps": "10", "rest_seconds": 60, "instructions": "x"},
        ]},
    ]}


def names(p, d):
    return [e["name"] for e in p["workouts"][d]["exercises"]]


class ApplyEditsTests(unittest.TestCase):
    def test_untouched_program_is_identical(self):
        self.assertEqual(apply_edits(prog(), []), prog())

    def test_replace_keeps_scheme_and_others(self):
        p = apply_edits(prog(), [{"op": "replace", "day": 1, "ex": 2, "name": "DB press", "en": "dumbbell bench press"}])
        ex = p["workouts"][0]["exercises"][1]
        self.assertEqual((ex["name"], ex["sets"], ex["reps"], ex["rest_seconds"], ex["id"]), ("DB press", 4, "8", 120, ""))
        self.assertNotIn("notes", ex)
        self.assertEqual(p["workouts"][0]["exercises"][0], prog()["workouts"][0]["exercises"][0])
        self.assertEqual([e["name"] for e in new_exercises(p)], ["DB press"])

    def test_numbers_refer_to_original_list(self):
        # Önce 1. hareketi sil, sonra (eski) 2. hareketi değiştir: yine Bench değişmeli.
        p = apply_edits(prog(), [
            {"op": "remove", "day": 1, "ex": 1},
            {"op": "replace", "day": 1, "ex": 2, "name": "X"},
        ])
        self.assertEqual(names(p, 0), ["X", "Rope", "OH ext"])

    def test_add_after_and_end(self):
        p = apply_edits(prog(), [
            {"op": "add", "day": 2, "after": 1, "name": "Row", "sets": 3, "reps": "10"},
            {"op": "add", "day": 2, "name": "Curl"},
            {"op": "add", "day": 2, "after": 0, "name": "Isınma", "sec": 300, "part": "warmup"},
        ])
        self.assertEqual(names(p, 1), ["Isınma", "Barfiks", "Row", "Kendi hareketim", "Curl"])
        warm = p["workouts"][1]["exercises"][0]
        self.assertEqual((warm["duration_seconds"], warm["reps"], warm["section"]), (300, None, "warmup"))

    def test_set_all(self):
        p = apply_edits(prog(), [{"op": "set", "rest": 90}])
        self.assertTrue(all(e["rest_seconds"] == 90 for w in p["workouts"] for e in w["exercises"]))
        self.assertEqual(p["workouts"][1]["exercises"][1]["instructions"], "x")

    def test_superset_moves_together(self):
        p = apply_edits(prog(), [{"op": "superset", "day": 2, "ex": [1, 2]}])
        g = [e.get("superset_group") for e in p["workouts"][1]["exercises"]]
        self.assertTrue(g[0] and g[0] == g[1])
        self.assertNotEqual(g[0], 1)  # 1. gündeki süpersetle karışmaz

    def test_days(self):
        p = apply_edits(prog(), [
            {"op": "remove_day", "day": 1},
            {"op": "add_day", "name": "C", "exercises": [{"name": "Koşu", "sec": 1800}]},
            {"op": "rename_day", "day": 2, "name": "Sırt"},
            {"op": "rename_program", "name": "Yeni"},
        ])
        self.assertEqual([(w["day_number"], w["name"]) for w in p["workouts"]], [(1, "Sırt"), (2, "C")])
        self.assertEqual(p["program_name"], "Yeni")

    def test_invalid_refs_ignored(self):
        p = apply_edits(prog(), [{"op": "remove", "day": 9, "ex": 1}, {"op": "replace", "day": 1, "ex": 99, "name": "Z"}, "x"])
        self.assertEqual(p, prog())

    def test_render(self):
        text = render_program(prog())
        self.assertIn("Gün 1: A", text)
        self.assertIn("1. Band pull-apart 2x20 mola 30sn [ısınma]", text)
        self.assertIn("[süperset 1]", text)


if __name__ == "__main__":
    unittest.main()
