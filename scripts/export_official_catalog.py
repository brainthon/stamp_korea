"""Export only published official DB records into the app's offline catalog.
Uses the public project key in --config; never needs a service-role credential.
"""
import argparse,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--config',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();cfg=json.loads(a.config.read_text());records=[];offset=0
while True:
    url=cfg['SUPABASE_URL']+'/rest/v1/official_stamp_catalog?select=data&source_verified=eq.true&order=id&limit=1000&offset='+str(offset)
    config='url = "'+url+'"\nheader = "apikey: '+cfg['SUPABASE_PUBLISHABLE_KEY']+'"\n'
    result=subprocess.run(['curl','--silent','--show-error','--fail','--max-time','30','--config','-'],input=config,text=True,capture_output=True,check=True)
    rows=json.loads(result.stdout);records.extend(row['data'] for row in rows)
    if len(rows)<1000:break
    offset+=1000
if not records:raise SystemExit('No published records; existing bundle preserved')
records.sort(key=lambda r:(r['id']!='epost_3834',r['id']))
a.output.write_text(json.dumps(records,ensure_ascii=False,indent=2))
print('Exported',len(records),'official records')
