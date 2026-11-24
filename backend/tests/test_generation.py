"""Program üretiminin iskelet mantığı (yapay zeka olmadan). Çalıştırma:
    cd backend && ./venv/bin/python -m unittest discover tests
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# main.py içe aktarılmıyor; yalnızca ai_service gerekli ve Supabase istemcisi istemiyor.
from app import ai_service, exercise_catalog as catalog, workout_planner as planner
from app.schemas import Logistics, UserOnboardingData


def make_user(**kw):
    base = dict(
        user_id="u", age=25, gender="Erkek", experience="Orta", primary_goal="Kas Kütlesi",
        specific_interests=["Göğüs"], health_restrictions=["Yok"],
        logistics=Logistics(location=["Spor Salonu"], equipment=[], days_per_week=4, max_duration_min=60),
    )
    base.update(kw)
    return UserOnboardingData(**base)


def no_ai(*args, **kwargs):
    raise RuntimeError("yapay zeka yok")


class GenerationTest(unittest.TestCase):
    def setUp(self):
        self._orig = ai_service.generate_json
        ai_service.generate_json = no_ai  # kural tabanlı yol

    def tearDown(self):
        ai_service.generate_json = self._orig

    def test_day_count_and_exercise_count(self):
        for days in range(1, 8):
            u = make_user(logistics=Logistics(location=["Spor Salonu"], equipment=[], days_per_week=days, max_duration_min=60))
            program = ai_service.generate_workout_program(u)
            self.assertEqual(len(program["workouts"]), days)
            for w in program["workouts"]:
                self.assertEqual(len(w["exercises"]), 8, w["name"])

    def test_no_repeated_exercise_within_day(self):
        program = ai_service.generate_workout_program(make_user())
        for w in program["workouts"]:
            ids = [e["id"] for e in w["exercises"]]
            self.assertEqual(len(ids), len(set(ids)))

    def test_ids_exist_and_names_are_canonical(self):
        program = ai_service.generate_workout_program(make_user())
        for w in program["workouts"]:
            for e in w["exercises"]:
                self.assertEqual(catalog.get_by_id(e["id"])["name"], e["name"])

    def test_home_without_equipment_has_no_barbell(self):
        u = make_user(logistics=Logistics(location=["Ev"], equipment=["Dambıl"], days_per_week=3, max_duration_min=45))
        program = ai_service.generate_workout_program(u)
        for w in program["workouts"]:
            for e in w["exercises"]:
                self.assertIn(catalog.get_by_id(e["id"])["equipment"], {"body weight", "dumbbell"})

    def test_no_pull_up_without_bar(self):
        u = make_user(logistics=Logistics(location=["Ev"], equipment=["Dambıl"], days_per_week=3, max_duration_min=45))
        program = ai_service.generate_workout_program(u)
        names = [e["name"] for w in program["workouts"] for e in w["exercises"]]
        self.assertFalse([n for n in names if "pull-up" in n or "chin" in n])

    def test_health_restriction_filters_exercises(self):
        u = make_user(health_restrictions=["Diz"])
        names = [e["name"] for w in ai_service.generate_workout_program(u)["workouts"] for e in w["exercises"]]
        self.assertFalse([n for n in names if "jump" in n or "lunge" in n])

    def test_sets_reps_vary_by_exercise_type(self):
        program = ai_service.generate_workout_program(make_user())
        schemes = {(e["sets"], e["reps"], e["rest_seconds"]) for w in program["workouts"] for e in w["exercises"]}
        self.assertGreater(len(schemes), 1)

    def test_timed_exercises_have_no_reps(self):
        program = ai_service.generate_workout_program(make_user(specific_interests=["Karın"]))
        for w in program["workouts"]:
            for e in w["exercises"]:
                if e["duration_seconds"]:
                    self.assertIsNone(e["reps"])

    def test_ai_choices_are_validated(self):
        """Yapay zekanın uydurduğu/uygunsuz id'ler atılır, eksikler havuzdan tamamlanır."""
        ai_service.generate_json = lambda *a, **k: {
            "program_name": "Test", "description": "x",
            "days": [{"exercises": [{"id": "9999", "note": "uydurma"}, {"id": "0025", "note": "gerçek"}]}] * 4,
        }
        program = ai_service.generate_workout_program(make_user())
        self.assertEqual(program["program_name"], "Test")
        for w in program["workouts"]:
            self.assertEqual(len(w["exercises"]), 8)
            self.assertNotIn("9999", [e["id"] for e in w["exercises"]])


class PlannerTest(unittest.TestCase):
    def test_scale_respects_total(self):
        for total in range(4, 9):
            plan = planner.build_plan(4, "Orta", ["pectorals", "biceps"], total)
            for d in plan:
                self.assertEqual(sum(c for _, c in d["targets"]), total)

    def test_beginner_three_days_is_full_body(self):
        plan = planner.build_plan(3, "Başlangıç", [], 6)
        self.assertTrue(all(d["name"].startswith("Tüm Vücut") for d in plan))


if __name__ == "__main__":
    unittest.main()
