#!/usr/bin/env python

import random
import string
import sys

##########################################################################
# generates NUM_RULE number of basic modsecurity rules (for main.conf)
#
# ./modsec-rulegen.py 1000 > main-1000rule.conf
# You then need to make the first line of main-1000rule.conf:
#
#       Include "/fsserver/modsec/modsecurity.conf"
###########################################################################

#RULE_TEMPLATE= 'SecRule ARGS:testparam "@contains test" "id:1234,deny,status:403"'
RULE_TEMPLATE= 'SecRule ARGS:testparam "@contains %s" "id:%d,deny,status:403"'

def random_string(size):
    return ''.join([random.choice(string.letters) for i in xrange(size)])


def main(argv):
    if len(argv) != 2:
        sys.stderr.write('./rulegen NUM_RULES\n')
        sys.exit(1)

    nrules = int(argv[1])

    for i in xrange(nrules):
        test_id = i + 1
        bad_string = random_string(6)
        rule = RULE_TEMPLATE % (bad_string, test_id)
        print rule


if __name__ == '__main__':
    main(sys.argv)

