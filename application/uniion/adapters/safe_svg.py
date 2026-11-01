"""Strict static SVG subset. Reject active/remote content rather than silently altering it."""
import re,xml.etree.ElementTree as ET
from uniion.core.contracts import Denied
TAGS=set('svg g defs path rect circle ellipse line polyline polygon text tspan title desc linearGradient radialGradient stop clipPath mask'.split())
ATTRS=set('id viewBox width height x y x1 y1 x2 y2 cx cy r rx ry dx dy d points transform fill fill-opacity fill-rule stroke stroke-width stroke-opacity stroke-linecap stroke-linejoin stroke-miterlimit stroke-dasharray stroke-dashoffset opacity clip-path clip-rule mask gradientUnits gradientTransform offset stop-color stop-opacity spreadMethod fx fy fr preserveAspectRatio font-family font-size font-weight font-style text-anchor dominant-baseline letter-spacing word-spacing style'.split())
CSS=set('fill fill-opacity fill-rule stroke stroke-width stroke-opacity stroke-linecap stroke-linejoin stroke-miterlimit stroke-dasharray stroke-dashoffset opacity clip-path clip-rule mask stop-color stop-opacity font-family font-size font-weight font-style text-anchor dominant-baseline letter-spacing word-spacing'.split())

def validate(raw):
 try:text=raw.decode('utf-8-sig')
 except UnicodeError:raise Denied() from None
 if len(raw)>2*1024*1024 or re.search(r'<!|<\?(?!xml\s)',text,re.I):raise Denied()
 try:root=ET.fromstring(text)
 except ET.ParseError:raise Denied() from None
 if root.tag!='{http://www.w3.org/2000/svg}svg':raise Denied()
 ids=set();refs=[];count=0
 def value(v):
  if len(v)>250000 or re.search(r'[\\<>\x00-\x08\x0b\x0c\x0e-\x1f]|(?:https?:|file:|data:|javascript:|expression\s*\(|@)',v,re.I):raise Denied()
  for ref in re.findall(r'url\(([^)]*)\)',v,re.I):
   if not re.fullmatch(r'#[A-Za-z_][\w.-]{0,100}',ref):raise Denied()
   refs.append(ref[1:])
  if re.search('url',re.sub(r'url\(#[A-Za-z_][\w.-]{0,100}\)','',v,flags=re.I),re.I):raise Denied()
 def visit(el,depth):
  nonlocal count
  count+=1
  if count>5000 or depth>32 or not el.tag.startswith('{http://www.w3.org/2000/svg}') or el.tag.split('}')[1] not in TAGS:raise Denied()
  for key,v in el.attrib.items():
   if key not in ATTRS:raise Denied()
   value(v)
   if key=='id':
    if not re.fullmatch(r'[A-Za-z_][\w.-]{0,100}',v) or v in ids:raise Denied()
    ids.add(v)
   if key=='style':
    for part in filter(str.strip,v.split(';')):
     if ':' not in part or part.split(':',1)[0].strip() not in CSS:raise Denied()
  for child in el:visit(child,depth+1)
 visit(root,0)
 if any(ref not in ids for ref in refs):raise Denied()
 # No <use>, image, filters, animation, stylesheets or links; no reference expansion loops.
 for el in root.iter():
  if el.tag.rsplit('}',1)[-1] in ('clipPath','mask'):
   if any('url(' in v.lower() for child in el.iter() for v in child.attrib.values()):raise Denied()
 for key in ('width','height'):
  if key in root.attrib:
   v=root.attrib[key]
   if not re.fullmatch(r'(?:[0-9]+(?:\.[0-9]+)?)(?:px|pt|mm|cm|in|%)?',v):raise Denied()
   if float(re.match(r'[0-9.]+',v)[0])>4096:raise Denied()
 if 'viewBox' in root.attrib:
  try:nums=[float(x) for x in re.split(r'[\s,]+',root.attrib['viewBox'].strip())]
  except ValueError:raise Denied() from None
  if len(nums)!=4 or not all(abs(n)<=100000 for n in nums) or min(nums[2:])<=0:raise Denied()
 return raw
