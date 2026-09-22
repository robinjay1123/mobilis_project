import urllib.request
import json
import time

for _ in range(8):
    try:
        req = urllib.request.Request(
            'https://api.github.com/repos/robinjay1123/mobilis_project/actions/runs?per_page=1',
            headers={'User-Agent': 'Mozilla/5.0'}
        )
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            runs = data.get('workflow_runs', [])
            if runs:
                r = runs[0]
                commit_hash = r.get('head_sha', '')[:7]
                print(f"Run #{r.get('run_number')} ({commit_hash}): status={r.get('status')} conclusion={r.get('conclusion')}")
                if r.get('status') == 'completed':
                    break
    except Exception as e:
        print('Check error:', e)
    time.sleep(4)
