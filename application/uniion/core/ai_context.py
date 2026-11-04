"""Bounded source projections, pseudonymization and verifiable extractive citations.

No inference provider, persistence or permissions live here. Adapters supply only
resources read through their current authorized contracts.
"""
import hashlib
import json
import re
import unicodedata
from html import unescape
from html.parser import HTMLParser
from uniion.core.contracts import Denied, Unavailable


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'))


def digest(value):
    return hashlib.sha256(canonical(value).encode()).hexdigest()


class TextOnly(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True); self.parts=[]; self.skip=0
    def handle_starttag(self, tag, attrs):
        if tag in ('script','style'): self.skip += 1
        if tag in ('p','br','div','li','tr'): self.parts.append('\n')
    def handle_endtag(self, tag):
        if tag in ('script','style') and self.skip: self.skip -= 1
    def handle_data(self, data):
        if not self.skip: self.parts.append(data)


def plain(value):
    if not isinstance(value,str): raise Denied('ai_invalid_source')
    # HTML is only decoded for text; never executed or fetched.
    parser=TextOnly(); parser.feed(value)
    text=unicodedata.normalize('NFKC',''.join(parser.parts))
    text=''.join(c for c in text if unicodedata.category(c) not in ('Cf','Cc') or c in '\n\t')
    return re.sub(r'[ \t]+',' ',text).strip()


class Masker:
    """Deterministic minimization, NOT a guarantee of exhaustive anonymization."""
    patterns=(
        ('COURRIEL',r'[\w.+-]+\s*@\s*[\w.-]+\.[A-Za-z]{2,}'),
        ('LIEN',r'https?://[^\s<>]+'),
        ('IBAN',r'\b[A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]){11,30}\b'),
        ('IDENTIFIANT',r'\b[12]\s?\d{2}\s?\d{2}\s?\d{2}\s?\d{3}\s?\d{3}(?:\s?\d{2})?\b'),
        ('TELEPHONE',r'(?<!\w)(?:\+33\s?(?:\(0\))?|0)[1-9](?:[ .-]?\d{2}){4}(?!\d)'),
        ('UUID',r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b'),
    )
    def __init__(self, names=()):
        self.names=sorted({plain(n) for n in names if isinstance(n,str) and len(n.strip())>=3},key=len,reverse=True)
        self.tokens={};self.clear={};self.count=0
    def token(self,kind,text):
        key=(kind,text.casefold())
        if key not in self.tokens:
            self.tokens[key]=f'[{kind}_{len(self.tokens)+1}]';self.clear[self.tokens[key]]=text
        self.count+=1
        return self.tokens[key]
    def mask(self,text):
        text=plain(text)
        for name in self.names:
            text=re.sub(r'(?<!\w)'+re.escape(name)+r'(?!\w)',lambda m:self.token('PERSONNE',m[0]),text,flags=re.I)
        for kind,pattern in self.patterns:
            text=re.sub(pattern,lambda m,k=kind:self.token(k,m[0]),text,flags=re.I)
        return text


def prepare(sources):
    if not 1<=len(sources)<=8: raise Denied('ai_source_count')
    masker=Masker(n for source in sources for n in source.get('names',[]))
    passages=[];citations=[]
    for i,source in enumerate(sources,1):
        label=f'S{i}'
        parts=[]
        for j,item in enumerate(source['passages'],1):
            text=masker.mask(item['text'])
            if text:parts.append({'id':f'P{j}','text':text})
        if not parts:raise Denied('ai_empty_source')
        passages.append({'source':label,'passages':parts})
        citations.append({'source':label,'kind':source['ref']['kind'],'title':masker.mask(source['title']),
                          'version':source['version'],'passages':{f'P{j}':p['location'] for j,p in enumerate(source['passages'],1)}})
    # Refuse oversize context instead of silently truncating cited evidence.
    if sum(len(p['text']) for s in passages for p in s['passages'])>24000:raise Denied('ai_context_too_large')
    return {'sources':passages,'citations':citations,'masked':masker.count}


TOKEN=re.compile(r'\[(PERSONNE|COURRIEL|LIEN|IBAN|IDENTIFIANT|TELEPHONE|UUID)_[0-9]+\]')


def token_map(sources):
    """Token -> clear text, by masking the sources exactly as prepare() does (R12).

    Masking is deterministic: for sources whose fingerprint is unchanged, the
    tokens are those the model saw. Server side only; never sent to the model."""
    masker=Masker(n for source in sources for n in source.get('names',[]))
    for source in sources:
        for item in source['passages']:masker.mask(item['text'])
        masker.mask(source['title'])
    return dict(masker.clear)


def reidentify(text, mapping):
    """Replace masking tokens by their clear value; refuse any token that cannot be restored."""
    restored=TOKEN.sub(lambda m:mapping.get(m[0],m[0]),text)
    if TOKEN.search(restored):raise Denied('ai_masked_tokens')
    return restored


def verify_excerpts(raw, context):
    if not isinstance(raw,str) or len(raw)>16000:raise Unavailable('ai_citations_invalid')
    try:
        # JSON only; no prose or fenced envelope that could mask ignored output.
        def unique(pairs):
            value={}
            for key,item in pairs:
                if key in value:raise ValueError()
                value[key]=item
            return value
        result=json.loads(raw,object_pairs_hook=unique)
        if not isinstance(result,dict) or set(result)!={'excerpts'} or not isinstance(result['excerpts'],list) or not 1<=len(result['excerpts'])<=12:raise ValueError()
        rows=[];seen=set()
        for item in result['excerpts']:
            if not isinstance(item,dict) or set(item)!={'source','passage','quote'} or any(not isinstance(v,str) for v in item.values()):raise ValueError()
            key=(item['source'],item['passage'],item['quote'])
            if key in seen:raise ValueError()
            seen.add(key)
            source=next(s for s in context['sources'] if s['source']==item['source'])
            passage=next(p for p in source['passages'] if p['id']==item['passage'])
            if not 8<=len(item['quote'].strip())<=1000 or item['quote'] not in passage['text']:raise ValueError()
            citation=next(c for c in context['citations'] if c['source']==item['source'])
            rows.append({**item,'title':citation['title'],'kind':citation['kind'],'version':citation['version'],
                         'location':citation['passages'][item['passage']]})
        return rows
    except (ValueError,KeyError,TypeError,StopIteration):
        raise Unavailable('ai_citations_invalid') from None
