#!/usr/bin/env python
# -*- coding: utf-8 -*-

# base import {{
import os
from os.path import expanduser
import sys
reload(sys)
sys.setdefaultencoding('utf-8')
import argparse
import yaml
import re
import logging
# }}

# base {{
# default vars
scriptName          = os.path.basename(sys.argv[0]).split('.')[0]
homeDir             = expanduser("~")
defaultConfigFiles  = [
    '/etc/' + scriptName + '/config.yaml',
    homeDir + '/.' + scriptName + '.yaml',
]
cfg = {
    'logFile':          '/var/log/' + scriptName + '/' + scriptName + '.log',
    'logFile':          'stdout',
    'logLevel':         'info',
}

# parse args
parser = argparse.ArgumentParser( description = '''
default config files: %s

''' % ', '.join(defaultConfigFiles),
formatter_class=argparse.RawTextHelpFormatter
)
parser.add_argument(
    '-c',
    '--config',
    help = 'path to config file',
)
args = parser.parse_args()
argConfigFile = args.config

# get settings
if argConfigFile:
    if os.path.isfile(argConfigFile):
        try:
            with open(argConfigFile, 'r') as ymlfile:
                cfg.update(yaml.load(ymlfile))
        except Exception as e:
            logging.error('failed load config file: "%s", error: "%s"', argConfigFile, e)
            exit(1)
else:
    for configFile in defaultConfigFiles:
        if os.path.isfile(configFile):
            try:
                with open(configFile, 'r') as ymlfile:
                    try:
                        cfg.update(yaml.load(ymlfile))
                    except Exception as e:
                        logging.warning('skipping load load config file: "%s", error "%s"', configFile, e)
                        continue
            except:
                continue

# fix logDir
cfg['logDir'] = os.path.dirname(cfg['logFile'])
if cfg['logDir'] == '':
    cfg['logDir'] = '.'
# }}

if __name__ == "__main__":
    # basic config {{
    for dirPath in [
        cfg['logDir'],
    ]:
        try:
            os.makedirs(dirPath)
        except OSError:
            if not os.path.isdir(dirPath):
                raise

    # выбор логлевела
    if re.match(r"^(warn|warning)$", cfg['logLevel'], re.IGNORECASE):
        logLevel = logging.WARNING
    elif re.match(r"^debug$", cfg['logLevel'], re.IGNORECASE):
        logLevel = logging.DEBUG
    else:
        logging.getLogger("urllib3").setLevel(logging.WARNING)
        logging.getLogger("requests").setLevel(logging.WARNING)
        logLevel = logging.INFO

    if cfg['logFile'] == 'stdout':
        logging.basicConfig(
            level       = logLevel,
            format      = '%(asctime)s\t%(levelname)s\t%(message)s',
            datefmt     = '%Y-%m-%dT%H:%M:%S',
        )
    else:
        logging.basicConfig(
            filename    = cfg['logFile'],
            level       = logLevel,
            format      = '%(asctime)s\t%(levelname)s\t%(message)s',
            datefmt     = '%Y-%m-%dT%H:%M:%S',
        )
    # }}

    print 'test'
