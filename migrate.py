import requests
import argparse 
import json
parser = argparse.ArgumentParser(description='Migrate data from one token to another')
parser.add_argument("-s",'--source_token', required=True,
                   help='Source token')
parser.add_argument("-d",'--dest_token', required=True,
                   help='Dest token')
parser.add_argument("-o",'--obj_type', required=True,
                   help='Object type: dashboard OR visualization OR savedsearch')

parser.add_argument("-r",'--replace_tokens', nargs="*", required=False,
                   help='Replace tokens in the format SOURCE_STRING::DEST_STRING')


args = parser.parse_args()
url = "https://api-ext.ciscozeus.io/logs/" + args.obj_type
src_headers = { "Zeus-Token": args.source_token}
dest_headers = {"Content-Type":"application/json", "Zeus-Token": args.dest_token}
 
src_resp = requests.get(url, headers=src_headers) 
#print("src_resp = " + src_resp.text)
objs = json.loads(src_resp.text)[args.obj_type + "s"]
#print("objs = " + json.dumps(objs))
payload = json.loads(json.dumps(objs).replace(args.source_token, args.dest_token))

if args.replace_tokens is not None:
  for repl_pair in args.replace_tokens:
    pairs = repl_pair.split("::")
    print("replace",pairs[0],"with",pairs[1])
    payload = json.loads(json.dumps(payload).replace(pairs[0], pairs[1]))
#print("payload = " + json.dumps(payload, indent=2))
resp = requests.post(url, headers=dest_headers, json=payload)
#print("Response = " + str(resp))
print("Completed!")
