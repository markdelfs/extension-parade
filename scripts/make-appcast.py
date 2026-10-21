#!/usr/bin/env python3
"""Create the appcast after signing the final ZIP with Sparkle's sign_update."""
import argparse
import datetime
import email.utils
import pathlib
import xml.etree.ElementTree as ET
p = argparse.ArgumentParser()
p.add_argument('--signature', required=True, help='EdDSA signature from sign_update -p')
p.add_argument('--archive', type=pathlib.Path, required=True)
p.add_argument('--output', type=pathlib.Path, required=True)
a = p.parse_args()
ns = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', ns)
r = ET.Element('rss', {'version': '2.0'})
c = ET.SubElement(r, 'channel')
ET.SubElement(c, 'title').text = 'Extension Parade Updates'
ET.SubElement(c, 'link').text = 'https://github.com/markdelfs/extension-parade'
ET.SubElement(c, 'description').text = 'Extension Parade for macOS'
i = ET.SubElement(c, 'item')
ET.SubElement(i, 'title').text = 'Extension Parade 1.0.1'
ET.SubElement(i, 'pubDate').text = email.utils.format_datetime(datetime.datetime.now(datetime.timezone.utc))
ET.SubElement(i, f'{{{ns}}}version').text = '2'
ET.SubElement(i, f'{{{ns}}}shortVersionString').text = '1.0.1'
ET.SubElement(i, f'{{{ns}}}minimumSystemVersion').text = '13.0'
ET.SubElement(i, 'description').text = 'The classic extension parade above your Dock. Includes replay, looping, size and speed controls, and optional launch at login.'
ET.SubElement(i, 'enclosure', {'url': 'https://github.com/markdelfs/extension-parade/releases/download/v1.0.1/Extension-Parade-1.0.1.zip', 'length': str(a.archive.stat().st_size), 'type': 'application/octet-stream', f'{{{ns}}}edSignature': a.signature})
ET.indent(r)
ET.ElementTree(r).write(a.output, encoding='utf-8', xml_declaration=True)
