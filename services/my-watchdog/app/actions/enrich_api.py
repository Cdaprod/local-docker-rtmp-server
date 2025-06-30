import requests, os


api_url = config.get('api_url') or os.environ.get("ENRICH_API_URL")


def run(filepath, config):
    api_url = config.get('api_url')
    if not api_url: return
    print(f"[enrich_api] POST {api_url} with {filepath}")
    files = {'file': open(filepath, 'rb')}
    try:
        r = requests.post(api_url, files=files, timeout=300)
        print(r.status_code, r.text)
    except Exception as e:
        print(f"Failed to enrich: {e}")