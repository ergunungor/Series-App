import unittest
from unittest import mock

from app import exercise_catalog as catalog
from app import llm
from app.ai_service import _expand_compact, estimate_minutes


class AliasTests(unittest.TestCase):
    def test_all_alias_targets_exist(self):
        self.assertEqual(catalog.missing_alias_targets(), [])

    def test_common_names(self):
        cases = {
            "Bench Press": "barbell bench press",
            "Back Squat": "barbell full squat",
            "Lat Pulldown": "cable lat pulldown full range of motion",
            "Farmer's Walk": "farmers walk",
            "barfiks": "pull-up",
            "şınav": "push-up",
            "Lunge (each leg)": "dumbbell lunge",
            "lunge her bacak": "dumbbell lunge",
            "köprü (glute bridge)": "low glute bridge on floor",
            "avustralya barfiksi": "inverted row",
        }
        for name, expected in cases.items():
            with self.subTest(name=name):
                hit = catalog.alias_match(name)
                self.assertIsNotNone(hit)
                self.assertEqual(hit["name"], expected)

    def test_unknown_name(self):
        self.assertIsNone(catalog.alias_match("duvarda oturma"))


class CompactSchemaTests(unittest.TestCase):
    def test_expand(self):
        p = {"workouts": [{"name": "G1", "min": 50, "exercises": [
            {"name": "Plank", "en": "plank", "sets": 3, "reps": None, "sec": 45, "rest": 30},
            {"name": "A", "en": "a", "sets": 3, "reps": "10", "ss": 1, "drop": 2},
        ]}]}
        _expand_compact(p)
        w = p["workouts"][0]
        self.assertEqual((w["day_number"], w["estimated_duration_min"]), (1, 50))
        e0, e1 = w["exercises"]
        self.assertEqual((e0["english_name"], e0["duration_seconds"], e0["rest_seconds"], e0["reps"]),
                         ("plank", 45, 30, None))
        self.assertEqual((e1["superset_group"], e1["drop_sets"], e1["rest_seconds"]), (1, 2, 60))

    def test_estimate_minutes(self):
        self.assertEqual(estimate_minutes([{"sets": 4, "rest_seconds": 120}] * 5), 55)
        self.assertEqual(estimate_minutes([]), 10)


class TruncationTests(unittest.TestCase):
    def test_length_finish_raises(self):
        resp = mock.Mock(status_code=200)
        resp.json.return_value = {"choices": [{"finish_reason": "length", "message": {"content": "{"}}]}
        with mock.patch.dict("os.environ", {"LLM_API_KEY": "x"}), \
                mock.patch.object(llm.httpx, "post", return_value=resp):
            with self.assertRaises(llm.LLMTruncatedError):
                llm._openai_request("openai/gpt-oss-120b", "p")

    def test_sends_max_tokens(self):
        resp = mock.Mock(status_code=200)
        resp.json.return_value = {"choices": [{"finish_reason": "stop", "message": {"content": "{}"}}]}
        with mock.patch.dict("os.environ", {"LLM_API_KEY": "x"}), \
                mock.patch.object(llm.httpx, "post", return_value=resp) as post:
            llm._openai_request("openai/gpt-oss-120b", "p")
        body = post.call_args.kwargs["json"]
        self.assertGreaterEqual(body["max_completion_tokens"], 8000)


if __name__ == "__main__":
    unittest.main()


class SectionTests(unittest.TestCase):
    def test_part_becomes_section(self):
        p = {"workouts": [{"name": "G", "exercises": [
            {"name": "Koşu", "en": "treadmill", "sets": 1, "sec": 300, "part": "warmup"},
            {"name": "Bench", "en": "bench press", "sets": 3, "reps": "8"},
            {"name": "Esneme", "en": "stretch", "sets": 1, "sec": 30, "part": "cooldown"},
        ]}]}
        _expand_compact(p)
        self.assertEqual([e.get("section") for e in p["workouts"][0]["exercises"]], ["warmup", None, "cooldown"])

    def test_structured_warmup_marked(self):
        from app.ai_service import program_from_structured_json
        out = program_from_structured_json({"schedule": [{"title_tr": "A", "warmup": [
            {"exercise_id": "0993", "sets": 2, "reps": "20"}], "items": [
            {"exercise_id": "0025", "sets": 3, "reps": "8"}]}]})
        self.assertEqual([e.get("section") for e in out["workouts"][0]["exercises"]], ["warmup", None])
