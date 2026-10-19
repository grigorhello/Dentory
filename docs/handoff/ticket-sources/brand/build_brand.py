import re, json, os, sys
# Usage: [SRC=… OUT=…] python3 build_brand.py <sha> [owner/repo]
# Brand tickets sit outside the build order (docs/BUILD-ORDER.md and build.py stay untouched). Every `## MS-1NN · title`
# section of brand-assets.md with its `meta:` line becomes OUT/MS-1NN.md, the GitHub issue body, with the asset links and
# previews pinned to <sha>. NUMBERS maps ticket ids to issue numbers once the issues exist; EXTRA mirrors build.py.
SRC=os.environ.get('SRC',os.path.dirname(os.path.abspath(__file__))+'/brand-assets.md'); OUT=os.environ.get('OUT','/tmp/brand-tickets')
SHA=sys.argv[1]; REPO=sys.argv[2] if len(sys.argv)>2 else 'grigorhello/Dentory'
NUMBERS={'MS-158':152,'MS-159':153,'MS-160':154,'MS-161':155,'MS-162':156}
EXTRA={'MS-153':124,'MS-154':125,'MS-155':143,'MS-156':144,'MS-157':145}
RAW=f'https://raw.githubusercontent.com/{REPO}/{SHA}/'; BLOB=f'https://github.com/{REPO}/blob/{SHA}/'
MS={'M0':1,'M1':2,'M2':3,'M3':4,'M4':5}
MSN={'M0':'M0 · Foundations','M1':'M1 · Internal Alpha','M2':'M2 · Clinic Pilot','M3':'M3 · Commercial Beta','M4':'M4 · V1 Launch'}
def num(t):
    n=int(t[3:]); return NUMBERS.get(t, n-29 if n<=152 else EXTRA.get(t))
def ref(t): return f"{t} (#{num(t)})" if num(t) else t
os.makedirs(OUT,exist_ok=True); tickets=[]
for part in re.split(r'^## (?=MS-\d+ · )',open(SRC).read(),flags=re.M)[1:]:
    head,rest=part.split('\n',1); meta_line,body=rest.split('\n',1)
    meta={k.strip():v.strip() for k,v in (kv.split('=',1) for kv in meta_line.replace('meta:','').split(';'))}
    tid,title=head.split(' · ',1); t=dict(id=tid,title=title.strip(),body=body.strip(),**meta)
    deps=[d for d in t.get('depends','').split(',') if d]; assets=[a for a in t.get('assets','').split(',') if a]
    lines=[f"> **Brand ticket, outside the build order** · **Blocked by** {', '.join(ref(d) for d in deps) or 'nothing'} · not in [`docs/BUILD-ORDER.md`]({BLOB}docs/BUILD-ORDER.md): the build thread takes it only when Grigor asks.",
           ">",
           f"> **For Claude Code:** read [`CLAUDE.md`]({BLOB}CLAUDE.md) and follow the [`dentory-ios` skill]({BLOB}.claude/skills/dentory-ios/SKILL.md) (MVVM, feature folders, SOLID, tests). The brand files and their rules are in [`design/brand/`]({BLOB}design/brand/README.md). Product decisions that apply everywhere are in {ref('MS-100')}; the brand decision is D17.",
           "",
           f"**Ticket** {tid} · **Milestone** {MSN[t['milestone']]} · **Priority** {t['priority']} · **Size** {t['size']} pts · **Depends on** {', '.join(ref(d) for d in deps) or 'nothing'}",""]
    if t.get('frames') or t.get('screens') or t.get('prd'):
        lines.append('## Design')
        if t.get('prd'): lines.append(f"- **PRD:** {t['prd']} in [`design/PRD-v1.1.md`]({BLOB}design/PRD-v1.1.md)")
        if t.get('screens'): lines.append(f"- **Prototype:** [`design/project/Dentory Mobile.dc.html`]({BLOB}design/project/Dentory%20Mobile.dc.html), screen key(s) `{t['screens']}`; element ids in PRD Appendix B")
        if t.get('frames'):
            imgs=[]
            for fr in t['frames'].split(','):
                nm=f"f{int(fr[1:]):02d}.png"; imgs.append(f'<a href="{RAW}design/frames/{nm}"><img src="{RAW}design/frames/{nm}" width="220" alt="{nm[:-4]}"></a>')
            lines.append(f"- **Frames:** {t['frames']}"); lines.append(''); lines.append(' '.join(imgs))
        lines.append('')
    if assets:
        lines+=['## Files','',f"All brand files: [`design/brand/`]({BLOB}design/brand/README.md). This ticket uses:",'','| File | Preview |','|---|---|']
        for a in assets:
            name=os.path.basename(a); link=f"[`{a}`]({BLOB}{a})"
            if a.endswith('.png'): prev=f'<img src="{RAW}{a}" height="64" alt="{name}">'+(' (white on transparent: shows on a dark background)' if 'tinted' in name else '')
            elif a.endswith('.svg'): prev=f'<img src="{RAW}{a}?sanitize=true" height="64" alt="{name}">'
            elif a.endswith('.ico'): prev='16, 32 and 48 px (no preview)'
            else: prev='text'
            lines.append(f"| {link} | {prev} |")
        lines.append('')
    b=re.sub(r'\bMS-1\d\d\b', lambda m: ref(m.group(0)) if m.group(0)!=tid else m.group(0), t['body'])
    lines.append(b)
    if t.get('dod')=='ios':
        lines+=['','## Definition of done',
          '- [ ] Follows the `dentory-ios` skill: code in its feature folder or in `Core/DesignSystem`, view without business logic; nothing from its "do not" list.',
          '- [ ] Built only with `Core/DesignSystem` tokens and components; screens match the frames on iPhone and stay within the 720 pt column on iPad.',
          '- [ ] PRD Appendix B element ids kept on every interactive element the change touches.',
          '- [ ] Zero warnings in Swift 6 mode, SwiftLint clean, `swiftui-pro` review run on the diff when SwiftUI code changed.',
          '- [ ] CI green. PR body says `Closes #'+(str(num(tid)) if num(tid) else 'N')+'` and shows simulator screenshots next to the brand files.']
    t['full']='\n'.join(lines); t['number']=num(tid); t['gh_title']=f"{tid} · {t['title']}"
    t['labels']=[f"type:{t['type']}",f"area:{t['area']}",f"priority:{t['priority']}"]; t['milestone_no']=MS[t['milestone']]
    open(f"{OUT}/{tid}.md",'w').write(f"# {t['gh_title']}\n\n"+t['full']+'\n'); tickets.append(t)
json.dump([{k:t[k] for k in ('id','gh_title','labels','milestone','milestone_no','priority','size','type','area','number','depends','full')} for t in tickets],open(OUT+'/tickets.json','w'),indent=1)
print(len(tickets),'tickets;', [t['gh_title'] for t in tickets])
