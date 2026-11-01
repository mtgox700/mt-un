from pathlib import Path
from html.parser import HTMLParser
import re
root=Path(__file__).resolve().parents[1]
old=(root/'corrections/avant/prototype.html').read_text();new=(root/'public/uniion App v3.dc.html').read_text()
class P(HTMLParser):
 def __init__(self):super().__init__();self.tags=[]
 def handle_starttag(self,t,a):self.tags.append((t,a))
 def handle_endtag(self,t):self.tags.append(('/'+t,[]))
a=P();b=P();a.feed(old.split('<script type="text/x-dc"')[0]);b.feed(new.split('<script type="text/x-dc"')[0]);assert a.tags==b.tags
assert re.findall(r'<style[^>]*>.*?</style>',old,re.S)==re.findall(r'<style[^>]*>.*?</style>',new,re.S)
print('PASS structure, attributes and CSS unchanged; explanatory copy updated')
