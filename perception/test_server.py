import base64
import json
import os
import threading
import unittest
import urllib.error
import urllib.request
from unittest.mock import patch
from http.server import ThreadingHTTPServer
import server
import evaluation


def observation():
    return {'vehiclePresent': True, 'usability': 'limited',
            'regions': [{'id': 'front', 'confidence': 0.8}], 'guidance': 'Front is visible in dim light.'}


class PerceptionTests(unittest.TestCase):
    def test_health_endpoint_is_public_and_bounded(self):
        http = ThreadingHTTPServer(('127.0.0.1', 0), server.Handler)
        thread = threading.Thread(target=http.serve_forever, daemon=True); thread.start()
        try:
            with urllib.request.urlopen(f'http://127.0.0.1:{http.server_port}/healthz') as response:
                self.assertEqual(response.status, 200)
                self.assertEqual(json.load(response)['status'], 'ok')
        finally:
            http.shutdown(); http.server_close(); thread.join()

    def test_rejects_contradictions_duplicates_and_invalid_confidence(self):
        for change in [
            {'vehiclePresent': False},
            {'regions': [{'id': 'front', 'confidence': float('nan')}]},
            {'regions': [{'id': 'roof', 'confidence': 2}]},
            {'regions': [{'id': 'unknown', 'confidence': 0.8}]},
            {'regions': [{'id': 'front', 'confidence': 0.8}] * 2}]:
            with self.assertRaises(ValueError):
                server.validate_observation(dict(observation(), **change))
        for guidance in ['', 'safe to drive', 'Engine looks healthy', '%%%%']:
            with self.assertRaises(ValueError):
                server.validate_observation(dict(observation(), guidance=guidance))
        with self.assertRaises(ValueError):
            server.validate_observation(dict(observation(), usability='unusable'))

    def test_real_http_boundary_joins_frame_and_enforces_auth(self):
        with patch.dict(os.environ, {'PERCEPTION_ACCESS_TOKEN': 'test-only-token', 'OPENAI_API_KEY': 'test-only-key'}), patch.object(server, 'analyze', return_value=observation()) as model:
            http = ThreadingHTTPServer(('127.0.0.1', 0), server.Handler)
            thread = threading.Thread(target=http.serve_forever, daemon=True)
            thread.start()
            try:
                payload = json.dumps({'frameID': 'night-front-1', 'imageBase64': base64.b64encode(b'\xff\xd8test\xff\xd9').decode()}).encode()
                url = f'http://127.0.0.1:{http.server_port}/v1/observe'
                request = urllib.request.Request(url, data=payload, headers={'Authorization': 'Bearer test-only-token'})
                with urllib.request.urlopen(request) as response:
                    value = json.load(response)
                self.assertEqual(value['frameID'], 'night-front-1')
                self.assertEqual(value['regions'][0]['id'], 'front')
                self.assertEqual(value['usability'], 'limited')
                model.assert_called_once()
                with self.assertRaises(urllib.error.HTTPError) as caught:
                    urllib.request.urlopen(urllib.request.Request(url, data=payload))
                self.assertEqual(caught.exception.code, 401)
            finally:
                http.shutdown()
                http.server_close()
                thread.join()

    def test_responses_payload_and_strict_output(self):
        output = {'status': 'completed', 'output': [{'type': 'message', 'content': [{'type': 'output_text', 'text': json.dumps(observation())}]}]}
        class Response:
            def __enter__(self): return self
            def __exit__(self, *_): pass
            def read(self): return json.dumps(output).encode()
        with patch('urllib.request.urlopen', return_value=Response()) as upstream:
            result = server.analyze(b'\xff\xd8test\xff\xd9', api_key='test-only-key', model='gpt-4.1-mini')
            self.assertEqual(result['usability'], 'limited')
            request = upstream.call_args.args[0]
            payload = json.loads(request.data)
            self.assertFalse(payload['store'])
            self.assertTrue(payload['text']['format']['strict'])
            self.assertTrue(payload['input'][0]['content'][1]['image_url'].startswith('data:image/jpeg;base64,'))
            self.assertNotIn('requestedRegion', payload)

    def test_evaluation_validation_requires_submitted_evidence_and_blocks_diagnosis(self):
        value = {'findings': [{'id': 'f1', 'region': 'rear', 'issue': 'scratch', 'confidence': 0.88,
                               'evidenceRefs': ['frame-1'], 'recommendedCheck': 'Review the rear panel with a qualified person'}],
                 'resaleLow': 18000, 'resaleHigh': 22000,
                 'longevityParagraph': 'This is a cautious planning estimate; photos cannot establish hidden mechanical condition or predict a lifespan.',
                 'replacementHorizon': 'Reassess after the next 12 months.',
                 'financialServicesRecommendation': 'Confirm the payoff or residual and mileage charges with Toyota Financial Services before deciding.',
                 'leaseBurden': None, 'assumptions': ['Trim and service history were not verified.'], 'uncertainty': ['Visible observations are not a diagnosis.']}
        self.assertEqual(evaluation.validate(value, {'frame-1'})['findings'][0]['issue'], 'scratch')
        with self.assertRaises(ValueError):
            evaluation.validate(value, {'other-frame'})
        bad = dict(value, findings=[dict(value['findings'][0], issue='engine failure')])
        with self.assertRaises(ValueError):
            evaluation.validate(bad, {'frame-1'})


if __name__ == '__main__':
    unittest.main()
