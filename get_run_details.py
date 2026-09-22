import urllib.request
import json

req = urllib.request.Request('https://api.github.com/repos/robinjay1123/mobilis_project/actions/runs', headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req) as resp:
    runs = json.loads(resp.read().decode('utf-8'))['workflow_runs']

latest = runs[0]
print(f"Run #{latest['run_number']}: {latest['id']}, conclusion: {latest['conclusion']}")

# Check annotations
check_runs_url = f"https://api.github.com/repos/robinjay1123/mobilis_project/check-runs/{latest['id']}" # or check-suites
# Get jobs
jobs_url = latest['jobs_url']
req_jobs = urllib.request.Request(jobs_url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req_jobs) as resp:
    jobs = json.loads(resp.read().decode('utf-8'))['jobs']

for job in jobs:
    job_id = job['id']
    print(f"Job: {job['name']} ({job_id}) - {job['conclusion']}")
    ann_url = f"https://api.github.com/repos/robinjay1123/mobilis_project/check-runs/{job_id}/annotations"
    try:
        req_ann = urllib.request.Request(ann_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req_ann) as resp_ann:
            anns = json.loads(resp_ann.read().decode('utf-8'))
            for a in anns:
                print("ANNOTATION:", a.get('message'))
    except Exception as e:
        print("Ann error:", e)
