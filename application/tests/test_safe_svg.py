import unittest
from uniion.adapters.safe_svg import validate
from uniion.core.contracts import Denied
SVG='<svg xmlns="http://www.w3.org/2000/svg" width="300" height="100" viewBox="0 0 300 100">{}</svg>'
class SafeSVGTests(unittest.TestCase):
 def test_static_paths_gradient_text(self):
  data=SVG.format('<defs><linearGradient id="g"><stop offset="0" stop-color="#173861"/><stop offset="1" stop-color="#d45224"/></linearGradient></defs><rect width="300" height="100" fill="url(#g)"/><text x="20" y="55" fill="white">SECTION FICTIVE</text>').encode();self.assertEqual(validate(data),data)
 def test_active_remote_and_entity_refused(self):
  attacks=['<script>alert(1)</script>','<foreignObject/>','<image href="https://example.invalid/a"/>','<use href="#x"/>','<rect onload="alert(1)"/>','<rect fill="url(https://example.invalid/a)"/>','<rect style="fill:u\\72l(https://example.invalid/a)"/>','<style>@import "https://example.invalid/a";</style>','<animate attributeName="x"/>','<rect fill="url(#missing)"/>','<mask id="a"><rect mask="url(#a)"/></mask>']
  for content in attacks:
   with self.subTest(content=content),self.assertRaises(Denied):validate(SVG.format(content).encode())
  for data in [b'<!DOCTYPE svg [<!ENTITY x SYSTEM "file:///etc/passwd">]>'+SVG.format('&x;').encode(),b'<?xml-stylesheet href="https://example.invalid/x"?>'+SVG.format('').encode(),b'<svg/>']:
   with self.assertRaises(Denied):validate(data)
 def test_bounds(self):
  for data in [SVG.format('<g>'*40+'</g>'*40),SVG.format('<path/>'*5001),SVG.format('').replace('width="300"','width="999999"')]:
   with self.assertRaises(Denied):validate(data.encode())
