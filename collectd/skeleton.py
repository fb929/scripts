#!/usr/bin/env python
# -*- coding: utf-8 -*-

import collectd

PLUGIN_NAME = 'filebeat'
cfg = dict()

collectd.info('%s: loading python plugin' % (PLUGIN_NAME))

def configure(configobj):
    collectd.info('%s: configure with: key=%s, children=%r' % (PLUGIN_NAME, configobj.key, configobj.children))
    config = {c.key: c.values for c in configobj.children}
    cfg.update(config)
    collectd.info('%s: configured with %r' % (PLUGIN_NAME, cfg))

def read(data=None):
    from random import random
    collectd.info('%s: reading data (data=%r)' % (PLUGIN_NAME, data))
    vl = collectd.Values(type='gauge')
    vl.plugin = PLUGIN_NAME
    vl.values = [ (int(random() * 3)) % 15 ]
    collectd.info('%s: read values: %r' % (PLUGIN_NAME, vl.values))
    vl.dispatch()

def write(vl, data=None):
    collectd.info('writing data (vl=%r, data=%r)' % (vl, data))
    for v in vl.values:
        collectd.debug("%s: writing %s (%s): %f" % (PLUGIN_NAME, vl.plugin, vl.type, v))

#
# register our callbacks to collectd
#

collectd.register_config(configure)
collectd.register_read(read)
#collectd.register_write(write)
