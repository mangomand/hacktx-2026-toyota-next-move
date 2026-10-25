import math
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from surface_field import surface_distances

class SurfaceFieldTests(unittest.TestCase):
    def test_distance_follows_curved_surface_not_euclidean_sphere(self):
        vs=[(0,0,0),(0,1,0),(1,1,0),(1,0,0)]
        d=surface_distances(vs,[(0,1),(1,2),(2,3)],vs[0],[True]*4)
        self.assertEqual(d,[0,1,2,3])
    def test_unseen_and_disconnected_remain_unreachable(self):
        vs=[(0,0,0),(1,0,0),(2,0,0),(3,0,0)]
        d=surface_distances(vs,[(0,1),(1,2)],vs[0],[True,False,True,True])
        self.assertEqual(d[0],0)
        self.assertTrue(all(math.isinf(v) for v in d[1:]))
    def test_split_uv_seams_connect_but_forbidden_duplicate_does_not(self):
        vs=[(0,0,0),(1,0,0),(1,0,0),(2,0,0),(1,0,0)]
        d=surface_distances(vs,[(0,1),(2,3)],vs[0],[True,True,True,True,False])
        self.assertEqual(d[:4],[0,1,1,2]);self.assertTrue(math.isinf(d[4]))
    def test_no_permission_means_no_reveal(self):
        self.assertTrue(all(math.isinf(v) for v in surface_distances([(0,0,0)],[],(0,0,0),[False])))
    def test_rejects_invalid_geometry_and_seed(self):
        for args in [([(math.nan,0,0)],[],(0,0,0),[True]), ([(0,0,0)],[],(math.inf,0,0),[True]), ([(0,0,0)],[(0,2)],(0,0,0),[True]), ([(0,0,0)],[],(0,0,0),[])]:
            with self.assertRaises(ValueError):surface_distances(*args)

if __name__=='__main__':unittest.main()
