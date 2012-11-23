#!/usr/bin/env python
# -*- coding: utf-8 -*-
'''
verifica se o IP do servidor de e-mail está em uma blacklist, baseado no
http://www.blacklistalert.org
'''
DOMAIN = 'google.com'

import urllib2
import sys

# add proxy
proxy_support = urllib2.ProxyHandler({"http" : "http://www-gw.ucs.br:3128"})
opener = urllib2.build_opener(proxy_support)
urllib2.install_opener(opener)

from sgmllib import SGMLParser
def get_blacklist(html):
    '''
    Search for a "<a>" with "target=_new" and not "whitelisted.org"
    Return a set() of links
    # src: http://diveintopython.org/html_processing/extracting_data.html
    '''
    class URLLister(SGMLParser):
        def reset(self):
            SGMLParser.reset(self)
            self.urls = []

        def start_a(self, attrs):
            attrs = dict(attrs)
            if 'target' in attrs \
                    and '_new' == attrs['target'] \
                    and 'whitelisted.org' not in attrs['href']:
                self.urls.append(attrs['href'])

    parser = URLLister()
    parser.feed(html)
    return set(parser.urls)


result = urllib2.urlopen('http://www.blacklistalert.org/', 'q=%s' % DOMAIN)
lines = result.readlines()
urls = get_blacklist(''.join(lines))

if urls:
    print 'CRITICAL: %s blacklisted! %s' % (DOMAIN, ' '.join(urls))
    sys.exit(2)

print 'OK: %s not blacklisted' % DOMAIN

