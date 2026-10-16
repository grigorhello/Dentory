import re, json, os, glob, sys
SRC='/mnt/project-files/medisave-plan-v2/src'; OUT='/mnt/project-files/medisave-plan-v2'
SHA=sys.argv[1]; FR='/home/claude/MediSave/design/frames'
RAW=f'https://raw.githubusercontent.com/grigorhello/MediSave/{SHA}/design/frames/'
BLOB='https://github.com/grigorhello/MediSave/blob/'+SHA+'/'
MS={'M0':1,'M1':2,'M2':3,'M3':4,'M4':5}
MSN={'M0':'M0 · Foundations','M1':'M1 · Internal Alpha','M2':'M2 · Clinic Pilot','M3':'M3 · Commercial Beta','M4':'M4 · V1 Launch'}
tickets=[]
for f in sorted(glob.glob(SRC+'/*.md')):
    txt=open(f).read()
    for part in re.split(r'^## (?=MS-\d+ · )',txt,flags=re.M)[1:]:
        head,rest=part.split('\n',1)
        meta_line,body=rest.split('\n',1)
        meta=dict(kv.strip().split('=',1) for kv in meta_line.replace('meta:','').split(';'))
        body=re.split(r'^# M\d', body, flags=re.M)[0].strip()
        tid,title=head.split(' · ',1)
        tickets.append(dict(id=tid,title=title.strip(),body=body,**{k:v.strip() for k,v in meta.items()}))
EXTRA={'MS-153':124,'MS-154':125}
num={t['id']:(int(t['id'][3:])-29 if int(t['id'][3:])<=152 else EXTRA[t['id']]) for t in tickets}
# build order: Kahn's algorithm, ties broken by milestone, priority, then ticket number
byid={t['id']:t for t in tickets}
DEPS={t['id']:[d for d in t['depends'].split(',') if d] for t in tickets}
unblocks={i:[] for i in byid}
for i,ds in DEPS.items():
    for d in ds: unblocks[d].append(i)
done=[]; left=set(byid)
while left:
    ready=[i for i in left if all(d in done for d in DEPS[i])]
    ready.sort(key=lambda i:(byid[i]['milestone'],byid[i]['priority'],int(i[3:])))
    done.append(ready[0]); left.remove(ready[0])
step={i:k+1 for k,i in enumerate(done)}
N=len(done)
tickets.sort(key=lambda t:step[t['id']])
def ref(m): return f"{m} (#{num[m]})" if m in num else m
for t in tickets:
    frames=[x for x in t['frames'].split(',') if x]
    deps=[x for x in t['depends'].split(',') if x]
    blk=', '.join(ref(d) for d in sorted(DEPS[t['id']],key=lambda d:step[d])) or 'nothing'
    unb=', '.join(ref(d) for d in sorted(unblocks[t['id']],key=lambda d:step[d])) or 'nothing'
    lines=[f"> **Build step {step[t['id']]} of {N}** · **Blocked by** {blk} · **Unblocks** {unb}",
           ">",
           f"> **For Claude Code:** read [`CLAUDE.md`]({BLOB}CLAUDE.md) and follow the [`medisave-ios` skill]({BLOB}.claude/skills/medisave-ios/SKILL.md) (MVVM, feature folders, SOLID, tests). Then read this ticket, its frames and the PRD section before writing code. Do not start while a blocker is open; the full sequence is in [`docs/BUILD-ORDER.md`]({BLOB}docs/BUILD-ORDER.md). Product decisions that apply everywhere are in {ref('MS-100')}.",
           "",
           f"**Ticket** {t['id']} · **Milestone** {MSN[t['milestone']]} · **Priority** {t['priority']} · **Size** {t['size']} pts · **Depends on** {', '.join(ref(d) for d in deps) or 'nothing'}",""]
    if frames or t['screens'] or t['prd']:
        lines.append('## Design')
        if t['prd']: lines.append(f"- **PRD:** {t['prd']} in [`design/PRD-v1.1.md`]({BLOB}design/PRD-v1.1.md)")
        if t['screens']: lines.append(f"- **Prototype:** [`design/project/MediSave Mobile.dc.html`]({BLOB}design/project/MediSave%20Mobile.dc.html), screen key(s) `{t['screens'].replace(',', '`, `')}`; element ids in PRD Appendix B")
        lines.append(f"- **Design system:** [`design/project/_ds/…/`]({BLOB}design/project/_ds/medisave-design-system-1666cb0d-4269-4a87-8f99-be4e150e5326) (tokens, components, rules)")
        if frames:
            imgs=[]
            for fr in frames:
                n=int(fr[1:]); base=f'f{n:02d}'
                for p in sorted(glob.glob(f'{FR}/{base}.png'))+sorted(glob.glob(f'{FR}/{base}-*.png')):
                    nm=os.path.basename(p)
                    imgs.append(f'<a href="{RAW}{nm}"><img src="{RAW}{nm}" width="220" alt="{nm[:-4]}"></a>')
            lines.append(f"- **Frames:** {', '.join(frames)} (click to enlarge; `-2`, `-3` are the same screen scrolled down)")
            lines.append(''); lines.append(' '.join(imgs))
        lines.append('')
    b=re.sub(r'\bMS-1\d\d\b', lambda m: ref(m.group(0)) if m.group(0)!=t['id'] else m.group(0), t['body'])
    b=b.replace('`design/frames/f','`design/frames/f')
    lines.append(b)
    if t['type'] in ('feature','tech'):
        lines+=['','## Definition of done',
          '- [ ] Follows the `medisave-ios` skill: code in its feature folder, view without business logic, `@Observable` view model with injected protocols, repository returning domain types; nothing from its "do not" list.',
          '- [ ] Built only with `Core/DesignSystem` tokens and components; screens match the frames above on iPhone and stay within the 720 pt column on iPad.',
          '- [ ] PRD Appendix B element ids set as `.accessibilityIdentifier` on every interactive element.',
          '- [ ] Swift Testing unit tests for view models and rules, pgTAP tests for any migration or RPC, XCUITest flow added or updated when a user flow changes.',
          '- [ ] Zero warnings in Swift 6 mode, SwiftLint clean, `swiftui-pro` review run on the diff.',
          '- [ ] CI green. PR body says `Closes #'+str(num[t['id']])+'` and shows simulator screenshots next to the frame images.']
    t['number']=num[t['id']]; t['step']=step[t['id']]
    t['full']='\n'.join(lines)
    t['labels']=[f"type:{t['type']}",f"area:{t['area']}",f"priority:{t['priority']}"]
    t['milestone_no']=MS[t['milestone']]
    t['gh_title']=f"{t['id']} · {t['title']}"
    open(f"{OUT}/tickets/{t['id']}.md",'w').write(f"# {t['gh_title']}\n\n"+t['full']+'\n')
json.dump([{k:t[k] for k in ('id','gh_title','labels','milestone','milestone_no','priority','size','type','area','number','frames','depends','full','step')} for t in tickets],open(OUT+'/tickets.json','w'),indent=1)
open(OUT+'/all-tickets.md','w').write('\n\n---\n\n'.join(f"# {t['gh_title']}\n\n{t['full']}" for t in tickets))
print(len(tickets), sum(int(t['size']) for t in tickets))
from collections import Counter; print(Counter(t['milestone'] for t in tickets)); print(max(len(t['full']) for t in tickets))

# docs/BUILD-ORDER.md for the repo
REPO='https://github.com/grigorhello/MediSave/issues/'
out=['# Build order','',f'Build the {N} tickets in this order. A ticket can start when every ticket in its "Blocked by" column is merged. Tickets next to each other with no link between them can run in parallel.','',
     'Generated from the ticket dependencies (ties broken by milestone, then priority). Each GitHub issue repeats its step at the top.','']
cur=None
for t in tickets:
    if t['milestone']!=cur:
        cur=t['milestone']; out+=['',f'## {MSN[cur]}','','| Step | Ticket | Issue | Pri | Pts | Blocked by |','|---|---|---|---|---|---|']
    b=', '.join(f"[{d}]({REPO}{num[d]})" for d in sorted(DEPS[t['id']],key=lambda d:step[d])) or '—'
    out.append(f"| {t['step']} | {t['id']} · {t['title']} | [#{t['number']}]({REPO}{t['number']}) | {t['priority']} | {t['size']} | {b} |")
open(OUT+'/BUILD-ORDER.md','w').write('\n'.join(out)+'\n')
