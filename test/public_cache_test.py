import importlib.util
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location(
    'public_cache', Path(__file__).parents[1] / 'tool' / 'update-public-cache.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class PublicCacheTest(unittest.TestCase):
    def test_merge_reserves_a_share_for_each_topic(self):
        per_topic = [
            [{'full_name': f'large/{i}', 'stargazers_count': 1000 - i}
             for i in range(20)],
            [{'full_name': f'small/{i}', 'stargazers_count': 20 - i}
             for i in range(20)],
        ]
        merged = MODULE.merge_topics(per_topic)
        self.assertEqual(len(merged), MODULE.PAGE_SIZE)
        self.assertGreaterEqual(
            len([item for item in merged if item['full_name'].startswith('small/')]),
            MODULE.PAGE_SIZE // 2)

    def test_merge_deduplicates_repositories(self):
        shared = {'full_name': 'same/repo', 'stargazers_count': 50}
        merged = MODULE.merge_topics([[shared], [shared]])
        self.assertEqual([item['full_name'] for item in merged], ['same/repo'])


if __name__ == '__main__':
    unittest.main()
